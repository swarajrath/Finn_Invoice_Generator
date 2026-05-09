# Invoice Intake API - Quick Summary

## Overview

Built a REST API endpoint in SAP to receive extracted invoice data from external document processing systems (orchestrators). The API validates data, creates invoice records in the database, and sends webhook callbacks for status updates.

---

## Architecture

```
External Orchestrator (Python/Node.js/Java)
           ↓
    HTTP POST (JSON)
           ↓
ZCL_FINN_INVOICE_INTAKE_HTTP (HTTP Handler)
           ↓
ZCL_FINN_INVOICE_INTAKE_API (Business Logic)
           ↓
    Database (ZFINN_INV_HRD / ZFINN_INV_ITEM)
           ↓
    Webhook Callback (Status Update)
```

---

## Components Created

### 1. ZCL_FINN_INVOICE_INTAKE_HTTP (HTTP Handler)
**Purpose:** REST endpoint for external systems

**Features:**
- Accepts POST requests only
- JSON request/response handling
- HTTP status codes (200/400/500)
- Error handling

**Endpoint:**
```
POST /sap/bc/http/finn_invoice_intake
Content-Type: application/json
```

---

### 2. ZCL_FINN_INVOICE_INTAKE_API (Business Logic)
**Purpose:** Core invoice processing logic

**Main Method:**
```abap
process_invoice_intake(
  is_request        TYPE ty_intake_request
  is_extracted_data TYPE ty_extraction_payload
) RETURNING rs_response TYPE ty_intake_response
```

**Features:**
- Validates extracted data using `ZCL_FINN_INVOICE_VALIDATOR`
- Creates invoice header and items in database
- Generates unique UUID for each invoice
- Logs events using `ZCL_FINN_INVOICE_LOGGER`
- Sends webhook callbacks for status updates
- Returns processing time in milliseconds

---

### 3. Z_TEST_INVOICE_INTAKE_API (Test Program)
**Purpose:** Test the API without HTTP calls

**Features:**
- Simulates orchestrator request
- Builds sample invoice data
- Tests database insertion
- Automatic cleanup of old test data
- Unique invoice numbers with timestamp

**Test Output:**

![Test Output](Invoice%20intake%20API%20output.png)

---

## Request Structure

### Intake Request (from Orchestrator)
```json
{
  "orchestration_id": "orch_20260509_001",
  "correlation_id": "corr_abc123",
  "document_id": "doc_inv_001",
  "document_url": "https://storage.example.com/invoice.pdf",
  "source_system": "OCR_ENGINE_V2",
  "processing_mode": "AUTO",
  "priority": 1,
  "callback_url": "https://orchestrator.example.com/callbacks",
  
  "header": {
    "invoice_number": "INV-2024-001",
    "vendor_number": "100045",
    "company_code": "1000",
    "invoice_date": "2024-05-01",
    "posting_date": "2024-05-07",
    "currency": "EUR",
    "gross_amount": 1710.00,
    "confidence_score": 0.95
  },
  
  "items": [
    {
      "item_number": "0001",
      "gl_account": "6000100",
      "amount": 500.00,
      "confidence_score": 0.92
    }
  ]
}
```

---

## Response Structure

### Success Response (200 OK)
```json
{
  "success": true,
  "invoice_uuid": "A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6",
  "status": "ACCEPTED",
  "validation_issues": null,
  "processing_time_ms": 156
}
```

### Error Response (400 Bad Request)
```json
{
  "success": false,
  "status": "ERROR",
  "error_code": "VALIDATION_FAILED",
  "error_message": "Vendor not found",
  "processing_time_ms": 89
}
```

---

## Database Tables

### ZFINN_INV_HRD (Invoice Header)
**Key Fields:**
- `HEADER_UUID` - Primary key (UUID)
- `INVOICE_NUMBER` - Invoice number from PDF
- `VENDOR_NUMBER` - Vendor
- `COMPANY_CODE` - Company code
- `STATUS` - Processing status (N=New, V=Validated, P=Posted)
- `EXTERNAL_DOC_ID` - Document ID from DMS
- `PDF_URL` - URL to original PDF
- `EXTRACTION_CONFIDENCE` - OCR confidence score

### ZFINN_INV_ITEM (Invoice Items)
**Key Fields:**
- `ITEM_UUID` - Primary key (UUID)
- `HEADER_UUID` - Foreign key to header
- `GL_ACCOUNT` - G/L account
- `AMOUNT` - Line item amount
- `COST_CENTER` - Cost center

---

## Webhook Callbacks

The API sends status updates back to the orchestrator:

```json
POST [callback_url]
{
  "orchestration_id": "orch_20260509_001",
  "invoice_uuid": "A1B2C3D4...",
  "status": "ACCEPTED",
  "message": "Invoice successfully received and validated",
  "timestamp": "2026-05-09T10:30:45.123Z"
}
```

**Status Values:**
- `ACCEPTED` - Initial acceptance
- `VALIDATED` - Validation completed
- `POSTED` - Posted to SAP FI
- `ERROR` - Processing error

---

## Key Features

✅ **UUID Generation:** Each invoice gets unique identifier  
✅ **Validation:** Uses existing validator class for data quality  
✅ **Database Persistence:** Stores header and items with transaction control  
✅ **Error Handling:** Comprehensive exception catching and rollback  
✅ **Webhook Support:** Asynchronous status updates to orchestrator  
✅ **Performance Tracking:** Returns processing time in milliseconds  
✅ **Audit Logging:** All events logged via logger class  

---

## Processing Flow

1. **Receive Request:** HTTP POST with JSON payload
2. **Parse JSON:** Deserialize to ABAP structures
3. **Validate Data:** Check vendor, accounts, amounts
4. **Generate UUID:** Create unique invoice identifier
5. **Insert Database:** Header + items in transaction
6. **Log Event:** Record intake in audit log
7. **Send Callback:** Notify orchestrator of status
8. **Return Response:** JSON with UUID and status

---

## Error Handling

**Common Errors:**
- `VALIDATION_ERROR` - Data validation failed
- `INVOICE_CREATE_ERROR` - Database insert failed
- `UUID_GENERATION_ERROR` - UUID creation failed
- `INTERNAL_ERROR` - Unexpected exception

**All errors trigger:**
- Automatic rollback
- Error callback to orchestrator
- Detailed error logging

---

## Files Delivered

### ABAP Classes
- `ZCL_FINN_INVOICE_INTAKE_API.abap` - Business logic
- `ZCL_FINN_INVOICE_INTAKE_HTTP.abap` - HTTP handler
- `Z_TEST_INVOICE_INTAKE_API.abap` - Test program

---

## Testing

**Test Program Results:**
- ✅ Invoice UUID generated successfully
- ✅ Database records created (header + items)
- ✅ Validation executed
- ✅ Status callbacks sent
- ✅ Processing time tracked

---
