# mod04_test.ps1
# 実行例: powershell -File "C:\ai-script\test\mod04_test.ps1"

try { chcp 65001 > $null } catch {}
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ModulePath = "C:\ai-script\mod\mod04.psm1"
if (-not (Test-Path $ModulePath)) { throw "モジュールが見つかりません: $ModulePath" }
Import-Module $ModulePath -Force

function Assert($cond, [string]$msg) { if (-not $cond) { throw "ASSERT FAILED: $msg" } }

Write-Host "=== MOD04 TEST START ==="

# テストデータ
$cases = @(
    @{ input = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';               expect = 'dQw4w9WgXcQ' },
    @{ input = 'https://youtu.be/dQw4w9WgXcQ';                              expect = 'dQw4w9WgXcQ' },
    @{ input = 'https://www.youtube.com/shorts/AbCdEfGhijk';                expect = 'AbCdEfGhijk' },
    @{ input = 'https://www.youtube.com/live/AbCDEFG1234?feature=share';    expect = 'AbCDEFG1234' },
    @{ input = 'https://www.youtube.com/embed/ZXCVBNMasdf';                 expect = 'ZXCVBNMasdf' },
    @{ input = 'https://studio.youtube.com/video/qwertyUIOP9/edit';         expect = 'qwertyUIOP9' },
    @{ input = '"https://www.youtube.com/watch?v=abc_DEF-123"';             expect = 'abc_DEF-123' },
    @{ input = "abc_DEF-123";                                               expect = 'abc_DEF-123' },  # 生ID
    @{ input = 'https://www.youtube.com/playlist?list=PLxxxx';              expect = $null },          # playlistはIDなし
    @{ input = 'not a url at all';                                          expect = $null }
)

# 実行
$pass = 0
for ($i=0; $i -lt $cases.Count; $i++) {
    $c = $cases[$i]
    $out = Resolve-YouTubeVideoId -InputString $c.input
    if ($c.expect -eq $null) {
        Assert ($out -eq $null) "Case#$i 期待: <null> / 実際: '$out' (input='$($c.input)')"
    } else {
        Assert ($out -eq $c.expect) "Case#$i 期待: '$($c.expect)' / 実際: '$out' (input='$($c.input)')"
    }
    $pass++
}
Write-Host "=== MOD04 TEST PASSED ($pass cases) ==="

# 互換エイリアスも簡易チェック
$out2 = Extract-VideoId 'https://youtu.be/12345678901'
Assert ($out2 -eq '12345678901') "Alias Extract-VideoId が動作しません"
Write-Host "Alias check OK"

Write-Host "=== ALL TESTS PASSED ==="
