# YAML 程式碼解說

---

## deployment.yaml

這個檔案包含**兩個 K8s 資源**，用 `---` 分隔。

---

### 第一部分：ConfigMap（第 1–29 行）

```yaml
apiVersion: v1
kind: ConfigMap          # 資源類型：用來儲存設定資料
metadata:
  name: nginx-html       # 這個 ConfigMap 的名稱，之後 Deployment 會用此名稱引用它
  namespace: default     # 放在預設的命名空間（Namespace）
data:
  index.html: |          # 定義一個 key 叫 index.html，值是下方的 HTML 內容
    <!DOCTYPE html>
    ...                  # 完整的網頁 HTML + CSS
```

**作用**：把靜態網頁的 HTML 程式碼「存進 K8s」，讓後面的 Nginx 容器可以取用，不需要另外打包自己的 Docker Image（映像檔）。

---

### 第二部分：Deployment（第 31–59 行）

```yaml
apiVersion: apps/v1
kind: Deployment         # 資源類型：負責管理 Pod 的部署與維運
metadata:
  name: nginx-deployment
  namespace: default
  labels:
    app: nginx           # 標籤（Label），用來識別這組資源屬於 nginx 應用

spec:
  replicas: 1            # 要維持幾個 Pod 同時運行，這裡是 1 個
  selector:
    matchLabels:
      app: nginx         # 這個 Deployment 管理「有 app:nginx 標籤」的 Pod

  template:              # 以下定義每個 Pod 的內容
    metadata:
      labels:
        app: nginx       # Pod 貼上 app:nginx 標籤（要與 selector 一致）
    spec:
      containers:
      - name: nginx
        image: nginx:latest      # 從 Docker Hub 下載官方 Nginx 映像（最新版）
        ports:
        - containerPort: 80     # 容器開放 80 port（HTTP 預設 port）

        volumeMounts:
        - name: html-content
          mountPath: /usr/share/nginx/html  # 把 HTML 掛進這個路徑（Nginx 預設網頁目錄）

      volumes:
      - name: html-content
        configMap:
          name: nginx-html      # 資料來源：上面定義的 ConfigMap
```

**重點邏輯**：ConfigMap 裡的 HTML → 透過 Volume 掛載 → 進入 Nginx 的網頁目錄 → 訪客看到網頁。

---

## service.yaml

```yaml
apiVersion: v1
kind: Service            # 資源類型：對外暴露 Pod 的網路入口
metadata:
  name: nginx-service
  namespace: default
  labels:
    app: nginx

spec:
  selector:
    app: nginx           # 把流量轉發給有 app:nginx 標籤的 Pod（對應到 Deployment 的 Pod）

  type: NodePort         # Service 類型：透過節點 IP + Port 讓外部可以存取
  ports:
  - protocol: TCP
    port: 80             # Service 在叢集內部監聽的 Port
    targetPort: 80       # 轉發到 Pod 的哪個 Port（Nginx 監聽 80）
    nodePort: 30080      # 對外開放的 Port，從瀏覽器用這個 Port 連入
```

**流量路徑**：

```
瀏覽器輸入 http://<Minikube IP>:30080
        ↓
    Service（NodePort 30080）
        ↓
    Pod（Nginx，port 80）
        ↓
    顯示 ConfigMap 裡的 HTML 網頁
```

---

## 兩個檔案的關係總結

| 檔案 | 職責 |
|------|------|
| `deployment.yaml` | 定義「要跑什麼」：Nginx 容器 + HTML 內容 |
| `service.yaml` | 定義「如何從外部連進去」：NodePort 30080 |

---

## 重要名詞說明

| 名詞 | 說明 |
|------|------|
| **ConfigMap** | K8s 用來儲存非機密設定資料（如 HTML、設定檔）的物件，讓設定與程式碼分離 |
| **Deployment** | 管理 Pod 生命週期的控制器，確保指定數量的 Pod 持續運行，Pod 掛掉會自動重建 |
| **Pod** | K8s 最小部署單位，內含一個或多個容器，共享網路與儲存空間 |
| **Service** | 為 Pod 提供固定的網路存取入口，即使 Pod 重啟 IP 改變，Service 位址不變 |
| **NodePort** | Service 的一種類型，將服務對外暴露到節點的指定 Port（範圍 30000–32767） |
| **replicas** | 副本數量，告訴 K8s 要同時維持幾個相同的 Pod 在運行 |
| **selector / matchLabels** | 用標籤篩選機制，讓 Deployment 或 Service 知道要管理/轉發給哪些 Pod |
| **volumeMounts / volumes** | 將外部資料（如 ConfigMap）掛載進容器的指定目錄，讓容器可以讀取 |
| **image: nginx:latest** | 指定容器要使用的 Docker 映像，`nginx:latest` 表示從 Docker Hub 拉取官方 Nginx 最新版 |
| **containerPort: 80** | 宣告容器內部開放的 Port，80 是 HTTP 的標準 Port |
| **namespace: default** | 命名空間，用來隔離不同環境的資源，`default` 是 K8s 預設的命名空間 |
