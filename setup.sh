#!/usr/bin/env bash
# =============================================================================
# MinervaDB GST Calculator for CPG -- Enterprise Setup Script
# =============================================================================
# Usage:
#   ./setup.sh                  Full interactive setup
#   ./setup.sh --migrate-only   Run migrations only (no seed data)
#   ./setup.sh --seed-only      Load seed data only
#   ./setup.sh --verify         Run health checks only
#   ./setup.sh --help           Show this help
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/setup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Colour codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# LOGGING
# ---------------------------------------------------------------------------
log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')] $*${NC}" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $*${NC}" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $*${NC}" | tee -a "$LOG_FILE"; }
info()  { echo -e "${BLUE}[$(date '+%H:%M:%S')] $*${NC}" | tee -a "$LOG_FILE"; }
header() {
  echo ""
  echo -e "${BOLD}${BLUE}================================================================${NC}"
  echo -e "${BOLD}${BLUE}  $*${NC}"
  echo -e "${BOLD}${BLUE}================================================================${NC}"
}

# ---------------------------------------------------------------------------
# ARGUMENT PARSING
# ---------------------------------------------------------------------------
MIGRATE_ONLY=false
SEED_ONLY=false
VERIFY_ONLY=false
SKIP_DOCKER=false

for arg in "$@"; do
  case $arg in
    --migrate-only) MIGRATE_ONLY=true ;;
    --seed-only)    SEED_ONLY=true ;;
    --verify)       VERIFY_ONLY=true ;;
    --skip-docker)  SKIP_DOCKER=true ;;
    --help|-h)
      cat <<'HELP'
MinervaDB GST Calculator for CPG -- Enterprise Setup Script

USAGE:
  ./setup.sh [OPTIONS]

OPTIONS:
  (none)              Full setup: validate env, create DB, migrate, seed, verify
  --migrate-only      Run database migrations only (skip seed data)
  --seed-only         Load seed data only (migrations must already be applied)
  --verify            Run health checks and connectivity tests only
  --skip-docker       Skip Docker availability check
  --help, -h          Show this help

ENVIRONMENT VARIABLES:
  Required: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, JWT_SECRET
  Optional: PGRST_PORT, PGRST_DB_ANON_ROLE
HELP
      exit 0 ;;
    *) error "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# LOAD ENVIRONMENT
# ---------------------------------------------------------------------------
load_env() {
  if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    log "Loading environment from .env"
    set -a
    # shellcheck disable=SC1090
    source "${SCRIPT_DIR}/.env"
    set +a
  else
    warn ".env file not found -- using environment variables directly"
  fi
}

# ---------------------------------------------------------------------------
# ENVIRONMENT VALIDATION
# ---------------------------------------------------------------------------
validate_env() {
  header "Validating Environment Variables"

  local errors=0

  check_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"
    local required="${2:-true}"
    if [[ -z "$var_value" ]]; then
      if [[ "$required" == "true" ]]; then
        error "  Required variable not set: $var_name"
        ((errors++))
      else
        warn "  Optional variable not set: $var_name"
      fi
    else
      log "  checkmark  $var_name is set"
    fi
  }

  check_var "DB_HOST"
  check_var "DB_PORT"
  check_var "DB_NAME"
  check_var "DB_USER"
  check_var "DB_PASSWORD"
  check_var "JWT_SECRET"
  check_var "PGRST_PORT" false

  if [[ ${#JWT_SECRET:-} -lt 32 ]] && [[ -n "${JWT_SECRET:-}" ]]; then
    error "JWT_SECRET must be at least 32 characters"
    ((errors++))
  fi

  if [[ $errors -gt 0 ]]; then
    error "$errors required variable(s) missing. Edit .env and retry."
    exit 1
  fi
  log "Environment validation: PASSED"
}

# ---------------------------------------------------------------------------
# PREREQUISITE CHECK
# ---------------------------------------------------------------------------
check_prerequisites() {
  header "Checking Prerequisites"

  if ! command -v psql &>/dev/null; then
    error "psql not found."
    error "  Ubuntu: sudo apt install -y postgresql-client"
    error "  macOS:  brew install libpq && brew link --force libpq"
    exit 1
  fi
  log "  psql: $(psql --version)"

  if [[ "$SKIP_DOCKER" == "false" ]]; then
    if command -v docker &>/dev/null; then
      log "  docker: $(docker --version)"
    else
      warn "  docker not found (use --skip-docker to suppress)"
    fi
  fi

  log "Prerequisites: OK"
}

# ---------------------------------------------------------------------------
# DATABASE CONNECTIVITY
# ---------------------------------------------------------------------------
check_db_connectivity() {
  header "Checking Database Connectivity"

  export PGPASSWORD="${DB_PASSWORD}"
  local retries=5

  for i in $(seq 1 $retries); do
    if psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
         -d postgres -c "SELECT 1" &>/dev/null; then
      log "  Connected to PostgreSQL at ${DB_HOST}:${DB_PORT}"
      return 0
    fi
    warn "  Connection attempt $i/$retries failed, retrying..."
    sleep 3
  done

  error "Cannot connect to PostgreSQL. Check DB_HOST, DB_PORT, DB_USER, DB_PASSWORD."
  exit 1
}

# ---------------------------------------------------------------------------
# DATABASE CREATION
# ---------------------------------------------------------------------------
create_database() {
  header "Creating Database"

  export PGPASSWORD="${DB_PASSWORD}"

  if psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
       -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" \
       | grep -q 1; then
    log "  Database '${DB_NAME}' already exists -- skipping"
    return 0
  fi

  log "  Creating database: ${DB_NAME}"
  psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d postgres \
    -c "CREATE DATABASE \"${DB_NAME}\" WITH ENCODING='UTF8' TEMPLATE=template0 OWNER='${DB_USER}';"
  log "  Database created successfully"
}

# ---------------------------------------------------------------------------
# RUN MIGRATIONS
# ---------------------------------------------------------------------------
run_migrations() {
  header "Running Database Migrations"

  export PGPASSWORD="${DB_PASSWORD}"

  local migrations=(
    "schema/01_extensions.sql"
    "schema/02_enums_domains.sql"
    "schema/03_master_tables.sql"
    "schema/04_transaction_tables.sql"
    "schema/05_audit_tables.sql"
    "functions/01_gst_rate_lookup.sql"
    "functions/02_pos_determination.sql"
    "functions/03_tax_calculation.sql"
    "functions/04_itc_engine.sql"
    "functions/05_invoice_functions.sql"
    "functions/06_gstr_preparation.sql"
    "views/01_tax_summary_views.sql"
    "views/02_itc_views.sql"
    "views/03_gstr_views.sql"
    "triggers/01_invoice_triggers.sql"
    "triggers/02_audit_triggers.sql"
    "postgrest/01_postgrest_roles.sql"
  )

  local success=0

  for migration in "${migrations[@]}"; do
    local filepath="${SCRIPT_DIR}/${migration}"
    if [[ ! -f "$filepath" ]]; then
      warn "  Not found: $migration -- skipping"
      continue
    fi
    info "  Applying: $migration"
    if psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
         -d "${DB_NAME}" -v ON_ERROR_STOP=1 \
         -f "$filepath" >> "${LOG_FILE}" 2>&1; then
      log "  OK: $migration"
      ((success++))
    else
      error "  FAILED: $migration"
      error "  Check ${LOG_FILE} for details. Stopping."
      exit 1
    fi
  done

  log "Migrations applied: $success"
}

# ---------------------------------------------------------------------------
# SEED DATA
# ---------------------------------------------------------------------------
load_seed_data() {
  header "Loading Seed Data"

  export PGPASSWORD="${DB_PASSWORD}"

  local seeds=(
    "data/01_gst_rates_seed.sql"
    "data/02_hsn_codes_cpg.sql"
    "data/03_state_codes.sql"
  )

  for seed in "${seeds[@]}"; do
    local filepath="${SCRIPT_DIR}/${seed}"
    [[ ! -f "$filepath" ]] && { warn "Seed not found: $seed"; continue; }
    info "  Loading: $seed"
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
      -d "${DB_NAME}" -f "$filepath" >> "${LOG_FILE}" 2>&1 || warn "Seed had warnings: $seed"
    log "  OK: $seed"
  done

  log "Seed data loaded"
}

# ---------------------------------------------------------------------------
# HEALTH CHECKS
# ---------------------------------------------------------------------------
run_health_checks() {
  header "Running Health Checks"

  export PGPASSWORD="${DB_PASSWORD}"

  # Schema
  psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    -tc "SELECT 1 FROM information_schema.schemata WHERE schema_name='gst'" \
    | grep -q 1 && log "  GST schema: EXISTS" || error "  GST schema: MISSING"

  # Key tables
  for tbl in hsn_code_master gst_rate_master state_master tax_invoice itc_ledger audit_log; do
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
      -tc "SELECT 1 FROM information_schema.tables WHERE table_schema='gst' AND table_name='${tbl}'" \
      | grep -q 1 && log "  Table gst.${tbl}: OK" || warn "  Table gst.${tbl}: MISSING"
  done

  # Key functions
  for fn in get_gst_rate calculate_invoice_tax determine_place_of_supply create_tax_invoice; do
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
      -tc "SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='gst' AND p.proname='${fn}'" \
      | grep -q 1 && log "  Function gst.${fn}: OK" || warn "  Function gst.${fn}: MISSING"
  done

  # Seed data counts
  local hsn_cnt
  hsn_cnt=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    -tc "SELECT COUNT(*) FROM gst.hsn_code_master" 2>/dev/null | tr -d ' ')
  [[ "${hsn_cnt:-0}" -gt 0 ]] && log "  HSN codes: ${hsn_cnt} records" || warn "  HSN codes: empty"

  # Roles
  for role in gst_admin gst_user gst_readonly authenticator; do
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
      -tc "SELECT 1 FROM pg_roles WHERE rolname='${role}'" \
      | grep -q 1 && log "  Role ${role}: OK" || warn "  Role ${role}: MISSING"
  done

  # PostgREST API
  local pgrst_port="${PGRST_PORT:-3000}"
  if command -v curl &>/dev/null; then
    curl -sf "http://localhost:${pgrst_port}/" &>/dev/null \
      && log "  PostgREST API: RESPONDING at http://localhost:${pgrst_port}" \
      || warn "  PostgREST API: Not running (start with: docker compose up -d)"
  fi

  log "Health checks complete"
}

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------
print_summary() {
  header "Setup Complete!"
  echo ""
  echo "  Database:   ${DB_NAME} @ ${DB_HOST}:${DB_PORT}"
  echo "  PostgREST:  http://localhost:${PGRST_PORT:-3000}"
  echo "  Swagger UI: http://localhost:8080"
  echo "  pgAdmin:    http://localhost:5050"
  echo ""
  echo "  Next steps:"
  echo "    docker compose up -d    # Start full API stack"
  echo "    make test               # Run test suites"
  echo "    open http://localhost:8080  # Explore the API"
  echo ""
  echo "  Full log: ${LOG_FILE}"
  echo ""
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
main() {
  echo "Setup started at ${TIMESTAMP}" > "${LOG_FILE}"
  load_env

  if [[ "${VERIFY_ONLY}" == "true" ]]; then
    validate_env; check_db_connectivity; run_health_checks; exit 0
  fi
  if [[ "${SEED_ONLY}" == "true" ]]; then
    validate_env; check_db_connectivity; load_seed_data; run_health_checks; exit 0
  fi
  if [[ "${MIGRATE_ONLY}" == "true" ]]; then
    validate_env; check_db_connectivity; run_migrations; run_health_checks; exit 0
  fi

  # Full setup
  validate_env
  check_prerequisites
  check_db_connectivity
  create_database
  run_migrations
  load_seed_data
  run_health_checks
  print_summary
}

main "$@"
