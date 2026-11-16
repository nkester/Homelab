# 08 - Serverless Execution (Knative)

## Overview
This document outlines the architectural blueprint for the Serverless Function-as-a-Service (FaaS) layer in the Homelab cluster, powered by **Knative Serving**. This layer provides the ability to deploy analytic functions and event-driven microservices that automatically scale up based on request volume and scale down to zero when idle, mimicking AWS Lambda.

## Component Architecture

The serverless architecture consists of three primary components working in tandem:

1.  **Knative Operator (Layer III):** 
    Deployed via an ArgoCD Helm Application, the Knative Operator manages the lifecycle, installation, and upgrades of the Knative Serving control plane.
2.  **Knative Serving Control Plane (Layer III):**
    *   **Autoscaler:** Monitors request concurrency and CPU metrics, dynamically adjusting the replica count of a given service.
    *   **Activator:** Intercepts traffic destined for a scaled-to-zero service. It holds the request in a buffer, signals the Autoscaler to spin up a pod (cold start), and proxies the request to the pod once it becomes ready.
    *   **Controller & Webhooks:** Manage the `KnativeServing`, `Service`, `Route`, `Configuration`, and `Revision` Custom Resources.
3.  **Kourier Ingress Gateway (Layer II/III):**
    An Envoy-based, lightweight ingress dedicated strictly to Knative traffic. It receives a `LoadBalancer` IP from `kube-vip` and handles the dynamic routing required by the Activator and Autoscaler.

## DNS and Routing Strategy

Knative relies heavily on DNS for routing. Services are assigned a unique URL based on the `config-domain` ConfigMap.

*   **Internal Routing:** By default, Knative uses `svc.cluster.local` for internal traffic. 
*   **External/Magic DNS:** We configure the domain to `homelab` or `10.10.10.x.sslip.io` to allow easy local access to serverless functions during development.

## Resource Constraints & Node Alignment

*   **Constraint:** `worker-1` is severely RAM constrained (~3.8GB total). 
*   **Mitigation:** While we are not enforcing hard node selectors during this initial rollout to maintain high availability, the Knative control plane introduces several active pods. Monitoring via our future Observability stack (Epic 5) is critical to ensure `worker-1` is not starved of memory. Future high-memory analytic functions will be specifically targeted away from `worker-1`.
