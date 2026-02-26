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

## 扩展参考资料 (Extended References)

为了更深入地理解 Nix 语言和 Flake 框架，以下是一些推荐的权威资源：

### Flake 框架 (flake-parts)

- **flake-parts GitHub Repository**: [https://github.com/hercules-ci/flake-parts](https://github.com/hercules-ci/flake-parts)
  - **描述**: `flake-parts` 是一个用于构建可组合、可扩展 Nix Flake 的框架。它提供了一种模块化的方式来定义和组合 Flake 的输出，非常适合大型或多主机配置项目。理解其模块系统、`perSystem` 和 `specialArgs` 的用法至关重要。

### Nix 语言基础 (Nix Language Fundamentals)

- **Nix Pills**: [https://nixos.org/guides/nix-pills/](https://nixos.org/guides/nix-pills/)
  - **描述**: Nix 语言的深度教程，从基本概念到高级主题，是理解 Nix 工作原理的基石。强烈推荐通读，尤其关注惰性求值、函数式编程范式和递归属性集。
- **NixOS/nixpkgs Manual (Nixpkgs 章节)**: [https://nixos.org/manual/nixpkgs/unstable/](https://nixos.org/manual/nixpkgs/unstable/)
  - **描述**: 官方的 Nixpkgs 手册，详细介绍了 Nixpkgs 的结构、如何定义包、使用 Overlays、以及 `lib` 库的各种实用函数。这是编写高质量 Nix 代码的必备参考。
- **Nix Language Reference**: [https://nixos.org/manual/nix/unstable/language/](https://nixos.org/manual/nix/unstable/language/)
  - **描述**: Nix 语言的官方语法和语义参考。当你不确定某个语法结构或内置函数的行为时，这里是最终的权威来源。

### NixOS 和 Home Manager

- **NixOS Manual**: [https://nixos.org/manual/nixos/unstable/](https://nixos.org/manual/nixos/unstable/)
  - **描述**: NixOS 系统的官方手册，详细解释了 NixOS 模块系统的运作方式、如何配置系统服务、硬件以及各种 NixOS 选项。
- **Home Manager Manual**: [https://nixos.org/manual/home-manager/master/](https://nixos.org/manual/home-manager/master/)
  - **描述**: Home Manager 的官方手册，介绍了如何使用 Home Manager 管理用户环境的配置，包括程序、点文件和 Shell 环境。理解其模块系统和选项对于管理用户配置至关重要。
