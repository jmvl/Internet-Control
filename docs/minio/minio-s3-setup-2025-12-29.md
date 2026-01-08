# MinIO S3 Object Storage Setup

**Date**: 2025-12-29
**Status**: Running
**Host**: docker-host-pct111 (192.168.1.20)

## Overview

Standalone MinIO S3-compatible object storage service deployed on the Docker VM, exposed via Nginx Proxy Manager with Let's Encrypt SSL.

## Access Details

| Service | URL | Port (Internal) |
|---------|-----|-----------------|
| S3 API | https://s3.acmea.tech | 9002 |
| Web Console | https://minio.acmea.tech | 9003 |

### Root Credentials

- **Username**: `admin`
- **Password**: `KlD9hSYCMBguOt1tWmHSo0ou`

### Service Account (API Access)

| Property | Value |
|----------|-------|
| **Access Key** | `K4SYBOUO6VSYI6I40IO2` |
| **Secret Key** | `hI8Ae5G+ah2MYH3Vd8+BINI9AuAbLFI0RSyM7tzJ` |
| **Parent User** | admin |
| **Policy** | inherited-policy |
| **Created** | 2025-12-29 |

## Infrastructure

### Docker Compose

Location: `/root/minio/docker-compose.yml`

```yaml
services:
  minio:
    image: minio/minio:latest
    container_name: minio
    restart: unless-stopped
    ports:
      - "9002:9000"   # S3 API
      - "9003:9001"   # Console
    environment:
      MINIO_ROOT_USER: admin
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    command: server --console-address ":9001" /data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3
    volumes:
      - ./data:/data
```

### Data Storage

- **Path**: `/root/minio/data`
- **Host**: 192.168.1.20

### DNS Configuration (Cloudflare)

| Record | Type | Target |
|--------|------|--------|
| s3.acmea.tech | CNAME | base.acmea.tech |
| minio.acmea.tech | CNAME | base.acmea.tech |

### NPM Proxy Hosts

| Domain | Backend | SSL |
|--------|---------|-----|
| s3.acmea.tech | 192.168.1.20:9002 | Let's Encrypt (ID: 57) |
| minio.acmea.tech | 192.168.1.20:9003 | Let's Encrypt (ID: 58) |

## Usage Examples

### Python (boto3)

```python
import boto3

s3 = boto3.client('s3',
    endpoint_url='https://s3.acmea.tech',
    aws_access_key_id='admin',
    aws_secret_access_key='KlD9hSYCMBguOt1tWmHSo0ou'
)

# Create bucket
s3.create_bucket(Bucket='my-bucket')

# Upload file
s3.upload_file('local-file.txt', 'my-bucket', 'remote-file.txt')

# List buckets
response = s3.list_buckets()
for bucket in response['Buckets']:
    print(bucket['Name'])
```

### AWS CLI

```bash
# Configure profile
aws configure --profile minio
# AWS Access Key ID: admin
# AWS Secret Access Key: KlD9hSYCMBguOt1tWmHSo0ou
# Default region: us-east-1
# Default output format: json

# Use with endpoint
aws --profile minio --endpoint-url https://s3.acmea.tech s3 ls
aws --profile minio --endpoint-url https://s3.acmea.tech s3 mb s3://my-bucket
aws --profile minio --endpoint-url https://s3.acmea.tech s3 cp file.txt s3://my-bucket/
```

### MinIO Client (mc)

```bash
# Add alias
mc alias set acmea https://s3.acmea.tech admin KlD9hSYCMBguOt1tWmHSo0ou

# List buckets
mc ls acmea

# Create bucket
mc mb acmea/my-bucket

# Copy files
mc cp file.txt acmea/my-bucket/
```

## Management

### Start/Stop

```bash
ssh root@192.168.1.20 'cd /root/minio && docker compose up -d'
ssh root@192.168.1.20 'cd /root/minio && docker compose down'
```

### View Logs

```bash
ssh root@192.168.1.20 'docker logs minio -f'
```

### Health Check

```bash
curl -s https://s3.acmea.tech/minio/health/live
# Returns 200 if healthy
```

## Current Buckets

| Bucket | Size | Purpose |
|--------|------|---------|
| smilingcards-dev | 3.8 MB | SmilingCards development assets |

**Last Updated**: 2025-12-31

## Related Services

- **Supabase MinIO** (separate): `/root/supabase-project/docker-compose.s3.yml` - Supabase-specific S3 storage (ports 9000/9001)
