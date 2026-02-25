---
name: nixos-rebuild
description: 使用 Flakes 进行 NixOS 系统构建和配置管理。当用户需要应用、测试或验证 NixOS 配置更改、处理特定主机的重建或排查常见重建错误时使用。
---

# NixOS 重建 Skill (NixOS Rebuild Skill)

本 Skill 为重建 NixOS 系统提供结构化工作流，特别针对基于 Flake 的配置进行了优化。

## 核心任务

### 1. 应用配置更改 (Switch)
立即应用更改并将其添加到引导加载程序（bootloader）中。
```bash
sudo nixos-rebuild switch --flake .#<host>
```
*本工作区中的主机: `k-on`, `minimal`, `yu`。*

### 2. 测试配置 (Test)
将更改应用到当前运行的系统，但不添加到引导加载程序中。适用于有风险的更改。
```bash
sudo nixos-rebuild test --flake .#<host>
```

### 3. 下次启动时应用 (Boot)
将更改添加到引导加载程序，但不立即应用到当前运行的系统。
```bash
sudo nixos-rebuild boot --flake .#<host>
```

### 4. 干跑 (Dry Activate)
查看将应用哪些更改，而不实际执行。
```bash
nixos-rebuild dry-activate --flake .#<host>
```

## 配置更新工作流

1. **验证更改**：在重建之前，检查更改是否有效（例如运行 `nix flake check`）。
2. **选择主机**：确定要重建的主机配置（`k-on`、`minimal` 或 `yu`）。
3. **重建**：执行相应的 `nixos-rebuild` 命令。
4. **验证**：重建后检查系统状态。

## 故障排除

如果重建失败，请参阅 [common-issues.md](references/common-issues.md)。

### 常用维护命令：
- **清理旧代（Generations）**：`sudo nix-collect-garbage -d`
- **优化存储**：`nix-store --optimize`
- **更新 Flake 输入**：`nix flake update`

## 主机特定说明
- **k-on**：带有 Lanzaboote (Secure Boot) 和 Home Manager 的主要桌面系统。
- **minimal**：最小化系统，无 Lanzaboote。
- **yu**：基于 WSL 的系统。
