# Nix 最佳实践指南

## 命名规范 (Naming Conventions)
- **Attribute Sets (属性集)**：属性名应使用 kebab-case（例如：`pkgs-unstable` 而不是 `pkgsUnstable` 或 `pkgs_unstable`），除非该键由现有包名（通常是 kebab-case）决定。
- **变量名**：变量名应具有描述性。
- **布尔值**：布尔值变量名应以 `is`, `has`, `enable`, `can` 开头（例如：`enableFeatures`）。
- **函数参数**：参数应明确命名，避免使用单字母名称，除非是在极其简短的 lambda 中。

## 代码风格与可维护性 (Maintainability)
- **避免全局 `with`**：在顶层使用 `with` 会掩盖变量来源，使调试困难。推荐在局部作用域使用，或显式引用（例如：`pkgs.lib.mkIf`）。
- **善用 `inherit`**：使用 `inherit` 从作用域中提取变量，使代码更加简洁且意图清晰。
- **垂直对齐**：对于长列表或属性集，每个元素占据一行。
- **注释**：复杂的 Nix 表达式（特别是递归或重度使用 `lib` 的部分）必须添加注释说明逻辑。

## 可扩展性 (Extensibility)
- **参数化**：尽量将硬编码的值提取为函数参数。
- **lib.mkMerge / lib.mkIf**：在 NixOS 模块或 Home Manager 配置中，使用这些原语而不是直接覆盖属性集。
- **Overlays**：提供 overlay 机制以便下游用户修改包定义。
- **Attribute Sets vs. Lists**：优先使用属性集，因为它们比列表更容易通过合并进行扩展。

## 常见反模式 (Anti-patterns)
- **死代码**：未引用的变量应使用 `_` 前缀或直接删除。
- **嵌套过深**：将大型属性集拆分为多个子文件并通过 `imports` 组合。
- **忽略 `lib` 工具函数**：重复实现 `lib` 中已有的逻辑（如 `flatten`, `mapAttrs`）。
