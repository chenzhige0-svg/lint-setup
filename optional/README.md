# optional —— 不参与主链路的替代方案

这些文件保留给特定项目，默认不要复制到新仓库：

| 文件                 | 用途              | 何时启用                                                                |
| -------------------- | ----------------- | ----------------------------------------------------------------------- |
| `ruff.toml`          | 独立 Ruff 配置    | 项目没有 `pyproject.toml` 时；注意它会覆盖 pyproject 中的 `[tool.ruff]` |
| `pyrightconfig.json` | 独立 Pyright 配置 | 项目不使用 `pyproject.toml` 时                                          |
| `mypy.ini`           | 遗留项目的 mypy   | 团队坚持 mypy 而非 pyright 时（二者只留一个）                           |
| `.flake8`            | flake8            | ROS `ament_flake8` 或遗留项目；本地主链路用 Ruff                        |
| `uncrustify.cfg`     | uncrustify        | ROS `ament_uncrustify` 链路；不要与 clang-format 同时用                 |
| `lefthook.yml`       | lefthook 钩子     | 团队决定不用 pre-commit 时；二者只留一个                                |

ROS 2 项目建议：本地用 Ruff + clang-format + clang-tidy，CI 里再跑 ament_flake8 /
ament_cpplint / ament_uncrustify，避免双套风格门禁。
