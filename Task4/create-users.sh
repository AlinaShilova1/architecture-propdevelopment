#!/usr/bin/env bash
set -euo pipefail

# Пользователь -> группа (RBAC в k8s опирается на "O=" из сертификата)
declare -A USER_GROUPS=(
  [alice]=platform-admins
  [bob]=readers
  [charlie]=sales-dev
  [diana]=finance-admins
  [eve]=security-team
)

# Папка для ключей/сертов
OUTDIR="./k8s-users"
mkdir -p "$OUTDIR"

CURRENT_CTX="$(kubectl config current-context)"
CLUSTER_NAME="$(kubectl config view -o jsonpath='{.contexts[?(@.name=="'"$CURRENT_CTX"'")].context.cluster}')"
SERVER_URL="$(kubectl config view -o jsonpath='{.clusters[?(@.name=="'"$CLUSTER_NAME"'")].cluster.server}')"

for USER in "${!USER_GROUPS[@]}"; do
  GROUP="${USER_GROUPS[$USER]}"
  WORKDIR="${OUTDIR}/${USER}"
  mkdir -p "$WORKDIR"
  pushd "$WORKDIR" >/dev/null

  # 1) ключ и CSR
  openssl genrsa -out "${USER}.key" 2048
  openssl req -new -key "${USER}.key" -out "${USER}.csr" -subj "/CN=${USER}/O=${GROUP}"

  # 2) CSR объект в Kubernetes
  CSR_NAME="csr-${USER}"
  cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${CSR_NAME}
spec:
  request: $(base64 < ${USER}.csr | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
EOF

  # 3) Одобряем и получаем сертификат
  kubectl certificate approve "${CSR_NAME}"
  kubectl get csr "${CSR_NAME}" -o jsonpath='{.status.certificate}' | base64 -d > "${USER}.crt"

  # 4) Добавляем креды/контекст
  kubectl config set-credentials "${USER}" \
    --client-certificate="$(pwd)/${USER}.crt" \
    --client-key="$(pwd)/${USER}.key" >/dev/null

  kubectl config set-context "${USER}@${CLUSTER_NAME}" \
    --cluster="${CLUSTER_NAME}" --user="${USER}" >/dev/null

  echo "✅ Пользователь ${USER} (группа ${GROUP}) создан. Контекст: ${USER}@${CLUSTER_NAME}"
  popd >/dev/null
done
