#!/usr/bin/env bash
set -euo pipefail

NAMESPACES=(sales utilities finance data)

# --- Cluster-level bindings ---
kubectl create clusterrolebinding crb-cluster-admins \
  --clusterrole=cluster-admin \
  --group=cluster-admins \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create clusterrolebinding crb-platform-admins \
  --clusterrole=platform-config \
  --group=platform-admins \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create clusterrolebinding crb-readers \
  --clusterrole=cluster-viewer \
  --group=readers \
  --dry-run=client -o yaml | kubectl apply -f -

# --- Namespaced bindings per org namespace ---
declare -A ADMIN_GROUPS=(
  [sales]=sales-admins
  [utilities]=utilities-admins
  [finance]=finance-admins
  [data]=data-admins
)
declare -A DEV_GROUPS=(
  [sales]=sales-dev
  [utilities]=utilities-dev
  [finance]=finance-dev
  [data]=data-dev
)
declare -A RO_GROUPS=(
  [sales]=sales-ro
  [utilities]=utilities-ro
  [finance]=finance-ro
  [data]=data-ro
)

for NS in "${NAMESPACES[@]}"; do
  kubectl create rolebinding "rb-${NS}-admins" -n "${NS}" \
    --role=ns-admin \
    --group="${ADMIN_GROUPS[$NS]}" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl create rolebinding "rb-${NS}-dev" -n "${NS}" \
    --role=ns-edit-no-secrets \
    --group="${DEV_GROUPS[$NS]}" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl create rolebinding "rb-${NS}-ro" -n "${NS}" \
    --role=ns-view \
    --group="${RO_GROUPS[$NS]}" \
    --dry-run=client -o yaml | kubectl apply -f -
done

# Точечный доступ к секретам (пример: finance)
kubectl create rolebinding rb-finance-secrets-security -n finance \
  --role=secrets-reader \
  --group=security-team \
  --dry-run=client -o yaml | kubectl apply -f -

# (опционально) для SRE:
# kubectl create rolebinding rb-finance-secrets-sre -n finance \
#   --role=secrets-reader \
#   --group=sre \
#   --dry-run=client -o yaml | kubectl apply -f -

echo "✅ ClusterRoleBinding/RoleBinding созданы."
