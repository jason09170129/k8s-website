# syntax=docker/dockerfile:1
# ============================================================
# 自訂 Nginx 映像 - 將靜態網頁打包進映像中
# Base image: nginx:1.27-alpine（輕量化 Alpine Linux 版本，約 50MB）
# ============================================================
FROM nginx:1.27-alpine

LABEL maintainer="Jason Chou <jasonchou.aj@gmail.com>"
LABEL description="Static website served by Nginx, deployed on Kubernetes"
LABEL version="1.0.0"

# 移除預設 Nginx 歡迎頁面
RUN rm -rf /usr/share/nginx/html/*

# 將本機 html/ 目錄下的靜態檔案複製進映像
COPY html/ /usr/share/nginx/html/

# 容器對外暴露 80 port（HTTP）
EXPOSE 80

# Healthcheck：每 30 秒檢查 Nginx 是否回應
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# 預設啟動指令（沿用 nginx 官方 image 的 CMD）
CMD ["nginx", "-g", "daemon off;"]
