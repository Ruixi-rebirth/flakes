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
./.agents/skills/nixos-rebuild/scripts/rebuild-wrapper.sh switch [host]
```

_脚本会自动从 Flake 中检测可用主机。_

### 2. 测试配置 (Test)

将更改应用到当前运行的系统，但不添加到引导加载程序中。适用于有风险的更改。

```bash
./.agents/skills/nixos-rebuild/scripts/rebuild-wrapper.sh test [host]
```

### 3. 下次启动时应用 (Boot)

将更改添加到引导加载程序，但不立即应用到当前运行的系统。

```bash
./.agents/skills/nixos-rebuild/scripts/rebuild-wrapper.sh boot [host]
```

### 4. 干跑 (Dry Activate)

查看将应用哪些更改，而不实际执行。

```bash
./.agents/skills/nixos-rebuild/scripts/rebuild-wrapper.sh dry-activate [host]
```

## 配置更新工作流 (脚本自动化流程)

脚本 `./.agents/skills/nixos-rebuild/scripts/rebuild-wrapper.sh` 已集成以下流程：

1. **验证更改 (Validate)**：运行 `nix flake check` 检查配置有效性。
2. **格式化代码 (Format)**：通过 `nix fmt` 确保代码风格统一。
3. **选择主机 (Select Host)**：自动检测当前主机，若不匹配则提示从 Flake 定义中选择。
4. **执行重建 (Rebuild)**：执行指定的 `nixos-rebuild` 子命令。
5. **验证结果 (Verify)**：检查重建后的系统状态。

## 故障排除

如果重建失败，请参阅 [common-issues.md](references/common-issues.md)。

### 常用维护命令：

- **清理旧代（Generations）**：`sudo nix-collect-garbage -d`
- **优化存储**：`nix-store --optimize`
- **更新 Flake 输入**：`nix flake update`

## 主机特定说明

主机定义位于 `hosts/` 目录下，系统会动态解析 `flake.nix` 中的 `nixosConfigurations`。
