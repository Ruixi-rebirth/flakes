---
name: nix-flake-updater
description: 更新 Nix flake inputs（选择性或全部）、重建系统并提交更改。当需要更新 flake.lock 依赖并通过系统重建进行验证时使用。
---

# Nix Flake 更新器 (Nix Flake Updater)

本 Skill 自动化了更新 Nix flake inputs、通过系统重建验证更改以及提交更新的过程。

## 工作流程

### 1. 识别 Inputs

扫描 `flake.nix` 文件以识别可用 inputs。你可以使用提供的脚本来列出它们：

```bash
.agents/skills/nix-flake-updater/scripts/update_flake.sh list
```

### 2. 用户选择

询问用户想要更新哪些 inputs。

- 提供列表中的特定 inputs 选项。
- 提供更新“全部 (all)” inputs 的选项。

### 3. 执行更新

针对选定的 inputs 运行更新命令：

- **特定 inputs**: `.agents/skills/nix-flake-updater/scripts/update_flake.sh update <input1> <input2> ...`
- **全部 inputs**: `.agents/skills/nix-flake-updater/scripts/update_flake.sh update all`

### 4. 验证与修正（关键步骤）

在 `flake.lock` 更新后，你 **必须** 验证更改。验证过程包含两个关键阶段：`nix flake check` 和系统重建。

#### 在 `nix flake check` 期间进行主动检测

在重建之前，运行 `nix flake check`。**即使命令成功执行（退出码为 0），你也必须监控输出中的警告信息。**

- **关注内容**: "renamed to" (更名为), "replaced by" (被替换为), "deprecated" (已弃用) 或 "unknown option" (未知选项)。
- **操作**: 如果出现 _任何_ 此类消息，**立即停止** 并进行修正。不要在存在待处理配置警告的情况下继续进行重建阶段。

#### 系统重建

如果 `nix flake check` 通过（且警告已处理），请使用 `nixos-rebuild` skill 继续重建：
`./.agents/skills/nixos-rebuild/scripts/rebuild-wrapper.sh switch [host]`

### 5. 故障排除与修正循环

如果 `nix flake check` 或重建失败，或者检测到了警告：

1.  **分析信息**: 仔细阅读错误/警告信息。确定导致问题的确切选项或软件包。
2.  **研究修复方案**:
    - 使用 `grep_search` 在配置中定位有问题的代码行。
    - 参考更新后的 input 文档（例如 NixOS unstable, Home Manager）。
3.  **应用修正**: 使用 `replace` 或 `write_file` 工具更新你的 Nix 配置文件。
4.  **重试验证**: 在重新尝试重建之前，运行 `nix flake check`（并处理任何 _新_ 出现的警告）。
5.  **迭代**: 重复此循环，直到构建成功 **且没有任何** 与配置相关的警告。

### 6. 提交更改

一旦重建成功且环境整洁，询问用户是否要提交。

- 如果是，激活并使用 `git-workflow` skill。
- 建议的提交信息：`chore: update flake inputs` 或 `chore: update <input-name> flake input`。
- 如果为了修复构建而进行了配置更改，请在提交正文中说明（例如 `feat: update flake inputs and fix renamed options`）。

## 资源

- **脚本**:
  - `scripts/update_flake.sh`: 处理列出和更新 flake inputs 的逻辑。
