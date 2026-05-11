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
- ✅ **PDF upload and extraction** with file browser UI (currently in demo mode with hardcoded values)
- ✅ **"Create from PDF" button** on List Report for creating invoices from PDF files
- ✅ **Automatic navigation** to Object Page after PDF upload
- ✅ **Auto-population of invoice fields** with extracted data (simulated)
- ✅ **Automatic line items creation** from extracted data

**In Progress:**
- 🚧 Real OCR integration (AWS Textract / Azure Form Recognizer / SAP Document Information Extraction)
- 🚧 PDF storage implementation (DMS / Archive / Custom table)

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

### PDF Upload - Create from PDF
Users can create new invoices by uploading PDF files directly from the List Report.

![Create from PDF](images/Create%20from%20pdf.png)

**Features:**
- File browser dialog for selecting PDF invoices from local system
- Upload button with "Create & Extract" action
- Automatic navigation to Object Page after upload
- Seamless user experience

### PDF Upload - Object Page After Extraction
After uploading a PDF, the invoice is automatically created and populated with extracted data.

![Object Page After PDF Upload](images/Object%20page%20edit%20after%20pdf%20upload.png)

**Features:**
- **Automatic field population** with extracted invoice data
- **Invoice Header**: Invoice Number, Vendor, Company Code, Dates, Amounts (currently hardcoded for demo)
- **Line Items**: Two line items automatically created with GL accounts, cost centers, and amounts
- **Status**: Set to "In Progress" (P) automatically
- **OCR Confidence**: Displayed in header (0.95 in demo mode)
- **Edit Mode**: User can review and modify extracted data before saving
- **Validation**: All master data validations run on save (vendor, GL account, etc.)

> **Note:** Current implementation uses **simulated extraction with hardcoded values** for demonstration purposes. The architecture is designed to easily integrate with real OCR services (AWS Textract, Azure Form Recognizer, or SAP Document Information Extraction). See `SAP_DI_INTEGRATION_GUIDE.md` for production OCR integration details.

**Hardcoded Demo Values:**
- Invoice Number: `INV` + 6-digit timestamp
- Vendor Number: `0000104405` (valid test vendor)
- Company Code: `0001`
- Currency: `USD`
- Gross Amount: `1190.00`
- Net Amount: `1000.00`
- Tax Amount: `190.00`
- Line Item 1: GL `0000400000`, Cost Center `1000`, Amount `500.00`
- Line Item 2: GL `0000476000`, Cost Center `2000`, Amount `500.00`

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



