-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: schema/03_master_tables.sql
-- Description: Master tables - GST rates, HSN codes, states, party master
-- Brand: MinervaDB GST Calculator for CPG
-- =============================================================================

SET search_path TO gst, public;

CREATE TABLE gst.state_master (
      state_code          CHAR(2)         NOT NULL,
      gst_state_code      CHAR(2)         NOT NULL,
      state_name          VARCHAR(100)    NOT NULL,
      union_territory     BOOLEAN         NOT NULL DEFAULT FALSE,
      is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
      created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_state_master PRIMARY KEY (state_code),
      CONSTRAINT uq_gst_state_code UNIQUE (gst_state_code)
  );

CREATE TABLE gst.hsn_code_master (
      hsn_id              UUID            NOT NULL DEFAULT uuid_generate_v4(),
      hsn_code            VARCHAR(8)      NOT NULL,
      hsn_description     VARCHAR(500)    NOT NULL,
      chapter_code        CHAR(2)         NOT NULL,
      chapter_description VARCHAR(200),
      cpg_category        VARCHAR(100),
      cpg_sub_category    VARCHAR(100),
      uom                 VARCHAR(20),
      is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
      effective_from      DATE            NOT NULL DEFAULT '2017-07-01',
      effective_to        DATE,
      created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_hsn_code_master PRIMARY KEY (hsn_id),
      CONSTRAINT uq_hsn_code UNIQUE (hsn_code)
  );

CREATE INDEX idx_hsn_chapter ON gst.hsn_code_master (chapter_code);
CREATE INDEX idx_hsn_cpg_category ON gst.hsn_code_master (cpg_category);

CREATE TABLE gst.gst_rate_master (
      rate_id             UUID            NOT NULL DEFAULT uuid_generate_v4(),
      hsn_code            VARCHAR(8)      NOT NULL,
      cgst_rate           NUMERIC(7,4)    NOT NULL DEFAULT 0,
      sgst_rate           NUMERIC(7,4)    NOT NULL DEFAULT 0,
      igst_rate           NUMERIC(7,4)    NOT NULL DEFAULT 0,
      utgst_rate          NUMERIC(7,4)    NOT NULL DEFAULT 0,
      cess_rate           NUMERIC(7,4)    NOT NULL DEFAULT 0,
      cess_amount         NUMERIC(17,2)   NOT NULL DEFAULT 0,
      supply_category     gst.supply_category NOT NULL DEFAULT 'TAXABLE',
      conditions          TEXT,
      notification_ref    VARCHAR(100),
      effective_from      DATE            NOT NULL DEFAULT '2017-07-01',
      effective_to        DATE,
      is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
      created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_gst_rate_master PRIMARY KEY (rate_id),
      CONSTRAINT fk_gst_rate_hsn FOREIGN KEY (hsn_code)
          REFERENCES gst.hsn_code_master (hsn_code),
      CONSTRAINT chk_cgst_sgst_equal CHECK (cgst_rate = sgst_rate),
      CONSTRAINT chk_igst_double_cgst CHECK (
          igst_rate = cgst_rate + sgst_rate OR
          (cgst_rate = 0 AND sgst_rate = 0 AND igst_rate = 0)
      )
  );

CREATE INDEX idx_gst_rate_hsn ON gst.gst_rate_master (hsn_code);

CREATE TABLE gst.party_master (
      party_id            UUID            NOT NULL DEFAULT uuid_generate_v4(),
      gstin               VARCHAR(15),
      pan                 CHAR(10),
      party_name          VARCHAR(200)    NOT NULL,
      trade_name          VARCHAR(200),
      registration_type   gst.registration_type NOT NULL DEFAULT 'REGULAR',
      address_line1       VARCHAR(200),
      address_line2       VARCHAR(200),
      city                VARCHAR(100),
      state_code          CHAR(2)         NOT NULL,
      pincode             CHAR(6),
      email               VARCHAR(200),
      phone               VARCHAR(15),
      is_supplier         BOOLEAN         NOT NULL DEFAULT FALSE,
      is_customer         BOOLEAN         NOT NULL DEFAULT FALSE,
      is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
      gstin_valid_from    DATE,
      gstin_valid_to      DATE,
      created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_party_master PRIMARY KEY (party_id),
      CONSTRAINT uq_party_gstin UNIQUE (gstin),
      CONSTRAINT fk_party_state FOREIGN KEY (state_code)
          REFERENCES gst.state_master (state_code),
      CONSTRAINT chk_gstin_format CHECK (
          gstin IS NULL OR
          gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$'
      ),
      CONSTRAINT chk_party_role CHECK (is_supplier = TRUE OR is_customer = TRUE)
  );

CREATE INDEX idx_party_gstin ON gst.party_master (gstin) WHERE gstin IS NOT NULL;

CREATE TABLE gst.company_gstin (
      company_gstin_id    UUID            NOT NULL DEFAULT uuid_generate_v4(),
      gstin               VARCHAR(15)     NOT NULL,
      legal_name          VARCHAR(200)    NOT NULL,
      trade_name          VARCHAR(200),
      state_code          CHAR(2)         NOT NULL,
      address_line1       VARCHAR(200),
      city                VARCHAR(100),
      pincode             CHAR(6),
      registration_type   gst.registration_type NOT NULL DEFAULT 'REGULAR',
      is_sez              BOOLEAN         NOT NULL DEFAULT FALSE,
      is_default          BOOLEAN         NOT NULL DEFAULT FALSE,
      is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
      registered_on       DATE,
      created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_company_gstin PRIMARY KEY (company_gstin_id),
      CONSTRAINT uq_company_gstin UNIQUE (gstin),
      CONSTRAINT fk_company_state FOREIGN KEY (state_code)
          REFERENCES gst.state_master (state_code)
  );

CREATE TABLE gst.product_master (
      product_id          UUID            NOT NULL DEFAULT uuid_generate_v4(),
      product_code        VARCHAR(50)     NOT NULL,
      product_name        VARCHAR(300)    NOT NULL,
      brand               VARCHAR(100),
      hsn_code            VARCHAR(8)      NOT NULL,
      uom                 VARCHAR(20)     NOT NULL DEFAULT 'NOS',
      mrp                 NUMERIC(17,2),
      is_food_item        BOOLEAN         NOT NULL DEFAULT FALSE,
      is_branded          BOOLEAN         NOT NULL DEFAULT TRUE,
      is_prepackaged      BOOLEAN         NOT NULL DEFAULT TRUE,
      cpg_category        VARCHAR(100),
      is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
      created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
      CONSTRAINT pk_product_master PRIMARY KEY (product_id),
      CONSTRAINT uq_product_code UNIQUE (product_code),
      CONSTRAINT fk_product_hsn FOREIGN KEY (hsn_code)
          REFERENCES gst.hsn_code_master (hsn_code)
  );

CREATE INDEX idx_product_hsn ON gst.product_master (hsn_code);

COMMENT ON TABLE gst.state_master IS 'Indian state and UT master with GST state codes';
COMMENT ON TABLE gst.hsn_code_master IS 'HSN code master for CPG products with category mapping';
COMMENT ON TABLE gst.gst_rate_master IS 'GST rate master with CGST/SGST/IGST rates by HSN code';
COMMENT ON TABLE gst.party_master IS 'Supplier and customer master with GSTIN and registration details';
COMMENT ON TABLE gst.company_gstin IS 'Own company GSTIN registrations across states';
COMMENT ON TABLE gst.product_master IS 'CPG product master with HSN code linkage for GST calculation';
