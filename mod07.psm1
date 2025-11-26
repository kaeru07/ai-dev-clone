#requires -Version 5.1
# mod07.psm1 : Dify チャットAPIへの送信と応答取得
# 依存: mod01 (JSON読込), mod02 (Ensure-AccessToken)
# API: https://api.dify.ai/v1/chat-messages

Set-StrictMode -Version Latest

Export-ModuleMember -Function Send-MessageToDify, Invoke-DifyChat, Get-DifyApiKey

# ---------- Dify APIキーを config/mykey.json から取得 ----------
function Get-DifyApiKey {
  [CmdletBinding()]
  param(
    [Parameter()][string]$Path = "C:\ai-script\config\mykey.json"
  )

  if (-not (Test-Path $Path)) {
    throw "Dify設定ファイルが見つかりません: $Path"
  }

  try {
    $json = Get-Content $Path -Raw | ConvertFrom-Json
    if (-not $json.DifyApiKey) { throw "mykey.json に DifyApiKey がありません。" }
    return $json.DifyApiKey
  } catch {
    throw "mykey.json の読込に失敗しました: $($_.Exception.Message)"
  }
}

# ---------- 単発メッセージ送信 ----------
function Send-MessageToDify {
  [CmdletBinding()]
  param(
    [Parameter()][string]$ApiKey,
    [Parameter(Mandatory)][string]$Query,
    [Parameter()][hashtable]$Inputs,
    [Parameter()][string]$User = "guest",
    [Parameter()][string]$ResponseMode = "blocking"
  )

  if (-not $ApiKey) {
    $ApiKey = Get-DifyApiKey
  }

  $endpoint = "https://api.dify.ai/v1/chat-messages"
  $headers  = @{
    Authorization = "Bearer $ApiKey"
    "Content-Type" = "application/json"
  }

  $body = @{
    query          = $Query
    inputs         = $Inputs
    user           = $User
    response_mode  = $ResponseMode
  }

  try {
    $resp = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Post -Body ($body | ConvertTo-Json -Depth 6 -Compress)
    return $resp
  } catch {
    Write-Host "Dify送信エラー: $($_.Exception.Message)" -ForegroundColor Yellow
    if($_.ErrorDetails.Message){ Write-Host $_.ErrorDetails.Message }
    return $null
  }
}

# ---------- 高レベル関数：メッセージ送信＋応答抽出 ----------
function Invoke-DifyChat {
  [CmdletBinding()]
  param(
    [Parameter()][string]$ApiKey,
    [Parameter(Mandatory)][string]$Query,
    [Parameter()][hashtable]$Inputs,
    [Parameter()][string]$User = "guest"
  )

  if (-not $ApiKey) {
    $ApiKey = Get-DifyApiKey
  }

  $resp = Send-MessageToDify -ApiKey $ApiKey -Query $Query -Inputs $Inputs -User $User
  if ($resp -and $resp.answer) {
    return $resp.answer
  } elseif ($resp -and $resp.output_text) {
    return $resp.output_text
  } else {
    return $null
  }
}
Export-ModuleMember -Function Get-DifyApiKey, Send-MessageToDify, Invoke-DifyChat
