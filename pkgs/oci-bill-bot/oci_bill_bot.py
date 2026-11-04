#!/usr/bin/env python3
"""
oci-bill-bot: 基于 QQ 官方 WebSocket 的 OCI 每日账单与防扣费巡检机器人
"""

from __future__ import annotations

import argparse
import asyncio
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from collections import defaultdict, deque
from typing import Any
from zoneinfo import ZoneInfo

import oci
import requests
import websockets
from cryptography.hazmat.primitives import serialization

DEFAULT_SOPS_KEY_PATH = "/run/secrets/oci_api_key"
DEFAULT_SOPS_USER_PATH = "/run/secrets/oci_user_ocid"
DEFAULT_SOPS_TENANCY_PATH = "/run/secrets/oci_tenancy_ocid"
DEFAULT_SOPS_QQ_APPID_PATH = "/run/secrets/qq_bot_appid"
DEFAULT_SOPS_QQ_SECRET_PATH = "/run/secrets/qq_bot_secret"
DEFAULT_SOPS_QQ_OWNER_PATH = "/run/secrets/qq_bot_owner_openid"
DEFAULT_REGION = "ap-singapore-1"
DEFAULT_STATE_FILE = "/var/lib/oci-bill-bot/state.json"

QQ_TOKEN_URL = "https://bots.qq.com/app/getAppAccessToken"
QQ_API_BASE = "https://api.sgroup.qq.com"
QQ_ATTACHMENTS_DIR = "/home/ruixi/.cache/qq_attachments"

# Intents: GROUP_AND_C2C_EVENT (1<<25) | PUBLIC_GUILD_MESSAGES (1<<30) | DIRECT_MESSAGE (1<<12)
DEFAULT_INTENTS = (1 << 25) | (1 << 30) | (1 << 12)


def log(msg: str) -> None:
    now_str = datetime.datetime.now(ZoneInfo("Asia/Singapore")).strftime(
        "%Y-%m-%d %H:%M:%S"
    )
    print(f"[{now_str}] {msg}", flush=True)


def read_secret_text(path: str) -> str | None:
    expanded = os.path.expanduser(path)
    if os.path.exists(expanded):
        try:
            with open(expanded, "r", encoding="utf-8") as f:
                return f.read().strip()
        except OSError:
            return None
    return None


def find_sops_yaml() -> str | None:
    candidates = [
        os.environ.get("OCI_SECRETS_YAML", ""),
        os.path.abspath("secrets/secrets.yaml"),
        os.path.expanduser("~/flakes/secrets/secrets.yaml"),
        "/home/ruixi/flakes/secrets/secrets.yaml",
    ]
    for path in candidates:
        if path and os.path.exists(path):
            return path
    return None


def sops_decrypt_key(yaml_path: str | None, key_name: str) -> str | None:
    if not yaml_path or not os.path.exists(yaml_path):
        return None
    env = os.environ.copy()
    user_age_key = os.path.expanduser("~/.config/sops/age/keys.txt")
    if (
        "SOPS_AGE_KEY_FILE" not in env
        and "SOPS_AGE_KEY" not in env
        and not os.path.exists(user_age_key)
        and os.path.exists("/var/lib/sops-nix/keys.txt")
    ):
        env["SOPS_AGE_KEY_FILE"] = "/var/lib/sops-nix/keys.txt"
    try:
        res = subprocess.run(
            ["sops", "-d", "--extract", f'["{key_name}"]', yaml_path],
            capture_output=True,
            text=True,
            check=True,
            env=env,
        )
        return res.stdout.strip()
    except Exception:
        return None


def get_secret(sops_path: str, key_name: str, env_name: str) -> str:
    val = (
        os.environ.get(env_name)
        or read_secret_text(sops_path)
        or sops_decrypt_key(find_sops_yaml(), key_name)
    )
    if not val:
        raise RuntimeError(f"未能读取机密配置 {key_name} ({sops_path})")
    return val


def calc_oci_fingerprint(pem_bytes: bytes) -> str:
    priv_key = serialization.load_pem_private_key(pem_bytes, password=None)
    pub_der = priv_key.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    md5_hex = hashlib.md5(pub_der).hexdigest()
    return ":".join(md5_hex[i : i + 2] for i in range(0, len(md5_hex), 2))


def get_oci_config() -> dict[str, Any]:
    pem_str = get_secret(DEFAULT_SOPS_KEY_PATH, "oci_api_key", "OCI_KEY_CONTENT")
    user_ocid = get_secret(DEFAULT_SOPS_USER_PATH, "oci_user_ocid", "OCI_USER_OCID")
    tenancy_ocid = get_secret(
        DEFAULT_SOPS_TENANCY_PATH, "oci_tenancy_ocid", "OCI_TENANCY_OCID"
    )
    region = os.environ.get("OCI_REGION", DEFAULT_REGION)
    fingerprint = calc_oci_fingerprint(pem_str.encode("utf-8"))
    config = {
        "user": user_ocid,
        "fingerprint": fingerprint,
        "tenancy": tenancy_ocid,
        "region": region,
        "key_content": pem_str,
    }
    oci.config.validate_config(config)
    return config


def build_oci_bill_report() -> tuple[str, float]:
    """
    查询 OCI Usage API 与存储/IP 资源状态，生成简洁明了的账单与防扣费巡检报告。
    返回 (report_text, today_or_latest_cost)。
    """
    config = get_oci_config()
    tenancy = config["tenancy"]
    usage_client = oci.usage_api.UsageapiClient(config)
    vn_client = oci.core.VirtualNetworkClient(config)
    bs_client = oci.core.BlockstorageClient(config)
    id_client = oci.identity.IdentityClient(config)

    now_utc = datetime.datetime.now(datetime.timezone.utc)
    month_start = datetime.datetime(
        now_utc.year, now_utc.month, 1, 0, 0, 0, tzinfo=datetime.timezone.utc
    )
    tomorrow_start = datetime.datetime(
        now_utc.year, now_utc.month, now_utc.day, 0, 0, 0, tzinfo=datetime.timezone.utc
    ) + datetime.timedelta(days=1)

    details = oci.usage_api.models.RequestSummarizedUsagesDetails(
        tenant_id=tenancy,
        time_usage_started=month_start,
        time_usage_ended=tomorrow_start,
        granularity="DAILY",
        query_type="COST",
        group_by=["service", "skuName"],
    )
    usage_data = usage_client.request_summarized_usages(details).data

    by_service: dict[str, float] = defaultdict(float)
    by_day: dict[str, float] = defaultdict(float)
    nonzero_skus: list[str] = []
    currency = "SGD"
    month_total = 0.0

    for item in usage_data.items:
        amt = float(item.computed_amount or 0.0)
        svc = item.service or "Other"
        day_str = item.time_usage_started.strftime("%Y-%m-%d")
        if item.currency and item.currency.strip():
            currency = item.currency.strip()
        by_service[svc] += amt
        by_day[day_str] += amt
        month_total += amt
        if amt > 0.00001:
            sku = item.sku_name or svc
            nonzero_skus.append(f"  {day_str} {sku}: {amt:.4f} {currency}")

    today_str = now_utc.strftime("%Y-%m-%d")
    yesterday_str = (now_utc - datetime.timedelta(days=1)).strftime("%Y-%m-%d")
    today_cost = by_day.get(today_str, 0.0)
    yesterday_cost = by_day.get(yesterday_str, 0.0)

    # 防扣费资源巡检：检查引导卷/块存储容量与未绑定预留 IP
    total_gb = 0
    vol_count = 0
    try:
        ads = id_client.list_availability_domains(tenancy).data
        for ad in ads:
            bvs = bs_client.list_boot_volumes(
                availability_domain=ad.name, compartment_id=tenancy
            ).data
            for bv in bvs:
                if bv.lifecycle_state not in ("TERMINATED", "TERMINATING"):
                    total_gb += int(bv.size_in_gbs or 0)
                    vol_count += 1
        vols = bs_client.list_volumes(compartment_id=tenancy).data
        for v in vols:
            if v.lifecycle_state not in ("TERMINATED", "TERMINATING"):
                total_gb += int(v.size_in_gbs or 0)
                vol_count += 1
    except Exception:
        pass

    reserved_ips = vn_client.list_public_ips(
        scope="REGION", compartment_id=tenancy, lifetime="RESERVED"
    ).data
    unbound_ips = [ip.ip_address for ip in reserved_ips if not ip.private_ip_id]
    bound_ips = [ip.ip_address for ip in reserved_ips if ip.private_ip_id]

    local_date = datetime.datetime.now(ZoneInfo("Asia/Singapore")).strftime("%Y-%m-%d")
    lines = [
        f"### OCI 账单日报 ({local_date})",
        f"- **本月累计**: `{month_total:.4f} {currency}`",
        f"- **今日费用**: `{today_cost:.4f} {currency}` (昨日: `{yesterday_cost:.4f} {currency}`)",
        "",
        "**服务明细 (本月)**",
    ]
    if by_service:
        for svc, amt in sorted(by_service.items()):
            lines.append(f"- {svc}: `{amt:.4f} {currency}`")
    else:
        lines.append("- 暂无账单记录")

    if nonzero_skus:
        lines.append("")
        lines.append("**非零扣费记录**")
        for item_line in nonzero_skus[-5:]:
            lines.append(f"- {item_line.strip()}")

    lines.append("")
    lines.append("**防扣费巡检**")
    storage_warn = " **[超免费额度!]**" if total_gb > 200 else ""
    lines.append(f"- **存储占用**: `{total_gb}/200 GB` ({vol_count} 个卷){storage_warn}")
    if unbound_ips:
        lines.append(
            f"- **闲置预留IP**: `{len(unbound_ips)}` 个 (`{', '.join(unbound_ips)}`) — 发 `/oci_clean` 可释放"
        )
    else:
        bound_str = ", ".join(bound_ips) if bound_ips else "无"
        lines.append(f"- **闲置预留IP**: `0` 个 (在用: `{bound_str}`)")

    if today_cost > 0.0001 or total_gb > 200 or unbound_ips:
        lines.append("- **结论**: **存在潜在计费项，请留意！**")
    else:
        lines.append("- **结论**: **正常 (今日 0 扣费)**")

    return "\n".join(lines), today_cost


ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
LOG_PREFIX_RE = re.compile(r"^\[(INFO|OK|WARN|ERR)\]\s*")
FILE_LINK_RE = re.compile(r"\[([^\]]+)\]\(file://([^\)]+)\)")
RAW_URL_RE = re.compile(r"(https?://[^\s\)>]+)")

DEFAULT_AGY_MODEL = "gemini-4-argon-medium"
DEFAULT_AGY_EFFORT = "medium"
DEFAULT_AGY_CWD = "/home/ruixi"

AGY_EFFORT_LEVELS = ("low", "medium", "high", "xhigh", "max")

AGY_MODEL_CATALOG: list[tuple[str, str]] = [
    ("gemini-4-argon-low", "Gemini 4 Argon (Low)"),
    ("gemini-4-argon-medium", "Gemini 4 Argon (Medium)"),
    ("gemini-4-argon-high", "Gemini 4 Argon (High)"),
    ("gemini-3.8-flash-low", "Gemini 3.8 Flash (Low)"),
    ("gemini-3.8-flash-medium", "Gemini 3.8 Flash (Medium)"),
    ("gemini-3.8-flash-high", "Gemini 3.8 Flash (High)"),
    ("claude-opus-5-5-low", "Claude Opus 5.5 (Low)"),
    ("claude-opus-5-5-medium", "Claude Opus 5.5 (Medium)"),
    ("claude-opus-5-5-high", "Claude Opus 5.5 (High)"),
    ("claude-sonnet-5-5-low", "Claude Sonnet 5.5 (Low)"),
    ("claude-sonnet-5-5-medium", "Claude Sonnet 5.5 (Medium)"),
    ("claude-sonnet-5-5-high", "Claude Sonnet 5.5 (High)"),
    ("gpt-oss-120b-medium", "GPT-OSS 120B (Medium)"),
]

AGY_MODEL_FAMILIES: dict[str, str] = {
    "argon": "gemini-4-argon",
    "gemini": "gemini-4-argon",
    "gemini-4-argon": "gemini-4-argon",
    "flash": "gemini-3.8-flash",
    "gemini-3.8-flash": "gemini-3.8-flash",
    "opus": "claude-opus-5-5",
    "claude-opus": "claude-opus-5-5",
    "claude-opus-5-5": "claude-opus-5-5",
    "sonnet": "claude-sonnet-5-5",
    "claude-sonnet": "claude-sonnet-5-5",
    "claude-sonnet-5-5": "claude-sonnet-5-5",
}

AGY_MODEL_ALIASES: dict[str, str] = {
    "argon-low": "gemini-4-argon-low",
    "argon-medium": "gemini-4-argon-medium",
    "argon-high": "gemini-4-argon-high",
    "flash-low": "gemini-3.8-flash-low",
    "flash-medium": "gemini-3.8-flash-medium",
    "flash-high": "gemini-3.8-flash-high",
    "opus-low": "claude-opus-5-5-low",
    "opus-medium": "claude-opus-5-5-medium",
    "opus-high": "claude-opus-5-5-high",
    "sonnet-low": "claude-sonnet-5-5-low",
    "sonnet-medium": "claude-sonnet-5-5-medium",
    "sonnet-high": "claude-sonnet-5-5-high",
    "gpt": "gpt-oss-120b-medium",
    "gpt-oss": "gpt-oss-120b-medium",
}


def _tier_for_effort(effort: str) -> str:
    if effort == "low":
        return "low"
    if effort in ("high", "xhigh", "max"):
        return "high"
    return "medium"


def resolve_agy_model(raw_model: str, current_effort: str) -> tuple[str, str | None]:
    """
    解析用户输入的模型名或简写，返回 (model_id, inferred_effort_or_None)。
    """
    key = raw_model.strip().lower()
    if key in AGY_MODEL_ALIASES:
        resolved = AGY_MODEL_ALIASES[key]
    elif key in AGY_MODEL_FAMILIES:
        prefix = AGY_MODEL_FAMILIES[key]
        tier = _tier_for_effort(current_effort)
        resolved = f"{prefix}-{tier}"
    else:
        resolved = key

    inferred_effort: str | None = None
    if resolved.endswith("-low"):
        inferred_effort = "low"
    elif resolved.endswith("-medium"):
        inferred_effort = "medium"
    elif resolved.endswith("-high") and current_effort not in ("high", "xhigh", "max"):
        inferred_effort = "high"
    return resolved, inferred_effort


def sync_model_with_effort(current_model: str, new_effort: str) -> str:
    """
    当切换 effort 时，若当前模型属于支持 -low/-medium/-high 的家族，自动同步其后缀。
    """
    tier = _tier_for_effort(new_effort)
    for suffix in ("-low", "-medium", "-high"):
        if current_model.endswith(suffix):
            base = current_model[: -len(suffix)]
            candidate = f"{base}-{tier}"
            known_ids = {m[0] for m in AGY_MODEL_CATALOG}
            if candidate in known_ids:
                return candidate
    return current_model


def _short_path(path: str) -> str:
    home = os.path.expanduser("~")
    if path == home:
        return "~"
    if path.startswith(home + "/"):
        return "~/" + path[len(home) + 1 :]
    return path


def _sanitize_agy_markdown(text: str) -> str:
    """
    清理 ANSI 序列并将 file:// 链接转为普通代码标记，防止触发 QQ 机器人链接拦截。
    """
    cleaned = _strip_ansi(text).strip()

    def _repl_file_link(m: re.Match[str]) -> str:
        label = m.group(1).strip()
        if label.startswith("`") and label.endswith("`"):
            return label
        return f"`{label}`"

    cleaned = FILE_LINK_RE.sub(_repl_file_link, cleaned)
    return cleaned


def _neutralize_urls(text: str) -> str:
    """
    当消息因包含未报备外部 URL 被 QQ API 拦截时，将 http(s):// 中的点号转义后重试。
    """
    return RAW_URL_RE.sub(lambda m: m.group(1).replace(".", "[.]"), text)


def _strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


AGY_TIMEOUT_SECONDS = 600
AGY_CHUNK_CHARS = 1200
AGY_MAX_CHUNKS = 4

TYPST_BIN = "typst"

KNOWN_COMMANDS = {
    "help",
    "oci_bill",
    "oci_ip",
    "oci_roll",
    "oci_check",
    "oci_bind",
    "oci_clean",
    "oci_link",
    "oci_status",
    "agy",
    "agy_new",
    "agy_cd",
    "agy_model",
    "agy_models",
    "agy_effort",
    "agy_status",
    "agy_stop",
    "agy_reset",
    "agy_queue",
    "agy_q",
    "agy_clear",
    "agy_clean",
    "render",
    "render_last",
    "r",
}


def get_typst_cmd() -> str:
    if os.path.isabs(TYPST_BIN) and os.path.exists(TYPST_BIN):
        return TYPST_BIN
    found = shutil.which(TYPST_BIN)
    if found:
        return found
    try:
        for entry in os.scandir("/nix/store"):
            if "-typst-" in entry.name or entry.name.startswith("typst-"):
                p = os.path.join(entry.path, "bin", "typst")
                if os.path.exists(p) and os.access(p, os.X_OK):
                    return p
    except Exception:
        pass
    return "typst"


def find_typst_font_paths() -> list[str]:
    candidates = [
        "/run/current-system/sw/share/fonts",
        "/run/current-system/sw/share/X11/fonts",
        "/var/run/current-system/sw/share/fonts",
    ]
    found = [p for p in candidates if os.path.isdir(p)]
    try:
        for entry in os.scandir("/nix/store"):
            if "source-han-sans" in entry.name:
                for sub in ("truetype", "opentype"):
                    p = os.path.join(entry.path, "share", "fonts", sub)
                    if os.path.isdir(p) and p not in found:
                        found.append(p)
    except Exception:
        pass
    return found


def md_to_typst(md: str) -> str:
    """
    将 Markdown 文本转换为 Typst 语法，保留标题、粗体、列表、代码块，并处理 Typst 特殊字符转义。
    """
    lines = md.splitlines()
    out: list[str] = []
    in_code_block = False
    in_quote = False
    quote_lines: list[str] = []

    def flush_quote() -> None:
        nonlocal in_quote, quote_lines
        if quote_lines:
            content = " \n".join(quote_lines)
            out.append(
                f'#block(stroke: (left: 3pt + rgb("#0969da")), inset: (left: 10pt, y: 5pt), '
                f'fill: rgb("#f6f8fa"), radius: (right: 4pt))[{content}]'
            )
            quote_lines = []
        in_quote = False

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("```"):
            flush_quote()
            in_code_block = not in_code_block
            out.append(line)
            continue
        if in_code_block:
            out.append(line)
            continue

        if stripped.startswith(">"):
            in_quote = True
            q_text = stripped.lstrip(">").strip()
            q_text = re.sub(r"\*\*(.+?)\*\*", r"*\1*", q_text)
            q_text = re.sub(r"(?<!\\)\$", r"\$", q_text)
            q_text = re.sub(r"(?<!\\)@", r"\@", q_text)
            q_text = re.sub(r"<([^>]+)>", r"[\1]", q_text)
            quote_lines.append(q_text)
            continue
        elif in_quote:
            flush_quote()

        if re.match(r"^(\-{3,}|\*{3,}|_{3,})$", stripped):
            out.append('#line(length: 100%, stroke: 0.8pt + rgb("#eaeef2"))')
            continue

        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            level = len(m.group(1))
            out.append("=" * level + " " + m.group(2))
            continue

        code_spans: list[str] = []

        def save_code(match: re.Match[str]) -> str:
            code_spans.append(match.group(0))
            return f"\x00CODE_{len(code_spans) - 1}\x00"

        l = re.sub(r"`[^`]+`", save_code, line)
        l = re.sub(r"\*\*(.+?)\*\*", r"*\1*", l)
        l = re.sub(r"^\s*\d+\.\s+", "+ ", l)
        l = re.sub(r'\[([^\]]+)\]\((https?://[^\)]+)\)', r'#link("\2")[\1]', l)
        l = re.sub(r"(?<!\\)\$", r"\$", l)
        l = re.sub(r"(?<!\\)@", r"\@", l)
        l = re.sub(r"(?<!\\)#", r"\#", l)
        l = re.sub(r"<([^>]+)>", r"[\1]", l)

        for i, span in enumerate(code_spans):
            l = l.replace(f"\x00CODE_{i}\x00", span)

        out.append(l)

    flush_quote()
    return "\n".join(out)


def extract_quoted_text(raw_event: dict[str, Any] | None) -> str | None:
    """
    从 QQ 接收到的原始事件 Payload 中提取被引用的消息文本（支持 C2C、群聊及各种引用字段结构）。
    """
    if not raw_event:
        return None

    # 1. QQ 官方标准 msg_elements (C2C 与 群聊引用)
    msg_elements = raw_event.get("msg_elements")
    if isinstance(msg_elements, list):
        texts: list[str] = []
        for elem in msg_elements:
            if isinstance(elem, dict):
                text_elem = elem.get("text_element") or {}
                cnt = text_elem.get("content")
                if cnt and cnt.strip():
                    texts.append(cnt.strip())
        if texts:
            return "\n".join(texts).strip()

    # 2. message_reference
    ref = raw_event.get("message_reference")
    if isinstance(ref, dict):
        if ref.get("content"):
            return str(ref["content"]).strip()
        msg_obj = ref.get("message")
        if isinstance(msg_obj, dict) and msg_obj.get("content"):
            return str(msg_obj["content"]).strip()

    # 3. 常见扩展或客户端自定引用字段
    for k in ("quoted_message", "ref_msg", "quote", "reply"):
        val = raw_event.get(k)
        if isinstance(val, dict) and val.get("content"):
            return str(val["content"]).strip()
        elif isinstance(val, str) and val.strip():
            return val.strip()

    return None


def _parse_agy_json(raw_text: str) -> dict[str, Any] | None:
    text = raw_text.strip()
    if not text:
        return None
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            return data
    except Exception:
        pass

    # 若输出中夹带了其他日志，从最后一行或倒找有效 JSON 对象
    for line in reversed(text.splitlines()):
        line = line.strip()
        if line.startswith("{") and line.endswith("}"):
            try:
                data = json.loads(line)
                if isinstance(data, dict) and "response" in data:
                    return data
            except Exception:
                continue

    last_brace = text.rfind("}")
    if last_brace != -1:
        first_brace = text.find("{")
        if first_brace != -1 and first_brace < last_brace:
            candidate = text[first_brace : last_brace + 1]
            try:
                data = json.loads(candidate)
                if isinstance(data, dict):
                    return data
            except Exception:
                pass
    return None


def _split_markdown_chunks(text: str, chunk_size: int = AGY_CHUNK_CHARS) -> list[str]:
    text = text.strip()
    if not text:
        return []
    if len(text) <= chunk_size:
        return [text]

    chunks: list[str] = []
    current_lines: list[str] = []
    current_len = 0
    in_code_block = False
    fence_tag = ""

    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        is_fence = stripped.startswith("```")

        if current_len + len(line) > chunk_size and current_lines:
            if in_code_block:
                current_lines.append("```\n")
            chunks.append("".join(current_lines).strip())
            current_lines = []
            current_len = 0
            if in_code_block:
                current_lines.append(f"```{fence_tag}\n")
                current_len += len(current_lines[-1])

        if is_fence:
            if in_code_block:
                in_code_block = False
                fence_tag = ""
            else:
                in_code_block = True
                fence_tag = stripped[3:].strip()

        current_lines.append(line)
        current_len += len(line)

    if current_lines:
        if in_code_block:
            current_lines.append("\n```\n")
        chunks.append("".join(current_lines).strip())
    return [c for c in chunks if c]



def _run_oci_ip(args: list[str], timeout: int = 180) -> tuple[int, str]:
    res = subprocess.run(
        ["oci-ip", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    combined = (res.stdout or "") + (
        ("\n" + res.stderr) if res.stderr else ""
    )
    return res.returncode, _strip_ansi(combined).strip()


def _format_cli_output(title: str, raw_out: str) -> list[str]:
    lines = [f"### {title}"]
    for raw in raw_out.splitlines():
        s = LOG_PREFIX_RE.sub("", raw.strip()).strip()
        if not s:
            if len(lines) > 1 and lines[-1] != "":
                lines.append("")
            continue
        if s.startswith("预留 IP ("):
            lines.append(f"\n**{s}**")
        elif ":" in s and not s.startswith("http"):
            k, v = s.split(":", 1)
            lines.append(f"- **{k.strip()}**: `{v.strip()}`")
        else:
            lines.append(f"- `{s}`")
    while lines and lines[-1] == "":
        lines.pop()
    return lines


def build_oci_ip_summary() -> str:
    code, out = _run_oci_ip(["status"], timeout=30)
    if code != 0:
        raise RuntimeError(out or "oci-ip status 执行失败")
    return "\n".join(_format_cli_output("OCI 预留 IP 状态", out))


def cleanup_unbound_ips() -> str:
    code, out = _run_oci_ip(["cleanup"], timeout=60)
    if code != 0:
        raise RuntimeError(out or "oci-ip cleanup 执行失败")
    return "\n".join(_format_cli_output("预留 IP 清理", out))


def build_singbox_links(ip_override: str | None = None) -> str:
    cmd = ["singbox-links"]
    if ip_override:
        cmd.append(ip_override)
    res = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=True,
        timeout=10,
    )
    lines = ["### Sing-box 节点"]
    for raw in res.stdout.strip().splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            lines.append(f"**{line.lstrip('#').strip()}**")
        else:
            lines.extend(["```text", line, "```"])
    return "\n".join(lines)


def roll_candidate_oci_ip(prefixes: list[str] | None = None) -> str:
    """步骤 1 (刷): 直接调用 oci-ip roll 刷出候选预留 IP（不换绑）。"""
    cli_args = [
        "roll",
        "-n",
        "10",
        "--check-reputation",
        "--no-abuser",
        "--max-risk",
        "50",
    ]
    if prefixes:
        for p in prefixes:
            cli_args.extend(["--prefix", p])

    code, out = _run_oci_ip(cli_args, timeout=240)
    if code != 0:
        raise RuntimeError(out or "oci-ip roll 未刷出符合条件的候选 IP")

    lines = _format_cli_output("OCI 刷出候选预留 IP", out)
    lines.extend(
        [
            "",
            "**下一步指令**",
            "- `/oci_check` : 检测候选与当前 IP 纯净度及国内连通性",
            "- `/oci_bind` : 将该候选 IP 正式换绑至服务器并释放旧 IP",
            "- `/oci_clean` : 放弃并释放该候选 IP（防闲置计费）",
        ]
    )
    return "\n".join(lines)


def check_oci_ips(target_ip: str | None = None) -> str:
    """步骤 2 (检查): 直接调用 oci-ip check 检测候选与当前预留 IP。"""
    cli_args = ["check", "-p", "443"]
    if target_ip:
        cli_args.append(target_ip)
    _, out = _run_oci_ip(cli_args, timeout=90)
    if not out:
        raise RuntimeError("oci-ip check 未返回检测结果")
    return "\n".join(_format_cli_output("OCI IP 质量检测", out))


def bind_candidate_oci_ip(target_ip: str | None = None) -> tuple[bool, str]:
    """步骤 3 (换): 直接调用 oci-ip bind --delete-old 完成换绑并清理旧 IP。"""
    cli_args = ["bind", "--delete-old"]
    if target_ip:
        cli_args.extend(["--ip", target_ip])

    code, out = _run_oci_ip(cli_args, timeout=120)
    if code == 2:
        return (
            False,
            "### 暂无待绑定的候选 IP\n"
            "- 当前账号下没有未绑定的候选预留 IP，**现有公网 IP 未做任何改动**。\n"
            "- 请先发 `/oci_roll` 刷取候选 IP，确认满意后再发 `/oci_bind` 换绑。",
        )
    if code == 3:
        return (
            False,
            "\n".join(
                _format_cli_output("存在多个候选预留 IP，请指定", out)
                + ["", "> 请发送 `/oci_bind <目标IP>` 指定要换绑的那一个。"]
            ),
        )
    if code != 0:
        raise RuntimeError(out or "oci-ip bind 执行失败")

    lines = _format_cli_output("OCI 换绑 IP 完成", out)
    m = re.search(r"切换为:\s*(\d+\.\d+\.\d+\.\d+)", out)
    new_ip = m.group(1) if m else None

    try:
        sb_links = build_singbox_links(ip_override=new_ip)
        lines.extend(["", sb_links])
    except Exception as e:
        lines.append(f"- **节点链接**: 生成失败 (`{e}`)")

    return True, "\n".join(lines)


def _fmt_bytes(num_bytes: float) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(num_bytes) < 1024.0 or unit == "TB":
            return f"{num_bytes:.2f} {unit}"
        num_bytes /= 1024.0
    return f"{num_bytes:.2f} TB"


def _read_cpu_times() -> tuple[int, int]:
    with open("/proc/stat", "r", encoding="utf-8") as f:
        parts = [int(x) for x in f.readline().split()[1:]]
    idle = parts[3] + (parts[4] if len(parts) > 4 else 0)
    return sum(parts), idle


def _read_net_bytes() -> tuple[int, int]:
    rx_total = 0
    tx_total = 0
    with open("/proc/net/dev", "r", encoding="utf-8") as f:
        for line in f.readlines()[2:]:
            if ":" not in line:
                continue
            iface, data = line.split(":", 1)
            iface = iface.strip()
            if iface == "lo":
                continue
            fields = data.split()
            rx_total += int(fields[0])
            tx_total += int(fields[8])
    return rx_total, tx_total


def build_server_status() -> str:
    t1, idle1 = _read_cpu_times()
    time.sleep(0.1)
    t2, idle2 = _read_cpu_times()
    rx_bytes, tx_bytes = _read_net_bytes()

    dt = max(1, t2 - t1)
    cpu_pct = max(0.0, 100.0 * (1.0 - (idle2 - idle1) / dt))

    with open("/proc/uptime", "r", encoding="utf-8") as f:
        up_sec = int(float(f.read().split()[0]))
    days, rem = divmod(up_sec, 86400)
    hours, rem = divmod(rem, 3600)
    mins = rem // 60
    uptime_str = f"{days}天 {hours}小时 {mins}分" if days else f"{hours}小时 {mins}分"

    with open("/proc/loadavg", "r", encoding="utf-8") as f:
        la = f.read().split()
    load_str = f"{la[0]} / {la[1]} / {la[2]}"
    cores = os.cpu_count() or 1

    mem_info: dict[str, int] = {}
    with open("/proc/meminfo", "r", encoding="utf-8") as f:
        for line in f:
            if ":" in line:
                k, v = line.split(":", 1)
                mem_info[k.strip()] = int(v.split()[0]) * 1024
    mem_total = mem_info.get("MemTotal", 1)
    mem_avail = mem_info.get("MemAvailable", 0)
    mem_used = max(0, mem_total - mem_avail)
    mem_pct = 100.0 * mem_used / mem_total

    swap_total = mem_info.get("SwapTotal", 0)
    swap_free = mem_info.get("SwapFree", 0)
    swap_used = max(0, swap_total - swap_free)

    disk = shutil.disk_usage("/")
    disk_pct = 100.0 * disk.used / max(1, disk.total)

    sb_res = subprocess.run(
        ["systemctl", "is-active", "sing-box"],
        capture_output=True,
        text=True,
    )
    sb_state = sb_res.stdout.strip() or "unknown"

    return "\n".join(
        [
            "### OCI 服务器状态",
            f"- **运行时长**: `{uptime_str}`",
            f"- **CPU 状态**: `{cpu_pct:.1f}%` (`{cores}` 核) | 负载 `{load_str}`",
            f"- **内存占用**: `{_fmt_bytes(mem_used)} / {_fmt_bytes(mem_total)}` (`{mem_pct:.1f}%`) | Swap `{_fmt_bytes(swap_used)} / {_fmt_bytes(swap_total)}`",
            f"- **磁盘占用**: `{_fmt_bytes(disk.used)} / {_fmt_bytes(disk.total)}` (`{disk_pct:.1f}%`)",
            f"- **累计流量**: `↓ {_fmt_bytes(rx_bytes)}` | `↑ {_fmt_bytes(tx_bytes)}`",
            f"- **Sing-box**: `{sb_state}`",
        ]
    )


class QQBotApp:
    def __init__(self, state_file: str, push_hour: int, push_minute: int) -> None:
        self.appid = get_secret(
            DEFAULT_SOPS_QQ_APPID_PATH, "qq_bot_appid", "QQ_BOT_APPID"
        )
        self.secret = get_secret(
            DEFAULT_SOPS_QQ_SECRET_PATH, "qq_bot_secret", "QQ_BOT_SECRET"
        )
        try:
            self.owner_openid = get_secret(
                DEFAULT_SOPS_QQ_OWNER_PATH,
                "qq_bot_owner_openid",
                "QQ_BOT_OWNER_OPENID",
            )
        except Exception:
            self.owner_openid = ""

        self.state_file = state_file
        self.push_hour = push_hour
        self.push_minute = push_minute

        self.access_token: str = ""
        self.token_expires_at: float = 0.0
        self.rolling_ip: bool = False
        self.agy_proc: asyncio.subprocess.Process | None = None
        self.agy_task_info: dict[str, Any] | None = None
        self.current_ws: Any = None
        self.agy_queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue()
        self.agy_busy: bool = False
        self.last_agy_response: str = ""
        self.last_bot_reply: str = ""
        self.recent_replies: deque[str] = deque(maxlen=30)
        self.state: dict[str, Any] = self.load_state()
        if not self.owner_openid and self.state.get("owner_openid"):
            self.owner_openid = str(self.state["owner_openid"])

    def load_state(self) -> dict[str, Any]:
        if os.path.exists(self.state_file):
            try:
                with open(self.state_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return {}

    def save_state(self) -> None:
        parent = os.path.dirname(self.state_file)
        if parent:
            os.makedirs(parent, exist_ok=True)
        tmp = f"{self.state_file}.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self.state, f, indent=2, ensure_ascii=False)
        os.replace(tmp, self.state_file)

    def ensure_token(self) -> str:
        now = time.time()
        if self.access_token and now < self.token_expires_at - 120:
            return self.access_token
        resp = requests.post(
            QQ_TOKEN_URL,
            json={"appId": self.appid, "clientSecret": self.secret},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        self.access_token = data["access_token"]
        self.token_expires_at = now + int(data.get("expires_in", 7200))
        return self.access_token

    def api_headers(self) -> dict[str, str]:
        return {
            "Authorization": f"QQBot {self.ensure_token()}",
            "Content-Type": "application/json",
        }

    def get_gateway_url(self) -> str:
        resp = requests.get(
            f"{QQ_API_BASE}/gateway", headers=self.api_headers(), timeout=10
        )
        resp.raise_for_status()
        return resp.json()["url"]

    def build_card_bodies(
        self,
        t_type: str,
        content: str,
        reply_msg_id: str | None,
    ) -> list[dict[str, Any]]:
        """
        优先使用 QQ 原生 Markdown 卡片 (msg_type=2) 渲染消息，支持代码块一键复制；
        若接口受限则依次回退至 Ark 列表卡片 (msg_type=3) 与纯文本 (msg_type=0)。
        """
        raw_lines = [line.strip() for line in content.strip().splitlines() if line.strip()]
        title = raw_lines[0].lstrip("#").strip() if raw_lines else "OCI 账单通知"

        ark_23 = {
            "template_id": 23,
            "kv": [
                {"key": "#DESC#", "value": title},
                {"key": "#PROMPT#", "value": title},
                {
                    "key": "#LIST#",
                    "obj": [
                        {"obj_kv": [{"key": "desc", "value": line}]}
                        for line in raw_lines
                    ],
                },
            ],
        }

        def attach_meta(base: dict[str, Any], with_reply: bool) -> dict[str, Any]:
            seq = int(self.state.get("msg_seq", 1)) + 1
            self.state["msg_seq"] = seq
            pkt = dict(base)
            if t_type in ("c2c", "group"):
                pkt["msg_seq"] = seq
            if with_reply and reply_msg_id:
                pkt["msg_id"] = reply_msg_id
            return pkt

        candidates: list[dict[str, Any]] = []
        with_reply_modes = [True, False] if reply_msg_id else [False]

        if t_type in ("channel", "dms"):
            for wr in with_reply_modes:
                candidates.append(attach_meta({"markdown": {"content": content}}, wr))
                candidates.append(attach_meta({"ark": ark_23}, wr))
                candidates.append(attach_meta({"content": content}, wr))
            return candidates

        card_templates: list[dict[str, Any]] = [
            {"msg_type": 2, "markdown": {"content": content}},
            {"msg_type": 3, "ark": ark_23},
            {"msg_type": 0, "content": content},
        ]

        for wr in with_reply_modes:
            for tpl in card_templates:
                candidates.append(attach_meta(tpl, wr))
        return candidates

    def send_message(
        self,
        target: dict[str, Any],
        content: str,
        reply_msg_id: str | None = None,
    ) -> bool:
        t_type = target.get("type")
        t_id = target.get("id")
        if not t_type or not t_id:
            return False

        if t_type == "c2c":
            url = f"{QQ_API_BASE}/v2/users/{t_id}/messages"
        elif t_type == "group":
            url = f"{QQ_API_BASE}/v2/groups/{t_id}/messages"
        elif t_type == "dms":
            url = f"{QQ_API_BASE}/dms/{t_id}/messages"
        elif t_type == "channel":
            url = f"{QQ_API_BASE}/channels/{t_id}/messages"
        else:
            return False

        payloads = self.build_card_bodies(t_type, content, reply_msg_id)
        for body in payloads:
            for attempt in range(2):
                try:
                    r = requests.post(
                        url, headers=self.api_headers(), json=body, timeout=10
                    )
                    if r.status_code in (200, 201, 202):
                        self.save_state()
                        return True
                    log(
                        f"消息发送 (msg_type={body.get('msg_type', 'markdown')}) 返回 {r.status_code}: {r.text}"
                    )
                    break
                except Exception as e:
                    log(f"发送消息异常 (try={attempt + 1}): {e}")
                    if attempt == 0:
                        time.sleep(2.0)
        return False

    def send_file_media(
        self,
        target: dict[str, Any],
        file_path: str,
        file_type: int = 1,  # 1: 图片, 4: 文件
    ) -> bool:
        """
        向 QQ 官方富媒体接口上传并发送本地图片或文件（使用官方标准的 JSON Base64 方式）
        """
        import base64

        t_type = target.get("type")
        t_id = target.get("id")
        if not t_type or not t_id or not os.path.exists(file_path):
            return False

        if t_type == "c2c":
            upload_url = f"{QQ_API_BASE}/v2/users/{t_id}/files"
            msg_url = f"{QQ_API_BASE}/v2/users/{t_id}/messages"
        elif t_type == "group":
            upload_url = f"{QQ_API_BASE}/v2/groups/{t_id}/files"
            msg_url = f"{QQ_API_BASE}/v2/groups/{t_id}/messages"
        elif t_type in ("channel", "dms"):
            endpoint = "channels" if t_type == "channel" else "dms"
            msg_url = f"{QQ_API_BASE}/{endpoint}/{t_id}/messages"
            headers = {"Authorization": f"QQBot {self.ensure_token()}"}
            try:
                with open(file_path, "rb") as f:
                    fname = os.path.basename(file_path)
                    files = {"file_image": (fname, f, "image/png")}
                    res = requests.post(msg_url, headers=headers, files=files, timeout=30)
                    return res.status_code in (200, 201, 202)
            except Exception as e:
                log(f"{t_type} 发送富媒体异常: {e}")
                return False
        else:
            return False

        try:
            with open(file_path, "rb") as f:
                b64_data = base64.b64encode(f.read()).decode("utf-8")

            upload_payload = {
                "file_type": file_type,
                "file_data": b64_data,
                "srv_send_msg": False,
            }
            upload_res = requests.post(
                upload_url,
                headers=self.api_headers(),
                json=upload_payload,
                timeout=40,
            )
            if upload_res.status_code not in (200, 201):
                log(f"富媒体文件上传失败 ({upload_res.status_code}): {upload_res.text}")
                return False

            file_info = upload_res.json().get("file_info")
            if not file_info:
                return False

            seq = int(self.state.get("msg_seq", 1)) + 1
            self.state["msg_seq"] = seq
            body = {
                "msg_type": 7,  # 富媒体
                "media": {"file_info": file_info},
                "msg_seq": seq,
            }
            res = requests.post(msg_url, headers=self.api_headers(), json=body, timeout=10)
            return res.status_code in (200, 201, 202)
        except Exception as e:
            log(f"发送富媒体异常: {e}")
            return False

    def render_markdown_card_image(self, md_text: str) -> str | None:
        """
        使用 Typst 将 Markdown 渲染为排版优雅的高清长图卡片。
        返回生成的本地 PNG 文件路径。
        """
        if not md_text or not md_text.strip():
            return None

        typst_content = md_to_typst(md_text.strip())
        now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        tmp_id = f"render_{int(time.time() * 1000)}"
        tmp_typ = f"/tmp/{tmp_id}.typ"
        out_png = f"/tmp/{tmp_id}.png"

        typst_code = f"""
#set page(
  width: 780pt,
  height: auto,
  margin: (x: 28pt, top: 24pt, bottom: 28pt),
  fill: rgb("#f6f8fa")
)

#set text(
  font: ("Source Han Sans SC", "Source Han Sans", "Noto Sans CJK SC", "PingFang SC"),
  size: 13.5pt,
  fill: rgb("#1f2328"),
  lang: "zh"
)

#set par(justify: false, leading: 0.85em)

#show heading: it => block(below: 10pt, above: 14pt)[
  #text(weight: "bold", fill: rgb("#0969da"))[#it.body]
]

#show raw.where(block: true): it => block(
  fill: rgb("#24292e"),
  inset: 12pt,
  radius: 8pt,
  width: 100%
)[
  #set text(fill: rgb("#f0f6fc"), size: 11.5pt)
  #it
]

#show raw.where(block: false): it => box(
  fill: rgb("#eff1f3"),
  inset: (x: 4pt, y: 2pt),
  radius: 4pt
)[
  #set text(fill: rgb("#bf3989"), size: 12pt)
  #it
]

// Card container
#block(
  width: 100%,
  stroke: 1pt + rgb("#d0d7de"),
  radius: 12pt,
  fill: white,
  inset: (x: 26pt, y: 22pt)
)[
  // Header
  #grid(
    columns: (1fr, auto),
    align: (left + horizon, right + horizon),
    [
      #box(
        fill: rgb("#0969da").lighten(88%),
        radius: 6pt,
        inset: (x: 8pt, y: 4pt)
      )[
        #text(size: 11pt, weight: "bold", fill: rgb("#0969da"))[🤖 Antigravity Reply]
      ]
    ],
    [
      #text(size: 10.5pt, fill: rgb("#656d76"))[{now_str}]
    ]
  )

  #v(10pt)
  #line(length: 100%, stroke: 0.8pt + rgb("#eaeef2"))
  #v(12pt)

  // Content
  {typst_content}
]
"""
        try:
            with open(tmp_typ, "w", encoding="utf-8") as f:
                f.write(typst_code)

            cmd = [get_typst_cmd(), "compile"]
            for fpath in find_typst_font_paths():
                cmd.extend(["--font-path", fpath])
            cmd.extend(["--ppi", "144", tmp_typ, out_png])

            res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if res.returncode != 0:
                log(f"Typst 渲染长图失败: {res.stderr}")
                return None
            return out_png
        except Exception as e:
            log(f"渲染 Markdown 卡片图片异常: {e}")
            return None
        finally:
            if os.path.exists(tmp_typ):
                try:
                    os.remove(tmp_typ)
                except OSError:
                    pass

    async def handle_user_command(
        self,
        target: dict[str, Any],
        sender_id: str,
        raw_content: str,
        msg_id: str,
        attachments: list[dict[str, Any]] | None = None,
        raw_event: dict[str, Any] | None = None,
    ) -> None:
        loop = asyncio.get_running_loop()

        # 权限校验：仅允许白名单 OpenID 调用
        if not self.owner_openid and sender_id:
            self.owner_openid = sender_id
            self.state["owner_openid"] = sender_id
            self.save_state()

        if self.owner_openid and sender_id != self.owner_openid:
            log(f"拒绝未授权用户 [{sender_id}] 调用: {raw_content}")
            return

        # 附件自动下载
        saved_files: list[str] = []
        if attachments:
            os.makedirs(QQ_ATTACHMENTS_DIR, exist_ok=True)
            for att in attachments:
                url = att.get("url")
                if not url:
                    continue
                filename = att.get("filename") or os.path.basename(url.split("?")[0]) or f"file_{int(time.time())}"
                save_path = os.path.join(QQ_ATTACHMENTS_DIR, filename)
                try:
                    def _download():
                        r = requests.get(url, timeout=30)
                        r.raise_for_status()
                        with open(save_path, "wb") as f:
                            f.write(r.content)
                        return save_path

                    fpath = await loop.run_in_executor(None, _download)
                    saved_files.append(fpath)
                    log(f"成功保存 QQ 附件: {fpath}")
                except Exception as e:
                    log(f"下载 QQ 附件失败 ({url}): {e}")

        text = raw_content.strip()
        # 频道 @ 消息会带 <@!botid> 前缀；仅剥离开头的 mention，避免误伤正文中的 ">"
        if text.startswith("<@"):
            text = text.split(">", 1)[-1].strip()
        has_slash = text.startswith("/")
        unprefixed = text.lstrip("/").strip()
        parts = unprefixed.split()
        first_word = parts[0].lower() if parts else ""

        # 仅当显式以 "/" 开头，或首词明确是已知运维命令时才解析为内部控制指令
        is_known_cmd = (
            first_word in KNOWN_COMMANDS
            or first_word.startswith("oci_")
            or (len(parts) >= 2 and parts[0].lower() == "oci")
        )

        if has_slash or is_known_cmd:
            if len(parts) >= 2 and parts[0].lower() == "oci":
                cmd = f"oci_{parts[1].lower().replace('-', '_')}"
                cmd_args = parts[2:]
                cmd_rest = unprefixed.split(maxsplit=2)[-1] if len(parts) > 2 else ""
            elif parts:
                cmd = parts[0].lower().replace("-", "_")
                cmd_args = parts[1:]
                cmd_rest = unprefixed[len(parts[0]) :].strip()
            else:
                cmd = ""
                cmd_args = []
                cmd_rest = ""
        else:
            # 普通消息（包括包含 URL、普通提问等）：不拆分首词，全量透传给 agy
            cmd = "agy"
            cmd_args = parts
            cmd_rest = unprefixed

        is_first_bind = "target" not in self.state
        self.state["target"] = target
        self.state["last_msg_id"] = msg_id
        self.save_state()

        log(f"收到指令 [{target.get('type')}:{target.get('id')}]: /{cmd} {cmd_args} (附件: {len(saved_files)} 个)")

        # 如果有附件，将本地文件路径拼接到 prompt 中传给 agy
        if saved_files:
            file_hints = []
            for sf in saved_files:
                ext = os.path.splitext(sf)[1].lower()
                if ext in (".png", ".jpg", ".jpeg", ".webp", ".gif"):
                    file_hints.append(f"[用户发送的图片已保存在服务器: {sf}，请结合图片进行分析]")
                else:
                    file_hints.append(f"[用户发送的文件已保存在服务器: {sf}，请直接读取或处理该文件]")
            combined_hint = "\n".join(file_hints)
            cmd_rest = f"{combined_hint}\n{cmd_rest}".strip()
            if not cmd or (not cmd.startswith("oci_") and cmd not in KNOWN_COMMANDS):
                cmd = "agy"

        # 兜底：未匹配到其它指令的普通内容全量转入 agy
        if cmd not in KNOWN_COMMANDS and not cmd.startswith("oci_") and (cmd_rest or saved_files):
            cmd = "agy"

        # 智能识别：若用户引用了一条消息，并且附言包含渲染相关词汇，自动转为 render 指令
        quoted_detected = extract_quoted_text(raw_event)
        if quoted_detected and any(kw in text for kw in ("渲染", "转图", "转成图", "做成图", "生成图")):
            cmd = "render"
            cmd_args = []
            cmd_rest = ""

        if cmd.startswith("agy") or cmd in ("render", "render_last", "r"):
            await self.handle_agy_command(
                target, msg_id, cmd, cmd_args, cmd_rest, raw_event=raw_event
            )
            return

        if cmd == "oci_roll":
            if self.rolling_ip:
                await loop.run_in_executor(
                    None,
                    self.send_message,
                    target,
                    "### 任务进行中\n- 当前正在执行 IP 操作任务，请等待完成。",
                    msg_id,
                )
                return

            self.rolling_ip = True
            prefix_hint = f" (目标前缀: `{', '.join(cmd_args)}`)" if cmd_args else ""
            await loop.run_in_executor(
                None,
                self.send_message,
                target,
                f"### 正在刷取候选预留 IP\n- 正在申请并检测纯净预留 IP{prefix_hint}（不会改动当前在用 IP），请稍候...",
                msg_id,
            )
            try:
                reply = await loop.run_in_executor(
                    None,
                    roll_candidate_oci_ip,
                    cmd_args if cmd_args else None,
                )
            except Exception as e:
                reply = f"### 刷取候选 IP 失败\n- `{e}`"
            finally:
                self.rolling_ip = False

            await loop.run_in_executor(
                None, self.send_message, target, reply, msg_id
            )
            return

        if cmd == "oci_check":
            target_ip = cmd_args[0] if cmd_args else None
            await loop.run_in_executor(
                None,
                self.send_message,
                target,
                "### 正在检测 IP 质量\n- 正在查询原生属地、Scamalytics 欺诈评分与国内 TCP 连通性，请稍候...",
                msg_id,
            )
            try:
                reply = await loop.run_in_executor(
                    None, check_oci_ips, target_ip
                )
            except Exception as e:
                reply = f"### 检测 IP 失败\n- `{e}`"
            await loop.run_in_executor(
                None, self.send_message, target, reply, msg_id
            )
            return

        if cmd == "oci_bind":
            if self.rolling_ip:
                await loop.run_in_executor(
                    None,
                    self.send_message,
                    target,
                    "### 任务进行中\n- 当前正在执行 IP 操作任务，请等待完成。",
                    msg_id,
                )
                return

            self.rolling_ip = True
            target_ip = cmd_args[0] if cmd_args else None
            did_switch = False
            try:
                did_switch, reply = await loop.run_in_executor(
                    None, bind_candidate_oci_ip, target_ip
                )
            except Exception as e:
                reply = f"### 换绑 IP 失败\n- `{e}`"
            finally:
                self.rolling_ip = False

            await loop.run_in_executor(
                None, self.send_message, target, reply, msg_id
            )
            if did_switch and self.current_ws is not None:
                try:
                    await self.current_ws.close()
                except Exception:
                    pass
            return

        try:
            if cmd == "oci_bill":
                report, _ = await loop.run_in_executor(None, build_oci_bill_report)
                if is_first_bind:
                    report += (
                        f"\n\n> 已绑定当前会话，每天 `{self.push_hour:02d}:{self.push_minute:02d}` 自动向你推送账单"
                    )
                reply = report
            elif cmd == "oci_ip":
                reply = await loop.run_in_executor(None, build_oci_ip_summary)
            elif cmd == "oci_clean":
                reply = await loop.run_in_executor(None, cleanup_unbound_ips)
            elif cmd == "oci_link":
                reply = await loop.run_in_executor(None, build_singbox_links)
            elif cmd == "oci_status":
                reply = await loop.run_in_executor(None, build_server_status)
            else:
                reply = (
                    "### OCI 助手\n"
                    "- `/oci_bill` : 查询账单与防扣费巡检\n"
                    "- `/oci_ip` : 查看预留 IP 状态\n"
                    "- `/oci_roll` : 刷取候选预留 IP (仅抽卡不换绑)\n"
                    "- `/oci_check` : 检测候选/当前 IP 纯净度与国内连通性\n"
                    "- `/oci_bind` : 将候选预留 IP 换绑至服务器并释放旧 IP\n"
                    "- `/oci_clean` : 释放未绑定预留 IP\n"
                    "- `/oci_link` : 获取 sing-box 节点链接\n"
                    "- `/oci_status` : 查看服务器实时负载与流量指标\n"
                    "\n"
                    "### AGY 远程 Agent\n"
                    "- `/agy <任务>` : 在当前目录续聊 (直接发不带 / 的消息也行)\n"
                    "- `/agy_new <任务>` : 开新会话\n"
                    "- `/render` (`/r`) : 将上一条回复渲染为精美长图 (支持 `/render <Markdown文本>`)\n"
                    "- `/agy_queue` : 查看任务排队情况\n"
                    "- `/agy_clear` : 清空所有排队中的任务\n"
                    "- `/agy_cd [目录]` : 查看/切换工作目录\n"
                    "- `/agy_model [模型]` : 查看/切换模型\n"
                    "- `/agy_effort [档位]` : 查看/切换推理强度\n"
                    "- `/agy_status` : 当前配置与任务状态\n"
                    "- `/agy_stop` : 终止正在运行的任务\n"
                    "- `/agy_reset` : 清空当前目录的会话记忆"
                )
        except Exception as e:
            reply = f"### 执行出错\n- `{e}`"

        await loop.run_in_executor(
            None, self.send_message, target, reply, msg_id
        )

    # ------------------------------------------------------------------
    # AGY 远程 Agent
    # ------------------------------------------------------------------

    def agy_cwd(self) -> str:
        cwd = str(self.state.get("agy_cwd") or DEFAULT_AGY_CWD)
        if not os.path.isdir(cwd):
            cwd = os.path.expanduser("~")
        return cwd

    def agy_model(self) -> str:
        return str(self.state.get("agy_model") or DEFAULT_AGY_MODEL)

    def agy_effort(self) -> str:
        return str(self.state.get("agy_effort") or DEFAULT_AGY_EFFORT)

    def agy_sessions(self) -> dict[str, str]:
        return self.state.setdefault("agy_sessions", {})

    def build_agy_status(self) -> str:
        cwd = self.agy_cwd()
        conv = self.agy_sessions().get(cwd)
        lines = [
            "### AGY 状态",
            f"- **工作目录**: `{_short_path(cwd)}`",
            f"- **模型**: `{self.agy_model()}`",
            f"- **推理强度**: `{self.agy_effort()}`",
            f"- **当前目录会话**: `{conv[:8] if conv else '无 (下次自动新建)'}`",
        ]
        info = self.agy_task_info
        if self.agy_proc is not None and info:
            elapsed = int(time.time() - info["started"])
            lines.append(
                f"- **运行中**: `{info['prompt'][:40]}` (已 `{elapsed}s`，`/agy_stop` 可终止)"
            )
        else:
            lines.append("- **运行中**: 无")
        qsize = self.agy_queue.qsize()
        lines.append(f"- **排队任务**: `{qsize}` 个")
        return "\n".join(lines)

    def build_agy_model_list(self) -> str:
        current_model = self.agy_model()
        current_effort = self.agy_effort()

        families: list[dict[str, Any]] = [
            {
                "name": "Gemini 4 Argon",
                "alias": "argon",
                "tiers": ["low", "medium", "high"],
                "prefix": "gemini-4-argon",
            },
            {
                "name": "Gemini 3.8 Flash",
                "alias": "flash",
                "tiers": ["low", "medium", "high"],
                "prefix": "gemini-3.8-flash",
            },
            {
                "name": "Claude Opus 5.5",
                "alias": "opus",
                "tiers": ["low", "medium", "high"],
                "prefix": "claude-opus-5-5",
            },
            {
                "name": "Claude Sonnet 5.5",
                "alias": "sonnet",
                "tiers": ["low", "medium", "high"],
                "prefix": "claude-sonnet-5-5",
            },
            {
                "name": "GPT-OSS 120B",
                "alias": "gpt",
                "tiers": ["medium"],
                "prefix": "gpt-oss-120b",
            },
        ]

        lines = ["### 🤖 可用模型系列"]
        for f in families:
            prefix = f["prefix"]
            is_cur = current_model.startswith(prefix)
            mark = f" ✅ `[{current_effort}]`" if is_cur else ""
            tiers_str = " · ".join(f"`{t}`" for t in f["tiers"])
            lines.append(f"- **{f['name']}** (`{f['alias']}`){mark}\n  - 档位: {tiers_str}")

        lines.extend(
            [
                "",
                f"> 当前: `{current_model}` (`{current_effort}`)",
                "> 切换示例: `/agy_model flash` 或 `/agy_effort high`",
            ]
        )
        return "\n".join(lines)

    async def send_async(
        self, target: dict[str, Any], content: str, msg_id: str | None
    ) -> bool:
        self.last_bot_reply = content
        if content and content.strip():
            self.recent_replies.append(content.strip())
        loop = asyncio.get_running_loop()
        ok = await loop.run_in_executor(None, self.send_message, target, content, msg_id)
        if not ok and RAW_URL_RE.search(content):
            ok = await loop.run_in_executor(
                None, self.send_message, target, _neutralize_urls(content), msg_id
            )
        return ok

    async def handle_agy_command(
        self,
        target: dict[str, Any],
        msg_id: str,
        cmd: str,
        cmd_args: list[str],
        cmd_rest: str,
        raw_event: dict[str, Any] | None = None,
    ) -> None:
        if cmd == "agy_status":
            await self.send_async(target, self.build_agy_status(), msg_id)
            return

        if cmd == "agy_stop":
            proc = self.agy_proc
            if proc is None or proc.returncode is not None:
                await self.send_async(target, "### AGY\n- 当前没有正在运行的任务。", msg_id)
                return
            if self.agy_task_info is not None:
                self.agy_task_info["stopped"] = True
            try:
                os.killpg(proc.pid, 15)
            except ProcessLookupError:
                pass
            queue_hint = ""
            if not self.agy_queue.empty():
                queue_hint = f"\n- 队列中尚有 `{self.agy_queue.qsize()}` 个排队任务，如需一并取消可发 `/agy_clear`。"
            await self.send_async(target, f"### AGY\n- 已发送终止信号。{queue_hint}", msg_id)
            return

        if cmd in ("agy_queue", "agy_q"):
            lines = ["### 📋 AGY 任务队列"]
            if self.agy_task_info:
                prompt_preview = self.agy_task_info.get("prompt", "")[:40]
                elapsed = int(time.time() - self.agy_task_info.get("started", time.time()))
                lines.append(f"- **正在执行**: `{prompt_preview}` (已运行 `{elapsed}s`)")
            else:
                lines.append("- **正在执行**: 无")
            qsize = self.agy_queue.qsize()
            lines.append(f"- **等待排队**: `{qsize}` 个任务")
            if qsize > 0:
                lines.append("> 排队任务将在前序任务结束后按顺序自动执行。发 `/agy_clear` 可清空队列。")
            await self.send_async(target, "\n".join(lines), msg_id)
            return

        if cmd in ("agy_clear", "agy_clean"):
            cleared_count = 0
            while not self.agy_queue.empty():
                try:
                    self.agy_queue.get_nowait()
                    self.agy_queue.task_done()
                    cleared_count += 1
                except (asyncio.QueueEmpty, ValueError):
                    break
            await self.send_async(
                target,
                f"### 🧹 AGY 队列已清空\n- 已取消 `{cleared_count}` 个正在排队的待处理任务。",
                msg_id,
            )
            return

        if cmd in ("render", "render_last", "r"):
            content_to_render = cmd_rest.strip() if cmd_rest else ""

            # 1. 检测是否有引用消息
            if not content_to_render:
                quoted = extract_quoted_text(raw_event)
                if quoted:
                    log(f"检测到引用消息内容: {quoted[:50]}...")
                    clean_quoted = quoted.strip()
                    matched_full = None
                    for hist in reversed(self.recent_replies):
                        if (
                            clean_quoted in hist
                            or hist in clean_quoted
                            or hist.startswith(clean_quoted[:30])
                        ):
                            matched_full = hist
                            break
                    content_to_render = matched_full or clean_quoted

            # 2. 兜底回退：渲染上一条回复
            if not content_to_render:
                content_to_render = self.last_agy_response or self.last_bot_reply

            if not content_to_render:
                await self.send_async(
                    target,
                    "### 渲染失败\n"
                    "- 暂无可渲染的历史回复或引用消息。\n"
                    "- **用法**:\n"
                    "  - 引用任意一条消息并发送 `/render` (或 `/r`)\n"
                    "  - 直接发送 `/render` 渲染机器人的上一条回复\n"
                    "  - 发送 `/render <Markdown文本>` 渲染指定文本",
                    msg_id,
                )
                return

            await self.send_async(target, "🎨 正在排版渲染为长图卡片，请稍候...", msg_id)
            loop = asyncio.get_running_loop()
            img_path = await loop.run_in_executor(
                None, self.render_markdown_card_image, content_to_render
            )
            if not img_path or not os.path.exists(img_path):
                await self.send_async(
                    target,
                    "### 渲染图片失败\n- Typst 编译异常，已保留文字输出。",
                    msg_id,
                )
                return

            ok = await loop.run_in_executor(
                None, self.send_file_media, target, img_path, 1
            )
            if not ok:
                await self.send_async(
                    target,
                    f"### 图片回传失败\n- 已生成图片但上传 QQ 接口未响应: `{img_path}`",
                    msg_id,
                )
            return

        if cmd == "agy_reset":
            cwd = self.agy_cwd()
            self.agy_sessions().pop(cwd, None)
            self.save_state()
            await self.send_async(
                target, f"### AGY\n- 已清空 `{_short_path(cwd)}` 的会话记忆。", msg_id
            )
            return

        if cmd == "agy_cd":
            if not cmd_rest:
                await self.send_async(
                    target, f"### AGY 工作目录\n- 当前: `{_short_path(self.agy_cwd())}`", msg_id
                )
                return
            new_dir = os.path.abspath(
                os.path.expanduser(cmd_rest)
                if cmd_rest.startswith(("~", "/"))
                else os.path.join(self.agy_cwd(), cmd_rest)
            )
            if not os.path.isdir(new_dir):
                await self.send_async(
                    target,
                    f"### 切换失败\n- 目录不存在: `{_short_path(new_dir)}`\n"
                    "- 可以先让 agy 创建，例如 `/agy 在 ~/code 下新建 demo 目录`",
                    msg_id,
                )
                return
            self.state["agy_cwd"] = new_dir
            self.save_state()
            has_conv = new_dir in self.agy_sessions()
            await self.send_async(
                target,
                f"### AGY 工作目录\n- 已切换到 `{_short_path(new_dir)}`\n"
                f"- {'将续接该目录之前的会话' if has_conv else '该目录暂无会话，下次将新建'}",
                msg_id,
            )
            return

        if cmd in ("agy_model", "agy_models"):
            if not cmd_args:
                await self.send_async(target, self.build_agy_model_list(), msg_id)
                return
            model_id, inferred_effort = resolve_agy_model(cmd_args[0], self.agy_effort())
            known = {m[0] for m in AGY_MODEL_CATALOG}
            self.state["agy_model"] = model_id
            if inferred_effort:
                self.state["agy_effort"] = inferred_effort
            self.save_state()
            warn = "" if model_id in known else "\n- ⚠️ 不在内置列表中，将原样传给 agy"
            await self.send_async(
                target,
                f"### AGY 模型\n- 模型: `{model_id}`\n- 推理强度: `{self.agy_effort()}`{warn}",
                msg_id,
            )
            return

        if cmd == "agy_effort":
            if not cmd_args:
                await self.send_async(
                    target,
                    f"### AGY 推理强度\n- 当前: `{self.agy_effort()}`\n"
                    f"- 可选: `{' / '.join(AGY_EFFORT_LEVELS)}`",
                    msg_id,
                )
                return
            level = cmd_args[0].lower()
            if level not in AGY_EFFORT_LEVELS:
                await self.send_async(
                    target,
                    f"### 无效档位\n- 可选: `{' / '.join(AGY_EFFORT_LEVELS)}`",
                    msg_id,
                )
                return
            self.state["agy_effort"] = level
            self.state["agy_model"] = sync_model_with_effort(self.agy_model(), level)
            self.save_state()
            await self.send_async(
                target,
                f"### AGY 推理强度\n- 推理强度: `{level}`\n- 模型: `{self.agy_model()}`",
                msg_id,
            )
            return

        if cmd in ("agy", "agy_new"):
            prompt = cmd_rest
            if not prompt:
                await self.send_async(
                    target,
                    "### AGY\n"
                    "- 用法: `/agy <任何想说或想做的事>` (或直接发普通消息)\n"
                    "- 开新会话: `/agy_new <内容>`\n\n"
                    + self.build_agy_status(),
                    msg_id,
                )
                return

            is_busy = self.agy_busy or (self.agy_proc is not None)
            qsize = self.agy_queue.qsize()
            pos = qsize + 1 if is_busy else 1

            await self.agy_queue.put(
                {
                    "target": target,
                    "msg_id": msg_id,
                    "prompt": prompt,
                    "new_session": (cmd == "agy_new"),
                    "queued_at": time.time(),
                }
            )

            if is_busy:
                prompt_snippet = prompt.replace("\n", " ")[:30] + (
                    "..." if len(prompt) > 30 else ""
                )
                await self.send_async(
                    target,
                    f"### 📥 任务已排队 (第 {pos} 位)\n"
                    f"- 待执行: `{prompt_snippet}`\n"
                    "- 当前任务执行完毕后将自动开始，无需重复发送。\n"
                    "- 发送 `/agy_queue` 可查看队列，`/agy_clear` 可清空排队。",
                    msg_id,
                )
            return

        await self.send_async(target, f"### AGY\n- 未知指令 `/{cmd}`，发 `/help` 查看帮助。", msg_id)

    async def run_agy_task(
        self,
        target: dict[str, Any],
        msg_id: str,
        prompt: str,
        new_session: bool,
    ) -> None:
        cwd = self.agy_cwd()
        model = self.agy_model()
        effort = self.agy_effort()
        sessions = self.agy_sessions()
        if new_session:
            sessions.pop(cwd, None)
            self.save_state()
        conv_id = sessions.get(cwd)

        # 随心所欲：不做人设干涉，直接原汁原味透传 prompt
        cmd = [
            "agy",
            "-p",
            prompt,
            "--output-format",
            "json",
            "--model",
            model,
            "--effort",
            effort,
            "--dangerously-skip-permissions",
        ]
        if conv_id:
            cmd.extend(["--conversation", conv_id])

        started = time.time()
        self.agy_task_info = {"prompt": prompt, "started": started, "stopped": False}
        stdout_b = b""
        stderr_b = b""
        timed_out = False
        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=cwd,
                stdin=asyncio.subprocess.DEVNULL,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                start_new_session=True,
            )
            self.agy_proc = proc
            try:
                stdout_b, stderr_b = await asyncio.wait_for(
                    proc.communicate(), timeout=AGY_TIMEOUT_SECONDS
                )
            except asyncio.TimeoutError:
                timed_out = True
                try:
                    os.killpg(proc.pid, 9)
                except ProcessLookupError:
                    pass
                stdout_b, stderr_b = await proc.communicate()
        except Exception as e:
            self.agy_proc = None
            self.agy_task_info = None
            await self.send_async(target, f"### AGY 启动失败\n- `{e}`", msg_id)
            return

        stopped = bool(self.agy_task_info and self.agy_task_info.get("stopped"))
        self.agy_proc = None
        self.agy_task_info = None
        elapsed = time.time() - started

        if timed_out or stopped:
            reason = "超时被终止" if timed_out else "已被手动终止"
            msg = f"### AGY 任务{reason}\n- 耗时 `{elapsed:.0f}s`\n- 已做的文件修改不会回滚，可用 `/agy` 让它检查现状。"
            self.last_agy_response = msg
            await self.send_async(target, msg, msg_id)
            return

        result = _parse_agy_json(stdout_b.decode("utf-8", "replace"))
        if result is None:
            err = _strip_ansi(
                (stderr_b.decode("utf-8", "replace") or stdout_b.decode("utf-8", "replace"))
            ).strip()
            if conv_id:
                # 会话可能已失效，清掉以便下次自动新建
                sessions.pop(cwd, None)
                self.save_state()
            err_msg = (
                f"### AGY 执行失败\n```text\n{err[-1500:] or '无输出'}\n```"
                + ("\n> 已清除当前目录会话，下次将自动新建" if conv_id else "")
            )
            self.last_agy_response = err_msg
            await self.send_async(target, err_msg, msg_id)
            return

        new_conv = result.get("conversation_id")
        if new_conv:
            sessions[cwd] = new_conv
            self.save_state()

        response = _sanitize_agy_markdown(str(result.get("response") or ""))
        self.last_agy_response = response
        if response and response.strip():
            self.recent_replies.append(response.strip())
        usage = result.get("usage") or {}
        total_tokens = int(usage.get("total_tokens") or 0)
        footer = (
            f"> `{model}` · `{effort}` · `{elapsed:.1f}s`"
            f" · `{total_tokens / 1000:.1f}k tok` · 会话 `{(new_conv or '')[:8]}`"
        )
        if not response:
            status = result.get("status", "")
            if status and status != "SUCCESS":
                response = f"*(执行状态: {status}，无文本输出)*"
            else:
                response = "(无文本回复)"

        chunks = _split_markdown_chunks(response, AGY_CHUNK_CHARS)
        truncated = len(chunks) > AGY_MAX_CHUNKS
        chunks = chunks[:AGY_MAX_CHUNKS]
        total = len(chunks)
        for i, chunk in enumerate(chunks, 1):
            header = "### 🤖 AGY" if total == 1 else f"### 🤖 AGY ({i}/{total})"
            body = f"{header}\n{chunk}"
            if i == total:
                if truncated:
                    body += "\n\n> 回复过长已截断，可让它“总结一下刚才的结果”"
                body += "\n\n" + footer
            ok = await self.send_async(target, body, msg_id)
            if not ok:
                log(f"AGY 分片 [{i}/{total}] 发送失败 (可能触发接口频控或拦截)")
            else:
                log(f"AGY 分片 [{i}/{total}] 发送成功")
            if i < total:
                await asyncio.sleep(0.6)

        # 检查是否生成了本地图片/视频并自动作为富媒体回传给 QQ
        try:
            media_paths = re.findall(r"(/[\w./-]+\.(?:png|jpg|jpeg|webp|gif|mp4))", response)
            sent_media = set()
            for mpath in media_paths:
                if os.path.exists(mpath) and mpath not in sent_media:
                    sent_media.add(mpath)
                    ftype = 2 if mpath.endswith(".mp4") else 1
                    loop = asyncio.get_running_loop()
                    await loop.run_in_executor(None, self.send_file_media, target, mpath, ftype)
        except Exception as e:
            log(f"回传生成富媒体异常: {e}")

    async def scheduler_loop(self) -> None:
        """后台定时任务：每天指定时间推送账单日报，且每小时巡检一次异常新增扣费。"""
        tz = ZoneInfo("Asia/Singapore")
        while True:
            await asyncio.sleep(30)
            target = self.state.get("target")
            if not target:
                continue

            now = datetime.datetime.now(tz)
            today_str = now.strftime("%Y-%m-%d")

            # 每日定时日报
            if (
                now.hour == self.push_hour
                and now.minute >= self.push_minute
                and self.state.get("last_daily_push_date") != today_str
            ):
                log(f"触发每日定时账单推送 ({today_str})...")
                loop = asyncio.get_running_loop()
                try:
                    report, _ = await loop.run_in_executor(None, build_oci_bill_report)
                    ok_sent = await loop.run_in_executor(
                        None,
                        self.send_message,
                        target,
                        report,
                        self.state.get("last_msg_id"),
                    )
                    if ok_sent:
                        self.state["last_daily_push_date"] = today_str
                        self.save_state()
                        log("每日账单推送成功")
                except Exception as e:
                    log(f"每日账单推送失败: {e}")

            # 每小时异常扣费监控：若今日产生新费用且尚未告警，立即推送预警
            hour_key = now.strftime("%Y-%m-%d-%H")
            if self.state.get("last_hourly_check") != hour_key:
                self.state["last_hourly_check"] = hour_key
                self.save_state()
                loop = asyncio.get_running_loop()
                try:
                    report, today_cost = await loop.run_in_executor(
                        None, build_oci_bill_report
                    )
                    alerted_cost = float(
                        self.state.get("alerted_cost_by_day", {}).get(today_str, 0.0)
                    )
                    if today_cost > max(0.0001, alerted_cost + 0.0001):
                        alert_msg = f"⚠️ [OCI 异常扣费预警]\n检测到今日新增费用: {today_cost:.4f}\n\n{report}"
                        await loop.run_in_executor(
                            None,
                            self.send_message,
                            target,
                            alert_msg,
                            self.state.get("last_msg_id"),
                        )
                        self.state.setdefault("alerted_cost_by_day", {})[
                            today_str
                        ] = today_cost
                        self.save_state()
                except Exception as e:
                    log(f"每小时巡检异常: {e}")

    async def ws_loop(self) -> None:
        while True:
            try:
                loop = asyncio.get_running_loop()
                gw_url = await loop.run_in_executor(None, self.get_gateway_url)
                token = await loop.run_in_executor(None, self.ensure_token)
                log(f"正在连接 QQ Bot WebSocket: {gw_url}")

                async with websockets.connect(gw_url, ping_interval=None) as ws:
                    self.current_ws = ws
                    hello_raw = await ws.recv()
                    hello = json.loads(hello_raw)
                    if hello.get("op") != 10:
                        raise RuntimeError(f"未收到 Hello 包: {hello}")

                    hb_interval = hello["d"]["heartbeat_interval"] / 1000.0
                    last_seq: int | None = None

                    identify_payload = {
                        "op": 2,
                        "d": {
                            "token": f"QQBot {token}",
                            "intents": DEFAULT_INTENTS,
                            "shard": [0, 1],
                            "properties": {
                                "$os": "linux",
                                "$browser": "oci-bill-bot",
                                "$device": "oci-bill-bot",
                            },
                        },
                    }
                    await ws.send(json.dumps(identify_payload))

                    async def heartbeat_task() -> None:
                        while True:
                            await asyncio.sleep(hb_interval)
                            await ws.send(json.dumps({"op": 1, "d": last_seq}))

                    hb_fut = asyncio.create_task(heartbeat_task())
                    try:
                        async for raw_msg in ws:
                            packet = json.loads(raw_msg)
                            op = packet.get("op")
                            if packet.get("s") is not None:
                                last_seq = packet["s"]

                            if op == 11:
                                # Heartbeat ACK
                                continue
                            if op == 7:
                                log("收到服务端 Reconnect 通知，准备重连...")
                                break
                            if op == 9:
                                log(f"收到 Invalid Session: {packet}")
                                break
                            if op == 0:
                                event_type = packet.get("t")
                                d = packet.get("d") or {}
                                if event_type == "READY":
                                    bot_name = (d.get("user") or {}).get(
                                        "username", "Bot"
                                    )
                                    log(
                                        f"WebSocket 鉴权成功！当前机器人: {bot_name} (等待接收消息以绑定推送目标)"
                                    )
                                elif event_type == "C2C_MESSAGE_CREATE":
                                    author = d.get("author") or {}
                                    openid = author.get("user_openid") or author.get("id") or ""
                                    content = d.get("content", "")
                                    attachments = d.get("attachments") or []
                                    msg_id = d.get("id", "")
                                    if openid:
                                        asyncio.create_task(
                                            self.handle_user_command(
                                                {"type": "c2c", "id": openid},
                                                openid,
                                                content,
                                                msg_id,
                                                attachments,
                                                raw_event=d,
                                            )
                                        )
                                elif event_type == "GROUP_AT_MESSAGE_CREATE":
                                    author = d.get("author") or {}
                                    sender_id = (
                                        author.get("member_openid")
                                        or author.get("user_openid")
                                        or author.get("id")
                                        or ""
                                    )
                                    group_openid = d.get("group_openid") or d.get(
                                        "group_id"
                                    )
                                    content = d.get("content", "")
                                    attachments = d.get("attachments") or []
                                    msg_id = d.get("id", "")
                                    if group_openid:
                                        asyncio.create_task(
                                            self.handle_user_command(
                                                {"type": "group", "id": group_openid},
                                                sender_id,
                                                content,
                                                msg_id,
                                                attachments,
                                                raw_event=d,
                                            )
                                        )
                                elif event_type == "AT_MESSAGE_CREATE":
                                    author = d.get("author") or {}
                                    sender_id = author.get("id") or ""
                                    channel_id = d.get("channel_id")
                                    content = d.get("content", "")
                                    attachments = d.get("attachments") or []
                                    msg_id = d.get("id", "")
                                    if channel_id:
                                        asyncio.create_task(
                                            self.handle_user_command(
                                                {"type": "channel", "id": channel_id},
                                                sender_id,
                                                content,
                                                msg_id,
                                                attachments,
                                                raw_event=d,
                                            )
                                        )
                                elif event_type == "DIRECT_MESSAGE_CREATE":
                                    author = d.get("author") or {}
                                    sender_id = author.get("id") or ""
                                    guild_id = d.get("guild_id")
                                    content = d.get("content", "")
                                    attachments = d.get("attachments") or []
                                    msg_id = d.get("id", "")
                                    if guild_id:
                                        asyncio.create_task(
                                            self.handle_user_command(
                                                {"type": "dms", "id": guild_id},
                                                sender_id,
                                                content,
                                                msg_id,
                                                attachments,
                                                raw_event=d,
                                            )
                                        )
                    finally:
                        hb_fut.cancel()

            except Exception as e:
                log(f"WebSocket 连接断开 ({e})，5 秒后重连...")
                await asyncio.sleep(5)

    async def agy_queue_worker(self) -> None:
        """后台异步任务队列消费者，按序执行收到的 AGY 任务"""
        log("AGY 任务队列消费者已启动")
        while True:
            item = await self.agy_queue.get()
            self.agy_busy = True
            try:
                if time.time() - item.get("queued_at", time.time()) > 1.5:
                    prompt_preview = item["prompt"].replace("\n", " ")[:30]
                    await self.send_async(
                        item["target"],
                        f"### 🚀 开始处理排队任务\n- 任务内容: `{prompt_preview}`",
                        item["msg_id"],
                    )
                await self.run_agy_task(
                    target=item["target"],
                    msg_id=item["msg_id"],
                    prompt=item["prompt"],
                    new_session=item["new_session"],
                )
            except Exception as e:
                log(f"AGY 队列执行任务异常: {e}")
            finally:
                self.agy_busy = False
                self.agy_queue.task_done()

    async def run(self) -> None:
        await asyncio.gather(
            self.ws_loop(),
            self.scheduler_loop(),
            self.agy_queue_worker(),
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="oci-bill-bot",
        description="QQ 官方 WebSocket OCI 每日账单与防扣费巡检机器人",
    )
    parser.add_argument(
        "--state-file",
        default=os.environ.get("OCI_BOT_STATE_FILE", DEFAULT_STATE_FILE),
        help=f"状态保存文件路径 (默认: {DEFAULT_STATE_FILE})",
    )
    parser.add_argument(
        "--push-hour",
        type=int,
        default=int(os.environ.get("OCI_BOT_PUSH_HOUR", "9")),
        help="每日自动推送账单的小时 (0-23, 默认北京时间/新加坡时间 9 点)",
    )
    parser.add_argument(
        "--push-minute",
        type=int,
        default=int(os.environ.get("OCI_BOT_PUSH_MINUTE", "0")),
        help="每日自动推送账单的分钟 (0-59, 默认 0)",
    )
    parser.add_argument(
        "--once-report",
        action="store_true",
        help="仅在终端生成并打印一次当前 OCI 账单日报（用于命令行快速自检）",
    )
    args = parser.parse_args()

    if args.once_report:
        report, _ = build_oci_bill_report()
        print(report)
        return 0

    app = QQBotApp(
        state_file=args.state_file,
        push_hour=args.push_hour,
        push_minute=args.push_minute,
    )
    asyncio.run(app.run())
    return 0


if __name__ == "__main__":
    sys.exit(main())
