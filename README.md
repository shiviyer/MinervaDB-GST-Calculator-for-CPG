# MinervaDB GST Calculator for CPG

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%2B-blue.svg)](https://www.postgresql.org/)
[![PostgREST](https://img.shields.io/badge/PostgREST-12.2-green.svg)](https://postgrest.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED.svg)](https://www.docker.com/)
[![Production Ready](https://img.shields.io/badge/Production-Ready-brightgreen.svg)]()
[![API First](https://img.shields.io/badge/Architecture-API--First-orange.svg)]()
[![GST Compliant](https://img.shields.io/badge/GST-Compliant-blue.svg)]()

**Enterprise-grade PostgreSQL GST Engine for India's Consumer Packaged Goods Industry**

[Quick Start](#quick-start) • [Architecture](#architecture) • [API Reference](#api-reference) • [Deployment](#deployment) • [Documentation](#documentation)

</div>

---

## Overview

**MinervaDB GST Calculator for CPG** is a production-grade, API-first Goods and Services Tax (GST) engine for India's Consumer Packaged Goods (CPG) industry — built entirely in **PostgreSQL 16**, **PL/pgSQL**, and **PostgREST**.

This is not a library. This is a complete, deployable, battle-tested fiscal infrastructure system. It handles the full GST compliance lifecycle — from rate lookup and tax calculation through invoice generation, ITC reconciliation, and GSTR return preparation — all exposed as a clean RESTful API via PostgREST with JWT authentication and row-level security.

### Why Database-First?

GST calculations are **data-intensive, rule-heavy, and audit-critical**. Embedding this logic in application code creates drift, duplication, and compliance risk. A database-first design ensures:

- **Single source of truth** — rate tables, HSN mappings, and transaction history live in one place
- **Zero application drift** — all tax logic is versioned SQL, not scattered business logic
- **Native performance** — set-based operations on partitioned tables handle millions of invoices
- **API-first via PostgREST** — every PL/pgSQL function is instantly a REST endpoint, no middleware needed
- **Audit-immutable** — triggers enforce tamper-proof audit logs at the database layer

---

## Key Features

| Feature | Description |
|---------|-------------|
| **Complete Tax Engine** | CGST, SGST, IGST, UTGST, and Cess computation for all GST slabs (0%, 3%, 5%, 12%, 18%, 28%) |
| **HSN Code Master** | 50+ CPG-specific HSN codes with automatic rate resolution and chapter-level fallbacks |
| **Place of Supply** | Automatic intra-state vs. inter-state determination with CGST+SGST / IGST routing |
| **Invoice Lifecycle** | Create, cancel, amend tax invoices and credit/debit notes with GST-compliant numbering |
| **Input Tax Credit** | ITC eligibility, accumulation, utilization, and reversal (Sec 16, 17(5) blocked credits) |
| **GSTR-1 / GSTR-3B** | Return-ready B2B, B2CS, CDNR aggregations for direct filing or JSON export |
| **Reverse Charge** | Full RCM handling for applicable CPG supply categories |
| **E-Invoice Ready** | Data structures aligned with IRP (Invoice Registration Portal) schema |
| **Multi-GSTIN** | Row-Level Security isolates data per GSTIN for multi-entity deployments |
| **PostgREST API** | Every function and view is a REST endpoint — OpenAPI spec auto-generated |
| **JWT Auth** | Stateless authentication with role-based access (admin / user / readonly) |
| **Audit Trail** | Immutable, trigger-maintained audit log with user, timestamp, and diff |
| **Partitioned Tables** | tax_invoice partitioned by financial year for predictable query performance |
| **Docker Compose** | One-command deployment: PostgreSQL + PostgREST + Swagger UI + pgAdmin |

---

## Repository Structure

```
MinervaDB-GST-Calculator-for-CPG/
|
+-- schema/                          # Database schema -- run in numeric order
|   +-- 01_extensions.sql            # uuid-ossp, pgcrypto, btree_gist
|   +-- 02_enums_domains.sql         # GST-specific types, enums, validation domains
|   +-- 03_master_tables.sql         # HSN master, GST rates, state codes, party master
|   +-- 04_transaction_tables.sql    # Invoices (partitioned), line items, ITC ledger
|   `-- 05_audit_tables.sql          # Immutable audit log, amendment history
|
+-- data/                            # Seed / reference data
|   +-- 01_gst_rates_seed.sql        # Chapter-level GST rate defaults
|   +-- 02_hsn_codes_cpg.sql         # 50+ CPG HSN codes + GST rate entries
|   `-- 03_state_codes.sql           # All 37 Indian state/UT codes (GST)
|
+-- functions/                       # PL/pgSQL business logic
|   +-- 01_gst_rate_lookup.sql       # Rate resolution: get_gst_rate(), lookup_hsn()
|   +-- 02_pos_determination.sql     # Place of supply: determine_pos()
|   +-- 03_tax_calculation.sql       # Core engine: calculate_invoice_tax()
|   +-- 04_itc_engine.sql            # ITC: compute_itc_eligibility(), utilize_itc()
|   +-- 05_invoice_functions.sql     # Lifecycle: create_tax_invoice(), cancel_invoice()
|   `-- 06_gstr_preparation.sql      # Returns: prepare_gstr1_data(), prepare_gstr3b_data()
|
+-- views/                           # Reporting views and materialized views
|   +-- 01_tax_summary_views.sql     # Monthly tax liability dashboard
|   +-- 02_itc_views.sql             # ITC balance, utilization, blocked credits
|   `-- 03_gstr_views.sql            # GSTR-1 B2B, B2CS, CDNR; GSTR-3B outward summary
|
+-- triggers/                        # Automatic enforcement
|   +-- 01_invoice_triggers.sql      # Validation, auto-calculation, filed-period lock
|   `-- 02_audit_triggers.sql        # Immutable audit log for all GST tables
|
+-- postgrest/                       # PostgREST API layer
|   +-- postgrest.conf               # Server configuration
|   `-- 01_postgrest_roles.sql       # Roles, RLS policies, JWT context, API views
|
+-- tests/                           # SQL test suites
|   +-- test_gst_calculation.sql     # 10 tax calculation unit tests
|   +-- test_itc_engine.sql          # ITC computation and reversal tests
|   `-- test_invoice_flow.sql        # End-to-end invoice lifecycle tests
|
+-- docs/                            # Extended documentation
|   +-- ARCHITECTURE.md              # Deep-dive: schema design, RLS, partitioning
|   +-- API_REFERENCE.md             # Complete PostgREST endpoint catalog
|   +-- GST_FRAMEWORK.md             # GST law reference, rate tables, compliance calendar
|   +-- CPG_TAX_CATEGORIES.md        # CPG product classification guide
|   `-- DEPLOYMENT.md                # Docker, bare-metal, and cloud deployment guides
|
+-- .github/
|   `-- workflows/
|       `-- ci.yml                   # GitHub Actions: lint + test pipeline
|
+-- .env.example                     # Environment variable template
+-- docker-compose.yml               # Full stack: PG16 + PostgREST + Swagger + pgAdmin
+-- Makefile                         # Developer targets: setup, test, migrate, seed
+-- setup.sh                         # Interactive enterprise setup and health check script
`-- init.sh                          # Non-interactive initialization (CI/automation)
```

---

## Architecture

### System Architecture

```
+-------------------------------------------------------------------------+
|                          CLIENT LAYER                                    |
|   ERP Systems    Mobile Apps    Analytics    GSTR Portal    CLI Tools    |
+------------------------------+------------------------------------------+
                               |  HTTPS / JWT Bearer Token
                               v
+-------------------------------------------------------------------------+
|                        POSTGREST API GATEWAY                             |
|                                                                          |
|   +----------------+  +----------------+  +----------------+            |
|   | /rpc/          |  | /invoice_*     |  | /v_gstr1_*     |            |
|   | functions      |  | table views    |  | return views   |            |
|   +----------------+  +----------------+  +----------------+            |
|                                                                          |
|   JWT Verify -> db-pre-request: gst.set_session_context()               |
|   Anon Role: gst_readonly  |  Auth: gst_user / gst_admin                |
+------------------------------+------------------------------------------+
                               |  pg_hba trust (loopback)
                               v
+-------------------------------------------------------------------------+
|                    POSTGRESQL 16 -- gst SCHEMA                          |
|                                                                          |
|  +-----------------------+    +---------------------------+             |
|  |   MASTER DATA         |    |   TRANSACTION TABLES      |             |
|  |                       |    |                           |             |
|  | hsn_code_master        |    | tax_invoice               |             |
|  | gst_rate_master        |    |   +-- FY2024_2025         | Partitioned |
|  | state_master           |    |   `-- FY2025_2026         | by Fin Year |
|  | party_master           |    | invoice_line_items        |             |
|  | gst_rate_history       |    | itc_ledger                |             |
|  +-----------------------+    | gst_payments              |             |
|                               +---------------------------+             |
|  +--------------------------------------------------+                  |
|  |               PL/pgSQL FUNCTION LAYER             |                  |
|  |                                                    |                  |
|  |  get_gst_rate()      determine_place_of_supply()  |                  |
|  |  calculate_invoice_tax()  create_tax_invoice()    |                  |
|  |  compute_itc_eligibility()  utilize_itc()         |                  |
|  |  prepare_gstr1_data()  prepare_gstr3b_data()      |                  |
|  +--------------------------------------------------+                  |
|                                                                          |
|  +------------------+  +------------------+  +------------------+      |
|  |  REPORTING VIEWS |  |  AUDIT TABLES    |  |  TRIGGERS        |      |
|  |                  |  |                  |  |                  |      |
|  | v_invoice_tax_   |  | audit_log        |  | trg_invoice_     |      |
|  |   summary        |  | amendment_hist   |  |   validate       |      |
|  | mv_gstr3b_tax_   |  | itc_reversal_log |  | trg_audit_       |      |
|  |   liability (MV) |  | gstr_filing_log  |  |   generic        |      |
|  | v_itc_balance    |  | e_invoice_log    |  | trg_updated_at   |      |
|  +------------------+  +------------------+  +------------------+      |
|                                                                          |
|  Row-Level Security: GSTIN isolation via current_setting('gst.gstin')  |
+-------------------------------------------------------------------------+
```

### API-First Design Principles

1. **Database is the API** — PostgREST exposes every PL/pgSQL function as a POST /rpc/<function> endpoint with zero configuration
2. **JWT-Native Auth** — JWT claims (sub, role, gstin) are extracted by set_session_context() and used for RLS and audit trail
3. **Stateless** — No application server, no session state; every request is self-contained
4. **OpenAPI Auto-Generated** — Swagger UI at http://localhost:8080 documents all endpoints live from the database schema
5. **Versioned SQL** — All changes are SQL migration files; schema evolution is git-tracked

---

## Quick Start

### Option 1: Docker Compose (Recommended)

```bash
# 1. Clone the repository
git clone https://github.com/shiviyer/MinervaDB-GST-Calculator-for-CPG.git
cd MinervaDB-GST-Calculator-for-CPG

# 2. Configure environment
cp .env.example .env
# Edit .env -- set DB_PASSWORD, JWT_SECRET (min 32 chars), and GSTIN

# 3. Start the full stack
docker compose up -d

# 4. Verify all services are healthy
docker compose ps
```

Services started:
- **postgres** → localhost:5432
- **postgrest** → localhost:3000 (REST API)
- **swagger-ui** → localhost:8080 (API Documentation)
- **pgadmin** → localhost:5050 (Database Admin)

### Option 2: Automated Setup Script

```bash
git clone https://github.com/shiviyer/MinervaDB-GST-Calculator-for-CPG.git
cd MinervaDB-GST-Calculator-for-CPG
cp .env.example .env && vim .env   # Set required variables
chmod +x setup.sh && ./setup.sh
```

The setup.sh script performs environment validation, database creation, sequential migrations with rollback on failure, seed data loading, PostgREST config generation, and end-to-end health verification.

### Option 3: Make

```bash
make setup        # Full setup (env check + migrate + seed)
make test         # Run all test suites
make docker-up    # Start Docker stack
make docker-down  # Stop Docker stack
make migrate      # Run pending migrations only
make seed         # Load/reload seed data
make lint         # SQL syntax validation
```

---

## API Reference

The complete API is auto-documented at **http://localhost:8080** (Swagger UI). Below is a summary of key endpoints.

### Authentication

All write operations require a JWT Bearer token:

```
Authorization: Bearer <jwt_token>
```

Generate a test token:

```bash
jwt encode --secret "$JWT_SECRET" '{"role":"gst_user","gstin":"27AABCU9603R1ZX","sub":"user@example.com"}'
```

### Calculate GST

```bash
curl -X POST http://localhost:3000/rpc/calculate_invoice_tax \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "p_seller_gstin":   "27AABCU9603R1ZX",
    "p_buyer_gstin":    "29BBBCA1234C1Z5",
    "p_hsn_code":       "1905",
    "p_supply_value":   100000.00,
    "p_seller_state":   "MH",
    "p_buyer_state":    "KA",
    "p_transaction_dt": "2025-06-01"
  }'
```

Response:

```json
{
  "supply_type":   "INTER_STATE",
  "taxable_value": 100000.00,
  "igst_rate":     18.00,
  "igst_amount":   18000.00,
  "cgst_rate":      0.00,
  "cgst_amount":    0.00,
  "sgst_rate":      0.00,
  "sgst_amount":    0.00,
  "cess_rate":      0.00,
  "cess_amount":    0.00,
  "total_tax":     18000.00,
  "invoice_value": 118000.00
}
```

### Create Invoice

```bash
curl -X POST http://localhost:3000/rpc/create_tax_invoice \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "p_seller_gstin": "27AABCU9603R1ZX",
    "p_buyer_gstin":  "29BBBCA1234C1Z5",
    "p_supply_date":  "2025-06-01",
    "p_line_items": [
      {"hsn_code": "1905", "description": "Biscuits 200g",   "quantity": 100, "unit": "PKT", "unit_price": 50.00},
      {"hsn_code": "2106", "description": "Protein Bar 40g", "quantity":  50, "unit": "PKT", "unit_price": 120.00}
    ]
  }'
```

### GSTR Return Data

```bash
# GSTR-1 B2B data
curl "http://localhost:3000/v_gstr1_b2b?gstin=eq.27AABCU9603R1ZX&period=eq.052025" \
  -H "Authorization: Bearer $TOKEN"

# Prepare GSTR-3B payload
curl -X POST http://localhost:3000/rpc/prepare_gstr3b_data \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"p_gstin": "27AABCU9603R1ZX", "p_month": 5, "p_year": 2025}'
```

### ITC Balance

```bash
curl "http://localhost:3000/v_itc_balance?gstin=eq.27AABCU9603R1ZX" \
  -H "Authorization: Bearer $TOKEN"
```

See [docs/API_REFERENCE.md](docs/API_REFERENCE.md) for the full endpoint catalog.

---

## GST Tax Slabs — CPG Reference

| Rate | CPG Product Categories |
|------|----------------------|
| **0%** | Fresh milk, eggs, vegetables, fruits, unbranded atta/maida, salt, unprocessed cereals |
| **5%** | Packaged food (branded), tea, coffee, edible oils, sugar, spices, packaged meat/fish |
| **12%** | Fruit juices, namkeen, bhujia, processed food, butter, ghee, cheese, dry fruits |
| **18%** | Chocolates, ice cream, instant food mixes, soups, health supplements, mineral water |
| **28%** | Aerated drinks, pan masala, chewing gum, caffeinated beverages |
| **28%+Cess** | Tobacco products, cigarettes, cigars, sugar-sweetened aerated drinks |

---

## Security Model

### Role Hierarchy

```
gst_admin      -- Full DDL + DML (migrations, master data management)
  gst_user     -- DML on transactions, EXECUTE on all functions
    gst_readonly  -- SELECT on views (reporting, dashboards, analytics)
      authenticator -- PostgREST connection role (NOINHERIT LOGIN)
```

### Row-Level Security

All transaction tables enforce per-GSTIN data isolation:

```sql
CREATE POLICY gstin_isolation ON gst.tax_invoice
  USING (seller_gstin = current_setting('gst.gstin', true)
      OR buyer_gstin  = current_setting('gst.gstin', true));
```

### JWT Claims

| Claim | GUC Set | Purpose |
|-------|---------|---------|
| sub | gst.user_id | Audit trail — who performed the action |
| role | PostgREST switch | Access control (gst_user / gst_admin) |
| gstin | gst.gstin | RLS predicate — per-GSTIN data isolation |

---

## Deployment

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for complete guides:

- **Docker Compose** — Development and staging (included)
- **Bare Metal** — Ubuntu 22.04 / RHEL 9 production setup
- **AWS RDS + EC2** — Managed PostgreSQL with PostgREST on EC2
- **Security Hardening** — pg_hba.conf, SSL/TLS, secrets management

### Minimum Resource Requirements

| Environment | PostgreSQL | PostgREST |
|------------|------------|-----------|
| Development | 2 vCPU / 4 GB RAM | 1 vCPU / 512 MB |
| Staging | 4 vCPU / 8 GB RAM | 2 vCPU / 1 GB |
| Production | 8 vCPU / 32 GB RAM | 4 vCPU / 2 GB |

---

## Testing

```bash
make test

# Or individually:
psql -d minervadb_gst_cpg -f tests/test_gst_calculation.sql
psql -d minervadb_gst_cpg -f tests/test_itc_engine.sql
psql -d minervadb_gst_cpg -f tests/test_invoice_flow.sql
```

| Test Suite | Scenarios |
|-----------|---------|
| test_gst_calculation.sql | CGST/SGST split, IGST routing, cess, zero-rated, exempt, RCM |
| test_itc_engine.sql | ITC eligibility, blocked credits (Sec 17(5)), partial exemption, reversal |
| test_invoice_flow.sql | Full lifecycle: create, validate, cancel, credit note, GSTR reconcile |

---

## Configuration Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| DB_HOST | Yes | localhost | PostgreSQL host |
| DB_PORT | Yes | 5432 | PostgreSQL port |
| DB_NAME | Yes | minervadb_gst_cpg | Database name |
| DB_PASSWORD | Yes | — | PostgreSQL password (min 16 chars) |
| JWT_SECRET | Yes | — | JWT signing secret (min 32 chars) |
| PGRST_PORT | No | 3000 | PostgREST listening port |
| PGRST_DB_ANON_ROLE | No | gst_readonly | Unauthenticated role |
| PGRST_MAX_ROWS | No | 1000 | Max rows per API response |
| PGADMIN_EMAIL | No | admin@minervadb.xyz | pgAdmin login email |
| PGADMIN_PASSWORD | No | — | pgAdmin password |

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Schema design, partitioning, RLS model, index design |
| [docs/API_REFERENCE.md](docs/API_REFERENCE.md) | Complete endpoint catalog with request/response examples |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Docker, bare-metal, cloud, and Kubernetes guides |
| [docs/GST_FRAMEWORK.md](docs/GST_FRAMEWORK.md) | GST law reference, compliance calendar, audit requirements |
| [docs/CPG_TAX_CATEGORIES.md](docs/CPG_TAX_CATEGORIES.md) | Product classification guide for CPG operators |

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. All database changes must be SQL migration files in the appropriate directory
4. Include or update tests in `tests/`
5. Ensure `make test` passes before opening a PR
6. Open a Pull Request against the `develop` branch

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## About MinervaDB

**MinervaDB** is a specialized database engineering and consulting firm focused on high-performance, scalable, and reliable open-source database infrastructure.

- Website: [https://minervadb.xyz](https://minervadb.xyz)
- GitHub: [https://github.com/MinervaDB](https://github.com/MinervaDB)
- Email: database@minervadb.xyz

---

<div align="center">
<strong>MinervaDB GST Calculator for CPG</strong><br/>
Purpose-built PostgreSQL GST engine for India's CPG industry<br/>
<em>Built with precision by MinervaDB — Where Databases Are an Art Form</em>
</div>
