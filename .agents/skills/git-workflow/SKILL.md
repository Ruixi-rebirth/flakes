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

**GPG 验证**：
提交代码需要 GPG 密钥验证。运行 `git commit` 时，请准备好等待用户输入或 GPG 代理（agent）的交互。

### 3. 推送到远程仓库
- **命令**：`git push`

## 工作流程

1. **分析**：使用 `git status` 和 `git diff` 了解更改内容。
2. **暂存**：使用 `git add` 暂存相关文件。
3. **生成提交**：
   - 确定合适的类型（如 `feat`, `fix`）。
   - 编写简短的摘要（最多 50 个字符）。
   - 如果更改复杂，添加详细的正文解释“为什么”。
   - 执行 `git commit -m "<message>"`（并等待 GPG 验证）。
4. **推送**：执行 `git push` 进行同步。

## 验证
- 推送后运行 `git status` 以确保工作目录干净。
- 对于本项目，建议在提交前运行 `nix flake check`。
