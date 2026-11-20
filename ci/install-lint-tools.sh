#!/usr/bin/env bash
# GitHub Actions 用：安装 pre-commit system hook 需要的工具。
# 放到仓库 .github/scripts/install-lint-tools.sh 并 chmod +x。
# 不需要的语言可删掉对应步骤；未匹配文件的 hook 不会执行。
set -euo pipefail

sudo apt-get update
sudo apt-get install -y --no-install-recommends cppcheck

python3 -m pip install --user \
	pre-commit==4.7.0 \
	ruff==0.17.5 \
	bandit==1.9.4 \
	yamllint==1.38.0 \
	clang-format==18.1.8 \
	clang-tidy==18.1.8 \
	shellcheck-py==0.11.0.1 \
	shfmt-py==4.2.0
if [[ -n "${GITHUB_PATH:-}" ]]; then
	echo "$HOME/.local/bin" >>"$GITHUB_PATH"
fi

npm install -g --silent \
	eslint@10.15.0 \
	@eslint/js@10.0.1 \
	typescript-eslint@8.73.0 \
	globals@17.14.0 \
	prettier@3.10.1 \
	typescript@7.0.2 \
	stylelint@17.16.0 \
	stylelint-config-standard@40.0.0 \
	markdownlint-cli2@0.24.1 \
	pyright@1.1.414

# 让复制到项目的 eslint.config.mjs 能回退到全局 npm 依赖
mkdir -p "$HOME/.config/dev-toolbox"
ln -sfn "$(npm root -g)" "$HOME/.config/dev-toolbox/node_modules"

mkdir -p "$HOME/.local/bin"

# hadolint
curl -fsSL --retry 5 --retry-all-errors -o /tmp/hadolint \
	https://github.com/hadolint/hadolint/releases/download/v2.15.1/hadolint-Linux-x86_64
install -m755 /tmp/hadolint "$HOME/.local/bin/hadolint"

# gitleaks
curl -fsSL --retry 5 --retry-all-errors -o /tmp/gitleaks.tar.gz \
	https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
tar xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks
install -m755 /tmp/gitleaks "$HOME/.local/bin/gitleaks"

# golangci-lint（有 Go 项目时保留）
if [[ "${INSTALL_GO_TOOLS:-1}" == "1" ]]; then
	curl -fsSL --retry 5 --retry-all-errors -o /tmp/golangci-lint.tar.gz \
		https://github.com/golangci/golangci-lint/releases/download/v2.15.0/golangci-lint-2.15.0-linux-amd64.tar.gz
	tar xzf /tmp/golangci-lint.tar.gz -C /tmp
	install -m755 /tmp/golangci-lint-2.15.0-linux-amd64/golangci-lint "$HOME/.local/bin/golangci-lint"
fi
