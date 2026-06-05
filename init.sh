#!/bin/bash
# =============================================================================
# MinervaDB GST Calculator for CPG — Database Initialization Script
# File: init.sh
# Usage: ./init.sh  OR  docker-compose exec postgres bash /docker-entrypoint-initdb.d/00_init.sh
# =============================================================================
set -euo pipefail
DB="${POSTGRES_DB:-minervadb_gst_cpg}"
USER="${POSTGRES_USER:-gst_admin}"
PSQL="psql -v ON_ERROR_STOP=1 -U $USER -d $DB"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log() { echo "[$(date '+%H:%M:%S')] $*"; }
run() { log "Running $1"; $PSQL -f "$1"; log "OK: $1"; }
log "MinervaDB GST Calculator — Initializing database: $DB"
log "[1/7] Schema..."
run "$DIR/schema/01_extensions.sql"
run "$DIR/schema/02_enums_domains.sql"
run "$DIR/schema/03_master_tables.sql"
run "$DIR/schema/04_transaction_tables.sql"
run "$DIR/schema/05_audit_tables.sql"
log "[2/7] Seed data..."
run "$DIR/data/03_state_codes.sql"
run "$DIR/data/02_hsn_codes_cpg.sql"
run "$DIR/data/01_gst_rates_seed.sql"
log "[3/7] Functions..."
run "$DIR/functions/01_gst_rate_lookup.sql"
run "$DIR/functions/02_pos_determination.sql"
run "$DIR/functions/03_tax_calculation.sql"
run "$DIR/functions/04_itc_engine.sql"
run "$DIR/functions/05_invoice_functions.sql"
run "$DIR/functions/06_gstr_preparation.sql"
log "[4/7] Views..."
run "$DIR/views/01_tax_summary_views.sql"
run "$DIR/views/02_itc_views.sql"
run "$DIR/views/03_gstr_views.sql"
log "[5/7] Triggers..."
run "$DIR/triggers/01_invoice_triggers.sql"
run "$DIR/triggers/02_audit_triggers.sql"
log "[6/7] PostgREST API layer..."
run "$DIR/postgrest/01_postgrest_roles.sql"
log "[7/7] Verification..."
$PSQL -c "SELECT COUNT(*) AS hsn_codes FROM gst.hsn_code_master;"
$PSQL -c "SELECT COUNT(*) AS gst_rates FROM gst.gst_rate_master;"
$PSQL -c "SELECT COUNT(*) AS states    FROM gst.state_master;"
log "Initialization COMPLETE. API: http://localhost:3000 | Swagger: http://localhost:8080"
