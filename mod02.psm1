# mod02.psm1
# 役割: アクセストークン有効性の判定 → 必要時のみ mod03(Update-AccessToken) で更新して返す
# 前提: mykey.json / youtube_tokens.json は既存と同じ構成

Set-StrictMode -Version Latest

# 依存モジュールの自動読込（mod01: JSON I/O, mod03: Update-AccessToken）
$root  = $env:AI_SCRIPT_ROOT
if (-not $root) { $root = 'C:\ai-script' }
$mod01 = Join-Path $root 'mod\mod01.psm1'
$mod03 = Join-Path $root 'mod\mod03.psm1'

if (-not (Get-Command Import-JsonFile -ErrorAction SilentlyContinue)) {
    if (Test-Path $mod01) { Import-Module $mod01 -Force } else { throw "mod01.psm1 が見つかりません: $mod01" }
}
if (-not (Get-Command Update-AccessToken -ErrorAction SilentlyContinue)) {
    if (Test-Path $mod03) { Import-Module $mod03 -Force } else { throw "mod03.psm1 が見つかりません: $mod03" }
}

function Get-ConfigPath {
    $cfg = $env:AI_CONFIG_PATH
    if (-not $cfg -or -not (Test-Path $cfg)) { $cfg = 'C:\ai-script\config\mykey.json' }
    return $cfg
}

# ---------- アクセストークンを用意（ゲートキーパー） ----------
function Ensure-AccessToken {
    [CmdletBinding()]
    param(
        [ref]$AccessToken,
        [ref]$Headers
    )

    # 設定とトークン読込
    $configPath = Get-ConfigPath
    $config = Import-JsonFile -Path $configPath
    if (-not $config) { throw "設定ファイルの読込に失敗しました: $configPath" }

    $tokenPath = $config.TokenPath
    if (-not $tokenPath) { throw "mykey.json に TokenPath がありません: $configPath" }
    if (-not (Test-Path $tokenPath)) { throw "トークンファイルがありません: $tokenPath" }

    $tok = Import-JsonFile -Path $tokenPath
    if (-not $tok) { throw "トークンJSONの読込に失敗: $tokenPath" }

    # 1) ローカルの期限情報で“ほぼ期限切れ”なら即更新（API叩く前に最小化）
    $needRefresh = $false
    if ($tok.issued_at -and $tok.expires_in) {
        try {
            $issued = [DateTimeOffset]::Parse($tok.issued_at)
            $ageSec = ([DateTimeOffset]::UtcNow - $issued).TotalSeconds
            if ($ageSec -ge ([double]$tok.expires_in - 60)) { $needRefresh = $true } # 60秒バッファ
        } catch { }
    }

    if ($needRefresh) {
        if (-not $tok.refresh_token) { throw "refresh_token がありません。最初の認可からやり直してください。($tokenPath)" }
        $null = Update-AccessToken    # ← mod03 で更新＆保存
        $tok = Import-JsonFile -Path $tokenPath
        if (-not $tok -or -not $tok.access_token) { throw "更新後のトークン再読込に失敗: $tokenPath" }
    }

    # 2) 現在のトークンで疎通トライ（無効・権限変更・ローテーション検知）
    $AccessToken.Value = $tok.access_token
    $Headers.Value = @{
        Authorization = "Bearer $($tok.access_token)"
        'Content-Type' = 'application/json'
    }

    $testUri = "https://www.googleapis.com/youtube/v3/channels?part=id&mine=true"
    try {
        Invoke-RestMethod -Headers $Headers.Value -Uri $testUri -Method Get | Out-Null
        return  # そのまま利用OK
    }
    catch {
        # 3) 失敗時のみ更新実施（ゲートキーパーとして最小回数に抑える）
        if (-not $tok.refresh_token) { throw "refresh_token がありません。最初の認可からやり直してください。($tokenPath)" }
        $res = Update-AccessToken
        if (-not $res.access_token) { throw "アクセストークンの更新に失敗しました。（応答なし）" }

        # 再読込してヘッダ更新
        $tok2 = Import-JsonFile -Path $tokenPath
        if (-not $tok2 -or -not $tok2.access_token) { throw "更新後のトークン再読込に失敗: $tokenPath" }

        $AccessToken.Value = $tok2.access_token
        $Headers.Value = @{
            Authorization = "Bearer $($tok2.access_token)"
            'Content-Type' = 'application/json'
        }

        # 念のため疎通確認
        Invoke-RestMethod -Headers $Headers.Value -Uri $testUri -Method Get | Out-Null
        return
    }
}

# 戻り値で受けたい用途向けのラッパ
function Get-AuthHeaders {
    [CmdletBinding()]
    param()
    $at = $null; $hd = $null
    Ensure-AccessToken -AccessToken ([ref]$at) -Headers ([ref]$hd)
    [pscustomobject]@{ access_token = $at; headers = $hd }
}

Export-ModuleMember -Function Ensure-AccessToken, Get-AuthHeaders
