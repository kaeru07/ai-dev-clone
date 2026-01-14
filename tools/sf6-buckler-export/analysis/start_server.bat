@echo off
chcp 932 >nul

REM Pythonの存在チェック
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo ========================================
    echo  Pythonが見つかりません
    echo ========================================
    echo.
    echo Pythonをインストールします...
    echo.
    
    REM Pythonインストーラーのダウンロード
    echo [1/3] Pythonインストーラーをダウンロード中...
    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $url='https://www.python.org/ftp/python/3.12.1/python-3.12.1-amd64.exe'; $output='%TEMP%\python-installer.exe'; Invoke-WebRequest -Uri $url -OutFile $output; if (Test-Path $output) {Write-Host 'ダウンロード完了'} else {Write-Host 'ダウンロード失敗'; exit 1}}"
    
    if %errorlevel% neq 0 (
        echo.
        echo ダウンロードに失敗しました。
        echo 手動でインストールしてください: https://www.python.org/
        pause
        exit /b 1
    )
    
    REM Pythonのインストール実行
    echo.
    echo [2/3] Pythonをインストール中...
    echo インストールが完了するまでお待ちください...
    echo.
    "%TEMP%\python-installer.exe" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    
    REM インストール完了待機
    echo.
    echo [3/3] インストール完了を待っています...
    timeout /t 15 /nobreak >nul
    
    REM 環境変数を再読み込み
    call refreshenv >nul 2>&1
    
    REM 再度チェック
    where python >nul 2>&1
    if %errorlevel% neq 0 (
        echo.
        echo Pythonのインストールが完了しませんでした。
        echo PCを再起動してから、もう一度このバッチファイルを実行してください。
        echo.
        echo または、手動でインストールしてください: https://www.python.org/
        echo （インストール時に「Add Python to PATH」にチェックを入れてください）
        pause
        exit /b 1
    )
    
    echo.
    echo ========================================
    echo  Pythonのインストールが完了しました！
    echo ========================================
    echo.
    timeout /t 2 /nobreak >nul
)

echo ========================================
echo  SF6 Battle Analysis - Local Server
echo ========================================
echo.
echo Python バージョン:
python --version
echo.
echo 📡 ローカルサーバーを起動しています...
echo.

REM 親フォルダ(sf6-buckler-export)に移動してサーバー起動
cd /d "%~dp0.."

echo 現在のディレクトリ: %CD%
echo.

REM Node.jsとCSV統合処理のチェック
where node >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%~dp0..\node_modules" (
        echo 📊 CSV統合処理を実行中...
        node src/consolidate_csv.js >nul 2>&1
        if %errorlevel% equ 0 (
            echo ✓ CSV統合完了
        ) else (
            echo ⚠ CSV統合でエラーが発生しましたが続行します
        )
    ) else (
        echo ⚠ node_modulesが見つかりません。CSV統合をスキップします
        echo   （export.batを一度実行すると自動でインストールされます）
    )
) else (
    echo ⚠ Node.jsが見つかりません。CSV統合をスキップします
    echo   （export.batを一度実行するとNode.jsの依存関係が解決されます）
)
echo.

echo 🌐 ブラウザを自動的に開きます...
echo    http://localhost:8000/analysis/analysis_report_dynamic.html
echo.

REM サーバーをバックグラウンドで起動
start /B python -m http.server 8000

REM サーバーが起動するまで少し待機
timeout /t 2 /nobreak >nul

REM デフォルトブラウザで開く
start http://localhost:8000/analysis/analysis_report_dynamic.html

echo.
echo ✅ ブラウザが開きました！
echo.
echo 💡 サーバーを停止するには Ctrl+C を押してください
echo.
echo ----------------------------------------
echo.

REM フォアグラウンドに戻す（Ctrl+Cで停止できるように）
python -m http.server 8000
