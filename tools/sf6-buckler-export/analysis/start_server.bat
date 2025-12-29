@echo off
chcp 65001 >nul
echo ========================================
echo  SF6 Battle Analysis - Local Server
echo ========================================
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
