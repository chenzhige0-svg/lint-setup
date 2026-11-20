#!/usr/bin/env bash
# 把 lint 配置接入一个已有项目。
#
# 用法：
#   bash scripts/bootstrap-project.sh /path/to/project
#   bash scripts/bootstrap-project.sh /path/to/project --with-ci
#   bash scripts/bootstrap-project.sh /path/to/project --force
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WITH_CI=0
FORCE=0
TARGET=""

for arg in "$@"; do
	case "$arg" in
	--with-ci) WITH_CI=1 ;;
	--force) FORCE=1 ;;
	-h | --help)
		sed -n '2,7p' "$0"
		exit 0
		;;
	-*)
		echo "未知参数: $arg" >&2
		exit 2
		;;
	*)
		TARGET=$arg
		;;
	esac
done

[ -n "$TARGET" ] || {
	echo "用法: $0 /path/to/project [--with-ci] [--force]" >&2
	exit 2
}
[ -d "$TARGET" ] || {
	echo "目录不存在: $TARGET" >&2
	exit 1
}
TARGET=$(cd "$TARGET" && pwd)

FILES=(
	pyproject.toml
	.prettierrc.json
	.prettierignore
	eslint.config.mjs
	stylelint.config.mjs
	.markdownlint-cli2.yaml
	.yamllint.yaml
	.hadolint.yaml
	.shellcheckrc
	.clang-format
	.clang-tidy
	.clangd
	.editorconfig
	.gitattributes
	.gitleaks.toml
	.pre-commit-config.yaml
	rustfmt.toml
	clippy.toml
	.golangci.yml
)

echo "==> 接入 $TARGET"
for f in "${FILES[@]}"; do
	src="$REPO_DIR/configs/$f"
	dst="$TARGET/$f"
	[ -f "$src" ] || continue

	if [ -e "$dst" ] && [ "$FORCE" -ne 1 ]; then
		if [ "$f" = "pyproject.toml" ]; then
			cp -f "$src" "$TARGET/pyproject.lint-snippet.toml"
			echo "  ! $f 已存在，lint 段落写入 pyproject.lint-snippet.toml，请手动合并"
		else
			echo "  - 跳过已存在: $f"
		fi
	else
		cp -f "$src" "$dst"
		echo "  + $f"
	fi
done

if [ "$WITH_CI" -eq 1 ]; then
	echo "==> 安装 CI 模板"
	mkdir -p "$TARGET/.github/workflows" "$TARGET/.github/scripts"
	if [ -e "$TARGET/.github/workflows/lint.yml" ] && [ "$FORCE" -ne 1 ]; then
		echo "  - 跳过已存在: .github/workflows/lint.yml"
	else
		cp -f "$REPO_DIR/ci/lint.yml" "$TARGET/.github/workflows/lint.yml"
		echo "  + .github/workflows/lint.yml"
	fi
	cp -f "$REPO_DIR/ci/install-lint-tools.sh" "$TARGET/.github/scripts/install-lint-tools.sh"
	chmod +x "$TARGET/.github/scripts/install-lint-tools.sh"
	echo "  + .github/scripts/install-lint-tools.sh"
fi

if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	if command -v pre-commit >/dev/null 2>&1; then
		echo "==> 安装 Git 钩子"
		(cd "$TARGET" && pre-commit install --install-hooks)
	else
		echo "  ! 未找到 pre-commit，跳过钩子安装"
	fi
else
	echo "  ! 目标不是 Git 仓库，跳过钩子安装"
fi

cat <<EOF

完成。下一步：
  cd $TARGET
  pre-commit run --all-files

提示：
  - 如果生成了 pyproject.lint-snippet.toml，请把 [tool.ruff] / [tool.bandit] / [tool.pyright]
    合并到项目自己的 pyproject.toml，然后删除该临时文件。
  - 首次运行自动修复 hook 会修改文件并返回失败，重新 git add 后再跑一次。
EOF
