# SF6 Battle Analysis - Local Server Starter (PowerShell)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " SF6 Battle Analysis - Local Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📡 ローカルサーバーを起動しています..." -ForegroundColor Green
Write-Host ""

# 親フォルダ(sf6-buckler-export)に移動
Set-Location (Join-Path $PSScriptRoot "..")

# ブラウザを自動的に開く
Start-Sleep -Seconds 1
Start-Process "http://localhost:8000/analysis/analysis_report_dynamic.html"

Write-Host "🌐 ブラウザで以下のURLを開きました:" -ForegroundColor Yellow
Write-Host "   http://localhost:8000/analysis/analysis_report_dynamic.html" -ForegroundColor White
Write-Host ""
Write-Host "💡 サーバーを停止するには Ctrl+C を押してください" -ForegroundColor Gray
Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Cyan
Write-Host ""

# Pythonでシンプルなhttpサーバーを起動
python -m http.server 8000
