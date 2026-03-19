<#
.SYNOPSIS
    家看护 - 安装配置脚本
.DESCRIPTION
    自动检测环境、创建配置文件、注册定时任务
.NOTES
    需要 OpenClaw CLI 已安装
#>

param(
    [string]$ConfigPath = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# 颜色函数
function Write-Step { param($msg) Write-Host ">>> $msg" -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host "    ✓ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "    ⚠ $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "    ✗ $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "🏠 家看护 - 安装配置向导" -ForegroundColor Magenta
Write-Host "=" * 40
Write-Host ""

# 脚本目录
$ScriptDir = Split-Path -Parent $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$SkillDir = Split-Path -Parent $ScriptDir
$DefaultConfig = Join-Path $SkillDir "config\default.json"
$UserConfig = Join-Path $SkillDir "config\config.json"

# ========== 步骤 1: 检查 OpenClaw ==========
Write-Step "检查 OpenClaw 环境"
try {
    $openclawVersion = openclaw --version 2>&1
    Write-OK "OpenClaw 已安装: $openclawVersion"
} catch {
    Write-Err "未找到 OpenClaw，请先安装: npm install -g openclaw"
    exit 1
}

# ========== 步骤 2: 加载/创建配置 ==========
Write-Step "加载配置文件"

if (Test-Path $UserConfig) {
    Write-OK "使用现有配置: $UserConfig"
    $config = Get-Content $UserConfig -Raw | ConvertFrom-Json
} elseif (Test-Path $DefaultConfig) {
    Write-OK "使用默认配置模板"
    $config = Get-Content $DefaultConfig -Raw | ConvertFrom-Json
} else {
    Write-Err "未找到配置文件: $DefaultConfig"
    exit 1
}

# ========== 步骤 3: 检测 MuMu 模拟器 ==========
Write-Step "检测 MuMu 模拟器"

$commonPaths = @(
    "D:\Program\MuMu\MuMuPlayer",
    "D:\Program Files\MuMu\MuMuPlayer",
    "C:\Program Files\MuMu\MuMuPlayer",
    "D:\MuMu\MuMuPlayer",
    "E:\Program\MuMu\MuMuPlayer",
    "E:\MuMu\MuMuPlayer"
)

$foundPath = $null
foreach ($path in $commonPaths) {
    if (Test-Path $path) {
        $foundPath = $path
        break
    }
}

if ($foundPath) {
    Write-OK "检测到 MuMu 模拟器: $foundPath"
    $config.emulator.install_path = $foundPath
} else {
    Write-Warn "未自动检测到 MuMu 模拟器"
    $customPath = Read-Host "请输入 MuMu 模拟器安装路径 (回车跳过)"
    if ($customPath -and (Test-Path $customPath)) {
        $config.emulator.install_path = $customPath
        Write-OK "已设置路径: $customPath"
    } else {
        Write-Warn "稍后请手动编辑 config.json 设置 install_path"
    }
}

# ========== 步骤 4: 检查模拟器运行状态 ==========
Write-Step "检查模拟器运行状态"

$muMuProcess = Get-Process MuMuVMMHeadless -ErrorAction SilentlyContinue
if ($muMuProcess) {
    Write-OK "模拟器正在运行"
} else {
    Write-Warn "模拟器未运行"
    $startNow = Read-Host "是否现在启动模拟器? (y/N)"
    if ($startNow -eq 'y' -or $startNow -eq 'Y') {
        $manager = Join-Path $config.emulator.install_path "nx_main\MuMuManager.exe"
        if (Test-Path $manager) {
            Write-Step "启动模拟器中，约需 20 秒..."
            & $manager control --vmindex $config.emulator.vm_index launch
            Start-Sleep -Seconds 20
            $muMuProcess = Get-Process MuMuVMMHeadless -ErrorAction SilentlyContinue
            if ($muMuProcess) {
                Write-OK "模拟器启动成功"
            } else {
                Write-Warn "模拟器启动中，请稍等..."
            }
        } else {
            Write-Warn "未找到 MuMuManager.exe: $manager"
        }
    }
}

# ========== 步骤 5: 检测 ADB 端口 ==========
Write-Step "检测 ADB 端口"

function Get-MuMuADBPort {
    $headless = Get-Process MuMuVMMHeadless -ErrorAction SilentlyContinue
    if (-not $headless) { return $null }
    
    $headlessPid = $headless.Id
    $netstat = netstat -ano 2>$null | findstr "LISTENING" | findstr $headlessPid
    foreach ($line in $netstat) {
        if ($line -match "16[0-9]{3}") {
            return $Matches[0]
        }
    }
    return $null
}

$adbPort = Get-MuMuADBPort
if ($adbPort) {
    Write-OK "检测到 ADB 端口: $adbPort"
    $config | Add-Member -NotePropertyName "detected_port" -NotePropertyValue $adbPort -Force
} else {
    Write-Warn "无法检测 ADB 端口（模拟器可能未运行）"
    Write-OK "安装脚本将在运行时自动检测端口"
}

# ========== 步骤 6: 检查米家 APP ==========
Write-Step "检查米家 APP"

if ($adbPort) {
    $adb = Join-Path $config.emulator.install_path "nx_device\12.0\shell\adb.exe"
    if (-not (Test-Path $adb)) {
        $adb = "adb"  # 尝试使用系统 ADB
    }
    
    try {
        $packages = & $adb -s "127.0.0.1:$adbPort" shell pm list packages 2>$null | findstr $config.mijia.package
        if ($packages) {
            Write-OK "米家 APP 已安装"
        } else {
            Write-Warn "未检测到米家 APP，请确保已安装"
        }
    } catch {
        Write-Warn "无法检查 APP 状态，请确保模拟器连接正常"
    }
} else {
    Write-Warn "跳过 APP 检查（模拟器未运行）"
}

# ========== 步骤 7: 创建输出目录 ==========
Write-Step "创建输出目录"

$outputDir = $config.capture.output_dir
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-OK "创建目录: $outputDir"
} else {
    Write-OK "目录已存在: $outputDir"
}

$screenshotsDir = Join-Path $outputDir "screenshots"
if (-not (Test-Path $screenshotsDir)) {
    New-Item -ItemType Directory -Path $screenshotsDir -Force | Out-Null
}

# ========== 步骤 8: 保存配置 ==========
Write-Step "保存配置文件"

$config | ConvertTo-Json -Depth 10 | Set-Content $UserConfig -Encoding UTF8
Write-OK "配置已保存: $UserConfig"

# ========== 步骤 9: 注册 Cron Job ==========
Write-Step "注册定时任务"

$cronScript = Join-Path $ScriptDir "check.ps1"
$cronCommand = "pwsh `"$cronScript`""

# 检查是否已存在
$existingCron = openclaw cron list 2>$null | findstr "home-watch"
if ($existingCron) {
    Write-OK "定时任务已存在，启用中..."
    openclaw cron update home-watch --enabled true 2>$null
} else {
    Write-Host "    创建每5分钟执行的定时任务..." -ForegroundColor Gray
    # 注意：实际创建需要通过 OpenClaw CLI 或 API
    Write-Warn "请通过 OpenClaw 对话创建定时任务，或手动运行:"
    Write-Host "    openclaw cron add --name home-watch --every 300000 --command `"$cronCommand`"" -ForegroundColor Yellow
}

# ========== 完成 ==========
Write-Host ""
Write-Host "=" * 40
Write-Host "✅ 安装配置完成！" -ForegroundColor Green
Write-Host ""
Write-Host "下一步：" -ForegroundColor Cyan
Write-Host "  1. 确保模拟器分辨率为 1600x900（横屏）" -ForegroundColor White
Write-Host "  2. 确保米家 APP 已登录并添加了摄像头" -ForegroundColor White
Write-Host "  3. 对 OpenClaw 说「启动家看护」开始监控" -ForegroundColor White
Write-Host ""
Write-Host "配置文件: $UserConfig" -ForegroundColor Gray
Write-Host "如需修改，请编辑后重新运行安装脚本" -ForegroundColor Gray
Write-Host ""
