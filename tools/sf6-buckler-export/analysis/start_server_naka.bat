@echo off
chcp 65001 >nul

echo ========================================
echo  SF6 Battle Analysis - Local Server
echo ========================================
echo.

REM Pythonの存在確認
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo エラー: Python が見つかりません
    echo.
    echo 対応方法:
    echo   1. https://www.python.org からPython 3.x をダウンロード
    echo   2. インストール時に「Add Python to PATH」にチェック
    echo   3. PCを再起動
    echo   4. このファイルを再実行
    echo.
    pause
    exit /b 1
)

echo Python バージョン:
python --version
echo.
echo 📡 ローカルサーバーを起動しています...
echo.

REM 親フォルダ(sf6-buckler-export)に移動してサーバー起動
cd /d "%~dp0.."

echo 現在のディレクトリ: %CD%
echo.

echo 🌐 ブラウザを自動的に開きます...
echo    http://localhost:8000/analysis/analysis_report_dynamic.html
echo.
echo サーバーを起動中...
echo Ctrl+C で停止できます
echo.

REM Chrome がインストールされているか確認
for /f "tokens=*" %%i in ('where chrome.exe 2^>nul') do set CHROME=%%i

if defined CHROME (
    REM Chrome で直接起動
    start "" "%CHROME%" "http://localhost:8000/analysis/analysis_report_dynamic.html"
) else (
    REM Chrome がなければ iexplore.exe で起動
    start "" "iexplore.exe" "http://localhost:8000/analysis/analysis_report_dynamic.html"
)

REM サーバー起動
python -m http.server 8000

