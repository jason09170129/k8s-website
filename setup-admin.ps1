# ============================================================
# 國泰 K8s 面試題 - 環境安裝與部署腳本 (需以系統管理員身份執行)
# ============================================================

$ErrorActionPreference = "Stop"
$BinDir = "C:\Users\jason\Desktop\國泰\bin"
$YamlDir = "C:\Users\jason\Desktop\國泰"

Write-Host "=== Step 1: 安裝 Docker Desktop ===" -ForegroundColor Cyan
winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
Write-Host "Docker Desktop 安裝完成，請確認 Docker Desktop 已啟動後按 Enter 繼續..."
Read-Host

Write-Host "=== Step 2: 安裝 minikube 與 kubectl ===" -ForegroundColor Cyan
$env:PATH = "$BinDir;$env:PATH"

# 驗證工具存在
if (-not (Test-Path "$BinDir\minikube.exe")) {
    Write-Host "minikube.exe 不存在，重新下載..."
    Invoke-WebRequest -Uri "https://storage.googleapis.com/minikube/releases/latest/minikube-windows-amd64.exe" -OutFile "$BinDir\minikube.exe"
}
if (-not (Test-Path "$BinDir\kubectl.exe")) {
    Write-Host "kubectl.exe 不存在，重新下載..."
    $ver = (Invoke-WebRequest "https://dl.k8s.io/release/stable.txt" -UseBasicParsing).Content.Trim()
    Invoke-WebRequest -Uri "https://dl.k8s.io/release/$ver/bin/windows/amd64/kubectl.exe" -OutFile "$BinDir\kubectl.exe"
}

Write-Host "minikube 版本: $(& $BinDir\minikube.exe version)"
Write-Host "kubectl 版本: $(& $BinDir\kubectl.exe version --client)"

Write-Host "`n=== Step 3: 啟動 Minikube ===" -ForegroundColor Cyan
& "$BinDir\minikube.exe" start --driver=docker
Write-Host "Minikube 狀態:"
& "$BinDir\minikube.exe" status

Write-Host "`n=== Step 4: 部署 YAML 檔案 ===" -ForegroundColor Cyan
& "$BinDir\kubectl.exe" apply -f "$YamlDir\deployment.yaml"
& "$BinDir\kubectl.exe" apply -f "$YamlDir\service.yaml"

Write-Host "`n等待 Pod 啟動..."
& "$BinDir\kubectl.exe" wait --for=condition=ready pod -l app=nginx --timeout=120s

Write-Host "`n=== Step 5: 查看部署狀態 ===" -ForegroundColor Cyan
& "$BinDir\kubectl.exe" get pods
& "$BinDir\kubectl.exe" get services

Write-Host "`n=== Step 6: 開啟瀏覽器 ===" -ForegroundColor Cyan
$url = & "$BinDir\minikube.exe" service nginx-service --url
Write-Host "服務網址: $url"
Start-Process $url

Write-Host "`n=== 部署完成！請截圖瀏覽器畫面（包含網址列）===" -ForegroundColor Green
