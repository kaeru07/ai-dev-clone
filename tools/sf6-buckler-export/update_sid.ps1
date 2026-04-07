param(
    [Parameter(Mandatory=$true)]
    [string]$SID
)

# 先頭・末尾の空白とコロンを除去（例: ":1234567890" → "1234567890"）
$SID = $SID.Trim().TrimStart(':').Trim()

if ($SID -eq '') {
    Write-Error "SIDが空です。"
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$file1 = Join-Path $scriptDir "src\export_buckler_auto.js"
$file2 = Join-Path $scriptDir "src\export_buckler.js"

# 静かに処理（メッセージは出力しない）

# ファイル1を更新
$content1 = Get-Content $file1 -Raw -Encoding UTF8
$content1 = $content1 -replace 'const SID = "[^"]*";', "const SID = `"$SID`";"
Set-Content $file1 -Value $content1 -Encoding UTF8 -NoNewline

# ファイル2を更新
$content2 = Get-Content $file2 -Raw -Encoding UTF8
$content2 = $content2 -replace 'const SID = "[^"]*";', "const SID = `"$SID`";"
Set-Content $file2 -Value $content2 -Encoding UTF8 -NoNewline

# 成功時は終了コード0を返す
exit 0
