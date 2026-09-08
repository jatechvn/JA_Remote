<#
.SYNOPSIS
    Script tu dong khoi phuc va dong bo toan bo AI Skills & System Rules.
#>
$ErrorActionPreference = "Stop"

$userProfile = $env:USERPROFILE
$globalSkills = "$userProfile\.gemini\antigravity\builtin\skills"
$globalRules  = "$userProfile\.claude\rules"

$scriptDir = $PSScriptRoot

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " KHOI PHUC VA DONG BO AI SKILLS & RULES " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# 1. Restore Skills to Global Builtin
$localSkills = "$scriptDir\skills"
if (Test-Path $localSkills) {
    Write-Host "[1/3] Dang khoi phuc Skills vao $globalSkills..." -ForegroundColor Yellow
    if (!(Test-Path $globalSkills)) { New-Item -ItemType Directory -Force -Path $globalSkills | Out-Null }
    Copy-Item -Recurse -Force "$localSkills\*" $globalSkills
    Write-Host "  -> Da dong bo vao global builtin skills thanh cong!" -ForegroundColor Green

    # Sync to local .agents/skills and .claude/skills
    $agentSkills = "$scriptDir\.agents\skills"
    $claudeSkills = "$scriptDir\.claude\skills"
    if (!(Test-Path $agentSkills)) { New-Item -ItemType Directory -Force -Path $agentSkills | Out-Null }
    if (!(Test-Path $claudeSkills)) { New-Item -ItemType Directory -Force -Path $claudeSkills | Out-Null }
    Copy-Item -Recurse -Force "$localSkills\*" $agentSkills
    Copy-Item -Recurse -Force "$localSkills\*" $claudeSkills
    Write-Host "  -> Da dong bo vao .agents/skills va .claude/skills!" -ForegroundColor Green
} else {
    Write-Host "  [!] Thu muc skills/ khong ton tai trong du an nay." -ForegroundColor Red
}

# 2. Restore Rules
$localRules = "$scriptDir\.claude\rules"
if (Test-Path $localRules) {
    Write-Host "[2/3] Dang khoi phuc System Rules vao $globalRules..." -ForegroundColor Yellow
    if (!(Test-Path $globalRules)) { New-Item -ItemType Directory -Force -Path $globalRules | Out-Null }
    Copy-Item -Recurse -Force "$localRules\*" $globalRules
    Write-Host "  -> Da khoi phuc thanh cong cac System Rules!" -ForegroundColor Green
} else {
    Write-Host "  [!] Thu muc .claude/rules khong ton tai trong du an nay." -ForegroundColor Red
}

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " HOAN TAT KHOI PHUC VA DONG BO SKILLS & RULES!" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Cyan
