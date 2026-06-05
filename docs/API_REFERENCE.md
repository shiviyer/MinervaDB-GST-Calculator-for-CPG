# API Reference

> **MinervaDB GST Calculator for CPG** — Complete PostgREST endpoint catalog.
>
> Base URL: `http://localhost:3000` (development) | `https://api.your-domain.com` (production)
> OpenAPI Spec: `http://localhost:8080` (Swagger UI, live from database schema)

---

## Authentication

### JWT Bearer Token

All write operations and most read operations require a JWT Bearer token in the `Authorization` header.

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Required JWT Claims

| Claim | Type | Required | Description |
|-------|------|----------|-------------|
| `role` | string | Yes | `gst_user` or `gst_admin` |
| `gstin` | string | Yes | 15-char GSTIN (enforces RLS) |
| `sub` | string | Yes | User identifier (audit trail) |
| `exp` | number | Recommended | Expiry timestamp (Unix epoch) |

### Generating a Test Token

```bash
# Using jwt-cli (brew install mike-engel/jwt-cli/jwt-cli)
jwt encode \
  --secret "$JWT_SECRET" \
  --exp="+8h" \
  '{"role":"gst_user","gstin":"27AABCU9603R1ZX","sub":"user@company.com"}'

# Using Python (pip install PyJWT)
python3 -c "
import jwt, datetime
payload = {
  'role': 'gst_user',
  'gstin': '27AABCU9603R1ZX',
  'sub': 'user@company.com',
  'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=8)
}
print(jwt.encode(payload, '$JWT_SECRET', algorithm='HS256'))
"
```

### Role Permissions

| Role | GET (views) | POST /rpc/ | POST/PATCH/DELETE (tables) | Admin |
|------|------------|------------|---------------------------|-------|
| `gst_readonly` (anon) | Read-only views | None | None | No |
| `gst_user` | All views | All functions | Transactions | No |
| `gst_admin` | All | All | All including master data | Yes |

---

## RPC Functions (POST /rpc/)

All PL/pgSQL functions in the `gst` schema are exposed as `POST /rpc/<function_name>` endpoints.
Parameters are passed as a JSON object in the request body.

---

### Tax Calculation

#### `calculate_invoice_tax`

Calculates GST components (CGST/SGST or IGST + Cess) for a supply.

**Endpoint:** `POST /rpc/calculate_invoice_tax`
**Auth:** Required (gst_user or gst_readonly)

**Request Body:**

```json
{
  "p_seller_gstin":   "27AABCU9603R1ZX",
  "p_buyer_gstin":    "29BBBCA1234C1Z5",
  "p_hsn_code":       "1905",
  "p_supply_value":   100000.00,
  "p_seller_state":   "MH",
  "p_buyer_state":    "KA",
  "p_transaction_dt": "2025-06-01",
  "p_is_rcm":         false
}
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `p_seller_gstin` | text | Yes | 15-char seller GSTIN |
| `p_buyer_gstin` | text | No | 15-char buyer GSTIN (null for B2C) |
| `p_hsn_code` | text | Yes | 4 or 8-digit HSN code |
| `p_supply_value` | numeric | Yes | Taxable value (excluding GST) |
| `p_seller_state` | text | Yes | Seller state code (e.g., MH, KA, DL) |
| `p_buyer_state` | text | Yes | Buyer state code |
| `p_transaction_dt` | date | Yes | Supply date (for rate history lookup) |
| `p_is_rcm` | boolean | No | Reverse charge mechanism (default: false) |

**Response:**

```json
{
  "supply_type":    "INTER_STATE",
  "hsn_code":       "1905",
  "taxable_value":  100000.00,
  "cgst_rate":      0.00,
  "cgst_amount":    0.00,
  "sgst_rate":      0.00,
  "sgst_amount":    0.00,
  "igst_rate":      18.00,
  "igst_amount":    18000.00,
  "cess_rate":      0.00,
  "cess_amount":    0.00,
  "total_tax":      18000.00,
  "invoice_value":  118000.00,
  "is_rcm":         false
}
```

**Example — Intra-state sale:**

```bash
curl -s -X POST http://localhost:3000/rpc/calculate_invoice_tax \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "p_seller_gstin":   "27AABCU9603R1ZX",
    "p_buyer_gstin":    "27BBBCA5678D1Z3",
    "p_hsn_code":       "2106",
    "p_supply_value":   50000.00,
    "p_seller_state":   "MH",
    "p_buyer_state":    "MH",
    "p_transaction_dt": "2025-06-01"
  }' | python3 -m json.tool

# Response: CGST 9% + SGST 9% = Rs. 9000 total
```

---

### Rate Lookup

#### `get_gst_rate`

Looks up the effective GST rate for an HSN code as of a given date.

**Endpoint:** `POST /rpc/get_gst_rate`
**Auth:** Optional (anon access allowed)

```bash
curl -X POST http://localhost:3000/rpc/get_gst_rate \
  -H 'Content-Type: application/json' \
  -d '{"p_hsn_code": "1905", "p_as_of_date": "2025-06-01"}'
```

**Response:**
```json
{
  "hsn_code":   "1905",
  "description": "Bread, pastry, cakes, biscuits",
  "cgst_rate":  9.00,
  "sgst_rate":  9.00,
  "igst_rate":  18.00,
  "cess_rate":  0.00,
  "effective_from": "2017-07-01"
}
```

#### `lookup_hsn_for_product`

Searches HSN codes by product description keyword.

```bash
curl -X POST http://localhost:3000/rpc/lookup_hsn_for_product \
  -H 'Content-Type: application/json' \
  -d '{"p_keyword": "biscuit"}'
```

---

### Place of Supply

#### `determine_place_of_supply`

Determines place of supply and tax type (CGST/SGST or IGST).

**Endpoint:** `POST /rpc/determine_place_of_supply`

```bash
curl -X POST http://localhost:3000/rpc/determine_place_of_supply \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "p_seller_gstin": "27AABCU9603R1ZX",
    "p_buyer_gstin":  "29BBBCA1234C1Z5",
    "p_supply_type":  "GOODS"
  }'
```

**Response:**
```json
{
  "place_of_supply": "KA",
  "supply_type":     "INTER_STATE",
  "tax_type":        "IGST",
  "seller_state":    "MH",
  "buyer_state":     "KA"
}
```

---

### Invoice Management

#### `create_tax_invoice`

Creates a GST-compliant tax invoice with auto-calculated tax.

**Endpoint:** `POST /rpc/create_tax_invoice`
**Auth:** Required (gst_user minimum)

```bash
curl -X POST http://localhost:3000/rpc/create_tax_invoice \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "p_seller_gstin": "27AABCU9603R1ZX",
    "p_buyer_gstin":  "29BBBCA1234C1Z5",
    "p_supply_date":  "2025-06-01",
    "p_dispatch_from_state": "MH",
    "p_line_items": [
      {
        "hsn_code":    "1905",
        "description": "Bourbon Biscuits 200g",
        "quantity":    100,
        "unit":        "PKT",
        "unit_price":  50.00,
        "discount":    0.00
      },
      {
        "hsn_code":    "2106",
        "description": "Protein Bar 40g",
        "quantity":    50,
        "unit":        "PKT",
        "unit_price":  120.00,
        "discount":    500.00
      }
    ]
  }'
```

**Response:**
```json
{
  "invoice_id":      "550e8400-e29b-41d4-a716-446655440000",
  "invoice_number":  "INV/MH/2526/000001",
  "invoice_date":    "2025-06-01",
  "seller_gstin":    "27AABCU9603R1ZX",
  "buyer_gstin":     "29BBBCA1234C1Z5",
  "taxable_value":   10500.00,
  "total_cgst":      0.00,
  "total_sgst":      0.00,
  "total_igst":      1890.00,
  "total_cess":      0.00,
  "invoice_value":   12390.00,
  "status":          "DRAFT"
}
```

#### `cancel_invoice`

Cancels a non-filed invoice.

**Endpoint:** `POST /rpc/cancel_invoice`
**Auth:** Required (gst_user minimum)

```bash
curl -X POST http://localhost:3000/rpc/cancel_invoice \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "p_invoice_id": "550e8400-e29b-41d4-a716-446655440000",
    "p_reason":     "Goods returned by buyer"
  }'
```

**Response:**
```json
{"invoice_id": "550e8400...", "status": "CANCELLED", "cancelled_at": "2025-06-02T10:30:00Z"}
```

**Error — Cannot cancel filed invoice:**
```json
{"code": "P0001", "details": null, "hint": null, "message": "Cannot cancel invoice: GSTR-1 has been filed for period 052025"}
```

#### `create_credit_note`

Issues a credit note against an original invoice.

**Endpoint:** `POST /rpc/create_credit_note`
**Auth:** Required (gst_user minimum)

```bash
curl -X POST http://localhost:3000/rpc/create_credit_note \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "p_original_invoice_id": "550e8400-e29b-41d4-a716-446655440000",
    "p_credit_amount":       5000.00,
    "p_reason":              "Trade discount post-supply",
    "p_note_date":           "2025-06-15"
  }'
```

#### `get_invoice_summary`

Returns a summary of an invoice including all tax components.

```bash
curl -X POST http://localhost:3000/rpc/get_invoice_summary \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"p_invoice_id": "550e8400-e29b-41d4-a716-446655440000"}'
```

---

### ITC Engine

#### `compute_itc_eligibility`

Determines ITC eligibility for a purchase invoice under CGST Act Section 16 and 17(5).

**Endpoint:** `POST /rpc/compute_itc_eligibility`

```bash
curl -X POST http://localhost:3000/rpc/compute_itc_eligibility \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "p_invoice_id":       "550e8400-e29b-41d4-a716-446655440000",
    "p_business_purpose": "TAXABLE_SUPPLY",
    "p_is_capital_goods":  false
  }'
```

**Response:**
```json
{
  "eligible":          true,
  "igst_eligible":     18000.00,
  "cgst_eligible":     0.00,
  "sgst_eligible":     0.00,
  "blocked_reason":    null,
  "section_reference": "Sec 16(1) CGST Act"
}
```

#### `utilize_itc`

Applies available ITC balance against output tax liability.

```bash
curl -X POST http://localhost:3000/rpc/utilize_itc \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "p_gstin":          "27AABCU9603R1ZX",
    "p_tax_period":     "052025",
    "p_igst_liability": 50000.00,
    "p_cgst_liability": 20000.00,
    "p_sgst_liability": 20000.00
  }'
```

---

### GSTR Return Preparation

#### `prepare_gstr1_data`

Aggregates outward supply data into GSTR-1 return format.

**Endpoint:** `POST /rpc/prepare_gstr1_data`

```bash
curl -X POST http://localhost:3000/rpc/prepare_gstr1_data \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "p_gstin":  "27AABCU9603R1ZX",
    "p_month":  5,
    "p_year":   2025
  }'
```

**Response structure:**
```json
{
  "gstin":      "27AABCU9603R1ZX",
  "period":     "052025",
  "b2b": [
    {
      "buyer_gstin":    "29BBBCA1234C1Z5",
      "invoice_count":  12,
      "taxable_value":  500000.00,
      "igst_amount":    90000.00,
      "cgst_amount":    0.00,
      "sgst_amount":    0.00
    }
  ],
  "b2cs": [{"state": "MH", "rate": 18, "taxable_value": 25000.00}],
  "nil_rated": {"taxable_value": 10000.00},
  "hsn_summary": [{"hsn_code": "1905", "description": "Biscuits", "uqc": "PKT", "quantity": 500, "taxable_value": 25000.00}]
}
```

#### `prepare_gstr3b_data`

Aggregates inward and outward supply data for GSTR-3B.

```bash
curl -X POST http://localhost:3000/rpc/prepare_gstr3b_data \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"p_gstin": "27AABCU9603R1ZX", "p_month": 5, "p_year": 2025}'
```

**Response — Section 3.1 (Outward Supplies):**
```json
{
  "section_3_1": {
    "taxable_outward":  {"taxable_value": 525000.00, "igst": 90000.00, "cgst": 9000.00, "sgst": 9000.00, "cess": 0.00},
    "nil_exempt":       {"inter_state": 5000.00, "intra_state": 10000.00},
    "rcm_inward":       {"taxable_value": 0.00, "igst": 0.00, "cgst": 0.00, "sgst": 0.00}
  },
  "section_4": {
    "itc_available": {"igst": 45000.00, "cgst": 4500.00, "sgst": 4500.00, "cess": 0.00},
    "itc_reversed":  {"rule_42_43": 0.00, "other": 0.00}
  }
}
```

---

## Views (GET /v_<view_name>)

Views support the full PostgREST filtering syntax:
- `?column=eq.value` — exact match
- `?column=gte.value` — greater than or equal
- `?column=like.*pattern*` — LIKE filter
- `?select=col1,col2` — column selection
- `?order=col.asc` — ordering
- `?limit=100&offset=0` — pagination

---

### Tax Summary Views

#### `GET /v_invoice_tax_summary`

Invoice-level tax summary with GSTIN, period, and all tax components.

```bash
# All invoices for a GSTIN in a period
curl "http://localhost:3000/v_invoice_tax_summary?seller_gstin=eq.27AABCU9603R1ZX&period=eq.052025" \
  -H "Authorization: Bearer $TOKEN"

# Invoices above Rs. 1 lakh
curl "http://localhost:3000/v_invoice_tax_summary?invoice_value=gte.100000&order=invoice_value.desc" \
  -H "Authorization: Bearer $TOKEN"
```

#### `GET /v_monthly_tax_liability`

Aggregated monthly tax liability by GSTIN and tax head.

```bash
curl "http://localhost:3000/v_monthly_tax_liability?gstin=eq.27AABCU9603R1ZX&order=period.desc&limit=12" \
  -H "Authorization: Bearer $TOKEN"
```

**Sample Response:**
```json
[
  {
    "gstin":         "27AABCU9603R1ZX",
    "period":        "052025",
    "taxable_value": 1250000.00,
    "total_igst":    90000.00,
    "total_cgst":    45000.00,
    "total_sgst":    45000.00,
    "total_cess":    0.00,
    "total_tax":     180000.00
  }
]
```

#### `GET /v_hsn_wise_summary`

HSN-wise outward supply summary for GSTR-1 Table 12.

```bash
curl "http://localhost:3000/v_hsn_wise_summary?gstin=eq.27AABCU9603R1ZX&period=eq.052025" \
  -H "Authorization: Bearer $TOKEN"
```

---

### ITC Views

#### `GET /v_itc_balance`

Current ITC opening/closing balance by GSTIN and tax head.

```bash
curl "http://localhost:3000/v_itc_balance?gstin=eq.27AABCU9603R1ZX" \
  -H "Authorization: Bearer $TOKEN"
```

**Sample Response:**
```json
[
  {
    "gstin":          "27AABCU9603R1ZX",
    "igst_balance":   45000.00,
    "cgst_balance":   12000.00,
    "sgst_balance":   12000.00,
    "cess_balance":   0.00
  }
]
```

#### `GET /v_itc_monthly_summary`

Month-wise ITC credit, utilization, and closing balance.

```bash
curl "http://localhost:3000/v_itc_monthly_summary?gstin=eq.27AABCU9603R1ZX&order=period.desc" \
  -H "Authorization: Bearer $TOKEN"
```

#### `GET /v_itc_blocked_credits`

ITC credits blocked under Section 17(5) (motor vehicles, personal use, etc.).

```bash
curl "http://localhost:3000/v_itc_blocked_credits?gstin=eq.27AABCU9603R1ZX" \
  -H "Authorization: Bearer $TOKEN"
```

---

### GSTR Views

#### `GET /v_gstr1_b2b`

B2B outward supplies for GSTR-1 Table 4A.

```bash
curl "http://localhost:3000/v_gstr1_b2b?gstin=eq.27AABCU9603R1ZX&period=eq.052025" \
  -H "Authorization: Bearer $TOKEN"
```

**Sample Response:**
```json
[
  {
    "seller_gstin":  "27AABCU9603R1ZX",
    "buyer_gstin":   "29BBBCA1234C1Z5",
    "period":        "052025",
    "invoice_count": 5,
    "taxable_value": 250000.00,
    "igst_amount":   45000.00,
    "cgst_amount":   0.00,
    "sgst_amount":   0.00
  }
]
```

#### `GET /v_gstr1_b2cs_summary`

B2C (small) outward supplies aggregated by state and rate for GSTR-1 Table 7.

```bash
curl "http://localhost:3000/v_gstr1_b2cs_summary?gstin=eq.27AABCU9603R1ZX&period=eq.052025" \
  -H "Authorization: Bearer $TOKEN"
```

#### `GET /v_gstr1_cdnr`

Credit/Debit notes against registered persons for GSTR-1 Table 9B.

```bash
curl "http://localhost:3000/v_gstr1_cdnr?gstin=eq.27AABCU9603R1ZX&period=eq.052025" \
  -H "Authorization: Bearer $TOKEN"
```

#### `GET /v_gstr3b_outward_summary`

Outward supply summary for GSTR-3B Section 3.1.

```bash
curl "http://localhost:3000/v_gstr3b_outward_summary?gstin=eq.27AABCU9603R1ZX&period=eq.052025" \
  -H "Authorization: Bearer $TOKEN"
```

#### `GET /v_gstr_filing_status`

GSTR-1 and GSTR-3B filing status by period.

```bash
curl "http://localhost:3000/v_gstr_filing_status?gstin=eq.27AABCU9603R1ZX&order=period.desc" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Error Responses

PostgREST returns standard HTTP status codes with a JSON error body.

| Status | Meaning |
|--------|---------|
| 200 | Success |
| 400 | Bad request — invalid parameters |
| 401 | Unauthorized — missing or invalid JWT |
| 403 | Forbidden — insufficient role permissions |
| 404 | Not found |
| 406 | Not acceptable — add `Accept: application/json` header |
| 409 | Conflict — e.g., duplicate invoice number |
| 422 | Unprocessable entity — constraint violation |
| 500 | Internal server error |

### Error Body Format

```json
{
  "code":    "P0001",
  "details": "Invoice 550e8400... has status CANCELLED",
  "hint":    "Only DRAFT invoices can be submitted",
  "message": "Cannot modify invoice: invalid status transition"
}
```

### Common Error Codes

| Code | Description |
|------|-------------|
| `P0001` | Custom application error from PL/pgSQL RAISE EXCEPTION |
| `23505` | Unique constraint violation (duplicate invoice number) |
| `23514` | Check constraint violation (e.g., CGST rate must equal SGST rate) |
| `42501` | Insufficient privileges (wrong role) |
| `PGRST301` | JWT expired |
| `PGRST302` | JWT invalid |

---

## Pagination and Filtering

### Standard PostgREST Query Parameters

```bash
# Pagination
curl "http://localhost:3000/v_invoice_tax_summary?limit=50&offset=100"

# Filtering
curl "http://localhost:3000/v_invoice_tax_summary?period=eq.052025&total_tax=gte.10000"

# Column selection (reduces payload)
curl "http://localhost:3000/v_invoice_tax_summary?select=invoice_number,invoice_value,total_tax"

# Ordering
curl "http://localhost:3000/v_invoice_tax_summary?order=invoice_value.desc"

# Count total records
curl "http://localhost:3000/v_invoice_tax_summary" \
  -H "Prefer: count=exact" \
  -I  # Read X-Total-Count from response headers
```

### Filter Operators

| Operator | SQL Equivalent | Example |
|----------|----------------|---------|
| `eq` | `=` | `?status=eq.DRAFT` |
| `neq` | `!=` | `?status=neq.CANCELLED` |
| `gt` | `>` | `?invoice_value=gt.100000` |
| `gte` | `>=` | `?invoice_value=gte.50000` |
| `lt` | `<` | `?total_tax=lt.10000` |
| `lte` | `<=` | `?total_tax=lte.50000` |
| `like` | `LIKE` | `?invoice_number=like.INV/MH/*` |
| `ilike` | `ILIKE` | `?description=ilike.*biscuit*` |
| `in` | `IN` | `?status=in.(DRAFT,SUBMITTED)` |
| `is` | `IS` | `?buyer_gstin=is.null` |

---

## OpenAPI / Swagger

PostgREST auto-generates an OpenAPI 3.0 specification from the database schema.
Access the interactive documentation at:

```
http://localhost:8080   →  Swagger UI (full interactive API explorer)
http://localhost:3000/  →  Raw OpenAPI JSON spec
```

The spec includes all views, functions, and their parameter types — derived live from PostgreSQL's information_schema.

---

## Rate Limits

In production, configure rate limiting in your Nginx reverse proxy:

```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
limit_req      zone=api burst=20 nodelay;
limit_req_status 429;
```

The `max-rows = 1000` setting in `postgrest.conf` enforces a server-side row limit per response.

---

## SDK Examples

### Python

```python
import requests

BASE_URL = 'http://localhost:3000'
TOKEN = 'your-jwt-token'

headers = {
    'Authorization': f'Bearer {TOKEN}',
    'Content-Type': 'application/json',
    'Accept': 'application/json'
}

# Calculate GST
resp = requests.post(f'{BASE_URL}/rpc/calculate_invoice_tax', headers=headers, json={
    'p_seller_gstin': '27AABCU9603R1ZX',
    'p_buyer_gstin':  '29BBBCA1234C1Z5',
    'p_hsn_code':     '1905',
    'p_supply_value': 100000.00,
    'p_seller_state': 'MH',
    'p_buyer_state':  'KA',
    'p_transaction_dt': '2025-06-01'
})
print(resp.json())

# Get ITC balance
resp = requests.get(f'{BASE_URL}/v_itc_balance',
    headers=headers,
    params={'gstin': 'eq.27AABCU9603R1ZX'}
)
print(resp.json())
```

### JavaScript / Node.js

```javascript
const BASE_URL = 'http://localhost:3000';
const TOKEN = process.env.JWT_TOKEN;

const headers = {
  'Authorization': `Bearer ${TOKEN}`,
  'Content-Type': 'application/json'
};

// Calculate GST
const response = await fetch(`${BASE_URL}/rpc/calculate_invoice_tax`, {
  method: 'POST',
  headers,
  body: JSON.stringify({
    p_seller_gstin:   '27AABCU9603R1ZX',
    p_buyer_gstin:    '29BBBCA1234C1Z5',
    p_hsn_code:       '1905',
    p_supply_value:   100000.00,
    p_seller_state:   'MH',
    p_buyer_state:    'KA',
    p_transaction_dt: '2025-06-01'
  })
});
const data = await response.json();
console.log(data);
```

---

## Support

- Full OpenAPI spec: http://localhost:8080
- Issues: https://github.com/shiviyer/MinervaDB-GST-Calculator-for-CPG/issues
- MinervaDB: database@minervadb.xyz
