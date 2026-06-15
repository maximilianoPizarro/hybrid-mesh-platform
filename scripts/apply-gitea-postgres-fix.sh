#!/usr/bin/env bash
# Fix Gitea PostgreSQL HA PVC ownership on OpenShift (restricted SCC / fsGroup).
set -euo pipefail

NS="${GITEA_NS:-gitea}"
PG_UID="${GITEA_PG_UID:-1000910000}"
REPLICAS="${GITEA_PG_REPLICAS:-1}"

echo "== Gitea PostgreSQL PVC fix (ns=$NS replicas=$REPLICAS uid=$PG_UID) =="

if ! oc whoami &>/dev/null; then
  echo "ERROR: log in to hub" >&2
  exit 1
fi

oc delete job gitea-postgres-fix-perms-manual -n "$NS" --ignore-not-found 2>/dev/null || true

echo "Scale postgres STS to 0 before PVC chown (avoid SELinux volume conflict)"
oc scale sts gitea-postgresql-ha-postgresql -n "$NS" --replicas=0 2>/dev/null || true
oc wait --for=delete pod/gitea-postgresql-ha-postgresql-0 -n "$NS" --timeout=120s 2>/dev/null || sleep 10

for i in $(seq 0 $((REPLICAS - 1))); do
  pvc="data-gitea-postgresql-ha-postgresql-${i}"
  if ! oc get pvc "$pvc" -n "$NS" &>/dev/null; then
    echo "skip missing pvc $pvc"
    continue
  fi
  job="gitea-postgres-fix-${i}"
  oc delete job "$job" -n "$NS" --ignore-not-found 2>/dev/null || true
  cat <<EOF | oc apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${NS}
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      securityContext:
        runAsUser: 0
      containers:
      - name: fix
        image: registry.redhat.io/ubi9/ubi-minimal:latest
        command: ["chown","-R","${PG_UID}:${PG_UID}","/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: ${pvc}
EOF
  oc wait --for=condition=complete "job/${job}" -n "$NS" --timeout=120s 2>/dev/null || oc logs "job/${job}" -n "$NS" || true
done

echo "Restart postgres + pgpool"
oc scale sts gitea-postgresql-ha-postgresql -n "$NS" --replicas="$REPLICAS" 2>/dev/null || true
oc delete pod -n "$NS" -l app.kubernetes.io/component=postgresql --force --grace-period=0 2>/dev/null || true
oc rollout restart deploy/gitea-postgresql-ha-pgpool -n "$NS" 2>/dev/null || true
sleep 20
oc get pods -n "$NS" | grep -E 'postgresql|pgpool|gitea-' || true
HUB_DOMAIN="${HUB_DOMAIN:-$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null)}"
if [[ -n "$HUB_DOMAIN" ]]; then
  code=$(curl -skI -o /dev/null -w '%{http_code}' --connect-timeout 10 "https://gitea-gitea.${HUB_DOMAIN}/" 2>/dev/null || echo 000)
  echo "gitea-gitea HTTP ${code}"
fi
echo "OK: gitea postgres fix applied"
