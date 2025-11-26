<# ==========================
 mod07_test.ps1
 - 前提: C:\ai-script\config\mykey.json に DifyApiKey が存在
========================== #>

try { chcp 65001 > $null } catch {}
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Import-Module "C:\ai-script\mod\mod07.psm1" -Force

function Assert($cond,[string]$msg){ if(-not $cond){ throw "ASSERT FAILED: $msg" } }

Write-Host "=== MOD07 TEST START ==="

# ---- 1. APIキー取得 ----
$key = Get-DifyApiKey
Assert ($key) "Dify APIキーが取得できませんでした。"
Write-Host "OK: APIキー読込成功。"

# ---- 2. シンプル送信テスト ----
$resp = Send-MessageToDify -ApiKey $key -Query "Hello Dify, how are you?" -Inputs @{}
Assert ($resp) "Dify応答がありません"
Write-Host "Send-MessageToDify 応答OK"

# ---- 3. answer抽出テスト ----
$answer = Invoke-DifyChat -ApiKey $key -Query "テストメッセージを返して"
Assert ($answer) "Invoke-DifyChat が空応答"
Write-Host "Invoke-DifyChat 応答: $answer"

Write-Host "=== MOD07 TEST END ==="
