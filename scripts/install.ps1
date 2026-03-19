# OpenClaw 技能安装脚本
# 用法: pwsh -File install.ps1 [-Skill skill-name]

param(
    [string]$Skill = "all"
)

$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Log-Info { Write-ColorOutput Cyan "[INFO]" $args }
function Log-Success { Write-ColorOutput Green "[OK]" $args }
function Log-Error { Write-ColorOutput Red "[ERROR]" $args }

# 获取脚本所在目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSource = Join-Path $ScriptDir "skills"

# 目标目录
$TargetDir = "$env:USERPROFILE\.miniclaw\skills"
if ($env:OPENCLAW_SKILLS_DIR) {
    $TargetDir = $env:OPENCLAW_SKILLS_DIR
}

Log-Info "安装目录: $TargetDir"
Log-Info "技能源目录: $SkillsSource"

# 创建目标目录
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Log-Success "创建目录: $TargetDir"
}

# 获取所有技能
$AllSkills = Get-ChildItem -Path $SkillsSource -Directory | ForEach-Object { $_.Name }

if ($Skill -eq "all") {
    Log-Info "安装所有技能: $($AllSkills -join ', ')"
    $SkillsToInstall = $AllSkills
} else {
    $SkillsToInstall = @($Skill)
}

# 安装技能
$Installed = 0
$Failed = 0

foreach ($skillName in $SkillsToInstall) {
    $sourcePath = Join-Path $SkillsSource $skillName
    $targetPath = Join-Path $TargetDir $skillName
    
    if (-not (Test-Path $sourcePath)) {
        Log-Error "技能不存在: $skillName"
        $Failed++
        continue
    }
    
    # 检查 SKILL.md
    $skillFile = Join-Path $sourcePath "SKILL.md"
    if (-not (Test-Path $skillFile)) {
        Log-Error "缺少 SKILL.md: $skillName"
        $Failed++
        continue
    }
    
    try {
        # 如果目标已存在，先删除
        if (Test-Path $targetPath) {
            Remove-Item -Path $targetPath -Recurse -Force
        }
        
        # 复制技能
        Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
        Log-Success "已安装: $skillName"
        $Installed++
    } catch {
        Log-Error "安装失败: $skillName - $_"
        $Failed++
    }
}

# 输出结果
Write-Output ""
Log-Info "========== 安装完成 =========="
Log-Success "成功: $Installed 个技能"
if ($Failed -gt 0) {
    Log-Error "失败: $Failed 个技能"
}

# 列出已安装技能
Write-Output ""
Log-Info "已安装的技能:"
Get-ChildItem -Path $TargetDir -Directory | ForEach-Object {
    $skillMd = Join-Path $_.FullName "SKILL.md"
    if (Test-Path $skillMd) {
        $content = Get-Content $skillMd -Raw
        if ($content -match 'name:\s*(.+)') {
            $name = $Matches[1].Trim()
        }
        if ($content -match 'description:\s*(.+)') {
            $desc = $Matches[1].Trim()
            if ($desc.Length -gt 60) { $desc = $desc.Substring(0, 60) + "..." }
        }
        Write-Output "  - $name : $desc"
    }
}

Write-Output ""
Log-Info "重启 OpenClaw 以加载新技能"
