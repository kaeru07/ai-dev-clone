<# ==========================
 mod06_test.ps1
 - 前提: mod02, mod05 動作済み
 - 環境変数 YOUTUBE_VIDEO_ID or YOUTUBE_LIVECHAT_ID があれば利用
========================== #>

try { chcp 65001 > $null } catch {}
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Import-Module "C:\ai-script\mod\mod02.psm1" -Force
Import-Module "C:\ai-script\mod\mod05.psm1" -Force
Import-Module "C:\ai-script\mod\mod06.psm1" -Force

function Assert($cond,[string]$msg){ if(-not $cond){ throw "ASSERT FAILED: $msg" } }

Write-Host "=== MOD06 TEST START ==="

# 1. アクセストークン取得
$at=$null; $hd=$null
Ensure-AccessToken -AccessToken ([ref]$at) -Headers ([ref]$hd)
Assert ($hd -and $hd.Authorization) "Headers not prepared"
Write-Host "OK: Access token ensured."

# 2. liveChatId の決定
$chatId=$env:YOUTUBE_LIVECHAT_ID
if(-not $chatId){
  $vid=$env:YOUTUBE_VIDEO_ID
  if(-not $vid){
    $det=Detect-ActiveLive -Headers $hd
    if($det){ $vid=$det.videoId; $chatId=$det.chatId }
  }
  if(-not $chatId -and $vid){
    $chatId = Get-LiveChatId -Headers $hd -VideoId $vid
  }
}
Assert ($chatId) "liveChatId 未取得"
Write-Host "OK: liveChatId=$chatId"

# 3. 最新コメント取得
$res = Get-LiveChatMessages -Headers $hd -LiveChatId $chatId
Assert ($res.items.Count -ge 0) "Get-LiveChatMessages failed"
Write-Host ("取得コメント数: {0}" -f $res.items.Count)

# 4. ループ動作テスト（1回のみ）
Write-Host "コメント監視テスト開始（1ループのみ）..."
Watch-LiveChatLoop -Headers $hd -LiveChatId $chatId -MaxLoops 1

Write-Host "=== MOD06 TEST END ==="
