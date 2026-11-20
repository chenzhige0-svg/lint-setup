#!/usr/bin/env bash
# 在 WSL / Ubuntu 用户目录安装 lint 工具链（默认不需要 sudo）。
#
# 用法：
#   bash scripts/install-wsl.sh
#   bash scripts/install-wsl.sh --with-go --with-rust
#   bash scripts/install-wsl.sh --force       # 覆盖 ~/.config/dev-toolbox 中已有配置
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TOOLBOX="$HOME/.config/dev-toolbox"
WITH_GO=0
WITH_RUST=0
FORCE=0

for arg in "$@"; do
	case "$arg" in
	--with-go) WITH_GO=1 ;;
	--with-rust) WITH_RUST=1 ;;
	--force) FORCE=1 ;;
	-h | --help)
		sed -n '2,7p' "$0"
		exit 0
		;;
	*)
		echo "未知参数: $arg" >&2
		exit 2
		;;
	esac
done

# 版本固定，避免不同机器上格式结果漂移
RUFF=0.17.5
BANDIT=1.9.4
YAMLLINT=1.38.0
PRECOMMIT=4.7.0
CLANG_FORMAT=18.1.8
CLANG_TIDY=18.1.8
SHELLCHECK_PY=0.11.0.1
SHFMT_PY=4.2.0

ESLINT=10.15.0
PRETTIER=3.10.1
TYPESCRIPT=7.0.2
TSESLINT=8.73.0
ESLINT_JS=10.0.1
GLOBALS=17.14.0
STYLELINT=17.16.0
STYLELINT_STANDARD=40.0.0
MARKDOWNLINT=0.24.1
PYRIGHT=1.1.414

HADOLINT=2.15.1
GITLEAKS=8.30.1
GOLANGCI=2.15.0

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die() {
	printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2
	exit 1
}

command -v python3 >/dev/null || die "缺少 python3"
command -v curl >/dev/null || die "缺少 curl"

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------- Python
install_python_tools() {
	local pkgs=(
		"ruff==$RUFF"
		"bandit==$BANDIT"
		"yamllint==$YAMLLINT"
		"pre-commit==$PRECOMMIT"
		"clang-format==$CLANG_FORMAT"
		"clang-tidy==$CLANG_TIDY"
		"shellcheck-py==$SHELLCHECK_PY"
		"shfmt-py==$SHFMT_PY"
	)

	info "安装 Python 工具"
	if python3 -m pip install --user --upgrade "${pkgs[@]}" 2>/tmp/lint-setup-pip.log; then
		return 0
	fi

	warn "pip --user 失败（常见原因：PEP 668），尝试 uv / pipx"

	# uv 可以在没有 sudo、没有 venv 的情况下安装 Python CLI 工具
	if ! command -v uv >/dev/null 2>&1; then
		curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 || true
		export PATH="$HOME/.local/bin:$PATH"
	fi
	if command -v uv >/dev/null 2>&1; then
		local pkg
		for pkg in "${pkgs[@]}"; do
			uv tool install --force "$pkg" >/dev/null 2>&1 || warn "uv 安装失败: $pkg"
		done
		return 0
	fi

	if command -v pipx >/dev/null 2>&1; then
		local pkg name
		for pkg in "${pkgs[@]}"; do
			name=${pkg%%==*}
			pipx install --force "$pkg" >/dev/null 2>&1 || pipx upgrade "$name" >/dev/null 2>&1 || true
		done
		return 0
	fi

	cat >&2 <<'EOF'
[x] 无法安装 Python 工具。
    Ubuntu 24.04 的系统 Python 受 PEP 668 保护，可选：
      1. 安装 Miniconda，在 base 环境重新运行本脚本
      2. sudo apt install pipx && pipx ensurepath，然后重新运行
      3. python3 -m venv ~/.venvs/lint && ~/.venvs/lint/bin/pip install ...
EOF
	return 1
}

install_python_tools

# ---------------------------------------------------------------- Node
ensure_node() {
	if command -v node >/dev/null 2>&1; then
		local major
		major=$(node -p 'process.versions.node.split(".")[0]')
		if [ "$major" -ge 20 ]; then
			return 0
		fi
	fi

	info "Node.js < 20 或未安装，使用 nvm 安装 Node 22"
	export NVM_DIR="$HOME/.nvm"
	if [ ! -s "$NVM_DIR/nvm.sh" ]; then
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
	fi
	# shellcheck source=/dev/null
	. "$NVM_DIR/nvm.sh"
	nvm install 22
	nvm use 22
}

if command -v npm >/dev/null 2>&1; then
	ensure_node
	info "安装 Node 全局工具"
	npm install -g --silent \
		"eslint@$ESLINT" \
		"@eslint/js@$ESLINT_JS" \
		"typescript-eslint@$TSESLINT" \
		"globals@$GLOBALS" \
		"prettier@$PRETTIER" \
		"typescript@$TYPESCRIPT" \
		"stylelint@$STYLELINT" \
		"stylelint-config-standard@$STYLELINT_STANDARD" \
		"markdownlint-cli2@$MARKDOWNLINT" \
		"pyright@$PYRIGHT"
else
	warn "未找到 npm，跳过前端工具；安装 Node 22 后重跑本脚本"
fi

# ESLint 配置在项目找不到本地依赖时会回退到 $TOOLBOX/node_modules
if command -v npm >/dev/null 2>&1; then
	NPM_GLOBAL_ROOT=$(npm root -g 2>/dev/null || true)
	if [ -n "$NPM_GLOBAL_ROOT" ] && [ -d "$NPM_GLOBAL_ROOT" ]; then
		mkdir -p "$TOOLBOX"
		ln -sfn "$NPM_GLOBAL_ROOT" "$TOOLBOX/node_modules"
	fi
fi

# ---------------------------------------------------------------- 二进制
install_bin() {
	local url=$1 dest=$2
	info "下载 $(basename "$dest")"
	curl -fsSL --retry 5 --retry-all-errors -o /tmp/lint-setup-bin "$url"
	install -m755 /tmp/lint-setup-bin "$dest"
}

install_bin \
	"https://github.com/hadolint/hadolint/releases/download/v${HADOLINT}/hadolint-Linux-x86_64" \
	"$HOME/.local/bin/hadolint"

info "下载 gitleaks"
curl -fsSL --retry 5 --retry-all-errors \
	-o /tmp/lint-gitleaks.tar.gz \
	"https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS}/gitleaks_${GITLEAKS}_linux_x64.tar.gz"
tar xzf /tmp/lint-gitleaks.tar.gz -C /tmp gitleaks
install -m755 /tmp/gitleaks "$HOME/.local/bin/gitleaks"

info "下载 golangci-lint"
curl -fsSL --retry 5 --retry-all-errors \
	-o /tmp/lint-golangci.tar.gz \
	"https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI}/golangci-lint-${GOLANGCI}-linux-amd64.tar.gz"
tar xzf /tmp/lint-golangci.tar.gz -C /tmp
install -m755 "/tmp/golangci-lint-${GOLANGCI}-linux-amd64/golangci-lint" "$HOME/.local/bin/golangci-lint"

# ---------------------------------------------------------------- Go / Rust
if [ "$WITH_GO" -eq 1 ]; then
	info "安装 Go"
	GOVER=$(curl -fsSL "https://go.dev/dl/?mode=json" |
		python3 -c 'import sys,json; print([r["version"] for r in json.load(sys.stdin) if r["stable"]][0])')
	curl -fsSL --retry 5 --retry-all-errors \
		-o /tmp/lint-go.tar.gz "https://go.dev/dl/${GOVER}.linux-amd64.tar.gz"
	rm -rf "$HOME/.local/go"
	tar -C "$HOME/.local" -xzf /tmp/lint-go.tar.gz
	ln -sf "$HOME/.local/go/bin/go" "$HOME/.local/bin/go"
	ln -sf "$HOME/.local/go/bin/gofmt" "$HOME/.local/bin/gofmt"
fi

if [ "$WITH_RUST" -eq 1 ]; then
	info "安装 Rust（minimal + clippy + rustfmt）"
	if ! command -v rustup >/dev/null 2>&1; then
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
			sh -s -- -y --profile minimal --default-toolchain stable \
				--component clippy --component rustfmt --no-modify-path
	fi
	for bin in rustc cargo rustfmt clippy-driver; do
		[ -x "$HOME/.cargo/bin/$bin" ] && ln -sf "$HOME/.cargo/bin/$bin" "$HOME/.local/bin/$bin"
	done
fi

# ---------------------------------------------------------------- 配置
copy_configs() {
	info "复制配置到 $TOOLBOX"
	mkdir -p "$TOOLBOX"
	(
		cd "$REPO_DIR/configs"
		for f in * .[!.]*; do
			[ -e "$f" ] || continue
			if [ -e "$TOOLBOX/$f" ] && [ "$FORCE" -ne 1 ]; then
				warn "已存在，跳过: $f"
			else
				cp -f "$f" "$TOOLBOX/$f"
			fi
		done
	)

	mkdir -p "$HOME/.config/zsh"
	cp -f "$REPO_DIR/zsh/lint.zsh" "$HOME/.config/zsh/lint.zsh"

	mkdir -p "$HOME/.vscode-server/data/Machine"
	if [ -f "$HOME/.vscode-server/data/Machine/settings.json" ] && [ "$FORCE" -ne 1 ]; then
		warn "VS Code settings.json 已存在，跳过（--force 可覆盖）"
	else
		cp -f "$REPO_DIR/editor/vscode-settings.json" "$HOME/.vscode-server/data/Machine/settings.json"
	fi
}

copy_configs

# ---------------------------------------------------------------- zsh
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"
if ! grep -q '>>> dev-toolbox >>>' "$ZSHRC"; then
	info "写入 ~/.zshrc"
	cat >>"$ZSHRC" <<'EOF'

# >>> dev-toolbox >>>
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/go/bin:$HOME/go/bin:$PATH"
[[ -f ~/.config/zsh/lint.zsh ]] && source ~/.config/zsh/lint.zsh
# <<< dev-toolbox <<<
EOF
else
	info "$HOME/.zshrc 已包含 dev-toolbox 配置块，跳过"
fi

# ---------------------------------------------------------------- 检查
info "检查安装结果"
missing=0
for cmd in ruff bandit yamllint pre-commit clang-format clang-tidy shellcheck shfmt hadolint gitleaks; do
	if command -v "$cmd" >/dev/null 2>&1; then
		printf '  ✓ %-16s %s\n' "$cmd" "$("$cmd" --version 2>&1 | head -1)"
	else
		printf '  ✗ %-16s 未安装\n' "$cmd"
		missing=1
	fi
done

for cmd in eslint prettier pyright; do
	if command -v "$cmd" >/dev/null 2>&1; then
		printf '  ✓ %-16s %s\n' "$cmd" "$("$cmd" --version 2>&1 | head -1)"
	else
		warn "$cmd 未安装（Node 工具）"
	fi
done

if ! command -v clangd >/dev/null 2>&1; then
	warn "clangd 未安装：VS Code 的 clangd 扩展首次使用会提示下载，或 sudo apt install clangd"
fi

if command -v pre-commit >/dev/null 2>&1; then
	pre-commit validate-config "$TOOLBOX/.pre-commit-config.yaml"
fi

echo
if [ "$missing" -ne 0 ]; then
	warn "有工具未安装，请检查上面的输出"
	exit 1
fi
info "完成。执行 'exec zsh' 后即可使用 lint py / lint sh / lint all"
