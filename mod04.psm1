# mod04.psm1
# 役割: 文字列(URL/ID)から YouTube の videoId を解決する
# 承認動詞: Resolve（互換エイリアス: Extract-VideoId）

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

function Resolve-YouTubeVideoId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputString
    )

    # 1) 前処理
    $s = $InputString.Trim() -replace '^[''"]|[''"]$',''

    # 2) URLとして解析を試みる（失敗したら "生のID かも" として後段へ回す）
    try {
        $u = [System.Uri]$s
        $host = $u.Host.ToLower()
        $path = $u.AbsolutePath

        # youtube.* ドメイン（www., m. など含む）
        if ($host -like '*youtube.*' -or $host -eq 'youtu.be' -or $host -like 'studio.youtube.*') {
            if ($host -eq 'youtu.be') {
                if ($path -match '^/([A-Za-z0-9_\-]{6,64})') { $s = $Matches[1] }
            }
            elseif ($host -like 'studio.youtube.*') {
                if ($path -match '/video/([A-Za-z0-9_\-]{6,64})') { $s = $Matches[1] }
            }
            else {
                # youtube.com / www.youtube.com / m.youtube.com など
                $qs = [System.Web.HttpUtility]::ParseQueryString($u.Query)
                if ($qs['v']) { $s = $qs['v'] }
                elseif ($path -match '/live/([A-Za-z0-9_\-]{6,64})')   { $s = $Matches[1] }
                elseif ($path -match '/shorts/([A-Za-z0-9_\-]{6,64})') { $s = $Matches[1] }
                elseif ($path -match '/embed/([A-Za-z0-9_\-]{6,64})')  { $s = $Matches[1] }
                # それ以外は v= を持たないURL（再生リスト等）なので後段の生ID判定へ
            }
        }
    } catch {
        # URLとして無視 → 後段の生ID判定へ
    }

    # 3) 生IDフォーマット最終判定（YouTubeは11文字が多いが余裕を持って許容）
    if ($s -match '^[A-Za-z0-9_\-]{6,64}$') { return $s }

    return $null
}

# 互換エイリアス（既存スクリプトの呼び名を維持）
Set-Alias Extract-VideoId Resolve-YouTubeVideoId

Export-ModuleMember -Function Resolve-YouTubeVideoId -Alias Extract-VideoId
