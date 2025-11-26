# mod03.psm1
Set-StrictMode -Version Latest

# --- 依存: mod01（Import/Export-JsonFile）を自動読込 ---
if (-not (Get-Command Import-JsonFile -ErrorAction SilentlyContinue)) {
    $root = $env:AI_SCRIPT_ROOT
    if (-not $root) { $root = 'C:\ai-script' }
    $mod01 = Join-Path $root 'mod\mod01.psm1'
    if (Test-Path $mod01) {
        Import-Module $mod01 -Force
    } else {
        throw "mod01.psm1 が見つかりませんでした。場所: $mod01"
    }
}

# --- パス解決（環境変数で上書き可） ---
function Get-ConfigPath {
    $cfg = $env:AI_CONFIG_PATH
    if (-not $cfg -or -not (Test-Path $cfg)) {
        $cfg = 'C:\ai-script\config\mykey.json'
    }
    return $cfg
}

# --- 内部: 設定とトークンを読む ---
function Get-OAuthContext {
    $configPath = Get-ConfigPath
    $config = Import-JsonFile -Path $configPath
    if (-not $config) { throw "設定の読込に失敗: $configPath" }

    $clientId     = $config.ClientId
    $clientSecret = $config.ClientSecret
    $tokenPath    = $config.TokenPath
    if (-not $clientId -or -not $clientSecret -or -not $tokenPath) {
        throw "ClientId / ClientSecret / TokenPath は必須です（$configPath）"
    }

    $token = Import-JsonFile -Path $tokenPath
    if (-not $token) { throw "トークン読込に失敗: $tokenPath" }
    if (-not $token.refresh_token) { throw "refresh_token が $tokenPath にありません" }

    [pscustomobject]@{
        ConfigPath   = $configPath
        TokenPath    = $tokenPath
        ClientId     = $clientId
        ClientSecret = $clientSecret
        Token        = $token
    }
}

# --- 内部: 実リフレッシュ呼び出し ---
function Invoke-TokenRefreshInternal {
    param(
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$ClientSecret,
        [Parameter(Mandatory)][string]$RefreshToken
    )
    $uri = 'https://oauth2.googleapis.com/token'
    $body = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        refresh_token = $RefreshToken
        grant_type    = 'refresh_token'
    }
    try {
        Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType 'application/x-www-form-urlencoded'
    }
    catch {
        # 可能なら Google のエラー本文（JSON）を吸い上げて表示
        $msg = $_.Exception.Message
        try {
            $resp = $_.Exception.Response
            if ($resp -and $resp.GetResponseStream) {
                $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
                $raw = $reader.ReadToEnd()
                if ($raw) {
                    try {
                        $json = $raw | ConvertFrom-Json
                        if ($json.error -or $json.error_description) {
                            $msg = "error=$($json.error); desc=$($json.error_description)"
                        } else {
                            $msg = $raw
                        }
                    } catch { $msg = $raw }
                }
            }
        } catch {}
        throw "トークンリフレッシュ失敗: $msg"
    }
}


# --- 公開: 引数なしで設定を読み、リフレッシュして保存 ---
function Update-AccessToken {
    [CmdletBinding()]
    param()

    $ctx = Get-OAuthContext
    $res = Invoke-TokenRefreshInternal -ClientId $ctx.ClientId -ClientSecret $ctx.ClientSecret -RefreshToken $ctx.Token.refresh_token

    if (-not $res.access_token) {
        throw "access_token が取得できませんでした。応答: $($res | ConvertTo-Json -Depth 5)"
    }

    # バックアップ
    $backup = "$($ctx.TokenPath).bak_{0:yyyyMMdd_HHmmss}" -f (Get-Date)
    try { Copy-Item -LiteralPath $ctx.TokenPath -Destination $backup -Force } catch {}

    # 保存（mod01の Export-JsonFile 使用）
    $tok = $ctx.Token
    $tok.access_token = $res.access_token
    if ($res.PSObject.Properties.Name -contains 'expires_in') { $tok.expires_in = $res.expires_in }
    if ($res.PSObject.Properties.Name -contains 'token_type') { $tok.token_type = $res.token_type }
    $tok.issued_at = (Get-Date).ToUniversalTime().ToString('o')

    Export-JsonFile -Object $tok -Path $ctx.TokenPath

    # 呼び出し側でも使えるよう最小情報を返す
    [pscustomobject]@{
        access_token = $tok.access_token
        expires_in   = $tok.expires_in
        token_path   = $ctx.TokenPath
        backup_path  = $backup
    }
}

# 互換エイリアス（旧名でも呼べる）
Set-Alias Refresh-AccessToken Update-AccessToken

Export-ModuleMember -Function Update-AccessToken -Alias Refresh-AccessToken
