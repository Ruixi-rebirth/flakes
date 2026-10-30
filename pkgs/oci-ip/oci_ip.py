#!/usr/bin/env python3
"""
oci-ip: Oracle Cloud (OCI) 预留公网 IP 自动刷取（优质 IP 筛选）与无损绑定工具

默认自动从 sops-nix 解密路径读取认证信息：
  - 私钥文件: /run/secrets/oci_api_key (自动计算 fingerprint)
  - 用户 OCID: /run/secrets/oci_user_ocid
  - Tenancy / Region / 网卡私网 IP OCID: 自动从 OCI 实例元数据服务 (169.254.169.254) 获取
"""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import os
import re
import signal
import socket
import subprocess
import sys
import time
from dataclasses import dataclass, field
from typing import Any

import oci
import requests
from cryptography.hazmat.primitives import serialization

DEFAULT_SOPS_KEY_PATH = "/run/secrets/oci_api_key"
DEFAULT_SOPS_USER_PATH = "/run/secrets/oci_user_ocid"
DEFAULT_SOPS_TENANCY_PATH = "/run/secrets/oci_tenancy_ocid"
DEFAULT_REGION = "ap-singapore-1"

IMDS_BASE_URL = "http://169.254.169.254/opc/v2"
IMDS_HEADERS = {"Authorization": "Bearer Oracle"}

# ANSI colors
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
CYAN = "\033[36m"


def info(msg: str) -> None:
    print(f"{CYAN}[INFO]{RESET} {msg}", flush=True)


def ok(msg: str) -> None:
    print(f"{GREEN}[OK]{RESET}   {msg}", flush=True)


def warn(msg: str) -> None:
    print(f"{YELLOW}[WARN]{RESET} {msg}", flush=True)


def err(msg: str) -> None:
    print(f"{RED}[ERR]{RESET}  {msg}", file=sys.stderr, flush=True)


@dataclass
class QualityReport:
    ip: str
    passed: bool = True
    reasons: list[str] = field(default_factory=list)
    details: dict[str, Any] = field(default_factory=dict)


def fetch_imds(path: str, timeout: float = 0.5) -> Any | None:
    """从 OCI 实例元数据服务 (IMDSv2) 获取当前实例或网卡信息。"""
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


def calc_oci_fingerprint(pem_bytes: bytes) -> str:
    """根据私钥 .pem 内容自动计算 OCI API Key 的 MD5 指纹 (xx:xx:xx:...)，省去手动配置。"""
    priv_key = serialization.load_pem_private_key(pem_bytes, password=None)
    pub_der = priv_key.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    md5_hex = hashlib.md5(pub_der).hexdigest()
    return ":".join(md5_hex[i : i + 2] for i in range(0, len(md5_hex), 2))


def read_secret_text(path: str) -> str | None:
    expanded = os.path.expanduser(path)
    if os.path.exists(expanded):
        with open(expanded, "r", encoding="utf-8") as f:
            return f.read().strip()
    return None


def find_sops_yaml() -> str | None:
    """自动定位仓库中的 secrets/secrets.yaml，支持在本地电脑或服务器上直接解密。"""
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
    """当 /run/secrets 尚未生成或在本地电脑远程调用时，直接通过 sops 解密读取内存。"""
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


def build_vn_client(
    key_file: str,
    user_ocid: str | None,
    region: str | None = None,
) -> tuple[oci.core.VirtualNetworkClient, str | None, str]:
    """
    通过 sops 解密的私钥和 OCID 构建 OCI VirtualNetworkClient，
    同时支持在 OCI 实例上运行或在本地电脑 (k-on / yu) 远程运行。
    """
    imds_instance = fetch_imds("instance")
    imds_compartment = imds_instance.get("compartmentId") if imds_instance else None
    imds_region = (
        (imds_instance.get("canonicalRegionName") or imds_instance.get("region"))
        if imds_instance
        else None
    )

    expanded_key = os.path.expanduser(key_file)
    fallback_sops_yaml = find_sops_yaml()

    pem_str: str | None = None
    if os.path.exists(expanded_key):
        if os.geteuid() != 0 and not os.access(expanded_key, os.R_OK):
            os.execvp("sudo", ["sudo", sys.executable, *sys.argv])
        with open(expanded_key, "r", encoding="utf-8") as f:
            pem_str = f.read().strip()
    elif expanded_key == DEFAULT_SOPS_KEY_PATH:
        pem_str = sops_decrypt_key(fallback_sops_yaml, "oci_api_key")

    if not pem_str:
        raise RuntimeError(
            f"未找到 OCI API 私钥文件: {expanded_key}\n"
            "请确保 /run/secrets/oci_api_key 存在，或在包含 secrets/secrets.yaml 的机器上运行。"
        )

    fingerprint = calc_oci_fingerprint(pem_str.encode("utf-8"))
    effective_user = (
        user_ocid
        or os.environ.get("OCI_USER_OCID")
        or read_secret_text(DEFAULT_SOPS_USER_PATH)
        or sops_decrypt_key(fallback_sops_yaml, "oci_user_ocid")
    )
    effective_tenancy = (
        os.environ.get("OCI_TENANCY_OCID")
        or imds_compartment
        or read_secret_text(DEFAULT_SOPS_TENANCY_PATH)
        or sops_decrypt_key(fallback_sops_yaml, "oci_tenancy_ocid")
    )
    effective_region = (
        region
        or os.environ.get("OCI_REGION")
        or imds_region
        or DEFAULT_REGION
    )

    if not effective_user:
        raise RuntimeError(
            f"已加载私钥 (自动计算指纹: {fingerprint})，但未找到 User OCID。"
        )
    if not effective_tenancy:
        raise RuntimeError(
            "未能自动识别 tenancy OCID，请确保 secrets.yaml 中包含 oci_tenancy_ocid。"
        )

    config = {
        "user": effective_user,
        "fingerprint": fingerprint,
        "tenancy": effective_tenancy,
        "region": effective_region,
        "key_content": pem_str,
    }
    oci.config.validate_config(config)
    return oci.core.VirtualNetworkClient(config), effective_tenancy, effective_region


def resolve_context(
    client: oci.core.VirtualNetworkClient,
    compartment_id: str | None,
    private_ip_id: str | None,
    default_compartment: str | None,
) -> tuple[str, str | None]:
    """
    自动补全 compartment_id 和目标实例主网卡的 private_ip_id：
    - 若在 OCI 实例上运行，优先通过 IMDS 元数据获取；
    - 若在本地电脑远程运行，自动通过 OCI API 查询 VCN 子网下的主网卡私网 IP。
    """
    comp_id = compartment_id or default_compartment
    priv_id = private_ip_id

    if not priv_id:
        vnics = fetch_imds("vnics")
        if vnics and isinstance(vnics, list) and len(vnics) > 0:
            vnic_id = vnics[0].get("vnicId")
            if vnic_id:
                try:
                    priv_ips = client.list_private_ips(vnic_id=vnic_id).data
                    for p in priv_ips:
                        if p.is_primary:
                            priv_id = p.id
                            if not comp_id:
                                comp_id = p.compartment_id
                            break
                    if not priv_id and priv_ips:
                        priv_id = priv_ips[0].id
                except oci.exceptions.ServiceError:
                    pass

    # 如果不在 OCI 实例本机上运行（远程模式），优先从已绑定预留 IP 反查，再遍历子网下的主私网 IP
    if not priv_id and comp_id:
        try:
            for item in client.list_public_ips(
                scope="REGION", compartment_id=comp_id, lifetime="RESERVED"
            ).data:
                if item.private_ip_id:
                    priv_id = item.private_ip_id
                    break
            if not priv_id:
                subnets = client.list_subnets(compartment_id=comp_id).data
                for subnet in subnets:
                    priv_ips = client.list_private_ips(subnet_id=subnet.id).data
                    for p in priv_ips:
                        if p.is_primary:
                            priv_id = p.id
                            break
                    if priv_id:
                        break
        except oci.exceptions.ServiceError:
            pass

    if not comp_id and priv_id:
        try:
            priv_obj = client.get_private_ip(priv_id).data
            comp_id = priv_obj.compartment_id
        except oci.exceptions.ServiceError:
            pass

    if not comp_id:
        raise RuntimeError(
            "无法自动确定 compartment_id，请通过 --compartment-id 显式指定。"
        )

    return comp_id, priv_id


def wait_public_ip_stable(
    client: oci.core.VirtualNetworkClient,
    public_ip_id: str,
    timeout: int = 30,
) -> oci.core.models.PublicIp:
    """等待预留公网 IP 进入稳定状态 (AVAILABLE / ASSIGNED / UNASSIGNED)。"""
    stable_states = {"AVAILABLE", "ASSIGNED", "UNASSIGNED"}
    deadline = time.time() + timeout
    last_obj = None
    while time.time() < deadline:
        try:
            last_obj = client.get_public_ip(public_ip_id).data
            if last_obj.lifecycle_state in stable_states:
                return last_obj
        except Exception:
            client = oci.core.VirtualNetworkClient(client.base_client.config)
        time.sleep(1.0)
    return last_obj


def fetch_ip_info(ip: str, timeout: float = 6.0) -> dict[str, Any] | None:
    """查询 ip-api.com 获取 ASN、原生地区与代理/高危标记。"""
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
    """从 Scamalytics 网页提取 IP 欺诈风险分 (0-100，越低越纯净)。"""
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


def check_china_tcp(ip: str, port: int = 22) -> dict[str, Any]:
    """
    通过对比海外直连与 Globalping 中国大陆探针的 TCP 握手，检测该 IP 的指定端口是否被墙 (GFW 阻断)。
    """
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


def evaluate_ip_quality(
    ip: str,
    cidrs: list[str] | None = None,
    prefixes: list[str] | None = None,
    exclude_cidrs: list[str] | None = None,
    exclude_prefixes: list[str] | None = None,
    regex_pattern: str | None = None,
    check_reputation: bool = False,
    max_scamalytics_score: int | None = None,
    reject_abuser: bool = False,
    allowed_countries: list[str] | None = None,
    check_cmd: str | None = None,
    check_gfw_port: int | None = None,
) -> QualityReport:
    """多维度评估单个 IP 是否符合“优质 IP”条件。"""
    report = QualityReport(ip=ip)
    ip_obj = ipaddress.ip_address(ip)

    # 排除网段 / 前缀
    if exclude_prefixes:
        for pref in exclude_prefixes:
            if ip.startswith(pref):
                report.passed = False
                report.reasons.append(f"命中排除前缀 {pref}")
                return report

    if exclude_cidrs:
        for cidr in exclude_cidrs:
            if ip_obj in ipaddress.ip_network(cidr, strict=False):
                report.passed = False
                report.reasons.append(f"命中排除网段 {cidr}")
                return report

    # 指定网段 / 前缀白名单
    if prefixes:
        if not any(ip.startswith(pref) for pref in prefixes):
            report.passed = False
            report.reasons.append(f"未匹配目标前缀 {prefixes}")
            return report
        report.reasons.append("匹配目标前缀")

    if cidrs:
        if not any(ip_obj in ipaddress.ip_network(c, strict=False) for c in cidrs):
            report.passed = False
            report.reasons.append(f"未匹配目标网段 {cidrs}")
            return report
        report.reasons.append("匹配目标 CIDR 网段")

    # 正则匹配（如靓号/特定段格式）
    if regex_pattern:
        if not re.search(regex_pattern, ip):
            report.passed = False
            report.reasons.append(f"未匹配正则 {regex_pattern}")
            return report
        report.reasons.append(f"匹配正则 {regex_pattern}")

    # IP 纯净度与原生属地检测
    need_ip_info = check_reputation or reject_abuser or bool(allowed_countries)
    if need_ip_info:
        data = fetch_ip_info(ip)
        if data:
            country_code = data.get("countryCode") or "UNKNOWN"
            country = data.get("country") or ""
            city = data.get("city") or ""
            asn = data.get("as") or ""
            org = data.get("org") or ""
            is_proxy = bool(data.get("proxy"))

            report.details["country"] = f"{country} ({country_code})"
            report.details["city"] = city
            report.details["asn"] = asn
            report.details["org"] = org
            report.details["is_proxy"] = is_proxy

            if allowed_countries:
                upper_allowed = [c.upper() for c in allowed_countries]
                if country_code.upper() not in upper_allowed:
                    report.passed = False
                    report.reasons.append(
                        f"IP 归属国家 {country_code} 不在允许列表 {upper_allowed} 中"
                    )
                    return report

            if reject_abuser and is_proxy:
                report.passed = False
                report.reasons.append("被标记为公开代理/高风险节点 (proxy=True)")
                return report
        else:
            warn(f"无法获取 {ip} 的归属地信息，跳过该项 API 检查")

    # Scamalytics 欺诈值检测
    if max_scamalytics_score is not None:
        score = fetch_scamalytics_score(ip)
        report.details["scamalytics_score"] = score
        if score is not None:
            if score > max_scamalytics_score:
                report.passed = False
                report.reasons.append(
                    f"Scamalytics 欺诈分 {score} 高于阈值 {max_scamalytics_score}"
                )
                return report
            report.reasons.append(
                f"Scamalytics 欺诈分 {score} <= {max_scamalytics_score}"
            )
        else:
            warn(f"无法获取 {ip} 的 Scamalytics 评分，跳过该项阈值对比")

    # 国内 TCP 墙检 (GFW 阻断检测)
    if check_gfw_port:
        gfw_info = check_china_tcp(ip, port=check_gfw_port)
        report.details["gfw"] = gfw_info
        if gfw_info["status"] == "blocked":
            report.passed = False
            report.reasons.append(
                f"国内 TCP {check_gfw_port} 被墙 (海外可连 / 国内探针 100% 阻断)"
            )
            return report
        elif gfw_info["status"] == "ok":
            report.reasons.append(
                f"国内 TCP {check_gfw_port} 正常 ({gfw_info['ok']}/{gfw_info['total']} 节点连通, ~{gfw_info['avg_ms']}ms)"
            )

    # 自定义外部检测命令（例如配合辅助私网 IP 实测 ping / 端口连通性）
    if check_cmd:
        formatted_cmd = check_cmd.format(ip=ip)
        res = subprocess.run(formatted_cmd, shell=True)
        if res.returncode != 0:
            report.passed = False
            report.reasons.append(
                f"自定义检测命令未通过 (exit={res.returncode}): {formatted_cmd}"
            )
            return report
        report.reasons.append("自定义检测命令通过")

    if not report.reasons:
        report.reasons.append("默认通过全部检测项")
    return report


def ensure_service_gateway(
    client: oci.core.VirtualNetworkClient,
    private_ip_id: str,
) -> None:
    """
    确保目标网卡所在 VCN 已挂载免费的 Oracle Services Network 服务网关 (Service Gateway) 并配置路由：
    防止在实例本机执行解绑旧公网 IP 时，因短暂失去公网 IPv4 而导致后续绑定新 IP 的 OCI API 请求断网超时。
    """
    try:
        priv_obj = client.get_private_ip(private_ip_id).data
        subnet = client.get_subnet(priv_obj.subnet_id).data
        comp_id = subnet.compartment_id
        vcn_id = subnet.vcn_id
        rt_id = subnet.route_table_id

        services = client.list_services().data
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
            for s in client.list_service_gateways(
                compartment_id=comp_id, vcn_id=vcn_id
            ).data
            if s.lifecycle_state not in ("TERMINATING", "TERMINATED")
        ]
        if sgws:
            sgw = sgws[0]
            existing_svc_ids = {s.service_id for s in (sgw.services or [])}
            if target_svc.id not in existing_svc_ids:
                client.attach_service_id(
                    sgw.id,
                    oci.core.models.ServiceIdRequestDetails(service_id=target_svc.id),
                )
        else:
            sgw = client.create_service_gateway(
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
                sgw = client.get_service_gateway(sgw.id).data

        if rt_id:
            rt = client.get_route_table(rt_id).data
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
                client.update_route_table(
                    rt_id,
                    oci.core.models.UpdateRouteTableDetails(route_rules=rules),
                )
    except Exception:
        pass


def bind_reserved_ip_to_private_ip(
    client: oci.core.VirtualNetworkClient,
    reserved_ip_id: str,
    private_ip_id: str,
    delete_old_reserved: bool = False,
) -> oci.core.models.PublicIp:
    """
    将指定的预留公网 IP 绑定到目标私网 IP：
    - 若目标私网 IP 当前绑定了临时公网 IP (EPHEMERAL)，先将其删除解绑；
    - 若目标私网 IP 当前绑定了另一个预留公网 IP (RESERVED)，先将其解绑（可选删除）；
    - 然后将新的预留公网 IP 绑定到目标私网 IP。
    """
    ensure_service_gateway(client, private_ip_id)
    # 重建客户端连接池，确保后续解绑/换绑 API 请求走刚生效的 Service Gateway 内网路由
    client = oci.core.VirtualNetworkClient(client.base_client.config)

    existing_pub: oci.core.models.PublicIp | None = None
    try:
        existing_pub = client.get_public_ip_by_private_ip_id(
            oci.core.models.GetPublicIpByPrivateIpIdDetails(private_ip_id=private_ip_id)
        ).data
    except oci.exceptions.ServiceError as e:
        if e.status != 404:
            raise

    if existing_pub and existing_pub.id == reserved_ip_id:
        ok(f"预留 IP {existing_pub.ip_address} 已经绑定在目标私网 IP 上，无需重复操作。")
        return existing_pub

    # 忽略 SIGHUP：防止在 SSH 连接旧公网 IP 时因解绑旧 IP 导致终端断连而中断换绑流程
    if hasattr(signal, "SIGHUP"):
        signal.signal(signal.SIGHUP, signal.SIG_IGN)

    old_reserved_to_delete: oci.core.models.PublicIp | None = None

    if existing_pub:
        if existing_pub.lifetime == "EPHEMERAL":
            info(
                f"目标私网 IP 当前绑定了临时公网 IP {existing_pub.ip_address}，正在移除临时 IP..."
            )
            client.delete_public_ip(existing_pub.id)
            for _ in range(30):
                try:
                    client.get_public_ip(existing_pub.id)
                    time.sleep(1.0)
                except oci.exceptions.ServiceError as e:
                    if e.status == 404:
                        break
        else:
            info(
                f"目标私网 IP 当前绑定了旧预留公网 IP {existing_pub.ip_address}，正在解绑..."
            )
            client.update_public_ip(
                existing_pub.id,
                oci.core.models.UpdatePublicIpDetails(private_ip_id=""),
            )
            wait_public_ip_stable(client, existing_pub.id)
            if delete_old_reserved:
                old_reserved_to_delete = existing_pub

    wait_public_ip_stable(client, reserved_ip_id)
    for bind_try in range(4):
        try:
            updated = client.update_public_ip(
                reserved_ip_id,
                oci.core.models.UpdatePublicIpDetails(private_ip_id=private_ip_id),
            ).data
            break
        except Exception:
            if bind_try == 3:
                raise
            time.sleep(1.5)
            client = oci.core.VirtualNetworkClient(client.base_client.config)
    updated = wait_public_ip_stable(client, reserved_ip_id)

    if old_reserved_to_delete is not None:
        info(f"新 IP 已就绪，正在释放旧预留公网 IP {old_reserved_to_delete.ip_address}...")
        try:
            client.delete_public_ip(old_reserved_to_delete.id)
        except Exception:
            pass

    # 等待新公网 IP 出站互联网路由就绪
    for _ in range(10):
        try:
            r = requests.get("https://icanhazip.com", timeout=3)
            if r.status_code == 200:
                break
        except Exception:
            pass
        time.sleep(1.0)

    return updated


def cmd_status(args: argparse.Namespace) -> int:
    client, default_comp, region_str = build_vn_client(
        args.key_file, args.user_ocid, args.region
    )
    comp_id, priv_id = resolve_context(
        client, args.compartment_id, args.private_ip_id, default_comp
    )

    priv_ip_str = "未知"
    cur_pub: oci.core.models.PublicIp | None = None

    if priv_id:
        try:
            priv_obj = client.get_private_ip(priv_id).data
            role_tag = "主网卡" if priv_obj.is_primary else "辅助网卡"
            priv_ip_str = f"{priv_obj.ip_address} ({role_tag})"
        except oci.exceptions.ServiceError:
            pass

        try:
            cur_pub = client.get_public_ip_by_private_ip_id(
                oci.core.models.GetPublicIpByPrivateIpIdDetails(private_ip_id=priv_id)
            ).data
        except oci.exceptions.ServiceError as e:
            if e.status != 404:
                raise

    reserved_list = client.list_public_ips(
        scope="REGION", compartment_id=comp_id, lifetime="RESERVED"
    ).data

    print(f"区域     : {region_str}")
    print(f"私网 IP  : {priv_ip_str}")
    if cur_pub:
        lifetime_cn = "预留" if cur_pub.lifetime == "RESERVED" else "临时"
        print(f"当前公网 : {GREEN}{cur_pub.ip_address}{RESET} ({lifetime_cn}, {cur_pub.display_name})")
    else:
        print(f"当前公网 : {YELLOW}未绑定{RESET}")

    print(f"\n预留 IP ({len(reserved_list)}):")
    if not reserved_list:
        print("  无")
    else:
        for item in reserved_list:
            if item.private_ip_id:
                state_str = (
                    f"{GREEN}已绑定本机{RESET}"
                    if item.private_ip_id == priv_id
                    else f"{CYAN}已绑定其他网卡{RESET}"
                )
            else:
                state_str = f"{YELLOW}未绑定{RESET}"

            created_date = (
                item.time_created.strftime("%Y-%m-%d")
                if getattr(item, "time_created", None)
                else ""
            )
            print(
                f"  {item.ip_address:<16}  {state_str}  {item.display_name or '-'}  {created_date}"
            )
    return 0


def _print_single_check(ip: str, args: argparse.Namespace, tag: str = "") -> bool:
    report = evaluate_ip_quality(
        ip=ip,
        cidrs=args.cidr,
        prefixes=args.prefix,
        exclude_cidrs=args.exclude_cidr,
        exclude_prefixes=args.exclude_prefix,
        regex_pattern=args.regex,
        check_reputation=True,
        max_scamalytics_score=args.max_risk
        if args.max_risk is not None
        else 100,
        reject_abuser=args.no_abuser,
        allowed_countries=args.country,
        check_cmd=args.check_cmd,
        check_gfw_port=args.port,
    )
    badge = f"{GREEN}PASS{RESET}" if report.passed else f"{RED}FAIL{RESET}"
    d = report.details
    score = d.get("scamalytics_score")
    score_str = f"{score}/100" if score is not None else "未知"
    proxy_str = f"{RED}是{RESET}" if d.get("is_proxy") else f"{GREEN}否{RESET}"

    gfw = d.get("gfw") or {}
    gfw_status = gfw.get("status")
    gfw_port = gfw.get("port", args.port)
    if gfw_status == "ok":
        gfw_str = f"{GREEN}正常 ({gfw['ok']}/{gfw['total']} 节点连通, ~{gfw['avg_ms']}ms){RESET}"
    elif gfw_status == "blocked":
        gfw_str = f"{RED}被墙 (海外可连 / 国内 100% 丢包){RESET}"
    elif gfw_status == "closed":
        gfw_str = f"{YELLOW}端口未开放或 IP 未绑定主机 (无法测国内连通){RESET}"
    else:
        gfw_str = "未知"

    tag_suffix = f" ({tag})" if tag else ""
    print(f"IP       : {ip}{tag_suffix} [{badge}]")
    print(f"地区     : {d.get('country', '-')} {d.get('city', '')}")
    print(f"ASN      : {d.get('asn', '-')}")
    print(f"代理标记 : {proxy_str}")
    print(f"欺诈评分 : {score_str}")
    print(f"国内 TCP : {gfw_str} (端口 {gfw_port})")
    return report.passed


def cmd_check(args: argparse.Namespace) -> int:
    if args.ip:
        return 0 if _print_single_check(args.ip, args) else 1

    client, default_comp, _ = build_vn_client(
        args.key_file, args.user_ocid, args.region
    )
    comp_id, _ = resolve_context(client, args.compartment_id, None, default_comp)
    reserved_list = client.list_public_ips(
        scope="REGION", compartment_id=comp_id, lifetime="RESERVED"
    ).data
    if not reserved_list:
        warn("当前账号下没有任何预留公网 IP。")
        return 1

    all_passed = True
    for idx, item in enumerate(reserved_list):
        if idx > 0:
            print()
        tag = "已绑定" if item.private_ip_id else "候选未绑定"
        if not _print_single_check(item.ip_address, args, tag=tag):
            all_passed = False
    return 0 if all_passed else 1


def cmd_bind(args: argparse.Namespace) -> int:
    client, default_comp, _ = build_vn_client(
        args.key_file, args.user_ocid, args.region
    )
    comp_id, priv_id = resolve_context(
        client, args.compartment_id, args.private_ip_id, default_comp
    )
    if not priv_id:
        err("未能自动识别目标私网 IP OCID，请使用 --private-ip-id 指定。")
        return 1

    target_pub_id = args.reserved_ip_id
    if not target_pub_id:
        if args.ip:
            pub_obj = client.get_public_ip_by_ip_address(
                oci.core.models.GetPublicIpByIpAddressDetails(ip_address=args.ip)
            ).data
            target_pub_id = pub_obj.id
        else:
            reserved_list = client.list_public_ips(
                scope="REGION", compartment_id=comp_id, lifetime="RESERVED"
            ).data
            unbound = [
                item
                for item in reserved_list
                if not item.private_ip_id
                and item.lifecycle_state in {"AVAILABLE", "UNASSIGNED"}
            ]
            if not unbound:
                err("当前账号下没有未绑定的候选预留 IP，现有公网 IP 未做任何改动。请先执行 oci-ip roll 刷取候选 IP。")
                return 2
            if len(unbound) > 1:
                cand_ips = ", ".join(item.ip_address for item in unbound)
                err(f"当前存在多个未绑定候选 IP: {cand_ips}，请使用 --ip <目标IP> 指定要绑定的那一个。")
                return 3
            target_pub_id = unbound[0].id

    info(f"正在将预留公网 IP ({target_pub_id}) 绑定到私网 IP ({priv_id})...")
    updated = bind_reserved_ip_to_private_ip(
        client,
        reserved_ip_id=target_pub_id,
        private_ip_id=priv_id,
        delete_old_reserved=args.delete_old,
    )
    ok(f"绑定成功！当前实例公网 IP 已切换为: {BOLD}{updated.ip_address}{RESET}")
    return 0


def cmd_cleanup(args: argparse.Namespace) -> int:
    client, default_comp, _ = build_vn_client(
        args.key_file, args.user_ocid, args.region
    )
    comp_id, _ = resolve_context(client, args.compartment_id, None, default_comp)
    reserved_list = client.list_public_ips(
        scope="REGION", compartment_id=comp_id, lifetime="RESERVED"
    ).data

    if getattr(args, "ip", None):
        for item in reserved_list:
            if item.ip_address == args.ip:
                if item.private_ip_id:
                    err(f"预留 IP {args.ip} 当前处于已绑定状态，禁止直接删除！")
                    return 1
                info(f"正在释放指定的未绑定预留 IP: {item.ip_address} ({item.id})...")
                client.delete_public_ip(item.id)
                ok(f"已释放预留 IP: {args.ip}")
                return 0
        err(f"未在当前区域找到预留 IP: {args.ip}")
        return 1

    removed = 0
    for item in reserved_list:
        if not item.private_ip_id and item.lifecycle_state in {"AVAILABLE", "UNASSIGNED"}:
            info(f"正在释放未绑定的预留 IP: {item.ip_address} ({item.id})...")
            client.delete_public_ip(item.id)
            removed += 1
    ok(f"清理完成，共释放 {removed} 个未绑定的预留公网 IP。")
    return 0


def cmd_roll(args: argparse.Namespace) -> int:
    client, default_comp, _ = build_vn_client(
        args.key_file, args.user_ocid, args.region
    )
    comp_id, priv_id = resolve_context(
        client, args.compartment_id, args.private_ip_id, default_comp
    )

    if args.bind and not priv_id:
        err("开启了 --bind 但未能自动识别主私网 IP OCID，请通过 --private-ip-id 指定。")
        return 1

    info(f"开始刷取 OCI 预留公网 IP (最大尝试次数: {args.max_attempts}, 间隔: {args.interval}s)")
    if args.prefix or args.cidr:
        info(f"目标网段/前缀筛选: prefix={args.prefix or []}, cidr={args.cidr or []}")
    if args.max_risk is not None or args.no_abuser:
        info(
            f"纯净度要求: Scamalytics <= {args.max_risk}, 拒绝滥用标记={args.no_abuser}"
        )

    for attempt in range(1, args.max_attempts + 1):
        display_name = f"{args.name_prefix}-{int(time.time())}"
        created_pub: oci.core.models.PublicIp | None = None
        try:
            create_details = oci.core.models.CreatePublicIpDetails(
                compartment_id=comp_id,
                lifetime="RESERVED",
                display_name=display_name,
            )
            created_pub = client.create_public_ip(create_details).data
            created_pub = wait_public_ip_stable(client, created_pub.id)
            candidate_ip = created_pub.ip_address
            info(f"[{attempt}/{args.max_attempts}] 抽中预留 IP: {BOLD}{candidate_ip}{RESET}")

            # 如果配置了辅助私网 IP 实测，可临时挂到辅助私网 IP 上执行连通性/延迟脚本
            if args.probe_private_ip_id:
                info(f"临时绑定 {candidate_ip} 到辅助私网 IP ({args.probe_private_ip_id}) 进行实测...")
                bind_reserved_ip_to_private_ip(
                    client, created_pub.id, args.probe_private_ip_id
                )
                time.sleep(2.0)

            report = evaluate_ip_quality(
                ip=candidate_ip,
                cidrs=args.cidr,
                prefixes=args.prefix,
                exclude_cidrs=args.exclude_cidr,
                exclude_prefixes=args.exclude_prefix,
                regex_pattern=args.regex,
                check_reputation=args.check_reputation,
                max_scamalytics_score=args.max_risk,
                reject_abuser=args.no_abuser,
                allowed_countries=args.country,
                check_cmd=args.check_cmd,
            )

            # 若临时挂到了辅助私网 IP，测完先解绑
            if args.probe_private_ip_id:
                client.update_public_ip(
                    created_pub.id,
                    oci.core.models.UpdatePublicIpDetails(private_ip_id=""),
                )
                wait_public_ip_stable(client, created_pub.id)

            if report.passed:
                ok(f"命中优质预留 IP: {BOLD}{candidate_ip}{RESET}")
                d = report.details
                if d:
                    score = d.get("scamalytics_score")
                    score_str = f"{score}/100" if score is not None else "未知"
                    proxy_str = f"{RED}是{RESET}" if d.get("is_proxy") else f"{GREEN}否{RESET}"
                    print(f"地区     : {d.get('country', '-')} {d.get('city', '')}")
                    print(f"ASN      : {d.get('asn', '-')}")
                    print(f"代理标记 : {proxy_str}")
                    print(f"欺诈评分 : {score_str}")
                for reason in report.reasons:
                    ok(f"通过条件 : {reason}")

                if args.bind and priv_id:
                    info(f"正在将优质 IP {candidate_ip} 替换绑定到目标私网 IP ({priv_id})...")
                    bind_reserved_ip_to_private_ip(
                        client,
                        reserved_ip_id=created_pub.id,
                        private_ip_id=priv_id,
                        delete_old_reserved=args.delete_old,
                    )
                    ok(f"已完成自动绑定！新公网 IP: {BOLD}{candidate_ip}{RESET}")
                else:
                    info(f"该预留 IP 已保留在账户中 (未绑定)。")
                return 0

            # 未通过筛选：立即释放并等待下一轮
            reason_summary = "; ".join(report.reasons)
            warn(f"[{attempt}/{args.max_attempts}] 淘汰 {candidate_ip}: {reason_summary}")
            client.delete_public_ip(created_pub.id)
            created_pub = None

        except oci.exceptions.ServiceError as e:
            if created_pub is not None:
                try:
                    client.delete_public_ip(created_pub.id)
                except Exception:
                    pass
            if e.status == 429:
                backoff = max(args.interval * 2, 10.0)
                warn(f"触发 OCI API 速率限制 (429 TooManyRequests)，退避等待 {backoff}s...")
                time.sleep(backoff)
                continue
            err(f"OCI API 异常 (status={e.status}, code={e.code}): {e.message}")
            return 1
        except KeyboardInterrupt:
            warn("收到中断信号 (Ctrl+C)！")
            if created_pub is not None and not args.keep_on_interrupt:
                info(f"正在清理当前未命中的临时预留 IP {created_pub.ip_address}...")
                try:
                    client.delete_public_ip(created_pub.id)
                except Exception:
                    pass
            return 130

        if attempt < args.max_attempts:
            time.sleep(args.interval)

    err(f"已达到最大尝试次数 ({args.max_attempts})，暂未刷出符合条件的预留 IP。")
    return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="oci-ip",
        description="OCI 预留公网 IP 自动刷取（优质 IP 筛选）与无损绑定工具",
    )
    parser.add_argument(
        "--key-file",
        default=os.environ.get("OCI_KEY_FILE", DEFAULT_SOPS_KEY_PATH),
        help=f"OCI API 私钥 .pem 路径 (默认读取 sops: {DEFAULT_SOPS_KEY_PATH})",
    )
    parser.add_argument(
        "--user-ocid",
        default=None,
        help=f"OCI User OCID (默认读取 sops: {DEFAULT_SOPS_USER_PATH})",
    )
    parser.add_argument(
        "--region",
        default=os.environ.get("OCI_REGION"),
        help="覆盖 OCI Region (默认从实例元数据自动识别)",
    )
    parser.add_argument(
        "--compartment-id",
        default=os.environ.get("OCI_COMPARTMENT_ID"),
        help="Compartment OCID (默认从实例元数据自动识别)",
    )
    parser.add_argument(
        "--private-ip-id",
        default=os.environ.get("OCI_PRIVATE_IP_ID"),
        help="目标网卡主私网 IP 的 OCID (默认从实例元数据自动识别)",
    )

    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    # status / list / ls
    p_status = subparsers.add_parser(
        "status",
        aliases=["list", "ls"],
        help="查询当前网卡公网 IP 与账号下所有预留 IP 列表",
    )
    p_status.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="显示完整的底层 OCID 信息",
    )
    p_status.set_defaults(func=cmd_status)

    # roll
    p_roll = subparsers.add_parser("roll", help="循环申请预留 IP 并按条件筛选优质 IP")
    p_roll.add_argument(
        "-n",
        "--max-attempts",
        type=int,
        default=30,
        help="最大刷取尝试次数 (默认: 30)",
    )
    p_roll.add_argument(
        "-i",
        "--interval",
        type=float,
        default=4.0,
        help="每次重刷之间的间隔秒数，避免触发 API 限流 (默认: 4.0)",
    )
    p_roll.add_argument(
        "--name-prefix",
        default="reserved-ip",
        help="预留 IP 的名称前缀 (默认: reserved-ip)",
    )
    p_roll.add_argument(
        "--prefix",
        action="append",
        help="期望匹配的 IP 前缀，可多次指定 (如 --prefix 138.2. --prefix 146.56.)",
    )
    p_roll.add_argument(
        "--cidr",
        action="append",
        help="期望匹配的 CIDR 网段，可多次指定 (如 --cidr 138.2.0.0/16)",
    )
    p_roll.add_argument(
        "--exclude-prefix",
        action="append",
        help="需要排除的劣质 IP 前缀，可多次指定",
    )
    p_roll.add_argument(
        "--exclude-cidr",
        action="append",
        help="需要排除的劣质 CIDR 网段，可多次指定",
    )
    p_roll.add_argument(
        "--regex",
        help="IP 地址正则表达式匹配 (如尾号或连号筛选)",
    )
    p_roll.add_argument(
        "--check-reputation",
        action="store_true",
        help="启用 ipapi.is 查询 IP 归属地、ASN 与风险画像",
    )
    p_roll.add_argument(
        "--no-abuser",
        action="store_true",
        help="自动淘汰被 ipapi.is 标记为 abuser / proxy / tor 的高危 IP",
    )
    p_roll.add_argument(
        "--max-risk",
        type=int,
        help="要求 Scamalytics 欺诈风险评分不高于该阈值 (0-100，如 --max-risk 25)",
    )
    p_roll.add_argument(
        "--country",
        action="append",
        help="要求 IP 原生归属国家代码匹配 (如 --country SG --country JP)",
    )
    p_roll.add_argument(
        "--probe-private-ip-id",
        help="可选：辅助私网 IP 的 OCID，用于在不中断主 SSH 连接的前提下临时绑定实测连通性",
    )
    p_roll.add_argument(
        "--check-cmd",
        help="可选：自定义检测命令（支持 {ip} 占位符，返回码为 0 视为通过）",
    )
    p_roll.add_argument(
        "--bind",
        action="store_true",
        help="抽中优质预留 IP 后，立即自动替换绑定到目标实例主私网 IP",
    )
    p_roll.add_argument(
        "--delete-old",
        action="store_true",
        help="自动绑定时，如果原先绑定的是旧预留 IP，解绑后顺便将其释放删除",
    )
    p_roll.add_argument(
        "--keep-on-interrupt",
        action="store_true",
        help="按 Ctrl+C 中断时保留最后一个刚申请的预留 IP",
    )
    p_roll.set_defaults(func=cmd_roll)

    # bind
    p_bind = subparsers.add_parser("bind", help="将已有预留公网 IP 无损替换绑定到实例网卡")
    p_bind.add_argument("--ip", help="要绑定的预留公网 IP 地址")
    p_bind.add_argument("--reserved-ip-id", help="要绑定的预留公网 IP OCID")
    p_bind.add_argument(
        "--delete-old",
        action="store_true",
        help="若实例原先绑定的是另一个旧预留 IP，解绑后将其删除",
    )
    p_bind.set_defaults(func=cmd_bind)

    # check
    p_check = subparsers.add_parser("check", help="检测指定 IP 或当前账号下所有预留 IP 的纯净度与国内 TCP 墙检")
    p_check.add_argument("ip", nargs="?", help="要检测的公网 IP 地址 (省略则自动检测账号下所有预留 IP)")
    p_check.add_argument(
        "-p",
        "--port",
        type=int,
        default=443,
        help="检测国内 TCP 连通性的端口号 (默认: 443)",
    )
    p_check.add_argument("--prefix", action="append", help="期望匹配的 IP 前缀")
    p_check.add_argument("--cidr", action="append", help="期望匹配的 CIDR 网段")
    p_check.add_argument("--exclude-prefix", action="append", help="排除的 IP 前缀")
    p_check.add_argument("--exclude-cidr", action="append", help="排除的 CIDR 网段")
    p_check.add_argument("--regex", help="正则匹配规则")
    p_check.add_argument("--no-abuser", action="store_true", help="拒绝 abuser/proxy/tor")
    p_check.add_argument("--max-risk", type=int, help="最大 Scamalytics 欺诈分阈值")
    p_check.add_argument("--country", action="append", help="允许的原生国家代码")
    p_check.add_argument("--check-cmd", help="自定义检测命令（支持 {ip} 占位符）")
    p_check.set_defaults(func=cmd_check)

    # cleanup / rm / delete
    p_cleanup = subparsers.add_parser(
        "cleanup",
        aliases=["rm", "delete"],
        help="释放未绑定的闲置预留 IP（默认清理全部未绑定 IP，也可用 --ip 指定单个）",
    )
    p_cleanup.add_argument(
        "--ip",
        help="仅释放指定的某一个未绑定预留 IP 地址",
    )
    p_cleanup.set_defaults(func=cmd_cleanup)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return args.func(args)
    except Exception as e:
        err(str(e))
        return 1


if __name__ == "__main__":
    sys.exit(main())
