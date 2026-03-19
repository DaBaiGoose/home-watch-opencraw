---
name: home-watch
description: 家看护 - 智能家庭监控助手。基于模拟器+米家摄像头+AI视觉识别，定时截图监控家中情况，智能识别画面内容并语音播报关怀。说"启动家看护"开始监控，说"关闭家看护"停止。
user-invocable: true
---

# 家看护 🏠📷

基于 OpenClaw 的智能家庭监控系统，支持米家 APP 摄像头定时截图、AI 画面识别、个性化语音播报。

## 功能特性

- 📸 **定时截图**：自动连接模拟器，定时截取米家摄像头画面
- 🤖 **AI 识别**：智能分析画面人物、场景、活动
- 🗣️ **智能播报**：根据不同人群（小朋友/老人/成年人）生成关怀语音
- 📋 **日志记录**：每次巡检自动记录画面描述
- 🎲 **随机间隔**：巡检间隔随机化，更自然

## 使用方式

| 语音指令 | 功能 |
|---------|------|
| 启动家看护 | 开始定时监控 |
| 关闭家看护 | 停止监控 |
| 看看日志 | 查看最新监控记录 |
| 现在什么情况 | 查看当前画面描述 |

## 安装

### 前置要求

1. **MuMu 模拟器**（或其他安卓模拟器）
2. **米家 APP** 已安装在模拟器中
3. **摄像头** 已添加到米家 APP

### 模拟器设置

> ⚠️ **重要**：模拟器分辨率必须设置为 **1600x900**（横屏模式）

设置方法：
1. 打开 MuMu 模拟器设置
2. 找到「显示设置」或「分辨率设置」
3. 设置为 1600x900
4. 重启模拟器生效

### 安装步骤

1. 将本技能复制到 OpenClaw skills 目录：
   ```
   cp -r home-watch ~/.openclaw/skills/
   ```

2. 运行安装脚本（首次配置）：
   ```powershell
   pwsh .\scripts\install.ps1
   ```

3. 按提示配置模拟器路径等参数

## 配置文件

配置文件位于：`config/config.json`（首次运行自动生成）

```json
{
  "emulator": {
    "type": "mumu",
    "install_path": "D:\\Program\\MuMu\\MuMuPlayer",
    "vm_index": 0
  },
  "mijia": {
    "package": "com.xiaomi.smarthome",
    "main_activity": ".SmartHomeMainActivity"
  },
  "camera": {
    "device_name": "小白智能摄像机",
    "tap_device_list": [210, 250],
    "tap_open_camera": [222, 425]
  },
  "capture": {
    "output_dir": "C:\\Users\\Administrator\\.openclaw\\media\\home-watch",
    "crop_region": [425, 175, 750, 425]
  },
  "broadcast": {
    "enabled": true,
    "interval_ms": 300000
  }
}
```

## 手动启动/停止

### 通过命令行

```powershell
# 启动（启用 cron job）
openclaw cron update home-watch --enabled true

# 停止（禁用 cron job）
openclaw cron update home-watch --enabled false
```

### 通过 OpenClaw 对话

直接对 AI 说：
- "启动家看护"
- "关闭家看护"

## 工作流程

```
1. 检查模拟器 → 未运行则自动启动（等待20秒）
2. 获取 ADB 端口 → 动态检测连接
3. 打开米家 APP → 确保在前台
4. 打开摄像头 → 点击设备进入实时画面
5. 截图 → 保存到本地
6. AI 识别 → 分析画面内容
7. 语音播报 → 根据策略生成关怀语音
8. 记录日志 → 追加到 log.txt
```

## 播报策略

### 小朋友 👧
- 玩耍/看电视 → 提醒写作业
- 写作业/学习 → 静默不打扰

### 长辈 👴
- 嘘寒问暖 + 养生贴士
- 称呼"叔叔阿姨"

### 成年人 👨
- 自然问候，轻松关怀
- 提醒休息喝水

## 日志位置

| 内容 | 路径 |
|------|------|
| 截图文件 | `C:\Users\Administrator\.openclaw\media\home-watch\screenshots\` |
| 画面日志 | `C:\Users\Administrator\.openclaw\media\home-watch\log.txt` |

## 故障排查

### 模拟器连接失败
1. 确认模拟器已启动
2. 检查 ADB 端口是否正确
3. 尝试重启模拟器

### 截图失败
1. 确认模拟器分辨率为 1600x900
2. 检查米家 APP 是否在前台
3. 手动执行 `scripts\check.ps1` 检查环境

### 摄像头打不开
1. 确认摄像头已添加到米家 APP
2. 尝试手动打开摄像头，检查是否有网络问题
3. 坐标可能因 APP 版本变化，需要重新校准

## 限制

- ⚠️ 仅支持米家 APP（其他智能家居平台暂不支持）
- ⚠️ 仅支持米家摄像头设备
- ⚠️ 模拟器分辨率必须为 1600x900
- ⚠️ 摄像头点击坐标基于当前 APP 版本，更新后可能需要调整

## 技术栈

- OpenClaw Cron 定时任务
- MuMu 模拟器 + ADB 协议
- PowerShell 自动化脚本
- AI 视觉识别（多模态模型）
- CosyVoice TTS 语音合成
