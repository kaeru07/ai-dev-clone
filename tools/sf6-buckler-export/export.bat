@echo off
cd /d "%~dp0"
chcp 65001 > nul
echo ===============================
echo Buckler BattleLog -> CSV
echo ===============================
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
