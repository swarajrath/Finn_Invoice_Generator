# Auto-Posting Engine - Quick Summary

## Overview

Built an SAP ABAP engine to automatically post vendor invoices using standard BAPIs (FB60 and MIRO methods). Includes test mode for safe validation without committing data.

---

## Components Created

### 1. ZCL_FINN_AUTO_POST_ENGINE (Main Class)
**Purpose:** Core posting engine with BAPI integration

**Key Features:**
- FB60 posting (general vendor invoices)
- MIRO posting (PO-based invoices)
- Request validation
- Test mode support (rollback instead of commit)
- Structured JSON-compatible request/response types

**Main Methods:**
- `post_invoice_fb60()` - Posts vendor invoice via BAPI_ACC_DOCUMENT_POST
- `post_invoice_miro()` - Posts PO invoice via BAPI_INCOMINGINVOICE_CREATE
- `validate_fb60_request()` / `validate_miro_request()` - Field validation

---

### 2. Z_TEST_AUTO_POST_ENGINE (Test Program)
**Purpose:** Interactive test tool with selection screen

**Features:**
- Selection screen for easy parameter input
- Test mode checkbox (safe testing with rollback)
- Support for both FB60 and MIRO methods
- Detailed output with BAPI messages
- Unique timestamp-based references

**Selection Screen:**

![Selection Screen](Start%20of%20selection%20parameters.png)

---

## Test Mode Feature

**How it works:**
- BAPI executes completely (all validations run)
- Document number is generated
- **ROLLBACK** is called instead of COMMIT
- No data is saved to database
- No reversal needed
- Can run unlimited times

**Usage:**
```abap
ls_response = lo_engine->post_invoice_fb60(
  is_request = ls_request
  iv_testrun = abap_true    " Test mode ON
).
```

---

## API Specification - Required Fields by TCode

### FB60 - General Vendor Invoice Posting

**Use Case:** Post non-PO invoices (utilities, consulting, services without purchase order)

**Mandatory Fields:**
```json
{
  "posting_method": "FB60",
  "header": {
    "company_code": "1000",           // Required
    "posting_date": "2026-05-09",     // Required
    "document_date": "2026-05-09",    // Required
    "currency": "EUR"                 // Required
  },
  "vendor_line": {
    "vendor_number": "1000",          // Required
    "amount": 1000.00                 // Required (credit amount)
  },
  "gl_lines": [                       // Required (at least 1)
    {
      "gl_account": "400000",         // Required
      "amount": 1000.00               // Required (debit amount)
    }
  ]
}
```

**Optional Fields:**
```json
{
  "header": {
    "reference": "INV-2024-001",
    "doc_header_text": "Office supplies",
    "exchange_rate": 1.18,
    "posting_period": "05",
    "fiscal_year": "2026"
  },
  "vendor_line": {
    "special_gl_ind": "A",
    "payment_terms": "Z030",
    "baseline_date": "2026-05-09",
    "payment_method": "T",
    "payment_block": "A",
    "assignment": "INV-001",
    "text": "Payment for services"
  },
  "gl_lines": [
    {
      "tax_code": "V1",
      "cost_center": "CC1000",
      "profit_center": "PC1000",
      "internal_order": "1000123456",
      "wbs_element": "P-12345-01-01",
      "business_area": "BA01",
      "assignment": "PROJECT-A",
      "text": "Line item description",
      "quantity": 100,
      "unit": "EA",
      "value_date": "2026-05-09"
    }
  ]
}
```

---

### MIRO - Invoice Verification (PO-based)

**Use Case:** Post invoices against purchase orders with goods receipt

**Mandatory Fields:**
```json
{
  "posting_method": "MIRO",
  "header": {
    "company_code": "1000",           // Required
    "invoice_date": "2026-05-01",     // Required
    "posting_date": "2026-05-09",     // Required
    "currency": "EUR"                 // Required
  },
  "po_items": [                       // Required (at least 1)
    {
      "po_number": "4500012345",      // Required
      "po_item": "00010"              // Required
    }
  ]
}
```

**Optional Fields:**
```json
{
  "header": {
    "reference": "INV-2024-001",
    "header_text": "GR Invoice",
    "exchange_rate": 1.18,
    "calculate_tax": true,            // Default: true
    "gross_invoice": false            // Default: false
  },
  "po_items": [
    {
      "quantity": 100,                // Optional (uses PO quantity if not provided)
      "amount": 1000.00,              // Optional (calculated from PO price)
      "ok_indicator": true            // Default: true (delivery complete)
    }
  ]
}
```

---

### Response Structure (Both Methods)
```json
{
  "success": true,
  "document_number": "1900000001",
  "fiscal_year": "2026",
  "company_code": "1000",
  "posting_date": "2026-05-09",
  "error_code": null,
  "error_message": null,
  "warning_messages": [],
  "bapi_return": [
    {
      "type": "S",
      "id": "RW",
      "number": "605",
      "message": "Document 1900000001 2026 posted successfully"
    }
  ]
}
```

---

## Field Validation Rules

### FB60 Validations
| Field | Rule | Example |
|-------|------|---------|
| `company_code` | Must exist in T001 | "1000" |
| `vendor_number` | Must exist in LFB1 for company code | "1000" |
| `posting_date` | Must be in open posting period | "2026-05-09" |
| `currency` | Must be valid currency code (TCURC) | "EUR", "USD" |
| `gl_account` | Must exist in SKB1 for company code | "400000" |
| `amount` | Vendor amount = Sum of GL amounts | 1000.00 |

### MIRO Validations
| Field | Rule | Example |
|-------|------|---------|
| `po_number` | Must exist in EKKO | "4500012345" |
| `po_item` | Must exist in EKPO | "00010" |
| `quantity` | Cannot exceed remaining PO quantity | 100 |
| `amount` | Cannot exceed remaining PO amount | 1000.00 |
| Goods Receipt | Must have GR posted (MIGO) | Required |

---

## Testing Results

**Successful Test Output:**

![Test Output](Output%20screen.png)

---

## Key Validations

**FB60 Validations:**
- ✓ Company code exists
- ✓ Vendor exists in company code
- ✓ GL accounts exist and not blocked
- ✓ Currency is valid
- ✓ Amounts balance (vendor = sum of GL lines)

**MIRO Validations:**
- ✓ Purchase order exists
- ✓ Goods receipt posted
- ✓ Invoice quantity/amount within PO limits

---

## Files Delivered

### ABAP Classes
- `ZCL_FINN_AUTO_POST_ENGINE.abap` - Main posting engine class
- `Z_TEST_AUTO_POST_ENGINE.abap` - Test program

### Documentation
- `AUTO_POST_API_SPECIFICATION.md` - Complete JSON API field specification
- `AUTO_POST_TESTING_GUIDE.md` - Detailed testing instructions
- `TESTING_AND_REVERSAL_GUIDE.md` - Test mode and reversal options
- `FINDING_MASTER_DATA_GUIDE.md` - How to find valid master data

---