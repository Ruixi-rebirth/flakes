---
name: flake-analyzer
description: 使用自定义的 Go MCP Server 对当前 NixOS Flake 仓库进行深度概览分析。用于快速了解项目规模、主机配置和文件结构。
---

# Flake 分析器 Skill (Flake Analyzer Skill)

本 Skill 旨在利用 `flake-stats-mcp` 工具提供的底层统计能力，为用户提供一个结构化的 Flake 仓库报告。

## 核心任务

### 1. 快速概览 (Quick Scan)

当用户询问“查一下我的 Flake”或“Flake 规模如何”时，请按照以下流程操作：

- **调用工具**：`get_flake_summary` (来自 `flake-stats-mcp` 服务)。
- **理解输出**：该工具会返回主机列表 (k-on, minimal, yu) 和 Nix 文件总数。
- **生成报告**：将这些信息以更友好的中文格式呈现给用户。

### 2. 状态检查

- **路径验证**：确认 `hosts/` 目录结构是否符合 Flake 规范。
- **文件分布**：根据文件总数评估配置的复杂程度。

## 工作流程

1. **激活工具**：确保 `flake-stats-mcp` 客户端已连接。
2. **执行调用**：通过 MCP 协议调用 `get_flake_summary`。
3. **关联分析**：
   - 如果主机数量较多（> 2），重点核实各主机的 `default.nix`。
   - 如果 Nix 文件较多（> 100），建议用户进行更细粒度的目录拆分。
4. **输出结论**：总结当前仓库的健康状态。

## 验证

- 每次运行分析后，确认输出的统计数字与当前工作目录下的实际情况一致。
