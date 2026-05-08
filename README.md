# FINN Invoice Tracking System

> **Finn Invoice Generator** - SAP Fiori application for automated invoice processing and tracking with RAP backend.

## 📋 Project Overview

FINN Invoice Tracking is an end-to-end invoice processing solution built on SAP BTP and ABAP RAP (RESTful Application Programming). The system automates invoice data extraction from PDF documents using OCR technology and provides a modern Fiori Elements UI for invoice management and tracking.

### Current Status: 🚧 In Development

**Completed Features:**
- ✅ List Report page with invoice overview
- ✅ Object Page with detailed invoice information
- ✅ Delete functionality for invoice records
- ✅ Multi-select support for bulk operations
- ✅ Draft table architecture for OData V4
- ✅ Backend validations (vendor checks, duplicate detection, GL account validation)
- ✅ Status tracking with color-coded indicators

**In Progress:**
- 🚧 Edit functionality (implementing draft-enabled behavior)
- 🚧 Document processing system for PDF invoice scanning and data extraction
- 🚧 OCR integration for automated invoice field recognition

**Planned:**
- 📅 Repost, Correct, and Cancel actions
- 📅 PDF viewer integration
- 📅 Approval workflow
- 📅 Bulk processing capabilities

---

## 📸 Application Screenshots

### List Report Page
The main dashboard displays all invoices with key information at a glance.

![List Report Page](images/List%20report%20page.png)

**Features:**
- Search and filter invoices by status, vendor, company code, or date range
- Status indicators (Success, Error, In Progress)
- Sortable columns with meaningful business labels
- Multi-select for bulk delete operations
- Quick navigation to invoice details

### Object Page
Detailed view of individual invoice with all associated information.

![Object Page](images/Object%20page.png)

**Features:**
- Header information with key metrics (Status, Gross Amount, Processing Time, OCR Confidence)
- General information section with invoice and document details
- Amounts breakdown (Gross, Net, Tax)
- Payment information (Terms, Baseline Date, Payment Block)
- Line items table with G/L account postings
- Error details section (when applicable)
- Processing timeline and audit information

### Additional Columns View
Extended table view showing additional invoice fields.

![Additional Columns](images/Additional%20columns.png)

---

## Project Structure

```
FINN_CaseStudy/
├── 01_Database_Design/      # Database table DDL definitions (header, items, log, draft tables)
├── ABAP_Classes/             # ABAP behavior implementations and utilities
│   ├── ZBP_C_INVOICETRACKING.abap          # RAP behavior implementation
│   ├── ZCL_FINN_INVOICE_VALIDATOR.abap     # Validation utility (vendor, GL, duplicate checks)
│   ├── ZCL_FINN_INVOICE_POSTER.abap        # BAPI wrapper for FI posting
│   ├── ZCL_FINN_INVOICE_LOGGER.abap        # Audit logging
│   └── ZCL_FINN_INVOICE_API_HANDLER.abap   # External API integration
├── CDS_Views/                # CDS views and behavior definitions
│   ├── Z_I_InvoiceHeader.ddls              # Interface layer (header)
│   ├── Z_I_InvoiceItem.ddls                # Interface layer (items)
│   ├── Z_C_InvoiceTracking.ddls            # Consumption layer (header)
│   ├── Z_C_InvoiceItems.ddls               # Consumption layer (items)
│   ├── Z_C_InvoiceTracking.bdef            # Behavior definition with draft
│   └── Z_C_InvoiceTracking.metadata.ddlx   # UI annotations
├── finninvoicetracking/      # Fiori Elements UI5 application
│   ├── webapp/
│   │   ├── manifest.json     # App descriptor
│   │   ├── annotations.xml   # OData annotations
│   │   └── ext/              # Controller extensions for custom actions
│   ├── ui5.yaml.template     # Template for backend configuration
│   └── package.json
├── images/                   # Application screenshots
└── .gitignore
```

## 🎯 Key Features

### Backend (ABAP RAP)
- **Draft-enabled entities** for OData V4 Edit functionality
- **Comprehensive validations:**
  - Vendor existence and blocking checks (LFA1/LFB1)
  - Duplicate invoice detection (BKPF + custom tables)
  - GL account validation (SKA1/SKB1)
  - Cost center and tax code validation
  - Posting period checks
- **BAPI integration** for posting to SAP FI (BAPI_ACC_DOCUMENT_POST)
- **Audit logging** with full event history
- **Dynamic feature control** for status-based action visibility

### Frontend (Fiori Elements)
- **List Report + Object Page** pattern
- **Value helps** for Supplier, Company Code, Currency, GL Account, Cost Center, etc.
- **Responsive design** with adaptive layouts
- **Type-safe TypeScript** controller extensions
- **OPA5 integration tests** for UI validation


---

## 📚 Technical Architecture

### Data Model
- **ZFINN_INV_HRD** - Invoice header table (active data)
- **ZFINN_INV_HRD_D** - Invoice header draft table (OData V4 draft support)
- **ZFINN_INV_ITEM** - Invoice line items table
- **ZFINN_INV_ITEM_D** - Invoice items draft table
- **ZFINN_INV_LOG** - Audit log and processing timeline


