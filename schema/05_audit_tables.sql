-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: schema/05_audit_tables.sql
-- Description: Audit logs, amendment history, and compliance trail tables
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- TABLE: audit_log — immutable event log for all GST entity changes
-- -------------------------------------------------------------------------
CREATE TABLE gst.audit_log (
      audit_id        UUID          NOT NULL DEFAULT uuid_generate_v4(),
      event_time      TIMESTAMPTZ   NOT NULL DEFAULT clock_timestamp(),
      schema_name     VARCHAR(63)   NOT NULL DEFAULT 'gst',
      table_name      VARCHAR(63)   NOT NULL,
      operation       CHAR(6)       NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
      record_id       TEXT          NOT NULL,
      old_data        JSONB,
      new_data        JSONB,
      changed_fields  TEXT[],
      session_user    TEXT          NOT NULL DEFAULT session_user,
      app_user        TEXT,
      client_addr     INET,
      application     TEXT,
      CONSTRAINT pk_audit_log PRIMARY KEY (audit_id)
  );

CREATE INDEX idx_audit_table_record   ON gst.audit_log (table_name, record_id);
CREATE INDEX idx_audit_event_time     ON gst.audit_log (event_time DESC);
CREATE INDEX idx_audit_operation      ON gst.audit_log (operation, table_name);

COMMENT ON TABLE gst.audit_log IS
    'Immutable audit log capturing all INSERT/UPDATE/DELETE operations across GST tables';

-- -------------------------------------------------------------------------
-- TABLE: invoice_amendment_history — tracks amendments to filed invoices
-- -------------------------------------------------------------------------
CREATE TABLE gst.invoice_amendment_history (
      amendment_id            UUID        NOT NULL DEFAULT uuid_generate_v4(),
      original_invoice_id     UUID        NOT NULL,
      original_invoice_no     VARCHAR(50) NOT NULL,
      original_invoice_dt     DATE        NOT NULL,
      amendment_invoice_id    UUID,
      amendment_invoice_no    VARCHAR(50),
      amendment_date          DATE        NOT NULL DEFAULT CURRENT_DATE,
      amendment_reason        TEXT        NOT NULL,
      amendment_type          VARCHAR(30) NOT NULL
          CHECK (amendment_type IN ('CORRECTION','CANCELLATION','CREDIT_NOTE','DEBIT_NOTE')),
      original_taxable_value  NUMERIC(17,2) NOT NULL,
      amended_taxable_value   NUMERIC(17,2),
      original_igst           NUMERIC(17,2) NOT NULL DEFAULT 0,
      amended_igst            NUMERIC(17,2),
      original_cgst           NUMERIC(17,2) NOT NULL DEFAULT 0,
      amended_cgst            NUMERIC(17,2),
      original_sgst           NUMERIC(17,2) NOT NULL DEFAULT 0,
      amended_sgst            NUMERIC(17,2),
      original_cess           NUMERIC(17,2) NOT NULL DEFAULT 0,
      amended_cess            NUMERIC(17,2),
      gstin                   VARCHAR(15)  NOT NULL,
      gstr1_period            CHAR(7),
      amended_gstr1_period    CHAR(7),
      created_by              VARCHAR(100),
      created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_invoice_amendment PRIMARY KEY (amendment_id)
  );

CREATE INDEX idx_amendment_orig_invoice ON gst.invoice_amendment_history (original_invoice_id);
CREATE INDEX idx_amendment_gstin        ON gst.invoice_amendment_history (gstin, amendment_date DESC);

COMMENT ON TABLE gst.invoice_amendment_history IS
    'Tracks all amendments, corrections, and cancellations to GST invoices post-filing';

-- -------------------------------------------------------------------------
-- TABLE: itc_reversal_log — mandatory ITC reversals per Rule 37/42/43
-- -------------------------------------------------------------------------
CREATE TABLE gst.itc_reversal_log (
      reversal_id         UUID         NOT NULL DEFAULT uuid_generate_v4(),
      gstin               VARCHAR(15)  NOT NULL,
      reversal_date       DATE         NOT NULL DEFAULT CURRENT_DATE,
      tax_period          CHAR(7)      NOT NULL,
      reversal_reason     VARCHAR(60)  NOT NULL
          CHECK (reversal_reason IN (
              'RULE_37_NON_PAYMENT',
              'RULE_42_EXEMPT_SUPPLY',
              'RULE_43_CAPITAL_GOODS',
              'SEC_17_5_BLOCKED',
              'VOLUNTARY',
              'CREDIT_NOTE_RECEIVED',
              'ANNUAL_RECONCILIATION'
          )),
      original_itc_id     UUID,
      igst_reversed       NUMERIC(17,2) NOT NULL DEFAULT 0,
      cgst_reversed       NUMERIC(17,2) NOT NULL DEFAULT 0,
      sgst_reversed       NUMERIC(17,2) NOT NULL DEFAULT 0,
      cess_reversed       NUMERIC(17,2) NOT NULL DEFAULT 0,
      total_reversed      NUMERIC(17,2) GENERATED ALWAYS AS
                              (igst_reversed + cgst_reversed + sgst_reversed + cess_reversed)
                              STORED,
      remarks             TEXT,
      created_by          VARCHAR(100),
      created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_itc_reversal_log PRIMARY KEY (reversal_id)
  );

CREATE INDEX idx_itc_reversal_gstin  ON gst.itc_reversal_log (gstin, tax_period);
CREATE INDEX idx_itc_reversal_reason ON gst.itc_reversal_log (reversal_reason);

COMMENT ON TABLE gst.itc_reversal_log IS
    'Mandatory ITC reversal tracking per CGST Rules 37, 42, 43 and Section 17(5)';

-- -------------------------------------------------------------------------
-- TABLE: gstr_filing_log — tracks GSTR return submission status
-- -------------------------------------------------------------------------
CREATE TABLE gst.gstr_filing_log (
      filing_id       UUID         NOT NULL DEFAULT uuid_generate_v4(),
      gstin           VARCHAR(15)  NOT NULL,
      return_type     gst.return_type NOT NULL,
      tax_period      CHAR(7)      NOT NULL,   -- MMYYYY
    filing_status   VARCHAR(20)  NOT NULL DEFAULT 'DRAFT'
          CHECK (filing_status IN ('DRAFT','PREPARED','SUBMITTED','FILED','REVISED','NIL')),
      arn             VARCHAR(30),             -- Acknowledgement Reference Number
    filed_at        TIMESTAMPTZ,
      total_taxable   NUMERIC(17,2),
      total_igst      NUMERIC(17,2),
      total_cgst      NUMERIC(17,2),
      total_sgst      NUMERIC(17,2),
      total_cess      NUMERIC(17,2),
      tax_paid_cash   NUMERIC(17,2),
      tax_paid_credit NUMERIC(17,2),
      late_fee        NUMERIC(17,2) DEFAULT 0,
      interest        NUMERIC(17,2) DEFAULT 0,
      created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_gstr_filing_log PRIMARY KEY (filing_id),
      CONSTRAINT uq_gstr_period     UNIQUE (gstin, return_type, tax_period)
  );

CREATE INDEX idx_gstr_filing_gstin  ON gst.gstr_filing_log (gstin, return_type, tax_period);

COMMENT ON TABLE gst.gstr_filing_log IS
    'GSTR return filing status log with ARN tracking for all GSTINs';

-- -------------------------------------------------------------------------
-- TABLE: e_invoice_log — IRN / QR code tracking for e-Invoicing mandate
-- -------------------------------------------------------------------------
CREATE TABLE gst.e_invoice_log (
      e_invoice_id    UUID         NOT NULL DEFAULT uuid_generate_v4(),
      invoice_id      UUID         NOT NULL,
      invoice_date    DATE         NOT NULL,
      seller_gstin    VARCHAR(15)  NOT NULL,
      irn             CHAR(64),               -- Invoice Reference Number (SHA-256)
    ack_no          VARCHAR(20),            -- Acknowledgement number from IRP
    ack_date        TIMESTAMPTZ,
      qr_code         TEXT,                   -- Base64 encoded QR
    signed_invoice  TEXT,                   -- Signed JSON from IRP
    irp_response    JSONB,                  -- Full IRP API response
    cancel_irn      CHAR(64),
      cancel_date     TIMESTAMPTZ,
      cancel_reason   VARCHAR(200),
      status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
          CHECK (status IN ('PENDING','GENERATED','CANCELLED','FAILED')),
      error_details   TEXT,
      created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_e_invoice_log PRIMARY KEY (e_invoice_id),
      CONSTRAINT uq_irn             UNIQUE (irn),
      CONSTRAINT fk_einv_invoice    FOREIGN KEY (invoice_id, invoice_date)
          REFERENCES gst.tax_invoice (invoice_id, invoice_date)
  );

CREATE INDEX idx_einv_invoice ON gst.e_invoice_log (invoice_id, invoice_date);
CREATE INDEX idx_einv_gstin   ON gst.e_invoice_log (seller_gstin, ack_date DESC);

COMMENT ON TABLE gst.e_invoice_log IS
    'E-Invoice IRN and QR code tracking for IRP integration (mandatory for large taxpayers)';

-- -------------------------------------------------------------------------
-- Grant privileges
-- -------------------------------------------------------------------------
GRANT SELECT, INSERT ON gst.audit_log              TO gst_user;
GRANT SELECT         ON gst.audit_log              TO gst_readonly;
GRANT ALL            ON gst.audit_log              TO gst_admin;

GRANT SELECT, INSERT, UPDATE ON gst.invoice_amendment_history TO gst_user;
GRANT SELECT                 ON gst.invoice_amendment_history TO gst_readonly;
GRANT ALL                    ON gst.invoice_amendment_history TO gst_admin;

GRANT SELECT, INSERT, UPDATE ON gst.itc_reversal_log  TO gst_user;
GRANT SELECT                 ON gst.itc_reversal_log  TO gst_readonly;
GRANT ALL                    ON gst.itc_reversal_log  TO gst_admin;

GRANT SELECT, INSERT, UPDATE ON gst.gstr_filing_log   TO gst_user;
GRANT SELECT                 ON gst.gstr_filing_log   TO gst_readonly;
GRANT ALL                    ON gst.gstr_filing_log   TO gst_admin;

GRANT SELECT, INSERT, UPDATE ON gst.e_invoice_log     TO gst_user;
GRANT SELECT                 ON gst.e_invoice_log     TO gst_readonly;
GRANT ALL                    ON gst.e_invoice_log     TO gst_admin;
