#requires -Version 5.1
# mod05.psm1 : YouTube live の自動検出 ＆ liveChatId 解決
# 依存: mod02(Ensure-AccessTokenで得た$Headersを受け取る), mod01(任意で使ってOKだが本モジュールでは未使用)
# API: liveBroadcasts, search, videos

Set-StrictMode -Version Latest

# ---------- 自動検出（第一候補：liveBroadcasts?mine=true / 第二候補：search?channelId） ----------
function Detect-ActiveLive {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Headers,
    [Parameter()][string]$ChannelId
  )
  # A) 限定/非公開でも拾える：mine=true で全件 → lifeCycleStatus をコード側で絞る
  $lb = $null
  try {
    $lb = Invoke-RestMethod -Headers $Headers -Uri "https://www.googleapis.com/youtube/v3/liveBroadcasts?part=id,snippet,status&mine=true&maxResults=50" -Method Get
  } catch {
    Write-Verbose "[Detect-ActiveLive] liveBroadcasts error: $($_.Exception.Message)"
  }

  if($lb -and $lb.items){
    $live = $lb.items | Where-Object {
      $_.status.lifeCycleStatus -in @('live','testing','liveStarting','ready')
    } | Select-Object -First 1
    if($live){
      $vid = $live.id               # broadcast id = videoId と同値（YouTube APIの性質上ここはvideoIdになる）
      $cid = $live.snippet.liveChatId # ここに liveChatId が入ることがある（即時に入らないケースあり）
      if($cid){
        return [pscustomobject]@{ videoId = $vid; chatId = $cid; source = 'liveBroadcasts' }
      } else {
        # chatId 未生成（配信開始直後など）→ 後段で videos から待機取得
        return [pscustomobject]@{ videoId = $vid; chatId = $null; source = 'liveBroadcasts' }
      }
    }
  }

  # B) 公開配信のみ拾える：search?channelId=...（保険）
  if($ChannelId){
    $sr = $null
    try {
      $sr = Invoke-RestMethod -Headers $Headers -Uri "https://www.googleapis.com/youtube/v3/search?part=id,snippet&eventType=live&type=video&channelId=$ChannelId&maxResults=1" -Method Get
    } catch {
      Write-Verbose "[Detect-ActiveLive] search error: $($_.Exception.Message)"
    }
    if($sr -and $sr.items.Count -gt 0){
      return [pscustomobject]@{ videoId = $sr.items[0].id.videoId; chatId = $null; source = 'search+videos' }
    }
  }

  return $null
}

# ---------- videoId → liveChatId を videos エンドポイントで解決 ----------
function Get-LiveChatId {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Headers,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_\-]{6,}$')][string]$VideoId
  )

  $url = "https://www.googleapis.com/youtube/v3/videos?part=liveStreamingDetails&id=$VideoId"
  try {
    $res = Invoke-RestMethod -Headers $Headers -Uri $url -Method Get
  } catch {
    Write-Verbose "[Get-LiveChatId] videos error: $($_.Exception.Message)"
    return $null
  }

  if(-not $res.items -or $res.items.Count -eq 0){ return $null }
  $ls = $res.items[0].liveStreamingDetails
  if(-not $ls){ return $null }

  # activeLiveChatId が存在すればそれが chatId
  return $ls.activeLiveChatId
}

# ---------- chatId 未生成時のポーリング ----------
function Wait-For-LiveChatId {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Headers,
    [Parameter(Mandatory)][string]$VideoId,
    [Parameter()][int]$MaxWaitSec = 60,
    [Parameter()][int]$IntervalSec = 5
  )

  $deadline = (Get-Date).AddSeconds($MaxWaitSec)
  do {
    $cid = Get-LiveChatId -Headers $Headers -VideoId $VideoId
    if($cid){ return $cid }
    Start-Sleep -Seconds $IntervalSec
  } while((Get-Date) -lt $deadline)

  return $null
}

# ---------- 総合解決：videoId が分かっていれば直解決、なければ自動検出 → 必要に応じて待機 ----------
function Resolve-LiveChat {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Headers,
    [Parameter()][string]$VideoId,
    [Parameter()][string]$ChannelId,
    [Parameter()][int]$WaitSec = 0,     # chatIdが未生成の時に待機する合計秒
    [Parameter()][int]$IntervalSec = 5  # 待機時のポーリング間隔
  )

  # 1) videoId 直指定なら最短経路
  if($VideoId){
    $chatId = Get-LiveChatId -Headers $Headers -VideoId $VideoId
    if(-not $chatId -and $WaitSec -gt 0){
      $chatId = Wait-For-LiveChatId -Headers $Headers -VideoId $VideoId -MaxWaitSec $WaitSec -IntervalSec $IntervalSec
    }
    if($chatId){
      return [pscustomobject]@{ videoId = $VideoId; chatId = $chatId; source = 'videos' }
    } else {
      return [pscustomobject]@{ videoId = $VideoId; chatId = $null; source = 'videos' }
    }
  }

  # 2) 自動検出（mine=true / search?channelId）
  $detected = Detect-ActiveLive -Headers $Headers -ChannelId $ChannelId
  if(-not $detected){ return $null }

  if($detected.chatId){
    return $detected
  }

  # 3) chatId が未生成なら videos で確認 & 任意で待機
  $cid = Get-LiveChatId -Headers $Headers -VideoId $detected.videoId
  if(-not $cid -and $WaitSec -gt 0){
    $cid = Wait-For-LiveChatId -Headers $Headers -VideoId $detected.videoId -MaxWaitSec $WaitSec -IntervalSec $IntervalSec
  }

  return [pscustomobject]@{
    videoId = $detected.videoId
    chatId  = $cid
    source  = $detected.source + '+videos'
  }
}

# --- Export (file end) ---
Export-ModuleMember -Function Detect-ActiveLive, Get-LiveChatId, Wait-For-LiveChatId, Resolve-LiveChat

