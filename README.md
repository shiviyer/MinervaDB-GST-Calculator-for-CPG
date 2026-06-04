# MinervaDB GST Calculator for CPG

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-blue.svg)](https://www.postgresql.org/)
[![PL/pgSQL](https://img.shields.io/badge/PL%2FpgSQL-Stored%20Procedures-green.svg)](https://www.postgresql.org/docs/current/plpgsql.html)

## Overview

**MinervaDB GST Calculator for CPG** is a production-grade, end-to-end Goods and Services Tax (GST) implementation for India's Consumer Packaged Goods (CPG) industry, built entirely in **PostgreSQL**, **SQL**, and **PL/pgSQL**. This solution provides a robust, scalable, and audit-ready GST computation engine that handles the full lifecycle of tax calculation, invoice generation, input tax credit (ITC) reconciliation, GSTR filing data preparation, and HSN/SAC classification — all within the database tier.

This project is developed and maintained under the **MinervaDB** brand and is purpose-built for CPG manufacturers, distributors, wholesalers, and retailers operating in the Indian market.

---

## Key Features

- **Complete GST Tax Engine** — CGST, SGST, IGST, UTGST, and Cess computation for all CPG product categories
- - **HSN Code Master** — Comprehensive Harmonized System of Nomenclature (HSN) code mapping for CPG products (food, beverages, personal care, household, tobacco)
  - - **Multi-rate Support** — Handles all GST slabs: 0%, 3%, 5%, 12%, 18%, 28% and special cess rates
    - - **Invoice Management** — Tax invoice, credit note, debit note generation with full audit trail
      - - **Input Tax Credit (ITC)** — Automated ITC eligibility determination, accumulation, and utilization logic
        - - **GSTR-1 / GSTR-3B Data Preparation** — Return-ready aggregated data views for B2B, B2C, exports, and exempted supplies
          - - **Place of Supply (POS) Logic** — Automatic intra-state vs. inter-state determination for CGST+SGST or IGST routing
            - - **Reverse Charge Mechanism (RCM)** — Full RCM support for applicable CPG supply categories
              - - **Composition Scheme** — Handling for small CPG traders and manufacturers under composition
                - - **E-way Bill Data** — Data structures supporting e-way bill generation for CPG consignments
                  - - **Audit & Compliance Trails** — Immutable transaction logs, amendment history, and reconciliation reports
                    - - **Performance Optimized** — Partitioned tables, covering indexes, and materialized views for high-volume CPG transaction processing
                     
                      - ---

                      ## Repository Structure

                      ```
                      MinervaDB-GST-Calculator-for-CPG/
                      ├── schema/
                      │   ├── 01_extensions.sql          -- Required PostgreSQL extensions
                      │   ├── 02_enums_domains.sql       -- Custom types, enums, domains
                      │   ├── 03_master_tables.sql       -- GST rates, HSN codes, states, party master
                      │   ├── 04_transaction_tables.sql  -- Invoices, line items, payments, ITC ledger
                      │   └── 05_audit_tables.sql        -- Audit logs, amendment history
                      ├── functions/
                      │   ├── 01_gst_rate_lookup.sql     -- GST rate resolution functions
                      │   ├── 02_pos_determination.sql   -- Place of supply logic
                      │   ├── 03_tax_calculation.sql     -- Core CGST/SGST/IGST/Cess calculation engine
                      │   ├── 04_itc_engine.sql          -- Input Tax Credit computation and utilization
                      │   ├── 05_invoice_functions.sql   -- Invoice creation and validation
                      │   └── 06_gstr_preparation.sql    -- GSTR-1 and GSTR-3B data preparation
                      ├── views/
                      │   ├── 01_tax_summary_views.sql   -- Tax liability dashboards
                      │   ├── 02_itc_views.sql           -- ITC ledger and utilization views
                      │   └── 03_gstr_views.sql          -- GSTR return filing views
                      ├── triggers/
                      │   ├── 01_invoice_triggers.sql    -- Invoice validation and auto-calculation triggers
                      │   └── 02_audit_triggers.sql      -- Audit trail triggers
                      ├── data/
                      │   ├── 01_gst_rates_seed.sql      -- GST rate master data
                      │   ├── 02_hsn_codes_cpg.sql       -- CPG HSN code reference data
                      │   └── 03_state_codes.sql         -- Indian state codes (GST)
                      ├── tests/
                      │   ├── test_gst_calculation.sql   -- Unit tests for tax calculation
                      │   ├── test_itc_engine.sql        -- ITC computation test cases
                      │   └── test_invoice_flow.sql      -- End-to-end invoice flow tests
                      └── docs/
                          ├── GST_FRAMEWORK.md           -- India GST framework overview
                          ├── CPG_TAX_CATEGORIES.md      -- CPG product tax category guide
                          └── DEPLOYMENT.md              -- Database deployment guide
                      ```

                      ---

                      ## Prerequisites

                      - PostgreSQL 14 or higher
                      - - Extensions: `uuid-ossp`, `pgcrypto`, `btree_gist`
                        - - Schema: Dedicated `gst` schema (created by migration scripts)
                          - - Roles: `gst_admin`, `gst_user`, `gst_readonly` (created by migration scripts)
                           
                            - ---

                            ## Quick Start

                            ### 1. Clone the Repository

                            ```bash
                            git clone https://github.com/shiviyer/MinervaDB-GST-Calculator-for-CPG.git
                            cd MinervaDB-GST-Calculator-for-CPG
                            ```

                            ### 2. Create the Database

                            ```sql
                            CREATE DATABASE minervadb_gst_cpg
                              WITH ENCODING = 'UTF8'
                                   LC_COLLATE = 'en_IN.UTF-8'
                                   LC_CTYPE   = 'en_IN.UTF-8'
                                   TEMPLATE   = template0;
                            ```

                            ### 3. Run Migrations in Order

                            ```bash
                            psql -d minervadb_gst_cpg -f schema/01_extensions.sql
                            psql -d minervadb_gst_cpg -f schema/02_enums_domains.sql
                            psql -d minervadb_gst_cpg -f schema/03_master_tables.sql
                            psql -d minervadb_gst_cpg -f schema/04_transaction_tables.sql
                            psql -d minervadb_gst_cpg -f schema/05_audit_tables.sql
                            psql -d minervadb_gst_cpg -f data/01_gst_rates_seed.sql
                            psql -d minervadb_gst_cpg -f data/02_hsn_codes_cpg.sql
                            psql -d minervadb_gst_cpg -f data/03_state_codes.sql
                            psql -d minervadb_gst_cpg -f functions/01_gst_rate_lookup.sql
                            psql -d minervadb_gst_cpg -f functions/02_pos_determination.sql
                            psql -d minervadb_gst_cpg -f functions/03_tax_calculation.sql
                            psql -d minervadb_gst_cpg -f functions/04_itc_engine.sql
                            psql -d minervadb_gst_cpg -f functions/05_invoice_functions.sql
                            psql -d minervadb_gst_cpg -f functions/06_gstr_preparation.sql
                            psql -d minervadb_gst_cpg -f views/01_tax_summary_views.sql
                            psql -d minervadb_gst_cpg -f views/02_itc_views.sql
                            psql -d minervadb_gst_cpg -f views/03_gstr_views.sql
                            psql -d minervadb_gst_cpg -f triggers/01_invoice_triggers.sql
                            psql -d minervadb_gst_cpg -f triggers/02_audit_triggers.sql
                            ```

                            ### 4. Calculate GST for a CPG Invoice

                            ```sql
                            -- Calculate GST for a B2B intra-state sale of packaged biscuits
                            SELECT * FROM gst.calculate_invoice_tax(
                                p_seller_gstin    => '27AABCU9603R1ZX',
                                p_buyer_gstin     => '27BBBCA1234C1Z5',
                                p_hsn_code        => '1905',           -- Biscuits, pastry, cakes
                                p_supply_value    => 100000.00,
                                p_seller_state    => 'MH',
                                p_buyer_state     => 'MH',
                                p_transaction_dt  => CURRENT_DATE
                            );
                            ```

                            ---

                            ## GST Tax Slabs for CPG Products

                            | GST Rate | CPG Product Categories |
                            |----------|----------------------|
                            | **0%**   | Fresh milk, eggs, fresh vegetables, fresh fruits, unbranded atta/maida/besan, salt, unbranded cereals |
                            | **5%**   | Packaged food (branded), tea, coffee, edible oils, sugar, spices, branded cereals, fish/meat (packaged) |
                            | **12%**  | Fruit juices, namkeen, bhujia, processed food, butter, ghee, cheese, dry fruits |
                            | **18%**  | Chocolates, ice cream, instant food mixes, soups, health supplements, branded beverages |
                            | **28%**  | Aerated/carbonated drinks, pan masala (without tobacco), chewing gum, caffeinated beverages |
                            | **28%+Cess** | Tobacco products, cigarettes, aerated drinks with high sugar |

                            ---

                            ## CPG Industry GST Challenges Addressed

                            This implementation specifically addresses the following CPG-industry complexities:

                            **Multi-SKU Transactions** — Single invoices with hundreds of line items spanning multiple HSN codes and tax rates are handled efficiently through set-based SQL operations.

                            **Trade Promotions & Discounts** — Volume discounts, trade schemes, and promotional free goods (FoC) are handled with correct GST treatment per CBIC guidelines.

                            **Inter-branch Stock Transfers** — Intra-company stock transfers between GSTIN-bearing branches are treated as taxable supplies with proper ITC flow.

                            **Return & Replacement** — Credit notes with original invoice linkage, reversal of ITC on sales returns, and goods return GST treatment.

                            **Composite vs. Mixed Supply** — Automatic classification and taxation of CPG gift packs, combos, and bundled offers.

                            **Job Work** — GST treatment for contract manufacturing, toll manufacturing, and third-party processing common in CPG.

                            **Exports** — Zero-rated supply handling for CPG exports with LUT/bond, IGST refund data preparation.

                            ---

                            ## Architecture

                            ```
                            Application Layer
                                   |
                                   v
                            PostgreSQL Database (minervadb_gst_cpg)
                                   |
                               ┌───┴────────────────────────────────────────┐
                               │  gst schema                                 │
                               │  ┌─────────────┐  ┌──────────────────────┐ │
                               │  │ Master Data │  │  Transaction Tables  │ │
                               │  │ - hsn_codes │  │  - tax_invoices      │ │
                               │  │ - gst_rates │  │  - invoice_line_items│ │
                               │  │ - state_mst │  │  - itc_ledger        │ │
                               │  │ - party_mst │  │  - gst_payments      │ │
                               │  └─────────────┘  └──────────────────────┘ │
                               │  ┌──────────────────────────────────────┐   │
                               │  │  PL/pgSQL Functions & Procedures     │   │
                               │  │  - calculate_invoice_tax()           │   │
                               │  │  - determine_place_of_supply()       │   │
                               │  │  - compute_itc_eligibility()         │   │
                               │  │  - prepare_gstr1_data()              │   │
                               │  │  - prepare_gstr3b_data()             │   │
                               │  └──────────────────────────────────────┘   │
                               │  ┌──────────────────────────────────────┐   │
                               │  │  Materialized Views & Reporting      │   │
                               │  │  - gstr1_b2b_summary                 │   │
                               │  │  - gstr3b_tax_liability              │   │
                               │  │  - itc_utilization_summary           │   │
                               │  └──────────────────────────────────────┘   │
                               └────────────────────────────────────────────┘
                            ```

                            ---

                            ## Testing

                            ```bash
                            psql -d minervadb_gst_cpg -f tests/test_gst_calculation.sql
                            psql -d minervadb_gst_cpg -f tests/test_itc_engine.sql
                            psql -d minervadb_gst_cpg -f tests/test_invoice_flow.sql
                            ```

                            ---

                            ## Contributing

                            Contributions are welcome! Please read `CONTRIBUTING.md` and submit pull requests against the `develop` branch.

                            1. Fork the repository
                            2. 2. Create a feature branch: `git checkout -b feature/your-feature-name`
                               3. 3. Commit your changes: `git commit -m 'Add: description of your changes'`
                                  4. 4. Push to the branch: `git push origin feature/your-feature-name`
                                     5. 5. Open a Pull Request
                                       
                                        6. ---
                                       
                                        7. ## License
                                       
                                        8. This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
                                       
                                        9. ---
                                       
                                        10. ## About MinervaDB
                                       
                                        11. **MinervaDB** is a specialized database engineering and consulting firm focused on high-performance, scalable, and reliable open-source database infrastructure. We build production-grade database solutions for complex enterprise and regulatory requirements.
                                       
                                        12. - Website: [https://minervadb.xyz](https://minervadb.xyz)
                                            - - GitHub: [https://github.com/MinervaDB](https://github.com/MinervaDB)
                                             
                                              - ---

                                              *MinervaDB GST Calculator for CPG — Purpose-built PostgreSQL GST engine for India's CPG industry*
