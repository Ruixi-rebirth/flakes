---
name: git-workflow
description: 标准化的代码暂存、提交（包含 GPG 签名）和推送流程。当需要使用约定式提交（Conventional Commits）并处理交互式 GPG 验证时使用。
---

# Git 工作流 Skill (Git Workflow Skill)

本 Skill 提供了一种遵循主流规范的结构化代码提交方法。

## 核心任务

### 1. 暂存更改 (Add)

将修改后的文件暂存以备提交。

- **特定文件**：`git add <file1> <file2>`
- **所有更改**：`git add .`（遵循现有的 `.gitignore`）

### 2. 创建提交 (约定式提交)

根据更改内容生成提交消息。消息应遵循格式：`<type>: <description>`，复杂更改应包含正文（body）进行详细说明。

**常用类型 (Types)**：

- `feat`: 新功能
- `fix`: 修复 Bug
- `docs`: 文档变更
- `style`: 代码格式调整（不影响逻辑，如空格、分号等）
- `refactor`: 代码重构（既不是修复 Bug 也不是添加新功能）
- `perf`: 性能优化
- `test`: 添加或更新测试
- `chore`: 构建过程或辅助工具的变动（如更新依赖、CI/CD 配置等）

**GPG 验证与交互操作**：
提交代码需要 GPG 密钥验证。在 Gemini CLI 中：

- **环境变量**：运行提交命令前应通过 `GPG_TTY=$(tty)` 告知 GPG 交互终端。
- **终端聚焦**：当出现 GPG 密码输入界面（如 pinentry-curses）时，聚焦到终端并进行输入操作。
- **完成认证**：输入密码并回车后，系统将自动继续后续流程。

### 3. 推送到远程仓库

- **命令**：`git push`

## 工作流程

1. **同步与分析**：
   - 执行 `git fetch` 检查远程更新。
   - 使用 `git status` 了解本地与远程的同步状态（是否领先、落后或分叉）。
   - 使用 `git diff` 确认具体更改内容。
2. **暂存**：使用 `git add` 暂存相关文件。
3. **生成提交**：
   - 确定合适的类型（如 `feat`, `fix`）。
   - 编写简短的摘要（最多 50 个字符）。
   - 如果更改复杂，添加详细的正文解释“为什么”。
   - 执行 `GPG_TTY=$(tty) git commit -m "<message>"`（并在出现提示时按 `Ctrl + f` 进行 GPG 认证）。
4. **同步与推送**：
   - 执行 `git remote -v` 以确认远程仓库的别名（如 `origin`, `gh`）和对应的 URL。
   - 如果本地与远程分叉（Diverged），建议执行 `git pull --rebase` 以保持提交历史整洁。
   - 执行 `git push <remote> <branch>` 进行同步。

## 验证

- **代码整洁**：提交前应运行 `nix fmt` 以确保代码符合格式规范。
- **配置有效**：建议在提交前运行 `nix flake check` 以验证 Flake 完整性。
- **状态同步**：推送后运行 `git status` 以确保工作目录干净。
