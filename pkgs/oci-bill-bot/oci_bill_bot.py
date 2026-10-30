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
import socket
import subprocess
import sys
import time
from collections import defaultdict
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

IMDS_BASE_URL = "http://169.254.169.254/opc/v2"
IMDS_HEADERS = {"Authorization": "Bearer Oracle"}

QQ_TOKEN_URL = "https://bots.qq.com/app/getAppAccessToken"
QQ_API_BASE = "https://api.sgroup.qq.com"

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


def build_oci_ip_summary() -> str:
    config = get_oci_config()
    tenancy = config["tenancy"]
    vn_client = oci.core.VirtualNetworkClient(config)
    reserved_ips = vn_client.list_public_ips(
        scope="REGION", compartment_id=tenancy, lifetime="RESERVED"
    ).data
    lines = [f"### OCI 预留 IP ({len(reserved_ips)})"]
    if not reserved_ips:
        lines.append("- 无")
    for item in reserved_ips:
        st = "已绑定" if item.private_ip_id else "未绑定(闲置)"
        lines.append(f"- `{item.ip_address}` **{st}** ({item.display_name or '-'})")
    return "\n".join(lines)


def cleanup_unbound_ips() -> str:
    config = get_oci_config()
    tenancy = config["tenancy"]
    vn_client = oci.core.VirtualNetworkClient(config)
    reserved_ips = vn_client.list_public_ips(
        scope="REGION", compartment_id=tenancy, lifetime="RESERVED"
    ).data
    removed: list[str] = []
    for item in reserved_ips:
        if not item.private_ip_id and item.lifecycle_state in {"AVAILABLE", "UNASSIGNED"}:
            vn_client.delete_public_ip(item.id)
            removed.append(item.ip_address)
    if not removed:
        return "### 预留 IP 清理\n- 当前没有未绑定的闲置预留 IP，无需清理。"
    return f"### 预留 IP 清理\n- 已释放 **{len(removed)}** 个未绑定预留 IP: `{', '.join(removed)}`"


def build_singbox_links(ip_override: str | None = None) -> str:
    cmd_bin = shutil.which("singbox-links") or "/run/current-system/sw/bin/singbox-links"
    cmd = [cmd_bin]
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


def fetch_imds(path: str, timeout: float = 0.5) -> Any | None:
    try:
        resp = requests.get(
            f"{IMDS_BASE_URL}/{path.lstrip('/')}",
            headers=IMDS_HEADERS,
            timeout=timeout,
        )
        if resp.status_code == 200:
            return resp.json()
    except requests.RequestException:
        pass
    return None


def resolve_primary_private_ip_id(
    vn_client: oci.core.VirtualNetworkClient,
    comp_id: str,
) -> str:
    vnics = fetch_imds("vnics")
    if vnics and isinstance(vnics, list) and len(vnics) > 0:
        vnic_id = vnics[0].get("vnicId")
        if vnic_id:
            try:
                priv_ips = vn_client.list_private_ips(vnic_id=vnic_id).data
                for p in priv_ips:
                    if p.is_primary:
                        return p.id
                if priv_ips:
                    return priv_ips[0].id
            except oci.exceptions.ServiceError:
                pass

    # 若不在 IMDS 环境中，优先从当前已绑定的预留 IP 反查主私网 IP
    reserved_ips = vn_client.list_public_ips(
        scope="REGION", compartment_id=comp_id, lifetime="RESERVED"
    ).data
    for item in reserved_ips:
        if item.private_ip_id:
            return item.private_ip_id

    subnets = vn_client.list_subnets(compartment_id=comp_id).data
    for subnet in subnets:
        priv_ips = vn_client.list_private_ips(subnet_id=subnet.id).data
        for p in priv_ips:
            if p.is_primary:
                return p.id

    raise RuntimeError("未能自动识别实例主网卡私网 IP OCID")


def ensure_service_gateway(
    vn_client: oci.core.VirtualNetworkClient,
    private_ip_id: str,
) -> None:
    """
    确保目标网卡所在 VCN 已挂载免费的 Oracle Services Network 服务网关 (Service Gateway) 并配置路由：
    防止在实例本机执行解绑旧公网 IP 时，因短暂失去公网 IPv4 而导致后续绑定新 IP 的 OCI API 请求断网超时。
    """
    try:
        priv_obj = vn_client.get_private_ip(private_ip_id).data
        subnet = vn_client.get_subnet(priv_obj.subnet_id).data
        comp_id = subnet.compartment_id
        vcn_id = subnet.vcn_id
        rt_id = subnet.route_table_id

        services = vn_client.list_services().data
        target_svc = None
        for svc in services:
            cb = (svc.cidr_block or "").lower()
            if cb.startswith("all-") and cb.endswith(
                "-services-in-oracle-services-network"
            ):
                target_svc = svc
                break
        if not target_svc and services:
            target_svc = services[0]
        if not target_svc:
            return

        sgws = [
            s
            for s in vn_client.list_service_gateways(
                compartment_id=comp_id, vcn_id=vcn_id
            ).data
            if s.lifecycle_state not in ("TERMINATING", "TERMINATED")
        ]
        if sgws:
            sgw = sgws[0]
            existing_svc_ids = {s.service_id for s in (sgw.services or [])}
            if target_svc.id not in existing_svc_ids:
                vn_client.attach_service_id(
                    sgw.id,
                    oci.core.models.ServiceIdRequestDetails(service_id=target_svc.id),
                )
        else:
            sgw = vn_client.create_service_gateway(
                oci.core.models.CreateServiceGatewayDetails(
                    compartment_id=comp_id,
                    vcn_id=vcn_id,
                    display_name="oci-internal-sgw",
                    services=[
                        oci.core.models.ServiceIdRequestDetails(
                            service_id=target_svc.id
                        )
                    ],
                )
            ).data
            for _ in range(20):
                if sgw.lifecycle_state == "AVAILABLE":
                    break
                time.sleep(1.0)
                sgw = vn_client.get_service_gateway(sgw.id).data

        if rt_id:
            rt = vn_client.get_route_table(rt_id).data
            rules = list(rt.route_rules or [])
            has_sgw_rule = any(
                r.destination == target_svc.cidr_block
                or r.network_entity_id == sgw.id
                for r in rules
            )
            if not has_sgw_rule:
                rules.append(
                    oci.core.models.RouteRule(
                        destination=target_svc.cidr_block,
                        destination_type="SERVICE_CIDR_BLOCK",
                        network_entity_id=sgw.id,
                        description="Oracle Services Network internal routing",
                    )
                )
                vn_client.update_route_table(
                    rt_id,
                    oci.core.models.UpdateRouteTableDetails(route_rules=rules),
                )
    except Exception as e:
        log(f"检查/配置 Service Gateway 时忽略非致命异常: {e}")


def wait_public_ip_stable(
    vn_client: oci.core.VirtualNetworkClient,
    public_ip_id: str,
    timeout: int = 30,
) -> oci.core.models.PublicIp:
    stable_states = {"AVAILABLE", "ASSIGNED", "UNASSIGNED"}
    deadline = time.time() + timeout
    last_obj = None
    while time.time() < deadline:
        last_obj = vn_client.get_public_ip(public_ip_id).data
        if last_obj.lifecycle_state in stable_states:
            return last_obj
        time.sleep(1.0)
    return last_obj


def fetch_ip_info(ip: str, timeout: float = 6.0) -> dict[str, Any] | None:
    try:
        resp = requests.get(
            f"http://ip-api.com/json/{ip}?fields=status,country,countryCode,regionName,city,isp,org,as,mobile,proxy,hosting,query",
            timeout=timeout,
        )
        if resp.status_code == 200:
            data = resp.json()
            if data.get("status") == "success":
                return data
    except requests.RequestException:
        pass
    return None


def fetch_scamalytics_score(ip: str, timeout: float = 6.0) -> int | None:
    try:
        resp = requests.get(
            f"https://scamalytics.com/ip/{ip}",
            headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"},
            timeout=timeout,
        )
        if resp.status_code == 200:
            match = re.search(r'"score"\s*:\s*"(\d+)"', resp.text)
            if not match:
                match = re.search(r"Fraud Score:\s*(\d+)", resp.text, re.IGNORECASE)
            if match:
                return int(match.group(1))
    except requests.RequestException:
        pass
    return None


def check_china_tcp(ip: str, port: int = 443) -> dict[str, Any]:
    overseas_open = False
    try:
        with socket.create_connection((ip, port), timeout=2.5):
            overseas_open = True
    except OSError:
        overseas_open = False

    if not overseas_open:
        return {"status": "closed", "port": port}

    try:
        resp = requests.post(
            "https://api.globalping.io/v1/measurements",
            json={
                "type": "ping",
                "target": ip,
                "locations": [{"country": "CN"}],
                "limit": 3,
                "measurementOptions": {
                    "protocol": "TCP",
                    "port": port,
                    "packets": 2,
                },
            },
            timeout=8.0,
        )
        if resp.status_code not in (200, 201, 202):
            return {"status": "unknown", "port": port}
        m_id = resp.json().get("id")
        if not m_id:
            return {"status": "unknown", "port": port}

        deadline = time.time() + 18.0
        data: dict[str, Any] = {}
        while time.time() < deadline:
            time.sleep(1.5)
            r = requests.get(
                f"https://api.globalping.io/v1/measurements/{m_id}", timeout=6.0
            )
            if r.status_code == 200:
                data = r.json()
                if data.get("status") != "in-progress":
                    break

        results = data.get("results") or []
        if not results:
            return {"status": "unknown", "port": port}

        ok_rtts: list[float] = []
        total = len(results)
        for item in results:
            stats = (item.get("result") or {}).get("stats") or {}
            rcv = int(stats.get("rcv") or 0)
            avg = stats.get("avg")
            if rcv > 0 and avg is not None:
                ok_rtts.append(float(avg))

        if not ok_rtts:
            return {"status": "blocked", "port": port, "ok": 0, "total": total}

        avg_ms = sum(ok_rtts) / len(ok_rtts)
        return {
            "status": "ok",
            "port": port,
            "ok": len(ok_rtts),
            "total": total,
            "avg_ms": round(avg_ms),
        }
    except requests.RequestException:
        return {"status": "unknown", "port": port}


def roll_and_switch_oci_ip(
    prefixes: list[str] | None = None,
    max_attempts: int = 10,
    max_risk: int = 50,
) -> str:
    """
    自动刷取新的优质 OCI 预留公网 IP，无损绑定至当前实例主网卡，
    同时自动释放旧预留 IP（杜绝闲置计费），并在完成后返回新 IP 质量报告与 sing-box 节点链接。
    """
    config = get_oci_config()
    comp_id = config["tenancy"]
    vn_client = oci.core.VirtualNetworkClient(config)
    priv_id = resolve_primary_private_ip_id(vn_client, comp_id)

    # 先确保 VCN 挂载免费 Service Gateway，确保本机解绑旧公网 IP 期间 OCI API 不断连
    ensure_service_gateway(vn_client, priv_id)

    initial_pub: oci.core.models.PublicIp | None = None
    try:
        initial_pub = vn_client.get_public_ip_by_private_ip_id(
            oci.core.models.GetPublicIpByPrivateIpIdDetails(private_ip_id=priv_id)
        ).data
    except oci.exceptions.ServiceError as e:
        if e.status != 404:
            raise
    initial_ip = initial_pub.ip_address if initial_pub else "未绑定"

    total_rolls = 0
    final_ip = ""
    final_info: dict[str, Any] = {}
    final_score: int | None = None
    final_gfw: dict[str, Any] = {"status": "unknown", "port": 443}

    # 外层循环：若绑定后实测国内 TCP 443 被墙，自动再换一次（最多 3 轮）
    for gfw_round in range(1, 4):
        chosen_pub: oci.core.models.PublicIp | None = None

        for attempt in range(1, max_attempts + 1):
            total_rolls += 1
            display_name = f"reserved-ip-{int(time.time())}"
            created_pub: oci.core.models.PublicIp | None = None
            try:
                created_pub = vn_client.create_public_ip(
                    oci.core.models.CreatePublicIpDetails(
                        compartment_id=comp_id,
                        lifetime="RESERVED",
                        display_name=display_name,
                    )
                ).data
                created_pub = wait_public_ip_stable(vn_client, created_pub.id)
                cand_ip = created_pub.ip_address
                log(f"[换IP] 第 {total_rolls} 次抽取到预留 IP: {cand_ip}")

                if prefixes and not any(cand_ip.startswith(p) for p in prefixes):
                    log(f"[换IP] {cand_ip} 未匹配前缀 {prefixes}，释放重试...")
                    vn_client.delete_public_ip(created_pub.id)
                    created_pub = None
                    if attempt < max_attempts:
                        time.sleep(2.5)
                    continue

                ip_info = fetch_ip_info(cand_ip) or {}
                scam_score = fetch_scamalytics_score(cand_ip)
                is_proxy = bool(ip_info.get("proxy"))

                quality_ok = (not is_proxy) and (
                    scam_score is None or scam_score <= max_risk
                )
                if quality_ok or (not prefixes and attempt == max_attempts):
                    chosen_pub = created_pub
                    final_ip = cand_ip
                    final_info = ip_info
                    final_score = scam_score
                    break

                log(
                    f"[换IP] 淘汰高危 IP {cand_ip} (proxy={is_proxy}, scam={scam_score})，释放重试..."
                )
                vn_client.delete_public_ip(created_pub.id)
                created_pub = None
            except oci.exceptions.ServiceError as e:
                if created_pub is not None:
                    try:
                        vn_client.delete_public_ip(created_pub.id)
                    except Exception:
                        pass
                if e.status == 429:
                    time.sleep(8.0)
                    continue
                raise

            if attempt < max_attempts:
                time.sleep(2.5)

        if not chosen_pub:
            raise RuntimeError(
                f"连续尝试 {max_attempts} 次未刷出符合条件的预留 IP（旧 IP `{initial_ip}` 保持不变）"
            )

        # 执行换绑：新建客户端连接以走 Service Gateway 路由，解绑旧 IP -> 绑定新 IP -> 删除旧预留 IP
        vn_client = oci.core.VirtualNetworkClient(config)
        cur_pub: oci.core.models.PublicIp | None = None
        try:
            cur_pub = vn_client.get_public_ip_by_private_ip_id(
                oci.core.models.GetPublicIpByPrivateIpIdDetails(private_ip_id=priv_id)
            ).data
        except oci.exceptions.ServiceError as e:
            if e.status != 404:
                raise

        if cur_pub and cur_pub.id != chosen_pub.id:
            if cur_pub.lifetime == "EPHEMERAL":
                vn_client.delete_public_ip(cur_pub.id)
                for _ in range(25):
                    try:
                        vn_client.get_public_ip(cur_pub.id)
                        time.sleep(1.0)
                    except oci.exceptions.ServiceError as e:
                        if e.status == 404:
                            break
            else:
                vn_client.update_public_ip(
                    cur_pub.id,
                    oci.core.models.UpdatePublicIpDetails(private_ip_id=""),
                )
                wait_public_ip_stable(vn_client, cur_pub.id)

        for bind_try in range(4):
            try:
                vn_client.update_public_ip(
                    chosen_pub.id,
                    oci.core.models.UpdatePublicIpDetails(private_ip_id=priv_id),
                )
                break
            except Exception:
                if bind_try == 3:
                    raise
                time.sleep(1.5)
                vn_client = oci.core.VirtualNetworkClient(config)

        wait_public_ip_stable(vn_client, chosen_pub.id)

        # 清理所有未绑定的闲置预留 IP（包含刚刚解绑的旧预留 IP），确保 0 遗留计费
        for item in vn_client.list_public_ips(
            scope="REGION", compartment_id=comp_id, lifetime="RESERVED"
        ).data:
            if not item.private_ip_id and item.id != chosen_pub.id:
                try:
                    vn_client.delete_public_ip(item.id)
                except Exception:
                    pass

        # 等待新公网 IP 出站路由就绪
        for _ in range(10):
            try:
                r = requests.get("https://icanhazip.com", timeout=3)
                if r.status_code == 200:
                    break
            except Exception:
                pass
            time.sleep(1.0)

        # 检测新绑定 IP 的国内 TCP 443 (以及 22) 连通性
        final_gfw = check_china_tcp(final_ip, port=443)
        if final_gfw.get("status") == "closed":
            final_gfw = check_china_tcp(final_ip, port=22)

        if final_gfw.get("status") == "blocked" and gfw_round < 3:
            log(f"[换IP] 新 IP {final_ip} 国内 TCP 被阻断，正在自动开启第 {gfw_round + 1} 轮重刷...")
            continue
        break

    country = final_info.get("country") or "-"
    cc = final_info.get("countryCode") or ""
    city = final_info.get("city") or ""
    loc_str = f"{country} ({cc}) {city}".strip() if cc else country
    asn_str = final_info.get("as") or "-"
    score_str = f"{final_score}/100" if final_score is not None else "未知"
    proxy_str = "是" if final_info.get("proxy") else "否"

    g_st = final_gfw.get("status")
    g_port = final_gfw.get("port", 443)
    if g_st == "ok":
        gfw_str = f"正常 ({final_gfw['ok']}/{final_gfw['total']} 节点连通, ~{final_gfw['avg_ms']}ms, 端口 {g_port})"
    elif g_st == "blocked":
        gfw_str = f"被阻断 (端口 {g_port})"
    else:
        gfw_str = f"未检出阻断 (端口 {g_port})"

    lines = [
        "### OCI 换 IP 完成",
        f"- **旧公网 IP**: `{initial_ip}` (已解绑并释放)",
        f"- **新公网 IP**: `{final_ip}` (共刷取 `{total_rolls}` 次)",
        f"- **归属地区**: `{loc_str}`",
        f"- **ASN 信息**: `{asn_str}`",
        f"- **纯净指标**: `欺诈分 {score_str}` | `代理标记: {proxy_str}`",
        f"- **国内 TCP**: `{gfw_str}`",
    ]
    try:
        sb_links = build_singbox_links(ip_override=final_ip)
        lines.extend(["", sb_links])
    except Exception as e:
        lines.append(f"- **节点链接**: 生成失败 (`{e}`)")

    return "\n".join(lines)


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
        self.current_ws: Any = None
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

    async def handle_user_command(
        self,
        target: dict[str, Any],
        sender_id: str,
        raw_content: str,
        msg_id: str,
    ) -> None:
        loop = asyncio.get_running_loop()

        # 权限校验：仅允许绑定的主人 OpenID 调用
        if not self.owner_openid and sender_id:
            self.owner_openid = sender_id
            self.state["owner_openid"] = sender_id
            self.save_state()

        if self.owner_openid and sender_id != self.owner_openid:
            log(f"拒绝非授权用户 [{sender_id}] 调用: {raw_content}")
            await loop.run_in_executor(
                None,
                self.send_message,
                target,
                "### 权限不足\n- 此机器人为私人专属，仅限主人调用。",
                msg_id,
            )
            return

        text = raw_content.strip()
        if ">" in text:
            text = text.split(">", 1)[-1].strip()
        text = text.lstrip("/").strip()
        parts = text.split()
        if len(parts) >= 2 and parts[0].lower() == "oci":
            cmd = f"oci_{parts[1].lower().replace('-', '_')}"
            cmd_args = parts[2:]
        elif parts:
            cmd = parts[0].lower().replace("-", "_")
            cmd_args = parts[1:]
        else:
            cmd = ""
            cmd_args = []

        is_first_bind = "target" not in self.state
        self.state["target"] = target
        self.state["last_msg_id"] = msg_id
        self.save_state()

        log(f"收到指令 [{target.get('type')}:{target.get('id')}]: /{cmd} {cmd_args}")

        if cmd in ("oci_roll", "oci_change", "oci_switch", "oci_newip"):
            if self.rolling_ip:
                await loop.run_in_executor(
                    None,
                    self.send_message,
                    target,
                    "### 任务进行中\n- 当前正在执行换 IP 任务，请等待本轮完成。",
                    msg_id,
                )
                return

            self.rolling_ip = True
            prefix_hint = f" (目标前缀: `{', '.join(cmd_args)}`)" if cmd_args else ""
            await loop.run_in_executor(
                None,
                self.send_message,
                target,
                f"### 正在更换公网 IP\n- 正在刷取并检测优质预留 IP{prefix_hint}，换绑期间网络会短暂切换，完成后将自动推送新 IP 与节点链接...",
                msg_id,
            )
            try:
                reply = await loop.run_in_executor(
                    None,
                    roll_and_switch_oci_ip,
                    cmd_args if cmd_args else None,
                )
            except Exception as e:
                reply = f"### 换 IP 失败\n- `{e}`"
            finally:
                self.rolling_ip = False

            await loop.run_in_executor(
                None, self.send_message, target, reply, msg_id
            )
            if self.current_ws is not None:
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
                    "- `/oci_roll` : 自动刷取并更换优质公网 IP (支持 `/oci_roll 138.2.`)\n"
                    "- `/oci_clean` : 释放未绑定预留 IP\n"
                    "- `/oci_link` : 获取 sing-box 节点链接\n"
                    "- `/oci_status` : 查看服务器实时负载与流量指标"
                )
        except Exception as e:
            reply = f"### 执行出错\n- `{e}`"

        await loop.run_in_executor(
            None, self.send_message, target, reply, msg_id
        )

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
                                    msg_id = d.get("id", "")
                                    if openid:
                                        asyncio.create_task(
                                            self.handle_user_command(
                                                {"type": "c2c", "id": openid},
                                                openid,
                                                content,
                                                msg_id,
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
                                    msg_id = d.get("id", "")
                                    if group_openid:
                                        asyncio.create_task(
                                            self.handle_user_command(
                                                {"type": "group", "id": group_openid},
                                                sender_id,
                                                content,
                                                msg_id,
                                            )
                                        )
                                elif event_type == "AT_MESSAGE_CREATE":
                                    author = d.get("author") or {}
                                    sender_id = author.get("id") or ""
                                    channel_id = d.get("channel_id")
                                    content = d.get("content", "")
                                    msg_id = d.get("id", "")
                                    if channel_id:
                                        asyncio.create_task(
                                            self.handle_user_command(
                                                {"type": "channel", "id": channel_id},
                                                sender_id,
                                                content,
                                                msg_id,
                                            )
                                        )
                                elif event_type == "DIRECT_MESSAGE_CREATE":
                                    author = d.get("author") or {}
                                    sender_id = author.get("id") or ""
                                    guild_id = d.get("guild_id")
                                    content = d.get("content", "")
                                    msg_id = d.get("id", "")
                                    if guild_id:
                                        asyncio.create_task(
                                            self.handle_user_command(
                                                {"type": "dms", "id": guild_id},
                                                sender_id,
                                                content,
                                                msg_id,
                                            )
                                        )
                    finally:
                        hb_fut.cancel()

            except Exception as e:
                log(f"WebSocket 连接断开 ({e})，5 秒后重连...")
                await asyncio.sleep(5)

    async def run(self) -> None:
        await asyncio.gather(
            self.ws_loop(),
            self.scheduler_loop(),
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
