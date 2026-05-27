# Kubernetes / Minikube 技術說明與作業解析

---

## 一、核心技術介紹

### 1. 容器（Container）
容器是一種輕量級的虛擬化技術，將應用程式與其執行環境（程式碼、函式庫、設定檔）打包在一起。
- 最常見的容器技術是 **Docker**（目前業界最主流的容器化工具，由 Docker Inc. 於 2013 年開源）
- 容器底層執行引擎稱為 **Container Runtime**，常見的有 **Containerd**（CNCF 畢業專案，K8s 1.24+ 預設）、CRI-O、runc 等
- 與虛擬機（VM，Virtual Machine，在實體硬體上模擬出完整電腦系統的軟體）不同，容器共用主機的作業系統核心（OS Kernel，負責管理硬體資源的底層程式），啟動速度更快、資源佔用更少
- 同一個容器映像（Image，打包好的唯讀應用程式模板，類似程式的「安裝光碟」）可以在任何環境執行，解決「在我電腦上可以跑」的問題

#### Docker vs Containerd 的關係
- **Docker** 是完整的開發者工具集（CLI + daemon + build + registry client），面向「使用者」
- **Containerd** 是 Docker 抽離出來的底層執行引擎，只負責「執行容器」，面向「系統」
- K8s 1.24 之前透過 dockershim 呼叫 Docker，1.24 起 dockershim 被移除，直接透過 CRI（Container Runtime Interface）呼叫 Containerd
- 結論：開發階段用 Docker 建構映像很方便；正式叢集底層多半是 Containerd 在跑容器

```
本機開發：  docker build → docker push
                              ↓
叢集執行：  kubelet → CRI → containerd → runc → 容器
```

**容器 vs 虛擬機比較：**

| 比較項目 | 容器（Container） | 虛擬機（VM） |
|---------|-----------------|------------|
| 啟動速度 | 秒級（1–3 秒） | 分鐘級 |
| 資源佔用 | 輕量（MB 等級） | 較重（GB 等級） |
| 隔離層級 | 共用 OS Kernel | 各自有獨立 OS |
| 可攜性 | 高，任何有 Docker 的環境皆可執行 | 較低，需搭配對應虛擬化平台 |
| 適合場景 | 微服務、快速部署 | 需要完整 OS 隔離的場景 |

**容器的生命週期：**
1. **撰寫 Dockerfile**（定義如何打包應用程式）
2. **Build Image**（docker build，產生唯讀映像檔）
3. **Push to Registry**（上傳至 Docker Hub / GitLab Container Registry 等映像倉庫）
4. **Pull & Run**（下載並執行，成為一個運行中的容器）

> 本專案完整執行步驟 1–4：自行撰寫 `Dockerfile` 把靜態 HTML 打包進 Nginx 映像，由 K8s 從本地或 GitLab Registry 拉取執行。

### 2. Kubernetes（K8s）
Kubernetes 是 Google 開源的**容器編排平台**，用來自動化部署、擴展和管理容器化應用程式。

**為什麼需要 Kubernetes？**
- 當服務從一個容器變成數十、數百個容器時，人工管理變得不可行
- K8s 自動處理：容器的啟動/重啟、負載平衡、滾動更新、故障恢復

**K8s 核心概念：**

| 概念 | 說明 |
|------|------|
| **Pod** | K8s 最小部署單位，一個 Pod 內含一個或多個容器 |
| **Deployment** | 管理 Pod 的部署策略，負責維持指定數量的 Pod 運行 |
| **Service** | 將 Pod 對外暴露為網路服務，提供固定的存取入口 |
| **ConfigMap** | 儲存設定資料（如設定檔、靜態檔案），與容器程式碼分離 |
| **Namespace** | 用來隔離不同環境或團隊的資源（如 dev、staging、prod） |

**K8s 架構：**
```
使用者/瀏覽器
     ↓
  Service（對外入口）
     ↓
  Pod（執行 Nginx 容器）
     ↓
  Deployment（管理 Pod 數量與版本）
```

### 3. Minikube
Minikube 是在本機（單台電腦）上執行 Kubernetes 叢集的工具，專為開發與測試設計。
- 正式環境的 K8s 叢集通常有多台機器（Master + Worker Nodes）
- Minikube 將整個叢集壓縮到一台機器內，方便本機開發測試
- 需要 Docker 或 VirtualBox 作為底層虛擬化支援

本專案啟動指令：
```powershell
minikube start --driver=docker --container-runtime=containerd
```
- `--driver=docker`：用 Docker Desktop 作為 VM 替代方案，建立一個 Linux 容器當作 K8s Node
- `--container-runtime=containerd`：指定 Node 內的 container runtime 為 Containerd，貼近正式叢集環境

### 4. kubectl
kubectl 是 Kubernetes 的命令列工具（CLI），用來與 K8s 叢集溝通。
```bash
kubectl apply -f deployment.yaml    # 套用設定
kubectl get pods                    # 查看 Pod 狀態
kubectl get services                # 查看 Service 狀態
kubectl logs <pod-name>             # 查看 Pod 日誌
kubectl describe pod <pod-name>     # 查看 Pod 詳細資訊
```

### 5. Nginx
Nginx 是高效能的開源網頁伺服器，常用於：
- 提供靜態網頁（HTML、CSS、JS）
- 反向代理（Reverse Proxy）
- 負載平衡（Load Balancer）

本作業使用 Nginx 來提供靜態 HTML 網頁。

---

## 二、YAML 檔案介紹

Kubernetes 的所有資源設定都使用 **YAML 格式**撰寫，語法規則：
- 用縮排（空格）表示層級關係
- `key: value` 格式表示屬性
- `-` 開頭表示清單項目

---

## 三、Dockerfile 解析

```dockerfile
# syntax=docker/dockerfile:1
FROM nginx:1.27-alpine          # 基底映像：輕量 Alpine 版 Nginx（~50MB）

LABEL maintainer="Jason Chou <jasonchou.aj@gmail.com>"
LABEL description="Static website served by Nginx, deployed on Kubernetes"
LABEL version="1.0.0"

RUN rm -rf /usr/share/nginx/html/*           # 移除預設歡迎頁
COPY html/ /usr/share/nginx/html/            # 把本機 html/ 打包進映像

EXPOSE 80                                     # 宣告對外 port

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]            # 容器啟動指令
```

**建構與執行：**
```bash
# 1. build（在 Dockerfile 所在目錄）
docker build -t syswatch-nginx:1.0.0 .

# 2. 本機驗證
docker run --rm -p 8080:80 syswatch-nginx:1.0.0
# 開 http://localhost:8080 看效果

# 3. 推到 GitLab Container Registry
docker tag syswatch-nginx:1.0.0 registry.gitlab.com/<group>/<project>:1.0.0
docker login registry.gitlab.com
docker push registry.gitlab.com/<group>/<project>:1.0.0
```

> Minikube 開發模式：可用 `minikube image build -t syswatch-nginx:1.0.0 .` 把映像直接 build 進叢集，省去 push 步驟。

---

## 四、deployment.yaml 解析

```yaml
apiVersion: apps/v1               # Deployment 使用 apps/v1 API
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: default
  labels:
    app: nginx
spec:
  replicas: 1                     # Pod 數量：1（可水平擴展）
  selector:
    matchLabels:
      app: nginx                  # 選取有此標籤的 Pod 來管理
  template:
    metadata:
      labels:
        app: nginx                # Pod 標籤（須與 selector 一致）
    spec:
      containers:
      - name: nginx
        image: syswatch-nginx:1.0.0   # 使用自訂映像（由 Dockerfile 建構）
        imagePullPolicy: IfNotPresent # 本地有就不拉，正式環境會改 Always
        ports:
        - containerPort: 80
        resources:                # 資源請求/上限（K8s 排程依據）
          requests:
            cpu: "50m"            # 0.05 CPU core
            memory: "32Mi"
          limits:
            cpu: "200m"
            memory: "128Mi"
        livenessProbe:            # 存活探針：失敗會重啟 Pod
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:           # 就緒探針：未通過不會被 Service 導流
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
```

**和舊版（ConfigMap 掛載 HTML）的差異：**

| 項目 | 舊版（ConfigMap） | 現版（自訂映像） |
|------|-----------------|----------------|
| HTML 來源 | ConfigMap volumeMount | COPY 進映像 |
| 修改網頁 | 改 ConfigMap → kubectl apply | 改 html/ → docker build → 重新 deploy |
| 映像版本控管 | 無（共用 nginx:latest） | 有（image tag 對應 git commit） |
| 與 CI/CD 結合 | 弱 | 強（pipeline 自動 build → push → deploy） |
| 適用場景 | 純配置調整 | 真實應用程式 |

**新增的最佳實踐：**
- `resources` → 防止單一 Pod 吃光節點資源、配合 HPA 自動擴縮
- `livenessProbe` / `readinessProbe` → 自我修復 + 流量管控的核心機制
- 固定 image tag（不用 `:latest`）→ 確保 Pod 重啟拿到的是同一份映像

---

## 五、service.yaml 解析

```yaml
apiVersion: v1
kind: Service           # 資源類型：Service
metadata:
  name: nginx-service
  namespace: default
  labels:
    app: nginx
spec:
  selector:
    app: nginx          # 將流量導向有 app: nginx 標籤的 Pod
  type: NodePort        # Service 類型：對外暴露到節點（Node）的 Port
  ports:
  - protocol: TCP
    port: 80            # Service 本身的 Port（K8s 叢集內部使用）
    targetPort: 80      # 轉發到 Pod 的 80 Port（Nginx 監聽的 Port）
    nodePort: 30080     # 對外暴露的 Port（透過此 Port 從外部存取）
```

**Service 類型比較：**

| 類型 | 說明 | 使用場景 |
|------|------|---------|
| ClusterIP | 僅叢集內部可存取（預設） | 微服務間通訊 |
| **NodePort** | 透過節點 IP + Port 從外部存取 | 本機開發測試（本作業使用） |
| LoadBalancer | 建立雲端負載平衡器 | 正式雲端環境（AWS/GCP/Azure） |

**流量路徑：**
```
瀏覽器 → <minikube IP>:30080 → Service:80 → Pod:80（Nginx）→ 顯示 HTML
```

---

## 五-2、hpa.yaml 解析（自動擴縮）

```yaml
apiVersion: autoscaling/v2          # v2 為 stable，支援多指標
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-hpa
spec:
  scaleTargetRef:                   # 鎖定要擴縮的對象
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deployment
  minReplicas: 2                    # 下限：永遠至少 2 個 Pod
  maxReplicas: 10                   # 上限：避免吃光資源
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50      # 目標 CPU 50%（相對 requests）
  behavior:                         # 擴縮速度調校（避免抖動）
    scaleUp:
      stabilizationWindowSeconds: 30
      policies: [{ type: Percent, value: 100, periodSeconds: 60 }]
    scaleDown:
      stabilizationWindowSeconds: 300
      policies: [{ type: Percent, value: 50, periodSeconds: 60 }]
```

**關鍵概念：**
- HPA 透過 **metrics-server** 取得 Pod 的 CPU/記憶體用量（Minikube 需 `minikube addons enable metrics-server`）
- CPU `Utilization` 是相對 `resources.requests.cpu` 的百分比，**沒設 requests 的 Pod，HPA 算出來的值是錯的**
- `behavior` 段控制擴縮反應速度：
  - 擴展積極（30s 觀察 + 每分鐘最多翻倍）→ 突發流量時快速應對
  - 收縮保守（5min 觀察 + 每分鐘最多砍半）→ 避免抖動把剛起來的 Pod 又收掉

**壓測示範：**
```bash
# 製造 CPU 壓力
kubectl run -it --rm load-gen --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://nginx-service; done"

# 另一視窗持續觀察
kubectl get hpa nginx-hpa --watch
# 預期看到 REPLICAS 從 3 → 6 → 10
```

---

## 六、作業完整執行流程

```bash
# Step 1：啟動 Minikube 環境（指定 Containerd 為 runtime）
minikube start --driver=docker --container-runtime=containerd

# Step 2：確認叢集狀態
minikube status
kubectl get nodes

# Step 3：建構自訂 Nginx 映像（HTML 打包進去）
minikube image build -t syswatch-nginx:1.0.0 .
# 等同於：docker build -t syswatch-nginx:1.0.0 .
# 用 minikube image build 可省去 push registry，映像直接放進叢集 image store

# Step 4：套用 deployment.yaml（建立 Deployment）
kubectl apply -f deployment.yaml

# Step 5：套用 service.yaml（建立 Service）
kubectl apply -f service.yaml

# Step 6：確認 Pod 是否正常運行
kubectl get pods
# 預期輸出：
# NAME                                READY   STATUS    RESTARTS   AGE
# nginx-deployment-xxxxxxxxx-xxxxx    1/1     Running   0          30s

# Step 7：確認 Service 是否建立
kubectl get services
# 預期輸出：
# NAME            TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
# nginx-service   NodePort   10.x.x.x       <none>        80:30080/TCP   30s

# Step 8：取得網址並開啟瀏覽器
minikube service nginx-service --url
# 輸出類似：http://192.168.49.2:30080
```

> 上述步驟已由 `deploy.ps1` 自動化，平日只需執行 `.\deploy.ps1`。

---

## 七、技術概念總結

```
┌─────────────────────────────────────────────┐
│              本機電腦（Windows）              │
│                                             │
│  ┌──────────────────────────────────────┐   │
│  │         Minikube（虛擬 K8s 叢集）     │   │
│  │                                      │   │
│  │  ┌────────────┐   ┌───────────────┐  │   │
│  │  │  Service   │   │  ConfigMap    │  │   │
│  │  │ NodePort   │   │ (HTML 內容)   │  │   │
│  │  │ :30080     │   └───────┬───────┘  │   │
│  │  └─────┬──────┘           │ 掛載     │   │
│  │        │ 導流             ↓          │   │
│  │        │         ┌───────────────┐  │   │
│  │        └────────→│  Pod (Nginx)  │  │   │
│  │                  │   port: 80    │  │   │
│  │                  └───────────────┘  │   │
│  │              Deployment 管理上方 Pod │   │
│  └──────────────────────────────────────┘   │
│                                             │
│  瀏覽器 → http://192.168.49.2:30080         │
└─────────────────────────────────────────────┘
```

---

## 八、Git 版本控制

本專案以 Git 進行原始碼版本管理，所有變更可被追蹤、回溯、協作。

**為什麼用 Git？**
- 部署設定（YAML）= 程式碼，必須跟程式碼一樣有版本控管（GitOps 精神）
- 任何 K8s 設定異動可透過 git log 追蹤「誰、何時、為何改了什麼」
- 配合 GitLab/GitHub 進行 Code Review、CI/CD 自動部署

**本專案 Git 結構：**
```
.git/                  # Git 版本資料
.gitignore             # 排除 bin/、*.exe、kubeconfig 等不該入版控的檔案
Dockerfile             # 映像建構腳本
.gitlab-ci.yml         # CI/CD pipeline 定義
deployment.yaml        # K8s Deployment 設定
service.yaml           # K8s Service 設定
html/index.html        # 應用程式內容
```

**常用 Git 指令：**
```bash
git init                       # 初始化本地 repo
git add .                      # 加入所有變更
git commit -m "feat: ..."      # 提交（遵循 Conventional Commits）
git remote add origin <url>    # 連接遠端 GitLab repo
git push -u origin main        # 推送並設定追蹤分支
git log --oneline              # 查看提交歷史
git revert <commit>            # 安全回退某次提交（產生新 commit）
```

**分支策略（建議）：**
```
main          ──── 永遠可部署的穩定版（受 GitLab branch protection 保護）
  ├─ feature/* ──── 新功能開發分支
  └─ hotfix/*  ──── 緊急修補分支
```

---

## 九、GitLab CI/CD Pipeline

`.gitlab-ci.yml` 定義一條 4 階段的自動化 pipeline，每次 push 到 main 分支自動觸發。

```
push main → ① build → ② test → ③ push → ④ deploy
              ↓         ↓        ↓         ↓
           docker     YAML     GitLab    kubectl
           build      lint +   Container set image
                      Trivy    Registry  + rollout
                      scan
```

| Stage | Job | 動作 | 失敗影響 |
|-------|-----|------|---------|
| **build** | build-image | `docker build` 產生映像，artifact 留給後續 stage | 整條 pipeline 中止 |
| **test** | lint-yaml | `kubectl --dry-run=client` 驗證 YAML schema | 中止 |
| **test** | scan-image | Trivy 掃描映像 CVE 漏洞（CRITICAL/HIGH） | allow_failure（不中止但會警示） |
| **push** | push-image | 登入 GitLab Container Registry，推送 `:SHA` 與 `:latest` tag | 中止 |
| **deploy** | deploy-k8s | `kubectl set image` 滾動更新 + `kubectl rollout status` 驗證 | 中止；需手動觸發（`when: manual`）|

**關鍵 GitLab 變數：**
- `$CI_REGISTRY_IMAGE` → 自動帶入 `registry.gitlab.com/<group>/<project>`
- `$CI_COMMIT_SHORT_SHA` → 短 commit hash，當作 image tag（每次 commit 對應唯一映像）
- `$CI_REGISTRY_USER` / `$CI_REGISTRY_PASSWORD` → GitLab 自動注入的 Registry 認證
- `$KUBECONFIG_B64` → 需在 GitLab 專案 Settings → CI/CD → Variables 手動設定（base64 後的 kubeconfig）

**Image tag 策略：**
- `:$CI_COMMIT_SHORT_SHA` → 不可變（immutable），每次 commit 一個唯一映像，便於回退
- `:latest` → 浮動指向最新版，方便本機 pull 但不應用於正式部署

**為什麼 deploy 設成 manual？**
- 自動部署到 production 風險高，常見實務是「自動部到 staging、手動點按鈕部到 production」
- 透過 `environment: production` 在 GitLab UI 留下部署歷史，配合 `kubectl rollout undo` 可一鍵回退

---

## 十、常見面試問題補充

**Q: K8s 與 Docker 的差別？**
A: Docker 負責「建立和執行單一容器」，K8s 負責「管理大量容器的部署、擴展和維運」。兩者互補，K8s 底層通常使用 Docker 執行容器。

**Q: 為什麼用 ConfigMap 儲存 HTML？**
A: 遵循 K8s 最佳實踐——設定與程式碼分離。不需要自建 Docker 映像，修改網頁內容只需更新 ConfigMap，不需要重新打包映像。

**Q: NodePort 的 Port 範圍？**
A: K8s 預設 NodePort 範圍是 30000–32767，本作業使用 30080。

**Q: 如何水平擴展（Scale）？**
A: 修改 `replicas` 數量，或使用指令：
```bash
kubectl scale deployment nginx-deployment --replicas=3
```

**Q: 如果 Pod 掛掉會怎樣？**
A: Deployment 的 Controller 會偵測到 Pod 數量不足，自動建立新的 Pod 來補足，達到自我修復（Self-healing）的效果。

**Q: Docker 和 Containerd 差別？K8s 為什麼從 Docker 改用 Containerd？**
A: Docker 是完整工具集（CLI + daemon + build），Containerd 是其抽出的底層 runtime。K8s 1.24 起移除 dockershim，因為它是 K8s 為相容 Docker 額外維護的轉接層，維護成本高、效能多一層 overhead；直接透過 CRI 呼叫 Containerd 更輕量、更貼近 OCI 標準。

**Q: 為什麼要把 HTML 打包進映像，而不是用 ConfigMap？**
A: ConfigMap 適合「設定」（檔案 < 1MB、文字為主），應用程式內容應隨映像版本一起變動，才能配合 image tag 做精準的版本控管與回退。若 HTML 改動後忘了 apply ConfigMap，會出現「映像版本一致但內容不一致」的情況，破壞可重現性。

**Q: 為什麼 image tag 不該用 :latest？**
A: `:latest` 是浮動標籤，Pod 重啟可能拉到不同版本，違反不可變基礎設施（Immutable Infrastructure）原則。固定 tag（如 commit SHA）才能確保「同一個 tag 永遠是同一個映像」，便於回退與稽核。

**Q: GitLab CI/CD 中 deploy 階段為什麼設成 manual？**
A: 自動部署到 production 風險高。實務上採「自動部 staging、手動部 production」模式，讓人為審核成為最後防線。若需自動化，可改用 GitOps（如 ArgoCD）監聽 git repo 變化來部署。

**Q: 在 Minikube 怎麼讓 K8s 拉到本地 build 的映像？**
A: 三種方式：(1) `minikube image build` 直接把映像 build 進叢集；(2) `minikube image load <image>` 把本機已 build 的映像載入；(3) 設定 `eval $(minikube docker-env)` 把 docker 指令重導到 Minikube 內 daemon。設定 `imagePullPolicy: IfNotPresent` 避免 K8s 跑去外部 registry 拉。
