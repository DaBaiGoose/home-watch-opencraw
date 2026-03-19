<#
.SYNOPSIS
    家看护 - 语音播报脚本
.DESCRIPTION
    通过模拟器对摄像头进行语音对讲
    1. 推送音频到模拟器
    2. 点击开始对讲
    3. PC端播放语音
    4. 等待播放完毕后关闭对讲
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$AudioPath,
    
    [string]$ConfigPath = ""
)

$ErrorActionPreference = "Stop"

# ========== 配置加载 ==========
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillDir = Split-Path -Parent $ScriptDir
$UserConfig = Join-Path $SkillDir "config\config.json"
$DefaultConfig = Join-Path $SkillDir "config\default.json"

if (Test-Path $UserConfig) {
    $config = Get-Content $UserConfig -Raw | ConvertFrom-Json
} elseif (Test-Path $DefaultConfig) {
    $config = Get-Content $DefaultConfig -Raw | ConvertFrom-Json
} else {
    Write-Error "未找到配置文件"
    exit 1
}

# ========== 工具函数 ==========
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

function Get-ADBPath {
    param($installPath)
    $adbPath = Join-Path $installPath "nx_device\12.0\shell\adb.exe"
    if (Test-Path $adbPath) { return $adbPath }
    return "adb"
}

function Get-AudioDuration {
    param($path)
    try {
        # 尝试用 Python 获取时长
        $duration = python -c "import wave; f=wave.open('$path','r'); print(f.getnframes()/f.getframerate())"
        return [math]::Ceiling([double]$duration)
    } catch {
        # 回退：估算时长
        return 5
    }
}

# ========== 检查音频文件 ==========
if (-not (Test-Path $AudioPath)) {
    Write-Error "音频文件不存在: $AudioPath"
    exit 1
}

# ========== 获取 ADB ==========
$adbPort = Get-MuMuADBPort
if (-not $adbPort) {
    Write-Error "无法检测 ADB 端口（模拟器可能未运行）"
    exit 1
}

$adb = Get-ADBPath $config.emulator.install_path
$device = "127.0.0.1:$adbPort"

# ========== 获取音频时长 ==========
$duration = Get-AudioDuration $AudioPath
Write-Output "音频时长: ${duration}秒"

# ========== 推送音频到模拟器 ==========
Write-Output "推送音频到模拟器..."
& $adb -s $device push $AudioPath /sdcard/tts_broadcast.wav 2>$null
Start-Sleep -Seconds 1

# ========== 开始对讲 ==========
# 麦克风按钮坐标 (496, 697)
Write-Output "开始对讲..."
& $adb -s $device shell input tap 496 697
Start-Sleep -Milliseconds 500

# ========== 播放语音 ==========
Write-Output "播放语音..."
$player = New-Object System.Media.SoundPlayer $AudioPath
$player.Play()

# ========== 等待播放完毕 ==========
Write-Output "等待播放完成 (${duration}秒)..."
Start-Sleep -Seconds ($duration + 1)

# ========== 关闭对讲 ==========
Write-Output "关闭对讲..."
& $adb -s $device shell input tap 496 697

Write-Output "语音播报完成"
exit 0
