#!/usr/bin/env bash
# 在 WSL Remote 侧安装 editor/extensions.txt 中的 VS Code 扩展。
# 先让 VS Code 通过 Remote-WSL 连接一次本机，生成 ~/.vscode-server 后再运行。
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LIST="$REPO_DIR/editor/extensions.txt"

[ -f "$LIST" ] || {
	echo "缺少扩展清单: $LIST" >&2
	exit 1
}

cli=""
for candidate in "$HOME"/.vscode-server/bin/*/bin/remote-cli/code; do
	[[ -x "$candidate" ]] && cli="$candidate"
done

if [[ -z "$cli" ]]; then
	cat >&2 <<'EOF'
[x] 未找到 WSL 侧 VS Code Server CLI。
    请先在 Windows 上用 Remote-WSL 打开本机，等待 VS Code 安装好 server，
    然后在 WSL 终端重新运行本脚本。

    扩展清单：editor/extensions.txt
    也可以在 VS Code 扩展面板中逐个安装，并选择 "Install in WSL: Ubuntu-24.04"。
EOF
	exit 1
fi

echo "使用 $cli"
while IFS= read -r ext; do
	[[ -z "$ext" || "$ext" == \#* ]] && continue
	echo "→ $ext"
	"$cli" --install-extension "$ext" --force
done <"$LIST"
echo "✓ 扩展安装完成"
