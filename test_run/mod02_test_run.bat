@echo off
chcp 65001 > nul
echo ====================================
echo Running mod02_test files...
echo ====================================
echo.
set /p confirm="テストを実行しますか? (y/n): "
if /i not "%confirm%"=="y" (
    echo テストをキャンセルしました。
    pause
    exit /b
)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\ai-script\test\mod02_test.ps1"
echo.
echo ------------------------------------
echo.
echo 何かキーを押すと終了します...
pause > nul
