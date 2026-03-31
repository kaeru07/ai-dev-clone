@echo off
chcp 932 >nul
cls

echo ========================================
echo  SF6 Battle Analysis - Local Server
echo ========================================
echo.

REM Pythonチェック
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo エラー: Pythonが見つかりません
    echo https://www.python.org/ からインストールしてください
    pause
    exit /b 1
)
echo Pythonバージョン:
python --version
echo.

REM ディレクトリ移動
cd /d "%~dp0.."
echo 現在のディレクトリ: %CD%
echo.

REM Node.jsとCSV統合処理
where node >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%~dp0..\node_modules" (
        if exist "%~dp0..\src\consolidate_csv.js" (
            echo CSV統合処理を実行中...
            chcp 65001 >nul
            node src\consolidate_csv.js
            chcp 932 >nul
            echo CSV統合が完了しました
        )
    ) else (
        echo 注意: node_modulesが見つかりません（オプション）
        echo export.batを実行すると依存関係がインストールされます
    )
) else (
    echo 注意: Node.jsが見つかりません（オプション、サーバーは起動します）
)
echo.

REM ポート8000チェック
netstat -ano | findstr :8000 | findstr LISTENING >nul 2>&1
if %errorlevel% equ 0 (
    echo ポート8000の既存プロセスを終了中...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do (
        taskkill /F /PID %%a >nul 2>&1
    )
    timeout /t 1 /nobreak >nul
)

echo HTTPサーバーを起動中...
echo URL: http://localhost:8000/analysis/analysis_report_dynamic.html
echo.
echo サーバーを停止するには Ctrl+C を押してください
echo ========================================
echo.

if defined CHROME (
    REM Chrome で直接起動
    start "" "%CHROME%" "http://localhost:8000/analysis/analysis_report_dynamic.html"
) else (
    REM Chrome がなければ iexplore.exe で起動
    start "" "iexplore.exe" "http://localhost:8000/analysis/analysis_report_dynamic.html"
)

python -m http.server 8000
echo.
echo サーバーが停止しました。
exit /b 0
