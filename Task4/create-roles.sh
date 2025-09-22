#!/usr/bin/env bash
set -euo pipefail

# Орг-структура → namespaces
NAMESPACES=(sales utilities finance data)

# Создаём ns (идемпотентно)
for ns in "${NAMESPACES[@]}"; do
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns"
done

# ---- ClusterRoles ----
cat <<'EOF' | kubectl apply -f -
# ClusterRole: только просмотр (агрегация к стандартной "view")
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
aggregationRule:
  clusterRoleSelectors:
    - matchLabels:
        rbac.authorization.k8s.io/aggregate-to-view: "true"
rules: []
---
# ClusterRole: настройка кластера без секретов/RBAC
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-config
rules:
  - apiGroups: [""]
    resources: [namespaces, nodes, pods, services, endpoints, events, configmaps, persistentvolumeclaims, persistentvolumes]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["apps"]
    resources: [deployments, statefulsets, daemonsets, replicasets]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["batch"]
    resources: [jobs, cronjobs]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["networking.k8s.io"]
    resources: [ingresses, networkpolicies]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["autoscaling"]
    resources: [horizontalpodautoscalers]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["storage.k8s.io"]
    resources: [storageclasses]
    verbs: [get, list, watch]
EOF

# ---- Namespaced Roles (для каждого ns) ----
for NS in "${NAMESPACES[@]}"; do
  cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ns-admin
  namespace: ${NS}
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ns-edit-no-secrets
  namespace: ${NS}
rules:
  - apiGroups: [""]
    resources: [pods, services, endpoints, events, configmaps, persistentvolumeclaims]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["apps"]
    resources: [deployments, statefulsets, daemonsets, replicasets]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["batch"]
    resources: [jobs, cronjobs]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["networking.k8s.io"]
    resources: [ingresses, networkpolicies]
    verbs: [get, list, watch, create, update, patch, delete]
  # Нет доступа к secrets и к RBAC объектам
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ns-view
  namespace: ${NS}
rules:
  - apiGroups: [""]
    resources: [pods, services, endpoints, events, configmaps]
    verbs: [get, list, watch]
  - apiGroups: ["apps"]
    resources: [deployments, statefulsets, daemonsets, replicasets]
    verbs: [get, list, watch]
  - apiGroups: ["batch"]
    resources: [jobs, cronjobs]
    verbs: [get, list, watch]
  - apiGroups: ["networking.k8s.io"]
    resources: [ingresses, networkpolicies]
    verbs: [get, list, watch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secrets-reader
  namespace: ${NS}
rules:
  - apiGroups: [""]
    resources: [secrets]
    verbs: [get, list, watch]
EOF
done

echo "✅ ClusterRoles и Role по ns созданы."
