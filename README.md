# OpenClaw 技能集合

> 一套实用的 OpenClaw/MiniClaw 技能和脚本，用于智能家居监控、语音合成、屏幕操作等场景。

## 技能列表

| 技能 | 描述 | 触发方式 |
|------|------|----------|
| **home-watch** | 家看护 - 米家摄像头定时截图+AI识别+语音播报 | 说"启动家看护" |
| **cosyvoice-tts** | 中文语音合成，支持多种情感风格 | 自动触发 |
| **mumu-mijia-capture** | MuMu模拟器米家摄像头截图 | 自动触发 |
| **screen-capture-hub** | 屏幕截图+OCR文字识别 | 说"截图"/"识别屏幕文字" |
| **windows-screenshot** | 纯PowerShell截图工具 | 说"截图" |
| **windows-ui-automation** | Windows桌面自动化（鼠标/键盘控制） | 自动触发 |
| **win-mouse-native** | Windows原生鼠标控制 | 自动触发 |

## 一键安装

### 方式一：对话安装（推荐）

在 OpenClaw 中直接对话：

```
从 https://github.com/你的用户名/openclaw-home-watch.git 下载所有技能并安装
```

AI 会自动执行安装命令。

### 方式二：命令行安装

**Windows (PowerShell):**
```powershell
# 克隆仓库
git clone https://github.com/你的用户名/openclaw-home-watch.git

# 复制技能到 MiniClaw 的 workspace 目录
$skillsDir = "$env:USERPROFILE\.miniclaw\workspace"
if (-not (Test-Path $skillsDir)) { New-Item -ItemType Directory -Path $skillsDir -Force }
Copy-Item -Path "openclaw-home-watch*" -Destination $skillsDir -Recurse -Force

# 验证安装
Get-ChildItem $skillsDir
```

## 技能详情

### home-watch - 家看护

基于 MuMu 模拟器 + 米家摄像头的智能家庭监控系统。

**功能：**
- 定时截图摄像头画面
- AI 识别画面内容
- 个性化语音播报（小朋友/老人/成年人不同策略）
- 日志记录

**前置要求：**
- MuMu 模拟器（分辨率 1600x900）
- 米家 APP + 米家摄像头

**使用：**
```
启动家看护    # 开始监控
关闭家看护    # 停止监控
看看日志      # 查看记录
```

---

### cosyvoice-tts - 语音合成

中文语音合成，使用免费的 CosyVoice2-0.5B 模型接口。

**特性：**
- 多种情感风格（开心、温柔、悲伤等）
- 自动分段处理长文本
- 支持输出到文件或直接播放

**使用：**
```bash
python <skill_dir>/scripts/cosyvoice_tts.py "要说的话" --play
```

---

### screen-capture-hub - 屏幕查看器

屏幕截图 + OCR 文字识别。

**功能：**
- 全屏/区域截图
- 中英文 OCR 识别
- 查找屏幕文字

**使用：**
```bash
python scripts/screenshot.py --output screenshot.png
python scripts/ocr_screenshot.py --text-output text.txt
```

---

### windows-screenshot - Windows 截图

纯 PowerShell 截图工具，无外部依赖。

**特性：**
- GDI+ 高效截图
- 自动 DPI 适配
- PNG 输出

**使用：**
```powershell
powershell -File screenshot.ps1
```

---

### windows-ui-automation - 桌面自动化

Windows 鼠标/键盘自动化。

**功能：**
- 鼠标移动、点击、拖拽
- 键盘输入、快捷键
- 窗口管理

---

### win-mouse-native - 原生鼠标控制

通过 user32.dll 实现精确鼠标控制。

**命令：**
```bash
win-mouse move <dx> <dy>    # 相对移动
win-mouse abs <x> <y>       # 绝对坐标
win-mouse click left        # 左键点击
```

## 目录结构

```
openclaw-skills/
├── README.md
├── skills/
│   ├── home-watch/
│   │   ├── SKILL.md          # 技能元数据
│   │   └── scripts/
│   ├── cosyvoice-tts/
│   │   ├── SKILL.md
│   │   └── scripts/
│   ├── mumu-mijia-capture/
│   ├── screen-capture-hub/
│   ├── windows-screenshot/
│   ├── windows-ui-automation/
│   └── win-mouse-native/
└── scripts/
    └── install.ps1           # 安装脚本
```


## 许可证

MIT License
