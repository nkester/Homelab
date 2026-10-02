# MinIO Storage Infrastructure & Tenant Configuration

## Overview
This directory contains the declarative manifests for the MinIO S3-compatible Object Storage Tenant deployed on top of Longhorn distributed block storage.

## Components
- **`tenant-secret.yaml`**: `ExternalSecret` resource syncing `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` from GitLab CI/CD variables via External Secrets Operator into `minio-creds` K8s Secret.
- **`tenant.yaml`**: `Tenant` Custom Resource (`minio.min.io/v2`) defining the 2-server pool across worker nodes backed by `storageClassName: longhorn` with `ReadWriteOnce` (RWO) PVC access modes.
- **`test-bucket.yaml`**: Declarative post-provisioning `Job` creating default buckets (`test-bucket` and `velero-backups`) via the `minio/mc` client.

## Operations & Verification
- **Cluster Endpoint (Internal S3 API):** `http://minio.minio-tenant.svc.cluster.local:9000`
- **Cluster Console (Web UI):** `http://minio.minio-tenant.svc.cluster.local:9001`
- **Secret Sync Status:** `kubectl get externalsecret -n minio-tenant`
- **Tenant Status:** `kubectl get tenant -n minio-tenant`
