-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: schema/04_transaction_tables.sql
-- Description: Transaction tables - invoices, line items, ITC ledger, payments
-- Brand: MinervaDB GST Calculator for CPG
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- TABLE: Tax Invoice Header (partitioned by invoice_date for performance)
-- -------------------------------------------------------------------------
CREATE TABLE gst.tax_invoice (
      invoice_id          UUID            NOT NULL DEFAULT uuid_generate_v4(),
      invoice_number      VARCHAR(50)     NOT NULL,
      invoice_date        DATE            NOT NULL,
      invoice_type        gst.invoice_type NOT NULL DEFAULT 'TAX_INVOICE',
      supply_type         gst.supply_type  NOT NULL DEFAULT 'B2B',
      seller_gstin        VARCHAR(15)     NOT NULL,
      buyer_gstin         VARCHAR(15),    -- NULL for unregistered buyer
    buyer_name          VARCHAR(200),
      buyer_state_code    CHAR(2)         NOT NULL,
      seller_state_code   CHAR(2)         NOT NULL,
      place_of_supply     CHAR(2)         NOT NULL,
      is_reverse_charge   BOOLEAN         NOT NULL DEFAULT FALSE,
      is_igst_applicable  BOOLEAN         NOT NULL DEFAULT FALSE,
      -- Reference to original invoice (for credit/debit notes)
    original_invoice_id UUID,
      original_invoice_no VARCHAR(50),
      original_invoice_dt DATE,
      -- Amounts (auto-computed by trigger from line items)
    taxable_value       NUMERIC(17,2)   NOT NULL DEFAULT 0,
      cgst_amount         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      sgst_amount         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      igst_amount         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      utgst_amount        NUMERIC(17,2)   NOT NULL DEFAULT 0,
      cess_amount         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      total_tax_amount    NUMERIC(17,2)   NOT NULL DEFAULT 0,
      invoice_value       NUMERIC(17,2)   NOT NULL DEFAULT 0,
      -- Discount
    trade_discount      NUMERIC(17,2)   NOT NULL DEFAULT 0,
      cash_discount       NUMERIC(17,2)   NOT NULL DEFAULT 0,
      -- Export fields
    export_type         VARCHAR(30),    -- WITH_IGST, WITHOUT_IGST, LUT_BOND
    shipping_bill_no    VARCHAR(30),
      shipping_bill_date  DATE,
      port_code           CHAR(6),
      -- Status
    is_cancelled        BOOLEAN         NOT NULL DEFAULT FALSE,
      cancelled_at        TIMESTAMPTZ,
      cancellation_reason TEXT,
      gstr1_period        CHAR(7),        -- MMYYYY format
    gstr3b_period       CHAR(7),
      is_amended          BOOLEAN         NOT NULL DEFAULT FALSE,
      created_by          VARCHAR(100),
      created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_tax_invoice PRIMARY KEY (invoice_id, invoice_date),
      CONSTRAINT uq_invoice_number UNIQUE (invoice_number, seller_gstin),
      CONSTRAINT fk_invoice_seller_state FOREIGN KEY (seller_state_code)
          REFERENCES gst.state_master (state_code),
      CONSTRAINT fk_invoice_buyer_state FOREIGN KEY (buyer_state_code)
          REFERENCES gst.state_master (state_code)
  ) PARTITION BY RANGE (invoice_date);

-- Create partitions by financial year (April to March)
CREATE TABLE gst.tax_invoice_fy2425
    PARTITION OF gst.tax_invoice
    FOR VALUES FROM ('2024-04-01') TO ('2025-04-01');

CREATE TABLE gst.tax_invoice_fy2526
    PARTITION OF gst.tax_invoice
    FOR VALUES FROM ('2025-04-01') TO ('2026-04-01');

CREATE TABLE gst.tax_invoice_fy2627
    PARTITION OF gst.tax_invoice
    FOR VALUES FROM ('2026-04-01') TO ('2027-04-01');

-- Indexes on the parent table
CREATE INDEX idx_invoice_seller_gstin ON gst.tax_invoice (seller_gstin, invoice_date);
CREATE INDEX idx_invoice_buyer_gstin ON gst.tax_invoice (buyer_gstin, invoice_date)
    WHERE buyer_gstin IS NOT NULL;
CREATE INDEX idx_invoice_gstr1_period ON gst.tax_invoice (gstr1_period, seller_gstin);
CREATE INDEX idx_invoice_date ON gst.tax_invoice (invoice_date DESC);

COMMENT ON TABLE gst.tax_invoice IS 'GST tax invoice header - partitioned by invoice date for CPG transactions';

-- -------------------------------------------------------------------------
-- TABLE: Invoice Line Items
-- -------------------------------------------------------------------------
CREATE TABLE gst.invoice_line_item (
      line_item_id        UUID            NOT NULL DEFAULT uuid_generate_v4(),
      invoice_id          UUID            NOT NULL,
      invoice_date        DATE            NOT NULL,
      line_number         SMALLINT        NOT NULL,
      product_id          UUID,
      product_code        VARCHAR(50),
      product_description VARCHAR(300)    NOT NULL,
      hsn_code            VARCHAR(8)      NOT NULL,
      uom                 VARCHAR(20)     NOT NULL DEFAULT 'NOS',
      quantity            NUMERIC(15,4)   NOT NULL,
      unit_price          NUMERIC(17,4)   NOT NULL,
      gross_amount        NUMERIC(17,2)   NOT NULL,
      discount_amount     NUMERIC(17,2)   NOT NULL DEFAULT 0,
      taxable_value       NUMERIC(17,2)   NOT NULL,
      cgst_rate           NUMERIC(7,4)    NOT NULL DEFAULT 0,
      cgst_amount         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      sgst_rate           NUMERIC(7,4)    NOT NULL DEFAULT 0,
      sgst_amount         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      igst_rate           NUMERIC(7,4)    NOT NULL DEFAULT 0,
      igst_amount         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      utgst_rate          NUMERIC(7,4)    NOT NULL DEFAULT 0,
      utgst_amount        NUMERIC(17,2)   NOT NULL DEFAULT 0,
      cess_rate           NUMERIC(7,4)    NOT NULL DEFAULT 0,
      cess_amount         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      total_tax_amount    NUMERIC(17,2)   NOT NULL DEFAULT 0,
      line_total          NUMERIC(17,2)   NOT NULL,
      supply_category     gst.supply_category NOT NULL DEFAULT 'TAXABLE',
      batch_number        VARCHAR(50),
      expiry_date         DATE,
      created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_invoice_line_item PRIMARY KEY (line_item_id),
      CONSTRAINT fk_line_invoice FOREIGN KEY (invoice_id, invoice_date)
          REFERENCES gst.tax_invoice (invoice_id, invoice_date) ON DELETE CASCADE,
      CONSTRAINT chk_line_number_positive CHECK (line_number > 0),
      CONSTRAINT chk_quantity_positive CHECK (quantity > 0),
      CONSTRAINT chk_taxable_value CHECK (taxable_value = gross_amount - discount_amount),
      CONSTRAINT chk_cgst_sgst_equal CHECK (
          cgst_rate = sgst_rate AND cgst_amount = sgst_amount
      )
  );

CREATE INDEX idx_line_invoice ON gst.invoice_line_item (invoice_id);
CREATE INDEX idx_line_hsn ON gst.invoice_line_item (hsn_code);
CREATE INDEX idx_line_product ON gst.invoice_line_item (product_id) WHERE product_id IS NOT NULL;

COMMENT ON TABLE gst.invoice_line_item IS 'GST invoice line items with per-item tax calculation for CPG products';

-- -------------------------------------------------------------------------
-- TABLE: ITC (Input Tax Credit) Ledger
-- -------------------------------------------------------------------------
CREATE TABLE gst.itc_ledger (
      itc_id              UUID            NOT NULL DEFAULT uuid_generate_v4(),
      gstin               VARCHAR(15)     NOT NULL,
      tax_period          CHAR(7)         NOT NULL,   -- MMYYYY
    transaction_date    DATE            NOT NULL,
      document_type       VARCHAR(30)     NOT NULL,   -- INVOICE, CREDIT_NOTE, ITC_04, ITC_REVERSAL
    document_number     VARCHAR(50)     NOT NULL,
      document_date       DATE            NOT NULL,
      supplier_gstin      VARCHAR(15),
      hsn_code            VARCHAR(8),
      igst_itc            NUMERIC(17,2)   NOT NULL DEFAULT 0,
      cgst_itc            NUMERIC(17,2)   NOT NULL DEFAULT 0,
      sgst_itc            NUMERIC(17,2)   NOT NULL DEFAULT 0,
      cess_itc            NUMERIC(17,2)   NOT NULL DEFAULT 0,
      itc_eligibility     gst.itc_eligibility NOT NULL DEFAULT 'ELIGIBLE',
      ineligibility_reason TEXT,
      is_reversed         BOOLEAN         NOT NULL DEFAULT FALSE,
      reversal_reference  VARCHAR(100),
      gstr2b_matched      BOOLEAN         NOT NULL DEFAULT FALSE,
      gstr2b_match_date   DATE,
      created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_itc_ledger PRIMARY KEY (itc_id)
  );

CREATE INDEX idx_itc_gstin_period ON gst.itc_ledger (gstin, tax_period);
CREATE INDEX idx_itc_supplier ON gst.itc_ledger (supplier_gstin) WHERE supplier_gstin IS NOT NULL;
CREATE INDEX idx_itc_eligibility ON gst.itc_ledger (itc_eligibility, is_reversed);

COMMENT ON TABLE gst.itc_ledger IS 'Input Tax Credit ledger tracking ITC accumulation, matching and reversals';

-- -------------------------------------------------------------------------
-- TABLE: GST Tax Payments
-- -------------------------------------------------------------------------
CREATE TABLE gst.gst_payment (
      payment_id          UUID            NOT NULL DEFAULT uuid_generate_v4(),
      gstin               VARCHAR(15)     NOT NULL,
      tax_period          CHAR(7)         NOT NULL,
      payment_date        DATE            NOT NULL,
      tax_type            gst.tax_type    NOT NULL,
      challan_number      VARCHAR(20),
      igst_cash           NUMERIC(17,2)   NOT NULL DEFAULT 0,
      cgst_cash           NUMERIC(17,2)   NOT NULL DEFAULT 0,
      sgst_cash           NUMERIC(17,2)   NOT NULL DEFAULT 0,
      cess_cash           NUMERIC(17,2)   NOT NULL DEFAULT 0,
      igst_credit         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      cgst_credit         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      sgst_credit         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      cess_credit         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      interest_paid       NUMERIC(17,2)   NOT NULL DEFAULT 0,
      penalty_paid        NUMERIC(17,2)   NOT NULL DEFAULT 0,
      late_fee_paid       NUMERIC(17,2)   NOT NULL DEFAULT 0,
      return_type         gst.return_type NOT NULL,
      created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_gst_payment PRIMARY KEY (payment_id)
  );

CREATE INDEX idx_payment_gstin_period ON gst.gst_payment (gstin, tax_period);

COMMENT ON TABLE gst.gst_payment IS 'GST tax payment records via cash and credit ledger';
