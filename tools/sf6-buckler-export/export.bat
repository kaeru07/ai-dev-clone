@echo off
cd /d "%~dp0"
chcp 65001 > nul

REM Node.jsの存在チェック
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo ===============================
    echo Node.jsが見つかりません
    echo ===============================
    echo.
    echo Node.jsをインストールします...
    echo.
    
    REM Node.jsインストーラーのダウンロード
    echo [1/3] Node.jsインストーラーをダウンロード中...
    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $url='https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi'; $output='%TEMP%\nodejs-installer.msi'; Invoke-WebRequest -Uri $url -OutFile $output; if (Test-Path $output) {Write-Host 'ダウンロード完了'} else {Write-Host 'ダウンロード失敗'; exit 1}}"
    
    if %errorlevel% neq 0 (
        echo.
        echo ダウンロードに失敗しました。
        echo 手動でインストールしてください: https://nodejs.org/
        pause
        exit /b 1
    )
    
    REM Node.jsのインストール実行
    echo.
    echo [2/3] Node.jsをインストール中...
    echo インストールウィザードが開きます。画面の指示に従ってください。
    echo.
    msiexec /i "%TEMP%\nodejs-installer.msi" /qb
    
    REM インストール完了待機
    echo.
    echo [3/3] インストール完了を待っています...
    timeout /t 10 /nobreak >nul
    
    REM 環境変数を再読み込み
    call refreshenv >nul 2>&1
    
    REM 再度チェック
    where node >nul 2>&1
    if %errorlevel% neq 0 (
        echo.
        echo Node.jsのインストールが完了しませんでした。
        echo PCを再起動してから、もう一度このバッチファイルを実行してください。
        echo.
        echo または、手動でインストールしてください: https://nodejs.org/
        pause
        exit /b 1
    )
    
    echo.
    echo Node.jsのインストールが完了しました！
    echo.
    
    REM npmパッケージのインストール
    echo 必要なパッケージをインストールします...
    call npm install
    
    if %errorlevel% neq 0 (
        echo.
        echo パッケージのインストールに失敗しました。
        echo 次のコマンドを手動で実行してください:
        echo   cd "%~dp0"
        echo   npm install
        echo   npx playwright install chromium
        pause
        exit /b 1
    )
    
    echo.
    echo Playwrightブラウザをインストールします...
    call npx playwright install chromium
    
    if %errorlevel% neq 0 (
        echo.
        echo Playwrightのインストールに失敗しました。
        echo 次のコマンドを手動で実行してください:
        echo   npx playwright install chromium
        pause
        exit /b 1
    )
    
    echo.
    echo ========================================
    echo セットアップが完了しました！
    echo ========================================
    echo.
    timeout /t 3 /nobreak >nul
)

echo ===============================
echo Buckler BattleLog -> CSV
echo ===============================
echo.
echo Node.js バージョン:
node --version
echo.
echo 1) ブラウザでBucklerにログイン
echo 2) バトルログ(ランクマ)が見える状態にする
echo.
echo 準備ができたら Enter を押してください
pause > nul
node "%~dp0src\export_buckler_auto.js"

if errorlevel 1 (
  echo.
  echo エラーで停止しました。上のログを確認してください。
  pause
  exit /b 1
)

echo.
echo 完了。battlelog.csv を確認してください。
pause
