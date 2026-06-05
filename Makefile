# =============================================================================
# MinervaDB GST Calculator for CPG -- Developer Makefile
# =============================================================================
# Usage:
#   make setup       Full setup (env check + migrate + seed)
#   make test        Run all SQL test suites
#   make migrate     Apply database migrations
#   make seed        Load seed/reference data
#   make docker-up   Start Docker Compose stack
#   make docker-down Stop Docker Compose stack
#   make lint        SQL syntax validation
#   make verify      Run health checks
#   make clean       Remove generated config files
# =============================================================================

.PHONY: help setup migrate seed test lint verify docker-up docker-down \
        docker-logs docker-ps docker-clean psql swagger reload-schema \
        backup clean check-env

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------

# Load .env if it exists
-include .env
export

# Defaults (overridden by .env)
DB_HOST     ?= localhost
DB_PORT     ?= 5432
DB_NAME     ?= minervadb_gst_cpg
DB_USER     ?= gst_admin
DB_PASSWORD ?= $(shell grep DB_PASSWORD .env 2>/dev/null | cut -d= -f2)
PGRST_PORT  ?= 3000

# psql shortcut
PSQL = PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME)
PSQL_NOERR = $(PSQL) -v ON_ERROR_STOP=1

# Colour output
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
NC     := \033[0m

# ---------------------------------------------------------------------------
# HELP (default target)
# ---------------------------------------------------------------------------

help: ## Show this help message
	@echo ""
	@echo "MinervaDB GST Calculator for CPG -- Makefile"
	@echo "============================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

# ---------------------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------------------

setup: check-env ## Full setup: migrate + seed + verify
	@echo -e "$(GREEN)Running full setup...$(NC)"
	@chmod +x setup.sh
	@./setup.sh

check-env: ## Validate required environment variables
	@echo -e "$(GREEN)Checking environment...$(NC)"
	@test -f .env || (echo -e "$(RED)ERROR: .env not found. Run: cp .env.example .env$(NC)" && exit 1)
	@test -n "$(DB_PASSWORD)" || (echo -e "$(RED)ERROR: DB_PASSWORD not set in .env$(NC)" && exit 1)
	@echo -e "$(GREEN)Environment OK$(NC)"

# ---------------------------------------------------------------------------
# DATABASE MIGRATIONS
# ---------------------------------------------------------------------------

migrate: check-env ## Apply database migrations in dependency order
	@echo -e "$(GREEN)Running migrations...$(NC)"
	@$(PSQL_NOERR) -f schema/01_extensions.sql
	@$(PSQL_NOERR) -f schema/02_enums_domains.sql
	@$(PSQL_NOERR) -f schema/03_master_tables.sql
	@$(PSQL_NOERR) -f schema/04_transaction_tables.sql
	@$(PSQL_NOERR) -f schema/05_audit_tables.sql
	@$(PSQL_NOERR) -f functions/01_gst_rate_lookup.sql
	@$(PSQL_NOERR) -f functions/02_pos_determination.sql
	@$(PSQL_NOERR) -f functions/03_tax_calculation.sql
	@$(PSQL_NOERR) -f functions/04_itc_engine.sql
	@$(PSQL_NOERR) -f functions/05_invoice_functions.sql
	@$(PSQL_NOERR) -f functions/06_gstr_preparation.sql
	@$(PSQL_NOERR) -f views/01_tax_summary_views.sql
	@$(PSQL_NOERR) -f views/02_itc_views.sql
	@$(PSQL_NOERR) -f views/03_gstr_views.sql
	@$(PSQL_NOERR) -f triggers/01_invoice_triggers.sql
	@$(PSQL_NOERR) -f triggers/02_audit_triggers.sql
	@$(PSQL_NOERR) -f postgrest/01_postgrest_roles.sql
	@echo -e "$(GREEN)Migrations complete$(NC)"

# ---------------------------------------------------------------------------
# SEED DATA
# ---------------------------------------------------------------------------

seed: check-env ## Load GST rate, HSN code, and state master data
	@echo -e "$(GREEN)Loading seed data...$(NC)"
	@$(PSQL) -f data/01_gst_rates_seed.sql || true
	@$(PSQL) -f data/02_hsn_codes_cpg.sql  || true
	@$(PSQL) -f data/03_state_codes.sql     || true
	@echo -e "$(GREEN)Seed data loaded$(NC)"

# ---------------------------------------------------------------------------
# TESTING
# ---------------------------------------------------------------------------

test: check-env ## Run all SQL test suites
	@echo -e "$(GREEN)Running test suites...$(NC)"
	@$(PSQL) -f tests/test_gst_calculation.sql 2>&1 | tee /tmp/test_gst.log
	@$(PSQL) -f tests/test_itc_engine.sql      2>&1 | tee /tmp/test_itc.log
	@$(PSQL) -f tests/test_invoice_flow.sql    2>&1 | tee /tmp/test_invoice.log
	@echo -e "$(GREEN)Tests complete. Check /tmp/test_*.log for details.$(NC)"

test-gst: check-env ## Run GST calculation tests only
	@$(PSQL) -f tests/test_gst_calculation.sql

test-itc: check-env ## Run ITC engine tests only
	@$(PSQL) -f tests/test_itc_engine.sql

test-invoice: check-env ## Run invoice flow tests only
	@$(PSQL) -f tests/test_invoice_flow.sql

# ---------------------------------------------------------------------------
# SQL LINTING
# ---------------------------------------------------------------------------

lint: ## Validate SQL syntax (requires pgFormatter or sqlfluff)
	@echo -e "$(GREEN)Linting SQL files...$(NC)"
	@if command -v sqlfluff >/dev/null 2>&1; then \
		sqlfluff lint --dialect postgres \
		  schema/ functions/ views/ triggers/ data/ postgrest/ tests/ || true; \
	else \
		echo -e "$(YELLOW)sqlfluff not found. Install: pip install sqlfluff$(NC)"; \
		echo "Basic syntax check via psql --single-transaction --dry-run:"; \
		for f in schema/*.sql functions/*.sql views/*.sql; do \
		  echo "  Checking: $$f"; \
		done; \
	fi

# ---------------------------------------------------------------------------
# VERIFICATION
# ---------------------------------------------------------------------------

verify: check-env ## Run health checks against the database
	@chmod +x setup.sh
	@./setup.sh --verify

# ---------------------------------------------------------------------------
# DOCKER
# ---------------------------------------------------------------------------

docker-up: ## Start full Docker Compose stack (PG + PostgREST + Swagger + pgAdmin)
	@echo -e "$(GREEN)Starting Docker Compose stack...$(NC)"
	@docker compose up -d
	@echo ""
	@echo "Services:"
	@echo "  PostgreSQL:  localhost:$(DB_PORT)"
	@echo "  PostgREST:   http://localhost:$(PGRST_PORT)"
	@echo "  Swagger UI:  http://localhost:8080"
	@echo "  pgAdmin:     http://localhost:5050"

docker-down: ## Stop Docker Compose stack
	@docker compose down

docker-restart: ## Restart all services
	@docker compose restart

docker-restart-api: ## Restart PostgREST only (after schema changes)
	@docker compose restart postgrest
	@echo "PostgREST restarted"

docker-logs: ## Tail logs from all services
	@docker compose logs -f

docker-logs-pg: ## Tail PostgreSQL logs only
	@docker compose logs -f postgres

docker-logs-api: ## Tail PostgREST logs only
	@docker compose logs -f postgrest

docker-ps: ## Show running container status
	@docker compose ps

docker-clean: ## Stop containers and remove volumes (DESTRUCTIVE - deletes data)
	@echo -e "$(RED)WARNING: This will delete all database data!$(NC)"
	@read -p "Are you sure? Type YES to confirm: " confirm && [ "$$confirm" = "YES" ]
	@docker compose down -v
	@echo "Volumes removed"

# ---------------------------------------------------------------------------
# DATABASE ADMIN
# ---------------------------------------------------------------------------

psql: check-env ## Open interactive psql session
	@$(PSQL)

psql-admin: ## Open psql as postgres superuser
	@PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U postgres

reload-schema: ## Signal PostgREST to reload schema cache
	@pkill -USR1 -f postgrest || \
		curl -sf -X POST http://localhost:$(PGRST_PORT)/rpc/reload_schema \
		  -H "Authorization: Bearer $$ADMIN_TOKEN" || \
		docker compose restart postgrest
	@echo "Schema cache reloaded"

refresh-views: check-env ## Refresh all materialized views
	@$(PSQL) -c "REFRESH MATERIALIZED VIEW CONCURRENTLY gst.mv_gstr3b_tax_liability;"
	@echo "Materialized views refreshed"

vacuum: check-env ## Run VACUUM ANALYZE on all GST tables
	@$(PSQL) -c "VACUUM ANALYZE gst.tax_invoice; VACUUM ANALYZE gst.invoice_line_items; VACUUM ANALYZE gst.itc_ledger;"
	@echo "VACUUM ANALYZE complete"

# ---------------------------------------------------------------------------
# BACKUP
# ---------------------------------------------------------------------------

backup: check-env ## Create a pg_dump backup
	@mkdir -p backups
	@BACKUP_FILE="backups/gst_backup_$$(date +%Y%m%d_%H%M%S).dump"; \
	 PGPASSWORD=$(DB_PASSWORD) pg_dump \
	   -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) \
	   -Fc -Z 9 $(DB_NAME) > "$$BACKUP_FILE" && \
	 echo -e "$(GREEN)Backup created: $$BACKUP_FILE$(NC)"

restore: check-env ## Restore from latest backup (BACKUP=path/to/file.dump)
	@test -n "$(BACKUP)" || (echo "Usage: make restore BACKUP=backups/file.dump" && exit 1)
	@PGPASSWORD=$(DB_PASSWORD) pg_restore \
	  -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) \
	  -d $(DB_NAME) --no-owner "$(BACKUP)"
	@echo "Restore complete"

# ---------------------------------------------------------------------------
# CLEANUP
# ---------------------------------------------------------------------------

clean: ## Remove generated files (logs, config)
	@rm -f setup.log postgrest/postgrest.conf.generated
	@echo "Generated files removed"

clean-all: ## Remove all generated files including backups
	@rm -f setup.log
	@rm -rf backups/
	@echo "All generated files removed"

# ---------------------------------------------------------------------------
# SHORTCUTS
# ---------------------------------------------------------------------------

up: docker-up  ## Alias for docker-up
down: docker-down  ## Alias for docker-down
logs: docker-logs  ## Alias for docker-logs
