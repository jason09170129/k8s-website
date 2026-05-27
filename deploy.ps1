# ============================================================
# K8s 部署腳本（含 Docker 映像建構）
# 流程：檢查 Docker → 啟動 Minikube → build 映像 → apply YAML → 開啟瀏覽器
# ============================================================

$BinDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "bin"
$YamlDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:PATH = "$BinDir;$env:PATH"

$ImageName = "syswatch-nginx"
$ImageTag = "1.0.0"
$ImageFull = "${ImageName}:${ImageTag}"

function Check-Command($cmd) {
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

# 確認 Docker 是否執行中
Write-Host "=== 檢查 Docker 狀態 ===" -ForegroundColor Cyan
$dockerRunning = $false
$attempts = 0
while (-not $dockerRunning -and $attempts -lt 6) {
    try {
        $null = docker info 2>&1
        if ($LASTEXITCODE -eq 0) { $dockerRunning = $true }
    } catch {}
    if (-not $dockerRunning) {
        $attempts++
        Write-Host "等待 Docker 啟動... ($attempts/6)"
        Start-Sleep -Seconds 10
    }
}
if (-not $dockerRunning) {
    Write-Host "Docker 未啟動！請先確認 Docker Desktop 已開啟。" -ForegroundColor Red
    exit 1
}
Write-Host "Docker 已就緒！" -ForegroundColor Green

# 啟動 Minikube（container-runtime 預設為 containerd，更貼近正式環境）
Write-Host "`n=== 啟動 Minikube (container-runtime=containerd) ===" -ForegroundColor Cyan
& "$BinDir\minikube.exe" start --driver=docker --container-runtime=containerd
if ($LASTEXITCODE -ne 0) { Write-Host "Minikube 啟動失敗！" -ForegroundColor Red; exit 1 }

Write-Host "`n=== Minikube 狀態 ===" -ForegroundColor Cyan
& "$BinDir\minikube.exe" status

# 建構自訂 Docker 映像（直接 build 進 Minikube 內的 containerd image store）
Write-Host "`n=== 建構自訂 Nginx 映像 ($ImageFull) ===" -ForegroundColor Cyan
Push-Location $YamlDir
try {
    # 用 minikube image build，讓映像直接進到 Minikube 叢集內部，不需 push 到外部 registry
    & "$BinDir\minikube.exe" image build -t $ImageFull .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker build 失敗！" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

Write-Host "`n=== 確認映像已在 Minikube 內 ===" -ForegroundColor Cyan
& "$BinDir\minikube.exe" image ls | Select-String $ImageName

# 套用 YAML
Write-Host "`n=== 套用 Deployment ===" -ForegroundColor Cyan
& "$BinDir\kubectl.exe" apply -f "$YamlDir\deployment.yaml"

Write-Host "`n=== 套用 Service ===" -ForegroundColor Cyan
& "$BinDir\kubectl.exe" apply -f "$YamlDir\service.yaml"

# 強制重新部署，讓新映像生效（同 tag 重 build 時必要）
Write-Host "`n=== 觸發 Rollout（套用最新映像）===" -ForegroundColor Cyan
& "$BinDir\kubectl.exe" rollout restart deployment/nginx-deployment

# 等待 Pod 就緒
Write-Host "`n=== 等待 Pod 啟動 ===" -ForegroundColor Cyan
& "$BinDir\kubectl.exe" wait --for=condition=ready pod -l app=nginx --timeout=120s

# 顯示狀態
Write-Host "`n=== 部署狀態 ===" -ForegroundColor Cyan
Write-Host "--- Pods ---"
& "$BinDir\kubectl.exe" get pods -o wide
Write-Host "--- Services ---"
& "$BinDir\kubectl.exe" get services

# 開啟瀏覽器
Write-Host "`n=== 開啟瀏覽器 ===" -ForegroundColor Cyan
$url = & "$BinDir\minikube.exe" service nginx-service --url
Write-Host "服務網址: $url" -ForegroundColor Yellow
Start-Process $url

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "部署完成！請截圖瀏覽器畫面（包含網址列）" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
