<# ==========================
 mod08_test.ps1
 - 前提: 配信中で liveChatId が取得できる状態
 - 動作: 手動で指定したメッセージを投稿
========================== #>

try { chcp 65001 > $null } catch {}
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Import-Module "C:\ai-script\mod\mod02.psm1" -Force
Import-Module "C:\ai-script\mod\mod05.psm1" -Force
Import-Module "C:\ai-script\mod\mod08.psm1" -Force

function Assert($cond,[string]$msg){ if(-not $cond){ throw "ASSERT FAILED: $msg" } }

Write-Host "=== MOD08 TEST START ==="

# ---- 1. アクセストークンを確保 ----
$at = $null; $hd = $null
Ensure-AccessToken -AccessToken ([ref]$at) -Headers ([ref]$hd)
Assert ($hd -and $hd.Authorization) "アクセストークン未取得"
Write-Host "OK: Access token ensured."

# ---- 2. liveChatId の決定 ----
$chatId = $env:YOUTUBE_LIVECHAT_ID
if (-not $chatId) {
  $det = Detect-ActiveLive -Headers $hd
  if ($det) { $chatId = $det.chatId }
}
Assert ($chatId) "liveChatId 未取得"
Write-Host "OK: liveChatId=$chatId"

# ---- 3. テスト投稿 ----
$msg = Read-Host "投稿メッセージを入力してください"
Assert ($msg) "メッセージが空です"
Write-Host "投稿中..."
Post-LiveChatMessage -Headers $hd -LiveChatId $chatId -Message $msg

Write-Host "=== MOD08 TEST END ==="
