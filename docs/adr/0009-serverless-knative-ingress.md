# ADR-0009: Serverless Execution and Ingress Strategy (Knative + Kourier vs NGINX)

* **Status:** Accepted
* **Date:** 2026-08-25
* **Author:** Neil Kester

## 1. Context
To provide a Serverless Function-as-a-Service (FaaS) layer that mirrors AWS Lambda's scale-to-zero capabilities, we are deploying **Knative Serving**. Knative requires an Ingress gateway to dynamically route traffic to its pods, managing cold starts and scaling algorithms. 

We had previously delayed the deployment of our general cluster ingress (NGINX Ingress Controller) from Feature 3.4. We needed to decide whether to standardize on a single Ingress Controller (NGINX) for the entire cluster (including Knative) or follow Knative's upstream recommendation of using Kourier for internal serverless routing while maintaining NGINX for external cluster traffic.

## 2. Decision
We selected **Option A**, which deploys **Kourier** specifically for Knative Serving and simultaneously deploys the **NGINX Ingress Controller** for general cluster HTTP traffic.

Key Architectural Decisions:
1. **Dedicated Knative Gateway:** Kourier (Envoy-based) will act as the dedicated gateway for Knative and receive its own LoadBalancer IP via Kube-VIP. 
2. **Cluster HTTP Ingress:** NGINX will act as the primary cluster ingress, satisfying the delayed requirement from Feature 3.4, and will also receive its own LoadBalancer IP.

## 3. Consequences
* **Positive:** By using Kourier, we align with Knative's default, officially supported ingress, avoiding the risk and compatibility issues of relying on a community NGINX plugin. Knative's latency-sensitive traffic is isolated from heavy, long-lived data transfers (like S3 traffic to MinIO) handled by NGINX. We also immediately resolve the technical debt by establishing our primary HTTP ingress for the cluster (NGINX) which will operate safely on HTTP and self-signed HTTPS until `cert-manager` is deployed in Epic 4.
* **Negative:** Running two separate ingress controllers increases memory and CPU utilization.
  * **Mitigation:** Resource usage will be monitored closely on our resource-constrained nodes (specifically `worker-1`) via our future Observability stack.
