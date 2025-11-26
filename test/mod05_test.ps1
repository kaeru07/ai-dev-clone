<# ==========================
 mod05_test.ps1
 - 前提: mod02 で Ensure-AccessToken が動作し、$Headers を得られる
 - オンラインAPIを叩くため、環境依存のための「緩い合格条件」を採用
 - 追加で以下の環境変数があれば詳細テストを有効化
    - $env:YOUTUBE_CHANNEL_ID : 自分のチャンネルID
    - $env:YOUTUBE_VIDEO_ID   : テストしたいライブ（または過去ライブ）の videoId
========================== #>

try { chcp 65001 > $null } catch {}
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Import-Module "C:\ai-script\mod\mod02.psm1" -Force
Import-Module "C:\ai-script\mod\mod05.psm1" -Force

function Assert($cond, [string]$msg) { if (-not $cond) { throw "ASSERT FAILED: $msg" } }

Write-Host "=== MOD05 TEST START ==="

# ---- 0) アクセストークンを取得（mod02経由） ----
$at = $null; $hd = $null
Ensure-AccessToken -AccessToken ([ref]$at) -Headers ([ref]$hd)
Assert ($hd -and $hd.Authorization) "Headers not prepared by Ensure-AccessToken"
Write-Host "OK: Access token ensured."

# ---- 1) 自動検出（mine=true優先 / search保険） ----
$det = $null
try {
  $det = Detect-ActiveLive -Headers $hd -ChannelId $env:YOUTUBE_CHANNEL_ID
} catch {
  Write-Host "WARN: Detect-ActiveLive threw: $($_.Exception.Message)"
}
# ライブが無い時間帯は $null でもOK とする
if ($det) {
  Write-Host "Detect-ActiveLive => videoId=$($det.videoId) chatId=$($det.chatId) source=$($det.source)"
  Assert ($det.videoId -match '^[A-Za-z0-9_\-]{6,}$') "Detected videoId format invalid"
} else {
  Write-Host "Detect-ActiveLive => no active live (this is acceptable if no live is running)"
}

# ---- 2) videos から chatId 解決（指定videoIdがあれば）----
if ($env:YOUTUBE_VIDEO_ID) {
  $cid = Get-LiveChatId -Headers $hd -VideoId $env:YOUTUBE_VIDEO_ID
  if ($cid) {
    Write-Host "Get-LiveChatId($env:YOUTUBE_VIDEO_ID) => chatId=$cid"
    Assert ($cid -match '^[A-Za-z0-9_\-]{6,}$') "chatId format invalid"
  } else {
    Write-Host "Get-LiveChatId($env:YOUTUBE_VIDEO_ID) => chatId not ready or not a live"
  }
} else {
  Write-Host "SKIP: YOUTUBE_VIDEO_ID not set"
}

# ---- 3) 総合解決（videoId優先 → 自動検出） ----
# 3-1) videoId 優先の解決
if ($env:YOUTUBE_VIDEO_ID) {
  $res = Resolve-LiveChat -Headers $hd -VideoId $env:YOUTUBE_VIDEO_ID -WaitSec 0
  Assert ($res -and $res.videoId -eq $env:YOUTUBE_VIDEO_ID) "Resolve-LiveChat(videoId) failed"
  Write-Host "Resolve-LiveChat(videoId) => videoId=$($res.videoId) chatId=$($res.chatId) source=$($res.source)"
} else {
  Write-Host "SKIP: Resolve-LiveChat(videoId) because YOUTUBE_VIDEO_ID not set"
}

# 3-2) 自動検出経路（Waitを短時間だけ検証可能）
try {
  $res2 = Resolve-LiveChat -Headers $hd -ChannelId $env:YOUTUBE_CHANNEL_ID -WaitSec 10 -IntervalSec 5
  if ($res2) {
    Write-Host "Resolve-LiveChat(auto) => videoId=$($res2.videoId) chatId=$($res2.chatId) source=$($res2.source)"
    Assert ($res2.videoId -match '^[A-Za-z0-9_\-]{6,}$') "auto videoId format invalid"
  } else {
    Write-Host "Resolve-LiveChat(auto) => no live detected (acceptable if no live now)"
  }
} catch {
  Write-Host "WARN: Resolve-LiveChat(auto) threw: $($_.Exception.Message)"
}

Write-Host "=== MOD05 TEST END ==="
