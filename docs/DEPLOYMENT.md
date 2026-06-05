# Deployment Guide

> **MinervaDB GST Calculator for CPG** — Complete deployment reference for all environments.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Configuration](#environment-configuration)
3. [Option A: Docker Compose](#option-a-docker-compose)
4. [Option B: Bare Metal (Ubuntu 22.04)](#option-b-bare-metal-ubuntu-2204)
5. [Option C: AWS RDS + EC2](#option-c-aws-rds--ec2)
6. [Option D: Kubernetes](#option-d-kubernetes)
7. [Database Migrations](#database-migrations)
8. [PostgREST Configuration](#postgrest-configuration)
9. [SSL/TLS Setup](#ssltls-setup)
10. [Security Hardening](#security-hardening)
11. [Monitoring and Observability](#monitoring-and-observability)
12. [Backup and Recovery](#backup-and-recovery)
13. [Upgrade Procedures](#upgrade-procedures)
14. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### All Environments

| Component | Minimum Version | Recommended |
|-----------|----------------|-------------|
| PostgreSQL | 14 | 16.x |
| PostgREST | 11.0 | 12.2.x |
| Docker | 24.0 | Latest |
| Docker Compose | 2.20 | Latest |

### Required PostgreSQL Extensions

```sql
-- Installed automatically by schema/01_extensions.sql
uuid-ossp     -- UUID generation
pgcrypto      -- Cryptographic functions
btree_gist    -- Date range exclusion constraints
```

---

## Environment Configuration

### Step 1: Copy and Edit .env

```bash
cp .env.example .env
chmod 600 .env
```

### Required Variables

```bash
# PostgreSQL
DB_HOST=localhost
DB_PORT=5432
DB_NAME=minervadb_gst_cpg
DB_USER=gst_admin
DB_PASSWORD=<minimum-16-character-password>

# PostgREST
JWT_SECRET=<minimum-32-character-secret>
PGRST_PORT=3000
PGRST_DB_ANON_ROLE=gst_readonly

# pgAdmin (optional)
PGADMIN_EMAIL=admin@yourcompany.com
PGADMIN_PASSWORD=<strong-password>
```

### Generating a Secure JWT Secret

```bash
openssl rand -hex 32
# or
python3 -c "import secrets; print(secrets.token_hex(32))"
```

---

## Option A: Docker Compose

This is the recommended method for development, staging, and small production deployments.

### Services Included

```
postgres      -> PostgreSQL 16 with all extensions
postgrest     -> PostgREST 12.2 API server
swagger-ui    -> OpenAPI documentation browser
pgadmin       -> Database administration UI (optional)
```

### Quick Start

```bash
# 1. Clone and configure
git clone https://github.com/shiviyer/MinervaDB-GST-Calculator-for-CPG.git
cd MinervaDB-GST-Calculator-for-CPG
cp .env.example .env && vim .env

# 2. Start all services
docker compose up -d

# 3. Verify health
docker compose ps
docker compose logs postgres    # Should show: database system is ready
docker compose logs postgrest   # Should show: Listening on port 3000

# 4. Test the API
curl http://localhost:3000/

# 5. Access Swagger UI
open http://localhost:8080
```

### Service URLs

| Service | URL | Credentials |
|---------|-----|------------|
| PostgREST API | http://localhost:3000 | JWT Bearer token |
| Swagger UI | http://localhost:8080 | None (read-only) |
| pgAdmin | http://localhost:5050 | From .env |
| PostgreSQL | localhost:5432 | From .env |

### Scaling PostgREST

```bash
docker compose up -d --scale postgrest=4
```

---

## Option B: Bare Metal (Ubuntu 22.04)

### Step 1: Install PostgreSQL 16

```bash
sudo apt install -y curl ca-certificates
sudo install -d /usr/share/postgresql-common/pgdg
curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail \
  https://www.postgresql.org/media/keys/ACCC4CF8.asc
sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] \
  https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
  > /etc/apt/sources.list.d/pgdg.list'
sudo apt update && sudo apt install -y postgresql-16 postgresql-contrib-16
sudo systemctl enable --now postgresql
```

### Step 2: Configure PostgreSQL

```sql
-- Run as postgres superuser
CREATE USER gst_admin WITH PASSWORD 'your-secure-password' CREATEDB CREATEROLE;
CREATE DATABASE minervadb_gst_cpg
  WITH ENCODING = 'UTF8'
       LC_COLLATE = 'en_IN.UTF-8'
       LC_CTYPE   = 'en_IN.UTF-8'
       TEMPLATE   = template0
       OWNER      = gst_admin;
```

### Step 3: Tune PostgreSQL for Production

Key settings for /etc/postgresql/16/main/postgresql.conf (32GB RAM server):

```ini
shared_buffers         = 8GB
effective_cache_size   = 24GB
work_mem               = 64MB
maintenance_work_mem   = 2GB
max_connections        = 200
wal_level              = replica
max_wal_size           = 4GB
random_page_cost       = 1.1
effective_io_concurrency = 200
log_min_duration_statement = 1000
```

### Step 4: Run Migrations

```bash
chmod +x setup.sh
./setup.sh
```

### Step 5: Install PostgREST

```bash
PGRST_VER="v12.2.3"
wget -q "https://github.com/PostgREST/postgrest/releases/download/${PGRST_VER}/postgrest-${PGRST_VER}-linux-static-x64.tar.xz"
tar xJf postgrest-*.tar.xz
sudo mv postgrest /usr/local/bin/
sudo chmod +x /usr/local/bin/postgrest
```

### Step 6: Configure PostgREST as systemd Service

Create /etc/postgrest/gst.conf:

```ini
db-uri         = "postgres://authenticator:AUTH_PASSWORD@localhost:5432/minervadb_gst_cpg"
db-schemas     = "gst"
db-anon-role   = "gst_readonly"
db-pre-request = "gst.set_session_context"
jwt-secret     = "your-jwt-secret-minimum-32-characters"
server-port    = 3000
server-host    = "!4"
log-level      = "warn"
db-pool        = 20
max-rows       = 1000
```

Create /etc/systemd/system/postgrest-gst.service:

```ini
[Unit]
Description=PostgREST -- MinervaDB GST API
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=postgrest
ExecStart=/usr/local/bin/postgrest /etc/postgrest/gst.conf
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
ProtectSystem=strict
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

```bash
sudo useradd --system --no-create-home --shell /sbin/nologin postgrest
sudo systemctl daemon-reload
sudo systemctl enable --now postgrest-gst
```

---

## Option C: AWS RDS + EC2

### Architecture

```
Internet Gateway
    |
    v
Application Load Balancer (HTTPS:443)
    |
    v
EC2 Auto Scaling Group (PostgREST)
    |
    v
RDS PostgreSQL 16 (Multi-AZ)
```

### Step 1: Create RDS Instance

```bash
aws rds create-db-instance \
  --db-instance-identifier minervadb-gst-prod \
  --db-instance-class db.r6g.2xlarge \
  --engine postgres --engine-version 16.3 \
  --master-username gst_admin \
  --master-user-password "$DB_PASSWORD" \
  --db-name minervadb_gst_cpg \
  --allocated-storage 500 --storage-type gp3 \
  --storage-encrypted --multi-az \
  --backup-retention-period 7 \
  --no-publicly-accessible
```

### Step 2: Store Secrets in AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name "minervadb-gst/db-credentials" \
  --secret-string '{"username":"gst_admin","password":"<pw>"}'

aws secretsmanager create-secret \
  --name "minervadb-gst/jwt-secret" \
  --secret-string '{"jwt_secret":"<secret>"}'
```

---

## Option D: Kubernetes

### Minimal values.yaml

```yaml
postgresql:
  auth:
    username: gst_admin
    database: minervadb_gst_cpg
  primary:
    resources:
      requests: { memory: 4Gi, cpu: '2' }
      limits:   { memory: 16Gi, cpu: '8' }
    persistence:
      enabled: true
      size: 100Gi

postgrest:
  replicaCount: 2
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
```

```bash
helm install minervadb-gst ./helm/minervadb-gst -f values.yaml \
  --set postgresql.auth.password="$DB_PASSWORD" \
  --namespace gst-production --create-namespace
```

---

## Database Migrations

### Migration Order

Always run in this exact sequence:

```
 1. schema/01_extensions.sql          -- Extensions
 2. schema/02_enums_domains.sql       -- Types and domains
 3. schema/03_master_tables.sql       -- Master data tables
 4. schema/04_transaction_tables.sql  -- Transaction tables (partitioned)
 5. schema/05_audit_tables.sql        -- Audit infrastructure
 6. data/01_gst_rates_seed.sql        -- Chapter-level GST rates
 7. data/02_hsn_codes_cpg.sql         -- HSN codes and rates
 8. data/03_state_codes.sql           -- State codes
 9. functions/01_gst_rate_lookup.sql  -- Rate resolution
10. functions/02_pos_determination.sql -- Place of supply
11. functions/03_tax_calculation.sql  -- Tax calculation engine
12. functions/04_itc_engine.sql       -- ITC engine
13. functions/05_invoice_functions.sql -- Invoice lifecycle
14. functions/06_gstr_preparation.sql -- GSTR preparation
15. views/01_tax_summary_views.sql    -- Reporting views
16. views/02_itc_views.sql            -- ITC views
17. views/03_gstr_views.sql           -- GSTR views
18. triggers/01_invoice_triggers.sql  -- Invoice triggers
19. triggers/02_audit_triggers.sql    -- Audit triggers
20. postgrest/01_postgrest_roles.sql  -- API roles and RLS
```

### Using setup.sh (Recommended)

```bash
./setup.sh                 # Full interactive setup
./setup.sh --migrate-only  # Run migrations without seed data
./setup.sh --seed-only     # Run seed data only
./setup.sh --verify        # Run health checks only
```

---

## PostgREST Configuration

### Full Configuration Reference

```ini
# postgrest/postgrest.conf
db-uri           = "postgres://authenticator:PASSWORD@HOST:5432/minervadb_gst_cpg"
db-schemas       = "gst"
db-anon-role     = "gst_readonly"
db-pre-request   = "gst.set_session_context"
jwt-secret       = "your-minimum-32-character-jwt-secret"
server-port      = 3000
server-host      = "!4"
db-pool          = 20
db-pool-timeout  = 10
max-rows         = 1000
log-level        = "warn"
```

### Generating JWT Tokens

```bash
# Using jwt-cli
jwt encode \
  --secret "$JWT_SECRET" \
  --exp="+8h" \
  '{"role":"gst_user","gstin":"27AABCU9603R1ZX","sub":"user@company.com"}'
```

---

## SSL/TLS Setup

### Nginx Reverse Proxy (Recommended)

```nginx
server {
    listen 443 ssl http2;
    server_name api.your-domain.com;

    ssl_certificate     /etc/letsencrypt/live/api.your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.your-domain.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options DENY;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        limit_req zone=api burst=20 nodelay;
    }
}
limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
```

---

## Security Hardening

### pg_hba.conf

```
# TYPE  DATABASE             USER             ADDRESS          METHOD
local   all                  postgres                          peer
local   all                  all                               reject
host    minervadb_gst_cpg    authenticator    127.0.0.1/32     scram-sha-256
host    minervadb_gst_cpg    gst_admin        10.0.1.0/24      scram-sha-256
host    all                  all              0.0.0.0/0        reject
```

### Firewall Rules

```bash
sudo ufw allow 443/tcp      # HTTPS
sudo ufw allow 22/tcp       # SSH
sudo ufw deny 3000/tcp      # Block direct PostgREST
sudo ufw deny 5432/tcp      # Block direct PostgreSQL
sudo ufw enable
```

---

## Monitoring and Observability

### Health Check

```bash
# PostgREST
curl -f http://localhost:3000/ || echo 'PostgREST down'

# PostgreSQL
pg_isready -h localhost -p 5432 -d minervadb_gst_cpg
```

### Key Database Metrics

```sql
-- Active connections
SELECT count(*), state FROM pg_stat_activity
WHERE datname = 'minervadb_gst_cpg' GROUP BY state;

-- Slow queries
SELECT query, calls, mean_exec_time
FROM pg_stat_statements
WHERE query ILIKE '%gst%'
ORDER BY mean_exec_time DESC LIMIT 20;
```

---

## Backup and Recovery

### Automated Daily Backups

```bash
# /etc/cron.d/minervadb-gst-backup
0 2 * * * postgres pg_dump -Fc -Z 9 minervadb_gst_cpg > /backups/gst_$(date +%Y%m%d).dump
0 3 * * * find /backups -name 'gst_*.dump' -mtime +30 -delete
```

---

## Upgrade Procedures

### Rolling Out Schema Changes

```bash
# 1. Create new migration file
# 2. Test on staging
make test

# 3. Apply to production
make migrate

# 4. Reload PostgREST schema cache
kill -USR1 $(pgrep postgrest)
```

---

## Troubleshooting

### PostgREST Cannot Connect

```bash
psql -d minervadb_gst_cpg -c "\du authenticator"
grep authenticator /etc/postgresql/16/main/pg_hba.conf
psql "postgres://authenticator:PASSWORD@localhost/minervadb_gst_cpg"
```

### 401 Unauthorized

```bash
# Decode token claims
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool
```

### Schema Cache Stale After Migration

```bash
kill -USR1 $(pgrep -f postgrest)
```

### Slow Invoice Queries

```sql
-- Check partition pruning
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM gst.tax_invoice
WHERE supply_date BETWEEN '2025-04-01' AND '2026-03-31';

-- Refresh materialized view
REFRESH MATERIALIZED VIEW CONCURRENTLY gst.mv_gstr3b_tax_liability;
```

---

## Support

- **Issues**: https://github.com/shiviyer/MinervaDB-GST-Calculator-for-CPG/issues
- **MinervaDB Consulting**: database@minervadb.xyz
- **Website**: https://minervadb.xyz
