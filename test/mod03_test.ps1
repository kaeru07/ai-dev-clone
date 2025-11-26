# C:\ai-script\test\mod03_test.ps1
# 実行例: powershell -File "C:\ai-script\test\mod03_test.ps1"

# --- 文字化け対策（Windows PowerShell用） ---
try { chcp 65001 > $null } catch {}
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# 設定読込はモジュール側で完結する前提
Import-Module "C:\ai-script\mod\mod03.psm1" -Force

# ★ 引数なしで“呼ぶだけ”
$result = Update-AccessToken   # (= Refresh-AccessToken エイリアスでも可)

if (-not $result.access_token) { throw "access_token を取得できませんでした" }

Write-Host "=== INTEGRATION mod3 TEST PASSED ==="
Write-Host "token_path : $($result.token_path)"
Write-Host "backup     : $($result.backup_path)"
