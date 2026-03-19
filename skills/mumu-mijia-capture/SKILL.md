---
name: home-watch
description: 家看护 - 米家摄像头定时截图监控。说"启动家看护"开始每5分钟截图+AI描述画面并记录日志，说"关闭家看护"停止。截图保存在本地，画面内容自动记录。
user-invocable: true
---

# 家看护 🏠📷

米家摄像头定时截图 + AI 画面描述 + 日志记录。

## 使用方式

- **启动**：说"启动家看护" → 每 5 分钟自动截图、AI 描述、记录日志，并把最新记录发给你
- **关闭**：说"关闭家看护" → 停止定时截图
- **查看记录**：说"看看日志" → 显示最新的画面记录

## 技术细节

- Cron Job ID: `2e29e539-4091-4760-801b-55b339ce206c`
- Cron 名称: `mumu-screenshot`
- 频率: 每 5 分钟（300000ms）
- sessionTarget: main（systemEvent 注入主 session）

## 启动命令

```
openclaw cron update 2e29e539-4091-4760-801b-55b339ce206c --enabled true
```

或通过 cron 工具:
```json
{"action": "update", "jobId": "2e29e539-4091-4760-801b-55b339ce206c", "patch": {"enabled": true}}
```

## 关闭命令

```
openclaw cron update 2e29e539-4091-4760-801b-55b339ce206c --enabled false
```

或通过 cron 工具:
```json
{"action": "update", "jobId": "2e29e539-4091-4760-801b-55b339ce206c", "patch": {"enabled": false}}
```

## 环境

- **MuMu 模拟器路径**: `D:\Program\MuMu\MuMuPlayer`
- **adb**: `D:\Program\MuMu\MuMuPlayer\nx_device\12.0\shell\adb.exe`
- **连接端口**: 每次启动可能变化，通过 `netstat -ano | findstr "LISTENING" | findstr "MuMuVMMHeadless"` 或 `MuMuManager.exe info --vmindex 0` 获取
- **屏幕分辨率**: 900x1600（竖屏）/ 实际显示为横屏模式
- **监控设备**: 小白智能摄像机 (2.5K)

## 打开摄像头流程

**前提**：MuMu 模拟器已启动、米家 APP 已打开

| 步骤 | 操作 | 坐标 | 说明 |
|------|------|------|------|
| 1 | 点击进入设备列表 | (210, 250) | 进入摄像头设备列表 |
| 2 | 点击打开摄像头 | (222, 425) | 打开摄像头实时画面，等待10秒加载 |

> ⚠️ **重要**：坐标使用截图坐标系 (1600x900)。如果点击后没进入摄像头画面，**重复步骤1和2**再试一次。如果反复失败，关闭模拟器重启后再试。

### 完整脚本

```powershell
$adb = "D:\Program\MuMu\MuMuPlayer\nx_device\12.0\shell\adb.exe"
$device = "127.0.0.1:<端口号>"  # 动态获取

# 打开米家APP
& $adb -s $device shell am start -n com.xiaomi.smarthome/.SmartHomeMainActivity
Start-Sleep -Seconds 3

# 步骤1: 进入设备列表
& $adb -s $device shell input tap 210 250
Start-Sleep -Seconds 5

# 步骤2: 打开摄像头画面（等待加载完成）
& $adb -s $device shell input tap 222 425
Start-Sleep -Seconds 10
```

> ⚠️ 坐标基于截图分辨率 1600x900。如果没成功，循环重复步骤1和2再试
```

### 注意事项
- 如果模拟器未启动，需先执行：`& "D:\Program\MuMu\MuMuPlayer\nx_main\MuMuManager.exe" control --vmindex 0 launch`，等待约15秒
- 米家APP需在前台，如不在需先用 `am start` 打开
- 摄像头加载需要5-8秒，等待时间要够长
- ADB 端口每次重启可能变化，需先获取再操作

## 视频画面坐标

| 参数 | 值 |
|------|-----|
| cropX | 425 |
| cropY | 175 |
| cropW | 750 |
| cropH | 425 |

## 截图流程

1. adb 连接 127.0.0.1:7555
2. `shell screencap -p /sdcard/screen.png` → `pull` 到本地
3. PowerShell 裁剪视频区域 (425,175 750x425)
4. AI 读取截图，中文描述画面
5. 追加到 `video-only/log.txt`，格式 `[YYYY-MM-DD HH:MM] 描述`，空行分隔
6. 把最新记录发给用户

## 保存位置

| 内容 | 路径 |
|------|------|
| 截图文件 | `C:\Users\Administrator\.openclaw\media\mumu-monitor\video-only\video_YYYYMMDD_HHmmss.png` |
| 画面日志 | `C:\Users\Administrator\.openclaw\media\mumu-monitor\video-only\log.txt` |
| 截图脚本 | `C:\Users\Administrator\.openclaw\media\mumu-monitor\capture-video.ps1` |

## 语音播报规则 🎯

每次截图后根据画面内容决定是否语音播报：

- **画面中没人** → 跳过语音播报，不生成语音，不做对讲，但仍要**用AI描述画面内容并记录日志**（例如：空房间、白墙、门、桌椅等场景信息）
- 每次播报开头必须带上当前具体时间，例如"早上七点十五"、"下午三点四十"、"晚上九点零五"
- **画面中有小朋友（儿童/小孩）** → 根据行为判断：
  - 在玩手机/看电视/玩耍等娱乐活动 → 提醒作业，例如："现在是早上七点十五，小朋友，在玩呀？作业写完了吗？先把作业写完再玩哦～"
  - 在写作业/学习/看书 → **不要播报**，不打扰学习，静默记录即可
- **画面中有老人家** → 嘘寒问暖 + 结合场景的养生/安全常识，称呼用"叔叔阿姨"**不要用"爷爷奶奶"**，例如："叔叔阿姨天凉了多穿件衣服哦，别着凉了" 或 "记得按时吃药，注意休息"
- **画面中有成年人（非儿童/老人）** → 根据场景自然问候，例如："中午好呀，休息一下喝杯水吧"、"在忙什么呢？注意休息哦"、"吃饭了没有？别饿着自己"。语气轻松自然，不要过于正式
- 播报内容要结合画面具体信息（时间、天气、在做什么），不要机械重复
- TTS 情感风格选温柔/关心，语速适中

## 语音对讲功能 🎤

通过模拟器对摄像头进行语音喊话。

### 使用流程

1. **生成语音**：用 CosyVoice TTS 生成 WAV 文件
2. **推送音频**：`adb push tts_output.wav /sdcard/tts_output.wav`
3. **点击开始对讲**：`adb shell input tap 496 697`（麦克风按钮）
4. **播放语音**：在 PC 端用 SoundPlayer 播放，系统音频路由到模拟器
5. **等待语音时长**：获取 WAV 时长，等待播放完毕
6. **点击关闭对讲**：`adb shell input tap 496 697`（再次点击麦克风按钮）

### 完整脚本示例

```powershell
$adb = "D:\Program\MuMu\MuMuPlayer\nx_device\12.0\shell\adb.exe"
$device = "127.0.0.1:16385"  # 注意：端口可能变化
$audioPath = "D:\openclaw\workspacce\tts_output.wav"

# 获取语音时长
$duration = [math]::Ceiling((python -c "import wave; f=wave.open('$audioPath','r'); print(f.getnframes()/f.getframerate())"))

# 推送音频
& $adb -s $device push $audioPath /sdcard/tts_output.wav

# 开始对讲
& $adb -s $device shell input tap 496 697

# 播放语音（PC 系统音频）
Start-Sleep -Milliseconds 300
$player = New-Object System.Media.SoundPlayer $audioPath
$player.Play()

# 等待播放完毕
Start-Sleep -Seconds ($duration + 1)

# 关闭对讲
& $adb -s $device shell input tap 496 697
```

### 端口查找方法

每次重启模拟器端口可能变化，查找当前端口：
```powershell
netstat -ano | findstr "LISTENING" | findstr "12[0-9][0-9][0-9]"
```
或使用 MuMuManager：
```powershell
& "D:\Program\MuMu\MuMuPlayer\nx_main\MuMuManager.exe" info --vmindex 0
```
返回的 `adb_port` 字段即为当前端口。

### 注意事项

- 麦克风按钮坐标 (496, 697) 基于特定视图，实际位置可能因界面布局变化
- 语音播放依赖 PC 系统音频能被模拟器捕获
- CosyVoice TTS 调用：`python D:\openclaw\workspacce\skills\cosyvoice-tts\scripts\cosyvoice_tts.py "说话内容" --output out.wav`
- 支持情感风格：开心、温柔、平静、兴奋等

## 启动家看护前的检查与准备

如果家看护启动时检测到模拟器未运行或摄像头未打开，先执行以下流程：

```powershell
$adb = "D:\Program\MuMu\MuMuPlayer\nx_device\12.0\shell\adb.exe"
$manager = "D:\Program\MuMu\MuMuPlayer\nx_main\MuMuManager.exe"

# 1. 检查模拟器是否运行
$muMuProcess = Get-Process MuMuVMMHeadless -ErrorAction SilentlyContinue
if (-not $muMuProcess) {
    echo "模拟器未启动，正在启动..."
    & $manager control --vmindex 0 launch
    Start-Sleep -Seconds 20  # 等待模拟器完全启动
}

# 2. 获取当前 ADB 端口
$portInfo = & $manager info --vmindex 0 2>&1
# 解析 JSON 获取 adb_port，或用 netstat 查找
$port = (netstat -ano | findstr "LISTENING" | findstr "MuMuVMMHeadless" | Select-String "16[0-9][0-9][0-9]" -AllMatches).ToString().Split(' ')[-1].Trim()
# 更可靠的方法：直接找 MuMuVMMHeadless 进程的端口
$headlessPid = (Get-Process MuMuVMMHeadless).Id
$port = (netstat -ano | findstr "LISTENING" | findstr $headlessPid | Select-String "16[0-9][0-9][0-9]" -AllMatches).Matches[0].Value
$device = "127.0.0.1:$port"

# 3. 确保米家APP在前台
& $adb -s $device shell am start -n com.xiaomi.smarthome/.SmartHomeMainActivity
Start-Sleep -Seconds 3

# 4. 打开摄像头（没成功就重试）
for ($try = 0; $try -lt 2; $try++) {
    & $adb -s $device shell input tap 210 250
    Start-Sleep -Seconds 3
    & $adb -s $device shell input tap 222 425
    Start-Sleep -Seconds 10
}

# 5. 截图确认
& $adb -s $device shell screencap /sdcard/screen.png
& $adb -s $device pull /sdcard/screen.png "C:\Users\Administrator\.openclaw\media\mumu-monitor\video-only\video_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
```

### 快捷检查函数

```powershell
function Get-MuMuDevice {
    $headlessPid = (Get-Process MuMuVMMHeadless -ErrorAction SilentlyContinue).Id
    if (-not $headlessPid) { return $null }
    $port = (netstat -ano | findstr "LISTENING" | findstr $headlessPid | Select-String "16[0-9][0-9][0-9]" -AllMatches).Matches[0].Value
    return "127.0.0.1:$port"
}
```

## 注意事项

- 需要 MuMu 模拟器运行中且米家 App 在前台显示摄像头画面
- 坐标基于 900x1600（竖屏）/ 横屏显示，分辨率变化需重校准
- 摄像头加载需 5-8 秒，等待时间要够长
- 自动清理 30 分钟前旧截图，日志保留
- cron 用 main session 执行，避免 isolated session 中文编码问题
- 语音对讲的 ADB 端口每次模拟器重启可能变化，需动态获取
- 家看护启动前应先检查模拟器状态，未启动则自动执行启动+打开摄像头流程
