@echo off
chcp 932 >nul
cls

echo ========================================
echo  SF6 Battle Analysis - Local Server
echo ========================================
echo.

REM Python�`�F�b�N
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo �G���[: Python��������܂���
    echo https://www.python.org/ ����C���X�g�[�����Ă�������
    pause
    exit /b 1
)
echo Python�o�[�W����:
python --version
echo.

REM �f�B���N�g���ړ�
cd /d "%~dp0.."
echo ���݂̃f�B���N�g��: %CD%
echo.

REM Node.js��CSV��������
where node >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%~dp0..\node_modules" (
        if exist "%~dp0..\src\consolidate_csv.js" (
            echo CSV�������������s��...
            chcp 65001 >nul
            node src\consolidate_csv.js
            chcp 932 >nul
            echo CSV�������������܂���
        )
    ) else (
        echo ����: node_modules��������܂���i�I�v�V�����j
        echo export.bat�����s����ƈˑ��֌W���C���X�g�[������܂�
    )
) else (
    echo ����: Node.js��������܂���i�I�v�V�����A�T�[�o�[�͋N�����܂��j
)
echo.

REM �|�[�g8000�`�F�b�N
netstat -ano | findstr :8000 | findstr LISTENING >nul 2>&1
if %errorlevel% equ 0 (
    echo �|�[�g8000�̊����v���Z�X���I����...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do (
        taskkill /F /PID %%a >nul 2>&1
    )
    timeout /t 1 /nobreak >nul
)

echo HTTP�T�[�o�[���N����...
echo URL: http://localhost:8000/analysis/analysis_report_dynamic.html
echo.
echo �T�[�o�[���~����ɂ� Ctrl+C �������Ă�������
echo ========================================
echo.

if defined CHROME (
    REM Chrome �Œ��ڋN��
    start "" "%CHROME%" "http://localhost:8000/analysis/analysis_report_dynamic.html"
) else (
    REM Chrome ���Ȃ���� iexplore.exe �ŋN��
    start "" "iexplore.exe" "http://localhost:8000/analysis/analysis_report_dynamic.html"
)

python -m http.server 8000
set "SERVER_EXIT=%errorlevel%"

REM Ctrl+C / Ctrl+Break stopped: treat as normal end and close window
if "%SERVER_EXIT%"=="0" exit
if "%SERVER_EXIT%"=="3221225786" exit
if "%SERVER_EXIT%"=="-1073741510" exit

echo.
echo G[: T[o[Nł܂ł
echo G[R[h: %SERVER_EXIT%
pause
exit /b %SERVER_EXIT%
