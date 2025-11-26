#requires -Version 5.1
# mod06.psm1 : YouTube Live コメント取得（監視ループ付き）
# 依存: mod02 (Ensure-AccessToken)
# API: youtube/v3/liveChat/messages

Set-StrictMode -Version Latest

Export-ModuleMember -Function Get-LiveChatMessages, Watch-LiveChatLoop

# ---------- liveChatId → コメント取得 ----------
function Get-LiveChatMessages {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Headers,
    [Parameter(Mandatory)][string]$LiveChatId,
    [Parameter()][string]$PageToken
  )

  $base = "https://www.googleapis.com/youtube/v3/liveChat/messages?liveChatId=$LiveChatId&part=snippet,authorDetails&maxResults=200"
  $uri  = if ($PageToken) { "$base&pageToken=$PageToken" } else { $base }

  try {
    $resp = Invoke-RestMethod -Headers $Headers -Uri $uri -Method Get
    return $resp
  } catch {
    Write-Verbose "[Get-LiveChatMessages] Error: $($_.Exception.Message)"
    return $null
  }
}

# ---------- コメント監視ループ ----------
function Watch-LiveChatLoop {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Headers,
    [Parameter(Mandatory)][string]$LiveChatId,
    [Parameter()][int]$IntervalMs = 0,          # 0=API推奨値に従う
    [Parameter()][int]$MaxLoops = 0             # 0=無限ループ
  )

  $seen = New-Object System.Collections.Generic.HashSet[string]
  $next = $null
  $loop = 0

  while ($true) {
    $resp = Get-LiveChatMessages -Headers $Headers -LiveChatId $LiveChatId -PageToken $next
    if (-not $resp) {
      Write-Host "コメント取得エラー。2秒後に再試行。" -ForegroundColor Yellow
      Start-Sleep 2
      continue
    }

    foreach ($it in $resp.items) {
      if (-not $seen.Add($it.id)) { continue }

      $msg = $it.snippet.displayMessage
      $author = $it.authorDetails.displayName
      Write-Host ("[{0}] {1}" -f $author, $msg)
    }

    $next = $resp.nextPageToken
    $sleepMs = if ($IntervalMs -gt 0) { $IntervalMs } else { [int]$resp.pollingIntervalMillis + 200 }
    Start-Sleep -Milliseconds $sleepMs

    $loop++
    if ($MaxLoops -gt 0 -and $loop -ge $MaxLoops) { break }
  }
}

Export-ModuleMember -Function Get-LiveChatMessages, Watch-LiveChatLoop

