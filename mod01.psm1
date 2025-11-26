# ---------- 共通: JSON保存/読込 ----------
# mod01.psm1
# JSONユーティリティ（Approved Verbs対応／互換エイリアス付き）
Set-StrictMode -Version Latest

function Export-JsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Object,
        [Parameter(Mandatory)][string]$Path,
        [int]$Depth = 8
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # UTF-8で安定保存
    $Object | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Import-JsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    try {
        (Get-Content -LiteralPath $Path -Raw -Encoding UTF8) | ConvertFrom-Json
    }
    catch {
        Write-Warning "Import-JsonFile: JSONの読み込みに失敗しました。$($_.Exception.Message)"
        return $null
    }
}

# 互換エイリアス（既存の呼び名でも使える）
Set-Alias Save-Json Export-JsonFile
Set-Alias Load-Json Import-JsonFile

# 公開
Export-ModuleMember -Function Export-JsonFile,Import-JsonFile -Alias Save-Json,Load-Json
