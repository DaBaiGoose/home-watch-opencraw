<#
.SYNOPSIS
    家看护 - 监控巡检脚本
.DESCRIPTION
    定时执行的巡检脚本：截图 → AI识别 → 语音播报 → 记录日志
    由 OpenClaw Cron Job 触发执行
#>

param(
    [string]$ConfigPath = ""
)

$ErrorActionPreference = "Stop"

# ========== 配置加载 ==========
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillDir = Split-Path -Parent $ScriptDir
$DefaultConfig = Join-Path $SkillDir "config\default.json"
$UserConfig = Join-Path $SkillDir "config\config.json"

# 优先使用用户配置，否则使用默认配置
if (Test-Path $UserConfig) {
    $config = Get-Content $UserConfig -Raw | ConvertFrom-Json
} elseif (Test-Path $DefaultConfig) {
    $config = Get-Content $DefaultConfig -Raw | ConvertFrom-Json
} else {
    Write-Error "未找到配置文件"
    exit 1
}

# ========== 随机间隔检查 ==========
$lastCheckFile = Join-Path $config.capture.output_dir "last_check.txt"
$shouldRun = $true

if (Test-Path $lastCheckFile) {
    $lastCheck = [int64](Get-Content $lastCheckFile -Raw)
    $now = [int64][DateTimeOffset]::Now.ToUnixTimeSeconds()
    $elapsed = $now - $lastCheck
    
    if ($elapsed -lt 300) {
        # 5分钟内，50%概率跳过
        $random = Get-Random -Minimum 0 -Maximum 2
        if ($random -eq 1) {
            $shouldRun = $false
        }
    }
}

if (-not $shouldRun) {
    # 记录但不执行
    $logMsg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm')] 跳过（随机间隔）"
    Write-Output $logMsg
    exit 0
}

# 记录本次检查时间
Set-Content $lastCheckFile -Value ([int64][DateTimeOffset]::Now.ToUnixTimeSeconds())

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

function Start-MuMuEmulator {
    param($installPath, $vmIndex)
    $manager = Join-Path $installPath "nx_main\MuMuManager.exe"
    if (Test-Path $manager) {
        & $manager control --vmindex $vmIndex launch
        Start-Sleep -Seconds 20
        return $true
    }
    return $false
}

function Get-ADBPath {
    param($installPath)
    $adbPath = Join-Path $installPath "nx_device\12.0\shell\adb.exe"
    if (Test-Path $adbPath) { return $adbPath }
    return "adb"  # 回退到系统 ADB
}

function Invoke-ADB {
    param($adb, $device, [string[]]$commands)
    foreach ($cmd in $commands) {
        & $adb -s $device shell $cmd
        Start-Sleep -Milliseconds 200
    }
}

function Save-Screenshot {
    param($adb, $device, $outputPath)
    # 截图并拉取
    & $adb -s $device shell screencap -p /sdcard/screen.png
    Start-Sleep -Milliseconds 500
    & $adb -s $device pull /sdcard/screen.png $outputPath 2>$null
    & $adb -s $device shell rm /sdcard/screen.png
    
    # 裁剪视频区域
    if (Test-Path $outputPath) {
        $cropX = $config.capture.crop_x
        $cropY = $config.capture.crop_y
        $cropW = $config.capture.crop_w
        $cropH = $config.capture.crop_h
        
        # 使用 ImageMagick 或 .NET 裁剪
        try {
            Add-Type -AssemblyName System.Drawing
            $img = [System.Drawing.Bitmap]::FromFile($outputPath)
            $cropped = $img.Clone(
                [System.Drawing.Rectangle]$cropX, $cropY, $cropW, $cropH,
                $img.PixelFormat
            )
            $img.Dispose()
            $cropped.Save($outputPath)
            $cropped.Dispose()
        } catch {
            # 如果裁剪失败，使用原始截图
            Write-Warning "裁剪失败，使用原始截图"
        }
        return $true
    }
    return $false
}

function Open-Camera {
    param($adb, $device)
    $maxRetries = 2
    
    for ($i = 0; $i -lt $maxRetries; $i++) {
        # 打开米家 APP
        & $adb -s $device shell am start -n "$($config.mijia.package)/$($config.mijia.main_activity)"
        Start-Sleep -Seconds 3
        
        # 点击设备列表
        $tapX = $config.camera.tap_device_list_x
        $tapY = $config.camera.tap_device_list_y
        & $adb -s $device shell input tap $tapX $tapY
        Start-Sleep -Seconds 5
        
        # 点击打开摄像头
        $tapX = $config.camera.tap_open_camera_x
        $tapY = $config.camera.tap_open_camera_y
        & $adb -s $device shell input tap $tapX $tapY
        Start-Sleep -Seconds $config.camera.wait_camera_load_sec
        
        # 验证截图
        $testPath = Join-Path $config.capture.output_dir "test_camera.png"
        $saved = Save-Screenshot $adb $device $testPath
        if ($saved -and (Get-Item $testPath).Length -gt 10KB) {
            Remove-Item $testPath -Force
            return $true
        }
    }
    return $false
}

# ========== 主流程 ==========

# 1. 检查模拟器
$muMuProcess = Get-Process MuMuVMMHeadless -ErrorAction SilentlyContinue
if (-not $muMuProcess) {
    Write-Output "模拟器未运行，正在启动..."
    $started = Start-MuMuEmulator $config.emulator.install_path $config.emulator.vm_index
    if (-not $started) {
        Write-Error "无法启动模拟器"
        exit 1
    }
}

# 2. 获取 ADB 端口
$adbPort = Get-MuMuADBPort
if (-not $adbPort) {
    Write-Error "无法检测 ADB 端口"
    exit 1
}

$adb = Get-ADBPath $config.emulator.install_path
$device = "127.0.0.1:$adbPort"

# 3. 打开摄像头
Write-Output "打开摄像头中..."
$cameraOpened = Open-Camera $adb $device
if (-not $cameraOpened) {
    Write-Warning "摄像头打开失败，尝试继续截图"
}

# 4. 截图
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$screenshotPath = Join-Path $config.capture.output_dir "screenshots\video_$timestamp.png"

Write-Output "截图: $screenshotPath"
$saved = Save-Screenshot $adb $device $screenshotPath

if (-not $saved -or -not (Test-Path $screenshotPath)) {
    Write-Error "截图失败"
    exit 1
}

# 5. 输出截图路径供 AI 读取
Write-Output "SCREENSHOT_PATH=$screenshotPath"

# 6. 等待 AI 处理
# 注意：实际的 AI 分析和语音播报由 OpenClaw 主 session 处理
# 这个脚本只负责截图和基础流程

# 7. 记录日志
$logDir = $config.capture.output_dir
$logFile = Join-Path $logDir "log.txt"
$logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm')] 截图完成: $screenshotPath (端口: $adbPort)"
Add-Content $logFile $logEntry -Encoding UTF8

Write-Output "巡检完成"
exit 0
