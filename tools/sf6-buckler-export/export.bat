@echo off
cd /d "%~dp0"
chcp 932 > nul
setlocal enabledelayedexpansion

REM 初回セットアップチェック
set SETUP_COMPLETE_FILE=%~dp0.setup_complete
set IS_FIRST_SETUP=0

if not exist "%SETUP_COMPLETE_FILE%" (
    set IS_FIRST_SETUP=1
    echo ===============================
    echo 初回セットアップを開始します
    echo ===============================
    echo.
    
    echo あなたのBuckler SIDを入力してください。
    echo SIDの確認方法：
    echo 1. Bucklerにログイン: https://www.buckler.gg/login
    echo 2. ブラウザの開発者ツールを開く（F12キー）
    echo 3. Consoleタブで以下のコマンドを実行:
    echo    document.cookie.split^(';'^).find^(c =^> c.trim^(^).startsWith^('SID='^)^).split^('='^)[1]
    echo 4. 表示された数字をコピーしてください
    echo.
    set /p USER_SID="SIDを入力: "
    
    if "!USER_SID!"=="" (
        echo エラー: SIDが入力されていません。
        pause
        exit /b 1
    )
    
    echo.
    echo SIDを設定中...
    powershell -ExecutionPolicy Bypass -File "%~dp0update_sid.ps1" "!USER_SID!" > nul 2>&1
    if errorlevel 1 (
        echo エラー: SIDの設定に失敗しました。
        pause
        exit /b 1
    )
    echo ? SIDの設定が完了しました
    
    REM セットアップ完了マーカーを作成
    echo. > "%SETUP_COMPLETE_FILE%"
    echo  セットアップが完了しました！
    echo.
)

REM node_modulesの確認とインストール
if not exist "%~dp0node_modules" (
    echo node_modulesが見つかりません。
    echo npm installを実行します...
    echo.
    call npm install
    if errorlevel 1 (
        echo.
        echo エラー: npm installに失敗しました。
        echo Node.jsがインストールされているか確認してください。
        pause
        exit /b 1
    )
    echo.
    echo  パッケージのインストールが完了しました！
    echo.
)

REM メインスクリプトの実行
if !IS_FIRST_SETUP! EQU 1 (
    echo 全ての設定が完了しました。
    echo 次回からは自動的にスクリプトが起動します。
    echo.
)

echo スクリプトを起動しています...
pause
echo.

node src/export_buckler_auto.js
pause