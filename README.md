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
├── 01_API_Creation/          # Invoice Intake API (Solution 1)
│   ├── ZCL_FINN_INVOICE_INTAKE_API.abap    # Core API logic (validation & storage)
│   ├── ZCL_FINN_INVOICE_INTAKE_HTTP.abap   # HTTP handler for REST endpoint
│   ├── Z_TEST_INVOICE_INTAKE_API.abap      # Success scenario test
│   ├── Z_TEST_INVOICE_INTAKE_ERROR.abap    # Error scenario test
│   └── README.md                            # API documentation
├── 02_AUTO_POST_ENGINE/      # Auto-Posting Engine (Solution 2)
│   ├── ZCL_FINN_AUTO_POST_ENGINE.abap      # Posting orchestration
│   ├── ZCL_FINN_BAPI_WRAPPER_FB60.abap     # FB60 BAPI wrapper
│   ├── ZCL_FINN_BAPI_WRAPPER_MIRO.abap     # MIRO BAPI wrapper
│   ├── Z_TEST_AUTO_POST_ENGINE.abap        # Posting test program
│   └── README.md                            # Posting engine documentation
├── ABAP_Classes/             # Shared utility classes
│   ├── ZBP_C_INVOICETRACKING.abap          # RAP behavior implementation
│   ├── ZCL_FINN_INVOICE_VALIDATOR.abap     # Validation utility (vendor, GL, duplicate checks)
│   └── ZCL_FINN_INVOICE_LOGGER.abap        # Audit logging
├── CDS_Views/                # CDS views and metadata extensions
│   ├── Z_I_InvoiceHeader.ddls              # Interface layer (header)
│   ├── Z_I_InvoiceItem.ddls                # Interface layer (items)
│   ├── Z_I_InvoiceLog.ddls                 # Interface layer (logs)
│   ├── Z_C_InvoiceTracking.ddls            # Consumption layer (header)
│   ├── Z_C_InvoiceItems.ddls               # Consumption layer (items)
│   ├── Z_C_InvoiceLogs.ddls                # Consumption layer (logs)
│   ├── Z_C_InvoiceTracking.bdef            # Behavior definition with draft
│   ├── Z_C_InvoiceTracking.metadata.ddlx   # UI annotations for header
│   ├── Z_C_InvoiceItems.metadata.ddlx      # UI annotations for line items
│   └── Z_C_InvoiceLogs.metadata.ddlx       # UI annotations for processing timeline
├── Database_Design/          # Database table DDL definitions
│   ├── ZFINN_INV_HRD.ddls                  # Invoice header table
│   ├── ZFINN_INV_ITEM.ddls                 # Invoice items table
│   ├── ZFINN_INV_LOG.ddls                  # Audit log table
│   └── Draft tables (ZFINN_INV_HRD_D, ZFINN_INV_ITEM_D)
├── finninvoicetracking/      # Fiori Elements UI5 application
│   ├── webapp/
│   │   ├── manifest.json     # App descriptor
│   │   ├── annotations/
│   │   │   └── annotation.xml              # Local OData annotations
│   │   └── localService/
│   │       └── mainService/
│   │           └── metadata.xml             # OData V4 service metadata
│   ├── ui5.yaml              # UI5 tooling configuration
│   └── package.json
├── Back_UP_Files/            # Archived implementations
├── images/                   # Application screenshots
├── GATEWAY_CLIENT_TESTING_GUIDE.md   # SAP Gateway Client testing instructions
├── INTERVIEW_PREPARATION.md          # Interview Q&A and technical deep dive
├── BAPI_DISCOVERY_GUIDE.md           # How to discover and analyze BAPIs
└── README.md                          # This file
```

## 🎯 Key Features

### Solution 1: Invoice Intake API (RESTful)
- **RESTful API endpoint** via ICF service (SICF transaction)
- **JSON-based data exchange** with external orchestration systems
- **Webhook callbacks** for asynchronous status updates
- **OCR confidence handling** with validation warnings
- **Alpha conversion** for vendor and GL account master data
- **Comprehensive error responses** with detailed validation messages

### Solution 2: Auto-Posting Engine (BAPI Integration)
- **BAPI wrapper classes** for FB60 and MIRO transactions
- **Multi-posting strategy** supporting PO and non-PO invoices
- **Automatic document type detection** and routing
- **Retry mechanism** for transient posting failures
- **SAP document number tracking** after successful posting

### Backend (ABAP RAP)
- **Draft-enabled entities** for OData V4 Edit functionality
- **Comprehensive validations:**
  - Vendor existence and blocking checks (LFA1/LFB1)
  - Duplicate invoice detection (BKPF + custom tables)
  - GL account validation (SKA1/SKB1)
  - Cost center and tax code validation
  - Posting period checks
- **Audit logging** with full event history stored in ZFINN_INV_LOG
- **Dynamic feature control** for status-based action visibility
- **UI annotations** with metadata extensions for proper field labels and layouts

### Frontend (Fiori Elements)
- **List Report + Object Page** pattern
- **Line Items table** with GL account, cost center, and amount details
- **Processing Timeline** showing audit log with timestamps and events
- **Value helps** for Supplier, Company Code, Currency, GL Account, Cost Center, etc.
- **Responsive design** with adaptive layouts
- **Criticality-based coloring** for status and severity indicators


---

## 📚 Technical Architecture

### Data Model
- **ZFINN_INV_HRD** - Invoice header table (active data)
- **ZFINN_INV_HRD_D** - Invoice header draft table (OData V4 draft support)
- **ZFINN_INV_ITEM** - Invoice line items table
- **ZFINN_INV_ITEM_D** - Invoice items draft table
- **ZFINN_INV_LOG** - Audit log and processing timeline

### CDS View Layers
- **Interface Views (Z_I_*)** - Direct database table access
  - Z_I_InvoiceHeader
  - Z_I_InvoiceItem
  - Z_I_InvoiceLog
- **Consumption Views (Z_C_*)** - Business logic and UI annotations
  - Z_C_InvoiceTracking (with metadata extension)
  - Z_C_InvoiceItems (with metadata extension)
  - Z_C_InvoiceLogs (with metadata extension)

### API Architecture
**Solution 1: Invoice Intake API**
```
External System → HTTP POST → ICF Service (ZFINN_INVOICE_INTAKE)
                              ↓
                   ZCL_FINN_INVOICE_INTAKE_HTTP
                              ↓
                   ZCL_FINN_INVOICE_INTAKE_API
                              ↓
         ┌──────────────────────┼──────────────────────┐
         ↓                      ↓                       ↓
  ZCL_FINN_INVOICE_    ZCL_FINN_INVOICE_     Database Tables
     VALIDATOR              LOGGER           (ZFINN_INV_*)
```



