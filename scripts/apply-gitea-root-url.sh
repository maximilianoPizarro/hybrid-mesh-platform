#!/usr/bin/env bash
# Fix Gitea ROOT_URL on the PVC (required when Route hostname != git.example.com).
set -euo pipefail

if ! command -v oc >/dev/null 2>&1; then
  echo "ERROR: oc not found" >&2
  exit 1
fi

HUB_DOMAIN="${HUB_DOMAIN:-$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null)}"
if [[ -z "$HUB_DOMAIN" ]]; then
  echo "ERROR: set HUB_DOMAIN or log in to the hub cluster" >&2
  exit 1
fi

HOST="gitea-gitea.${HUB_DOMAIN}"

echo "Patching Gitea app.ini on PVC for ROOT_URL=https://${HOST}/"

oc scale deploy/gitea -n gitea --replicas=0 2>/dev/null || true
sleep 5

oc delete job gitea-fix-app-ini-manual -n gitea --ignore-not-found
cat <<EOF | oc apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: gitea-fix-app-ini-manual
  namespace: gitea
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: fix
          image: registry.access.redhat.com/ubi9/ubi-minimal:latest
          command: ["/bin/bash", "-c"]
          args:
            - |
              set -euo pipefail
              INI=/data/gitea/conf/app.ini
              if [ ! -f "\$INI" ]; then echo "No app.ini — fresh install"; exit 0; fi
              sed -i "s|^DOMAIN = .*|DOMAIN = ${HOST}|" "\$INI"
              sed -i "s|^ROOT_URL = .*|ROOT_URL = https://${HOST}/|" "\$INI"
              sed -i "s|^PROTOCOL = .*|PROTOCOL = http|" "\$INI"
              sed -i "s|^SSH_DOMAIN = .*|SSH_DOMAIN = ${HOST}|" "\$INI"
              grep -E '^(DOMAIN|ROOT_URL|PROTOCOL|SSH_DOMAIN)' "\$INI"
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: gitea-shared-storage
EOF

oc wait --for=condition=complete job/gitea-fix-app-ini-manual -n gitea --timeout=120s
oc logs job/gitea-fix-app-ini-manual -n gitea

oc patch secret gitea-inline-config -n gitea --type=merge -p "{\"stringData\":{\"server\":\"APP_DATA_PATH=/data\\nDOMAIN=${HOST}\\nENABLE_PPROF=false\\nHTTP_PORT=3000\\nPROTOCOL=http\\nROOT_URL=https://${HOST}/\\nSSH_DOMAIN=${HOST}\\nSSH_LISTEN_PORT=2222\\nSSH_PORT=22\\nSTART_SSH_SERVER=true\\n\"}}" 2>/dev/null || true

oc scale deploy/gitea -n gitea --replicas=1
oc rollout status deploy/gitea -n gitea --timeout=300s

CODE="$(curl -sk -o /dev/null -w '%{http_code}' "https://${HOST}/assets/js/index.js?v=1.25.4" 2>/dev/null || echo 000)"
echo "Gitea assets HTTP: $CODE"
if [[ ! "$CODE" =~ ^2 ]]; then
  echo "WARN: assets still not 200 — check pod logs: oc logs -n gitea deploy/gitea -c gitea" >&2
  exit 1
fi
echo "OK: Gitea assets reachable"
