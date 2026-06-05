# Architecture Reference

> **MinervaDB GST Calculator for CPG** — Deep-dive into schema design, API architecture, and engineering decisions.

---

## Design Philosophy

### The Database-First Principle

This system is built on a fundamental principle: **the database is the application**. All business logic — tax rate lookups, place of supply determination, ITC eligibility, GSTR aggregation — lives in PL/pgSQL functions inside PostgreSQL. The API layer (PostgREST) is a thin, configuration-free proxy.

This approach offers critical advantages for a compliance system:

- **Law Compliance at the Data Layer** — GST law mandates specific calculation rules (CGST must equal SGST, IGST = CGST + SGST). Encoding these in database constraints means they cannot be bypassed by any application.
- **Immutable Audit Trail** — Trigger-based audit log captures every change inside the database transaction and cannot be disabled by application code.
- **Performance for High-Volume CPG** — Set-based SQL on indexed, partitioned tables handles 10,000+ invoices per day efficiently.
- **Zero API Maintenance** — PostgREST reads information_schema to auto-generate OpenAPI spec. New functions are immediately available.

---

## Schema Design

### Schema Isolation

All objects live in the `gst` schema, isolated from `public`:

```sql
CREATE SCHEMA IF NOT EXISTS gst;
REVOKE ALL ON SCHEMA gst FROM PUBLIC;
GRANT USAGE ON SCHEMA gst TO gst_readonly, gst_user, gst_admin;
```

### Custom Domains (Type Safety)

```sql
-- GSTIN: 15-character format-validated
CREATE DOMAIN gst.gstin_type AS TEXT
  CHECK (VALUE ~ '^[0-9]{2}[A-Z]{4}[0-9A-Z]{1}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');

-- HSN Code: 2,4,6,or 8-digit
CREATE DOMAIN gst.hsn_code_type AS TEXT
  CHECK (VALUE ~ '^[0-9]{2}([0-9]{2}([0-9]{2}([0-9]{2})?)?)?$');

-- Tax Rate: 0-100 with 2 decimal places
CREATE DOMAIN gst.tax_rate_type AS NUMERIC(5,2)
  CHECK (VALUE >= 0 AND VALUE <= 100);
```

---

## Table Architecture

### Dependency Hierarchy

```
Level 1 (Independent):
  state_master          -- 37 Indian states/UTs
  hsn_code_master       -- HSN hierarchy

Level 2 (Reference Level 1):
  gst_rate_master       -- Current rates per HSN
  gst_rate_history      -- Historical rates

Level 3 (Reference Level 1):
  party_master          -- Businesses and GSTIN registry

Level 4 (Transaction, Reference Levels 1-3):
  tax_invoice           -- Parent invoice (PARTITIONED by supply_date)
  invoice_line_items    -- Line items referencing tax_invoice
  itc_ledger            -- ITC credits and debits
  gst_payments          -- GST cash payments

Level 5 (Audit):
  audit_log             -- Universal append-only change log
  invoice_amendment_history
  itc_reversal_log
  gstr_filing_log
  e_invoice_log
```

### GST Rate Table Constraints

```sql
CREATE TABLE gst.gst_rate_master (
  hsn_code       gst.hsn_code_type,
  cgst_rate      gst.tax_rate_type NOT NULL,
  sgst_rate      gst.tax_rate_type NOT NULL,
  igst_rate      gst.tax_rate_type NOT NULL,
  effective_from DATE NOT NULL,
  effective_to   DATE,
  -- GST law: CGST must always equal SGST
  CONSTRAINT cgst_sgst_equal CHECK (cgst_rate = sgst_rate),
  -- IGST = CGST + SGST always
  CONSTRAINT igst_sum CHECK (igst_rate = cgst_rate + sgst_rate),
  -- No overlapping periods for same HSN (requires btree_gist)
  EXCLUDE USING gist (
    hsn_code WITH =,
    daterange(effective_from, COALESCE(effective_to, '9999-12-31')) WITH &&
  )
);
```

---

## Partitioning Strategy

### Range Partitioning by Financial Year

```sql
CREATE TABLE gst.tax_invoice (...)
  PARTITION BY RANGE (supply_date);

CREATE TABLE gst.tax_invoice_fy2024_2025
  PARTITION OF gst.tax_invoice
  FOR VALUES FROM ('2024-04-01') TO ('2025-04-01');

CREATE TABLE gst.tax_invoice_fy2025_2026
  PARTITION OF gst.tax_invoice
  FOR VALUES FROM ('2025-04-01') TO ('2026-04-01');
```

Indian GST financial years run April 1 to March 31, aligning perfectly with partition boundaries.

### Adding New Partitions (Annually)

```sql
-- Run before April 1st each year
CREATE TABLE gst.tax_invoice_fy2026_2027
  PARTITION OF gst.tax_invoice
  FOR VALUES FROM ('2026-04-01') TO ('2027-04-01');

CREATE INDEX ON gst.tax_invoice_fy2026_2027 (seller_gstin, supply_date);
CREATE INDEX ON gst.tax_invoice_fy2026_2027 (buyer_gstin)
  WHERE buyer_gstin IS NOT NULL;
```

---

## Function Layer Design

### SECURITY DEFINER Pattern

```sql
CREATE OR REPLACE FUNCTION gst.calculate_invoice_tax(...)
RETURNS gst.tax_calculation_result
LANGUAGE plpgsql
SECURITY DEFINER  -- Runs as function owner (gst_admin)
SET search_path = gst, public
AS $$ ... $$;

REVOKE ALL ON FUNCTION gst.calculate_invoice_tax FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gst.calculate_invoice_tax TO gst_user, gst_readonly;
```

### Composite Return Types

```sql
CREATE TYPE gst.tax_calculation_result AS (
  supply_type   gst.supply_type_enum,
  taxable_value NUMERIC(15,2),
  cgst_rate     gst.tax_rate_type,
  cgst_amount   gst.gst_amount_type,
  igst_rate     gst.tax_rate_type,
  igst_amount   gst.gst_amount_type,
  total_tax     gst.gst_amount_type,
  invoice_value NUMERIC(15,2)
);
```

PostgREST reads these return types and generates accurate OpenAPI schemas automatically.

---

## Row-Level Security Model

### JWT to RLS Flow

```
HTTP Request with JWT
  |
  v
PostgREST verifies JWT signature
  |
  v
db-pre-request: gst.set_session_context()
  |-- SET LOCAL gst.gstin   = jwt_claims->>'gstin'
  |-- SET LOCAL gst.user_id = jwt_claims->>'sub'
  |
  v
Query executes
  |
  v
RLS: WHERE seller_gstin = current_setting('gst.gstin')
  |
  v
Only that GSTIN's data returned
```

### RLS Policies

```sql
ALTER TABLE gst.tax_invoice ENABLE ROW LEVEL SECURITY;

CREATE POLICY invoice_gstin_isolation ON gst.tax_invoice
  FOR ALL TO gst_user, gst_readonly
  USING (
    seller_gstin = current_setting('gst.gstin', true)
    OR
    buyer_gstin  = current_setting('gst.gstin', true)
  );
```

---

## Audit Trail Design

### Immutable Audit Log

```sql
CREATE TABLE gst.audit_log (
  id         BIGSERIAL PRIMARY KEY,
  table_name TEXT NOT NULL,
  operation  TEXT NOT NULL,
  old_data   JSONB,
  new_data   JSONB,
  changed_by TEXT DEFAULT current_setting('gst.user_id', TRUE),
  changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Append-only: revoke destructive operations
REVOKE UPDATE, DELETE, TRUNCATE ON gst.audit_log FROM gst_admin;
```

---

## Index Design

```sql
-- Seller GSTR-1 filing query
CREATE INDEX idx_invoice_seller_period
  ON gst.tax_invoice (seller_gstin, supply_date DESC);

-- Buyer reconciliation (GSTR-2A)
CREATE INDEX idx_invoice_buyer_period
  ON gst.tax_invoice (buyer_gstin, supply_date DESC)
  WHERE buyer_gstin IS NOT NULL;

-- Status filtering (exclude cancelled)
CREATE INDEX idx_invoice_status
  ON gst.tax_invoice (status) WHERE status != 'CANCELLED';

-- Unique invoice number per GSTIN
CREATE UNIQUE INDEX idx_invoice_number
  ON gst.tax_invoice (invoice_number, seller_gstin);
```

---

## Performance Considerations

### Materialized Views

GSTR-3B aggregations are expensive. `mv_gstr3b_tax_liability` is pre-computed:

```sql
CREATE MATERIALIZED VIEW gst.mv_gstr3b_tax_liability AS
SELECT
  seller_gstin AS gstin,
  to_char(supply_date, 'MMYYYY') AS period,
  SUM(taxable_value) AS total_taxable,
  SUM(igst_amount)   AS total_igst,
  SUM(cgst_amount)   AS total_cgst,
  SUM(sgst_amount)   AS total_sgst
FROM gst.tax_invoice
WHERE status != 'CANCELLED'
GROUP BY seller_gstin, to_char(supply_date, 'MMYYYY')
WITH DATA;

-- Concurrent refresh (non-blocking)
CREATE UNIQUE INDEX ON gst.mv_gstr3b_tax_liability (gstin, period);
REFRESH MATERIALIZED VIEW CONCURRENTLY gst.mv_gstr3b_tax_liability;
```

---

## Further Reading

- [API_REFERENCE.md](API_REFERENCE.md) — REST endpoint catalog
- [DEPLOYMENT.md](DEPLOYMENT.md) — Deployment guides
- [GST_FRAMEWORK.md](GST_FRAMEWORK.md) — GST law reference
- [PostgreSQL Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html)
- [PostgREST Documentation](https://postgrest.org/en/stable/)
