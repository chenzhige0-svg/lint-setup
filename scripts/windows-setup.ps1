#Requires -Version 5.1
<#
.SYNOPSIS
    配置 Windows 侧的 lint 开发环境：Git、VS Code、Windows Terminal、WSL2。
.DESCRIPTION
    只安装基础软件并设置 Git 行尾；lint 工具本体安装在 WSL Ubuntu 中。
    需要 Windows 10 2004+ / Windows 11，并已启用 App Installer（winget）。
#>
$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "未找到 winget。请先从 Microsoft Store 安装 App Installer，或手动安装 Git / VS Code。"
    exit 1
}

$packages = @(
    @{ Id = "Git.Git"; Name = "Git for Windows" },
    @{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code" },
    @{ Id = "Microsoft.WindowsTerminal"; Name = "Windows Terminal" }
)

foreach ($pkg in $packages) {
    Write-Step "安装 $($pkg.Name)"
    winget install --id $pkg.Id --exact --source winget `
        --accept-package-agreements --accept-source-agreements
}

Write-Step "配置 Git 行尾"
git config --global core.autocrlf false
git config --global core.eol lf
git config --global init.defaultBranch main

Write-Step "检查 WSL"
$wsl = Get-Command wsl -ErrorAction SilentlyContinue
if (-not $wsl) {
    Write-Warn "WSL 未安装。请在管理员 PowerShell 执行：wsl --install -d Ubuntu-24.04，然后重启。"
} else {
    wsl --status
    Write-Host ""
    Write-Host "如果还没有 Ubuntu，请执行：wsl --install -d Ubuntu-24.04" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "下一步：" -ForegroundColor Green
Write-Host "  1. 在 WSL 中克隆本仓库并运行 bash scripts/install-wsl.sh"
Write-Host "  2. 用 VS Code 的 Remote-WSL 连接 Ubuntu"
Write-Host "  3. 在 WSL 中运行 bash scripts/install-vscode-extensions.sh"
