#requires -Version 5.1
# mod08.psm1 : YouTube Live チャットへの投稿
# 依存: mod02 (Ensure-AccessToken)
# API: https://www.googleapis.com/youtube/v3/liveChat/messages.insert

Set-StrictMode -Version Latest

# ---------- 投稿処理 ----------
function Post-LiveChatMessage {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Headers,
    [Parameter(Mandatory)][string]$LiveChatId,
    [Parameter(Mandatory)][string]$Message
  )

  if ([string]::IsNullOrWhiteSpace($Message)) {
    Write-Verbose "空メッセージのためスキップしました。"
    return
  }

  $body = @{
    snippet = @{
      liveChatId = $LiveChatId
      type = 'textMessageEvent'
      textMessageDetails = @{ messageText = $Message }
    }
  }

  $json = $body | ConvertTo-Json -Depth 5 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $headersPost = @{
    Authorization = $Headers.Authorization
    "Content-Type" = "application/json; charset=utf-8"
  }

  try {
    $resp = Invoke-RestMethod -Uri "https://www.googleapis.com/youtube/v3/liveChat/messages?part=snippet" `
      -Headers $headersPost -Method Post -Body $bytes
    Write-Host ("✅ 投稿OK → {0}" -f $Message) -ForegroundColor Cyan
    return $resp
  } catch {
    Write-Host "❌ 投稿エラー: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
    return $null
  }
}

# ---------- これを忘れると関数が外部から見えない ----------
Export-ModuleMember -Function Post-LiveChatMessage
