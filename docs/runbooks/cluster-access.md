# Operational Runbook: Cluster UI, API & Service Access

Centralized reference for accessing management UIs, extracting ephemeral session tokens, and running read-only service checks. Strictly adheres to the **Zero-Token-in-Git** policy—no credentials are stored here; all secrets are extracted dynamically from the cluster at runtime.

> [!NOTE]
> Once `cert-manager` and NGINX Ingress TLS routing are finalized in **Epic 4 (Feature 4.2)**, port-forward procedures below will be superseded by HTTPS ingress hostnames under `*.kester.lab`.

---

## 1. ArgoCD (GitOps Control Plane)

* **Namespace:** `argocd` | **Service:** `svc/argocd-server` (`80/TCP`, `--insecure` mode)
* **Local URL:** `http://localhost:8080`
* **Username:** `admin`

Start port-forward:
```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

Extract initial `admin` password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode && echo
```

---

## 2. Argo Workflows (DAG Orchestration)

* **Namespace:** `argo-workflows` | **Service:** `svc/argo-server` (`2746/TCP`, **HTTPS** self-signed TLS)
* **Local URL:** `https://localhost:2746` *(must explicitly include `https://`; hitting `http://` causes `connection reset by peer`)*

Start port-forward:
```bash
kubectl -n argo-workflows port-forward svc/argo-server 2746:2746
```

Extract Bearer token (if prompted by UI or for REST API calls):
```bash
echo "Bearer $(kubectl get secret gitlab-ci-runner-token -n argo-workflows -o jsonpath='{.data.token}' | base64 --decode | tr -d '\r\n')"
```

### Executing `knative-event-trigger` from the Argo Workflows UI

1. Start the port-forward above and open **`https://localhost:2746`** in your browser (accept the self-signed TLS warning).
2. *(Optional)* In a second terminal, watch `helloworld-go` scale from `0` -> `2/2 Running` -> `0`:
```bash
kubectl get pods -n default -l serving.knative.dev/service=helloworld-go -o wide -w
```
3. In the left navigation bar, select **Workflow Templates** → click **`knative-event-trigger`** → click **Submit**.
4. Leave `target_url` set to the default (`http://helloworld-go.default.svc.cluster.local`) and click **Submit**.
5. The DAG executes `invoke-knative-function` (`curlimages/curl`), hitting CoreDNS across namespaces (`argo-workflows` -> `default`), waking `helloworld-go` via the Knative Activator, and completing **Succeeded** (green) within ~1–2 seconds.
6. Inspect the execution status and HTTP response logs:
```bash
kubectl get workflows -n argo-workflows --sort-by=.metadata.creationTimestamp
```
```bash
kubectl logs -n argo-workflows -l workflows.argoproj.io/workflow=<WORKFLOW_NAME> -c main
```

### Submitting `knative-event-trigger` via REST API (No Browser Required)

With the port-forward active:
```bash
TOKEN=$(kubectl get secret gitlab-ci-runner-token -n argo-workflows -o jsonpath='{.data.token}' | base64 --decode | tr -d '\r\n')
curl -k -f -X POST "https://localhost:2746/api/v1/workflows/argo-workflows/submit" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"resourceKind":"WorkflowTemplate","resourceName":"knative-event-trigger"}'
```

---

## 3. Knative Serving (Kourier Gateway)

* **Namespace:** `knative-serving` | **LoadBalancer VIP:** `10.10.10.17` (Cilium eBPF LB-IPAM)
* **External Domain:** `*.kester.lab` (via `Host:` header) | **Internal DNS:** `http://<svc>.<ns>.svc.cluster.local`

Invoke `helloworld-go` externally through Kourier VIP:
```bash
curl -i -H "Host: helloworld-go.default.kester.lab" http://10.10.10.17
```

List all Knative Services and Revisions:
```bash
kubectl get ksvc,revision -A
```

---

## 4. Longhorn (Distributed Block Storage UI)

* **Namespace:** `longhorn-system` | **Service:** `svc/longhorn-frontend` (`80/TCP`)
* **Local URL:** `http://localhost:8081`

Start port-forward:
```bash
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8081:80
```

---

## 5. MinIO Object Storage Console (Interim — Migrating in Feature 4.3)

* **Namespace:** `minio-tenant` | **S3 API:** `9000/TCP` | **Console UI:** `9001/TCP`
* **Local URL:** `http://localhost:9001`

Start port-forward to Console UI:
```bash
kubectl -n minio-tenant port-forward svc/minio-console 9001:9090
```

Inspect active MinIO services (if service port differs after tenant reconciliation):
```bash
kubectl get svc -n minio-tenant
```

---

## 6. Core Cluster Health Checks (Read-Only)

Verify all Talos nodes and Kubernetes API readiness:
```bash
kubectl get nodes -o wide
```

Verify all ArgoCD applications are `Synced` and `Healthy`:
```bash
kubectl get applications -n argocd
```

Verify Cilium LoadBalancer VIP allocations (`10.10.10.17–10.10.10.25`):
```bash
kubectl get svc -A --field-selector spec.type=LoadBalancer
```
