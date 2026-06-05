-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: triggers/02_audit_triggers.sql
-- Description: Immutable audit trail triggers for all GST tables
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- TRIGGER FUNCTION: trg_audit_generic
-- Generic audit trigger for any table — captures old/new JSON and changed fields
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.trg_audit_generic()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old_data      JSONB := NULL;
    v_new_data      JSONB := NULL;
    v_record_id     TEXT;
    v_changed_fields TEXT[] := '{}';
    v_key           TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_old_data  := to_jsonb(OLD);
        v_record_id := OLD::TEXT;   -- best-effort record identifier
    ELSIF TG_OP = 'INSERT' THEN
        v_new_data  := to_jsonb(NEW);
        v_record_id := NEW::TEXT;
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_data  := to_jsonb(OLD);
        v_new_data  := to_jsonb(NEW);
        v_record_id := NEW::TEXT;
        -- Calculate changed field names
        FOR v_key IN SELECT key FROM jsonb_each(v_old_data) LOOP
            IF (v_old_data->v_key) IS DISTINCT FROM (v_new_data->v_key) THEN
                v_changed_fields := v_changed_fields || v_key;
            END IF;
        END LOOP;
        -- Skip audit if only updated_at changed
        IF v_changed_fields = ARRAY['updated_at'] THEN
            RETURN NEW;
        END IF;
    END IF;

    INSERT INTO gst.audit_log (
              table_name, operation, record_id,
              old_data, new_data, changed_fields,
              session_user, app_user, application
          ) VALUES (
              TG_TABLE_NAME, TG_OP,
              COALESCE(v_new_data->>'invoice_id', v_new_data->>'party_id',
                       v_new_data->>'rate_id',    v_new_data->>'itc_id',
                       v_new_data->>'audit_id',   v_record_id),
              v_old_data, v_new_data, v_changed_fields,
              session_user,
              current_setting('app.current_user', TRUE),
              current_setting('app.application_name', TRUE)
          );

    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION gst.trg_audit_generic IS
    'Generic audit trigger. Captures INSERT/UPDATE/DELETE as JSONB in audit_log.
     Set app.current_user and app.application_name via SET LOCAL for user-level tracing.';

-- -------------------------------------------------------------------------
-- Attach audit triggers to all auditable tables
-- -------------------------------------------------------------------------

-- tax_invoice
CREATE TRIGGER trg_audit_tax_invoice
    AFTER INSERT OR UPDATE OR DELETE ON gst.tax_invoice
    FOR EACH ROW EXECUTE FUNCTION gst.trg_audit_generic();

-- invoice_line_item
CREATE TRIGGER trg_audit_invoice_line_item
    AFTER INSERT OR UPDATE OR DELETE ON gst.invoice_line_item
    FOR EACH ROW EXECUTE FUNCTION gst.trg_audit_generic();

-- itc_ledger
CREATE TRIGGER trg_audit_itc_ledger
    AFTER INSERT OR UPDATE OR DELETE ON gst.itc_ledger
    FOR EACH ROW EXECUTE FUNCTION gst.trg_audit_generic();

-- party_master
CREATE TRIGGER trg_audit_party_master
    AFTER INSERT OR UPDATE OR DELETE ON gst.party_master
    FOR EACH ROW EXECUTE FUNCTION gst.trg_audit_generic();

-- gst_rate_master
CREATE TRIGGER trg_audit_gst_rate_master
    AFTER INSERT OR UPDATE OR DELETE ON gst.gst_rate_master
    FOR EACH ROW EXECUTE FUNCTION gst.trg_audit_generic();

-- -------------------------------------------------------------------------
-- TRIGGER FUNCTION: trg_updated_at
-- Auto-updates updated_at timestamp on any table with that column
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.trg_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

-- Attach updated_at trigger to master tables
CREATE TRIGGER trg_updated_at_party_master
    BEFORE UPDATE ON gst.party_master
    FOR EACH ROW EXECUTE FUNCTION gst.trg_updated_at();

CREATE TRIGGER trg_updated_at_gst_rate_master
    BEFORE UPDATE ON gst.gst_rate_master
    FOR EACH ROW EXECUTE FUNCTION gst.trg_updated_at();

CREATE TRIGGER trg_updated_at_hsn_code_master
    BEFORE UPDATE ON gst.hsn_code_master
    FOR EACH ROW EXECUTE FUNCTION gst.trg_updated_at();

CREATE TRIGGER trg_updated_at_company_gstin
    BEFORE UPDATE ON gst.company_gstin
    FOR EACH ROW EXECUTE FUNCTION gst.trg_updated_at();

CREATE TRIGGER trg_updated_at_gstr_filing_log
    BEFORE UPDATE ON gst.gstr_filing_log
    FOR EACH ROW EXECUTE FUNCTION gst.trg_updated_at();

CREATE TRIGGER trg_updated_at_e_invoice_log
    BEFORE UPDATE ON gst.e_invoice_log
    FOR EACH ROW EXECUTE FUNCTION gst.trg_updated_at();

COMMENT ON FUNCTION gst.trg_updated_at IS
    'Sets updated_at to NOW() on any UPDATE. Attach to any table with updated_at column.';
