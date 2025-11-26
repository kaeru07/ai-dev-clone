# mod01_test.ps1
# 実行例: powershell -File "C:\ai-script\test\mod01_test.ps1"

# --- 文字化け対策（Windows PowerShell用） ---
try { chcp 65001 > $null } catch {}
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- モジュール読込 ---
$ModulePath = "C:\ai-script\mod\mod01.psm1"
if (-not (Test-Path $ModulePath)) { throw "モジュールが見つかりません: $ModulePath" }
Import-Module $ModulePath -Force  # 承認動詞に直したので -DisableNameChecking は不要

# --- 簡易アサート ---
function Assert($cond, [string]$msg) { if (-not $cond) { throw "ASSERT FAILED: $msg" } }

# --- 作業ディレクトリ ---
$Root = Join-Path $env:TEMP "mod01_test_$(Get-Random)"
New-Item -ItemType Directory -Path $Root -Force | Out-Null

try {
    Write-Host "=== TEST START ($Root) ==="

    # TEST1: 保存（新API）
    $p = Join-Path $Root "sample.json"
    $o = [pscustomobject]@{ Name="Test"; Count=3 }
    Export-JsonFile -Object $o -Path $p
    Assert (Test-Path $p) "TEST1: 保存ファイルが存在しません"
    Write-Host "TEST1 PASS: Export-JsonFile 正常"

    # TEST2: 読込（新API）
    $d = Import-JsonFile -Path $p
    Assert ($d.Name  -eq "Test") "TEST2: Name が違います"
    Assert ($d.Count -eq 3)      "TEST2: Count が違います"
    Write-Host "TEST2 PASS: Import-JsonFile 正常"

    # TEST3: 旧APIでも動く（互換エイリアス）
    $d.Count = 5
    Save-Json $d $p             # ← 旧名
    $d2 = Load-Json $p          # ← 旧名
    Assert ($d2.Count -eq 5) "TEST3: 旧API経由の上書きが反映されません"
    Write-Host "TEST3 PASS: 旧API名でもOK"

    # TEST4: 不在ファイル
    $none = Import-JsonFile -Path (Join-Path $Root "nofile.json")
    Assert ($none -eq $null) "TEST4: 不在時は null が返るべき"
    Write-Host "TEST4 PASS: 不在時は null"

    Write-Host "=== ALL TESTS PASSED ==="
}
catch {
    Write-Host "`n*** TEST FAILED ***"
    Write-Host $_.Exception.Message
}
finally {
    Remove-Item $Root -Recurse -Force -ErrorAction SilentlyContinue
}