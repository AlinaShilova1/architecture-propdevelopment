#!/usr/bin/env bash
set -euo pipefail

# 1) Проверка, что docker-демон поднялся (DinD)
until docker info >/dev/null 2>&1; do
  echo "⏳ waiting for Docker daemon..."
  sleep 2
done

# 2) Чистый профиль Minikube и старт
MINIKUBE_PROFILE="empty"
minikube delete -p "$MINIKUBE_PROFILE" >/dev/null 2>&1 || true
minikube start -p "$MINIKUBE_PROFILE" --driver=docker --wait=false

# 3) Удобные алиасы
{
  echo "alias k=kubectl"
  echo "complete -F __start_kubectl k"
} >> ~/.bashrc

echo "✅ Minikube and kubectl are ready."