# GST Framework Reference

> **MinervaDB GST Calculator for CPG** — India's Goods and Services Tax (GST) framework as implemented in this system.

---

## Table of Contents

1. [GST Overview](#gst-overview)
2. [Tax Structure](#tax-structure)
3. [GST Rate Slabs](#gst-rate-slabs)
4. [CPG Product Tax Categories](#cpg-product-tax-categories)
5. [Place of Supply Rules](#place-of-supply-rules)
6. [Input Tax Credit](#input-tax-credit)
7. [GSTR Return Filing](#gstr-return-filing)
8. [Compliance Calendar](#compliance-calendar)
9. [E-Invoice Requirements](#e-invoice-requirements)
10. [Audit and Record-Keeping](#audit-and-record-keeping)

---

## GST Overview

Goods and Services Tax (GST) is India's unified indirect tax framework that replaced a complex system of central and state taxes on July 1, 2017. It is a **dual GST** system where both the Central Government and State Governments simultaneously levy taxes on the same tax base.

### Key Legislation

| Act | Governs |
|-----|--------|
| CGST Act, 2017 | Central GST on intra-state supplies |
| SGST Acts (29 states) | State GST on intra-state supplies |
| IGST Act, 2017 | Integrated GST on inter-state and import/export |
| UTGST Act, 2017 | Union Territory GST (for UTs without legislature) |
| GST (Compensation to States) Act, 2017 | Cess on specified goods |

### Administrative Bodies

- **CBIC** (Central Board of Indirect Taxes and Customs) — Policy and administration
- **GST Council** — Joint body of Centre and States; recommends rate changes
- **GSTN** (Goods and Services Tax Network) — Technology backbone
- **IRP** (Invoice Registration Portal) — E-invoice registration

---

## Tax Structure

### Dual GST Mechanics

```
INTRA-STATE SUPPLY (seller and buyer in same state):
  Taxable Value  x  CGST Rate  =  CGST Amount  -> Central Government
  Taxable Value  x  SGST Rate  =  SGST Amount  -> State Government
  Note: CGST Rate ALWAYS equals SGST Rate

INTER-STATE SUPPLY (seller and buyer in different states):
  Taxable Value  x  IGST Rate  =  IGST Amount  -> Central Government
  Note: IGST Rate = CGST Rate + SGST Rate (typically double the slab)

SPECIAL SUPPLIES:
  UTGST applies instead of SGST for Union Territories without legislature
  (Andaman & Nicobar, Dadra & NH, Lakshadweep, Chandigarh, D&NH)
```

### Tax on Tax Formula

```
Invoice Value = Taxable Value + Total GST
Total GST     = (Taxable Value x CGST%) + (Taxable Value x SGST%)
              = Taxable Value x (CGST% + SGST%)
              = Taxable Value x IGST%   [for inter-state]
```

### GSTIN Structure

Every GST-registered entity has a 15-character GSTIN:

```
POS 1-2:  State Code (e.g., 27 = Maharashtra, 07 = Delhi, 29 = Karnataka)
POS 3-12: PAN Number (10 characters)
POS 13:   Entity Code (1 = Individual, 2+ = multiple GSTINs on same PAN)
POS 14:   Z (default)
POS 15:   Checksum character

Example: 27 AABCU9603R 1 Z X
         ^^                    = Maharashtra
            ^^^^^^^^^^         = PAN: AABCU9603R
                      ^        = Entity: 1st registration
                        ^      = Default: Z
                          ^    = Check digit
```

---

## GST Rate Slabs

### Standard Slabs

| IGST Rate | CGST | SGST | Category |
|-----------|------|------|----------|
| 0% | 0% | 0% | Essential items, fresh produce, contraceptives |
| 5% | 2.5% | 2.5% | Packaged food, medicines, basic commodities |
| 12% | 6% | 6% | Processed food, butter, ghee, packaged dry fruits |
| 18% | 9% | 9% | Most manufactured goods, services |
| 28% | 14% | 14% | Luxury/demerit goods, aerated drinks |

### Special Rates

| Rate | Items |
|------|-------|
| 3% | Gold, silver, precious metals |
| 0.25% | Rough diamonds, precious stones |
| 28% + Cess | Tobacco, cigarettes, aerated drinks with sugar |

### Cess Rates (Selected CPG Items)

| Product | GST Rate | Cess | Effective Rate |
|---------|----------|------|----------------|
| Cigarettes (length >65mm) | 28% | Rs.5/stick + 36% | 64%+ |
| Cigars, cheroots | 28% | 21% | 49% |
| Aerated water with added sugar | 28% | 12% | 40% |
| Pan masala | 28% | 60% | 88% |
| Tobacco products (others) | 28% | Varies | 28%+ |

---

## CPG Product Tax Categories

### Food and Beverages

| HSN Range | Product | GST Rate |
|-----------|---------|----------|
| 0401-0406 | Milk, cream, butter, cheese, ghee | 5%-12% |
| 0701-0714 | Vegetables (fresh: 0%, packaged: 5%) | 0%-5% |
| 0801-0814 | Fruits (fresh: 0%, packaged: 12%) | 0%-12% |
| 1001-1008 | Cereals (unbranded: 0%, branded: 5%) | 0%-5% |
| 1101-1109 | Flour (unbranded: 0%, branded: 5%) | 0%-5% |
| 1201-1218 | Oil seeds, vegetable fats | 5% |
| 1501-1522 | Animal/vegetable fats and oils | 5% |
| 1601-1605 | Meat/fish preparations (packaged) | 12% |
| 1701-1704 | Sugars, confectionery | 12%-18% |
| 1801-1806 | Cocoa, chocolate | 18%-28% |
| 1901-1905 | Cereal preparations, biscuits, bread | 5%-18% |
| 2001-2009 | Preserved vegetables, fruit juices | 12% |
| 2101-2106 | Misc. food preparations, extracts | 5%-18% |
| 2201-2209 | Beverages (water: 18%, juices: 12%) | 12%-28% |

### Packaged Food Details

| Product | HSN | GST Rate | Notes |
|---------|-----|----------|-------|
| Branded atta/maida/besan | 1101/1102 | 5% | Unbranded: 0% |
| Branded rice | 1006 | 5% | Unbranded: 0% |
| Tea (packet) | 0902 | 5% | |
| Coffee (roasted, ground) | 0901 | 5% | |
| Edible oils (refined) | 1507-1515 | 5% | |
| Sugar | 1701 | 5% | |
| Spices (packaged) | 0904-0910 | 5% | |
| Salt | 2501 | 0% | |
| Butter | 0405 | 12% | |
| Ghee | 0405 | 12% | |
| Cheese | 0406 | 12% | |
| Ice cream | 2105 | 18% | |
| Chocolates | 1806 | 18% | |
| Biscuits (< Rs.100/kg MRP) | 1905 | 5% (2019 reduction) | Was 12% |
| Biscuits (>= Rs.100/kg MRP) | 1905 | 18% | |
| Namkeen/bhujia | 2106 | 12% | |
| Mineral water | 2201 | 18% | |
| Fruit juices | 2009 | 12% | |
| Aerated drinks | 2202 | 28% | + cess |
| Energy drinks | 2202 | 28% | |

### Personal Care and Household

| Product | HSN | GST Rate |
|---------|-----|----------|
| Soap (toilet) | 3401 | 18% |
| Detergents/washing powder | 3402 | 18% |
| Toothpaste | 3306 | 18% |
| Shampoo | 3305 | 18% |
| Skin care (cream, lotion) | 3304 | 18% |
| Hair oil | 1515 | 18% |
| Perfume, deodorant | 3303 | 18% |
| Sanitary pads | 3004 | 0% (Nil rated since July 2018) |
| Diapers (baby) | 9619 | 12% |
| Disinfectants | 3808 | 18% |

---

## Place of Supply Rules

### For Goods

```
Rule 1: Movement of Goods
  If goods are moved: POS = destination state
  If no movement: POS = location where goods are situated

Rule 2: Third-Party Delivery
  If supplier delivers to a third party: POS = place of delivery

Rule 3: Import
  POS = Location of the importer (always intra-state for the importer)

Rule 4: Export
  POS = Location outside India (zero-rated)
```

### GSTIN-Based Determination (Common Case)

```sql
-- Extract state from GSTIN
SELLER_STATE = LEFT(seller_gstin, 2)  -- First 2 chars of GSTIN
BUYER_STATE  = LEFT(buyer_gstin, 2)

IF seller_state = buyer_state THEN
  supply_type = 'INTRA_STATE'
  tax_type    = 'CGST + SGST'
ELSE
  supply_type = 'INTER_STATE'
  tax_type    = 'IGST'
END IF

-- Special: If buyer is in UT without legislature
IF buyer_state IN ('AN','DD','LD','CH','DN') AND supply_type = 'INTRA_STATE' THEN
  tax_type = 'CGST + UTGST'
END IF
```

---

## Input Tax Credit

### Basic Principle

ITC allows businesses to deduct taxes paid on purchases (inputs) from their GST liability on sales (output). This prevents cascading tax-on-tax.

### Eligibility Conditions (Section 16, CGST Act)

For ITC to be claimed, ALL of the following must be satisfied:

1. **Possession of tax invoice** — Valid invoice or debit note from registered supplier
2. **Receipt of goods/services** — Actual delivery (not just invoice)
3. **Tax actually paid by supplier** — Supplier must have deposited GST to government
4. **Return filed** — Buyer must have filed GSTR-3B for the period
5. **Time limit** — Earlier of: November 30 of following FY or date of filing annual return

### Blocked Credits (Section 17(5), CGST Act)

ITC is **not allowed** on:

| Category | Items | Exception |
|----------|-------|-----------|
| Motor vehicles | Cars, motorcycles | Allowed if used for resale, transport of goods/persons, or training |
| Food and beverages | Employee meals, outdoor catering | Allowed if providing taxable outward supply of same category |
| Beauty treatment | Cosmetic surgery, health services | |
| Membership clubs | Health, fitness, club membership | |
| Rent-a-cab | Cab hiring for employees | Allowed if obligatory under any law |
| Life/health insurance | For employees | Allowed if obligatory under any law |
| Construction | Immovable property | Allowed for plant and machinery (not buildings) |

### ITC Utilization Rules (Cross-Head)

```
IGST Credit can be used for: IGST liability first, then CGST, then SGST
CGST Credit can be used for: CGST liability first, then IGST (NOT SGST)
SGST Credit can be used for: SGST liability first, then IGST (NOT CGST)

Order of utilization:
1. IGST vs IGST output
2. IGST vs CGST output
3. IGST vs SGST output
4. CGST vs CGST output
5. CGST vs IGST output
6. SGST vs SGST output
7. SGST vs IGST output
```

---

## GSTR Return Filing

### Key Returns

| Return | Purpose | Due Date | Frequency |
|--------|---------|----------|----------|
| GSTR-1 | Outward supplies detail | 11th of next month | Monthly |
| GSTR-1 (QRMP) | Outward supplies (quarterly) | 13th of month after quarter | Quarterly |
| GSTR-3B | Summary + self-assessed liability | 20th of next month | Monthly |
| GSTR-3B (QRMP) | Summary (quarterly filers) | 22nd/24th of month after quarter | Quarterly |
| GSTR-9 | Annual return | December 31 of next FY | Annual |
| GSTR-9C | Reconciliation statement | December 31 of next FY (if turnover > Rs.5Cr) | Annual |

### GSTR-1 Sections

| Table | Content |
|-------|--------|
| 4A | B2B outward supplies (inter-state and intra-state) |
| 5A | B2C large supplies (inter-state, invoice value > Rs.2.5L) |
| 7 | B2CS (B2C small/all intra-state) |
| 6A | Exports with payment of IGST |
| 6B | Exports without payment of IGST (LUT) |
| 9B | Credit/debit notes against registered persons |
| 9C | Credit/debit notes against unregistered persons |
| 12 | HSN-wise summary of outward supplies |

### GSTR-3B Sections

| Section | Content |
|---------|--------|
| 3.1 | Outward taxable supplies (and zero-rated) |
| 3.2 | Inter-state supplies (to unregistered, composition, UIN) |
| 4 | ITC available, ITC reversed, net ITC |
| 5 | Values exempt, nil-rated, non-GST outward supplies |
| 6 | Payment of tax (IGST, CGST, SGST, Cess) |

---

## Compliance Calendar

### Monthly Compliance (Large Taxpayer)

```
Day 1-10:   Generate and review GSTR-1 data from sales invoices
Day 11:     File GSTR-1 (outward supplies)
Day 11-19:  Reconcile GSTR-2A (auto-populated purchases) with books
Day 20:     File GSTR-3B + Pay GST liability
Day 23+:    Receive GSTR-2B (ITC statement) for the month
```

### Annual Compliance

```
April 30:   File GSTR-4 (Composition scheme annual return)
June 30:    File GSTR-5 (Non-resident taxpayer)
September 30: File GSTR-6 (Input Service Distributor)
December 31:  File GSTR-9 (Annual return) and GSTR-9C (if applicable)
```

### Financial Year and Tax Period

GST financial year runs **April 1 to March 31**, aligning with Indian financial year.

Tax periods are referred to in MMYYYY format:
- `042025` = April 2025
- `032026` = March 2026

---

## E-Invoice Requirements

### Applicability Thresholds

| Aggregate Turnover | E-Invoice Mandatory Since |
|-------------------|-------------------------|
| > Rs.500 crore | October 1, 2020 |
| > Rs.100 crore | January 1, 2021 |
| > Rs.50 crore | April 1, 2021 |
| > Rs.20 crore | April 1, 2022 |
| > Rs.10 crore | October 1, 2022 |
| > Rs.5 crore | August 1, 2023 |

### E-Invoice Process

```
1. Generate invoice data in JSON format (IRP schema)
2. POST to Invoice Registration Portal (IRP) API
3. IRP validates and returns IRN (Invoice Reference Number)
4. IRP returns QR code (to be printed on invoice)
5. Invoice is valid only with IRN and QR code
6. IRP pushes data to GST portal (auto-populates GSTR-1)
```

### IRN Structure

The IRN (Invoice Reference Number) is a 64-character SHA-256 hash of:
- Supplier GSTIN
- Financial Year (YYYY-YY)
- Document Type (INV/CRN/DBN)
- Document Number

```sql
-- IRN generation in PostgreSQL
irn = encode(sha256(
  (seller_gstin || financial_year || document_type || invoice_number)::bytea
), 'hex');
```

---

## Audit and Record-Keeping

### Mandatory Records (Section 35, CGST Act)

Every registered person must maintain:

1. Production or manufacture records
2. Inward and outward supply of goods/services
3. Stock of goods
4. Input tax credit availed
5. Output tax payable and paid
6. Any other prescribed records

### Retention Period

| Record Type | Retention Period |
|------------|------------------|
| All GST records | 72 months (6 years) from due date of annual return |
| Pending litigation | Until litigation is finally settled |
| E-invoice IRN | As part of invoice records (72 months) |

### System Audit Requirements

This system maintains audit compliance through:

1. **Immutable audit_log table** — Every change to every GST table is logged with user, timestamp, and before/after state
2. **Invoice amendment history** — All invoice amendments are tracked with original and revised values
3. **GSTR filing log** — Filing status, filing date, and acknowledgment number per return
4. **ITC reversal log** — Track ITC reversed under Rule 42, 43, and voluntary reversals
5. **Trigger-based enforcement** — Filed-period lock prevents modification of invoices in a filed GSTR-1 period

### Record Extraction for Audit

```sql
-- All invoices for a GSTIN in a period (for audit)
SELECT * FROM gst.v_invoice_tax_summary
WHERE seller_gstin = '27AABCU9603R1ZX'
  AND supply_date BETWEEN '2024-04-01' AND '2025-03-31'
ORDER BY supply_date;

-- Audit trail for a specific invoice
SELECT changed_by, changed_at, operation, old_data, new_data
FROM gst.audit_log
WHERE table_name = 'tax_invoice'
  AND new_data->>'invoice_number' = 'INV/MH/2526/000001'
ORDER BY changed_at;

-- ITC utilization for a period
SELECT * FROM gst.v_itc_monthly_summary
WHERE gstin = '27AABCU9603R1ZX'
  AND period = '052025';
```

---

## Reference Documents

| Document | Source |
|----------|--------|
| CGST Act, 2017 | https://cbic-gst.gov.in |
| GST Rate Schedule (Goods) | CGST Notification 01/2017 and amendments |
| HSN Explanatory Notes | WCO (World Customs Organization) |
| E-Invoice Schema | https://einvoice1.gst.gov.in |
| GSTIN Validation Rules | GSTN technical specification |
| ITC Rules | CGST Rules 2017, Rules 36-44 |

---

*This document reflects GST provisions as of June 2025. Tax rates and compliance requirements are subject to change by the GST Council. Always verify with the latest CBIC notifications before filing returns.*
