CLASS zcl_finn_invoice_extractor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_pdf_upload,
        pdf_content    TYPE xstring,
        pdf_filename   TYPE string,
        pdf_mime_type  TYPE string,
      END OF ty_pdf_upload,

      BEGIN OF ty_extracted_data,
        invoice_number TYPE xblnr,
        vendor_number  TYPE lifnr,
        vendor_name    TYPE string,
        company_code   TYPE bukrs,
        invoice_date   TYPE bldat,
        document_date  TYPE bldat,
        posting_date   TYPE budat,
        currency       TYPE waers,
        gross_amount   TYPE wrbtr,
        net_amount     TYPE wrbtr,
        tax_amount     TYPE wrbtr,
        po_number      TYPE ebeln,
        confidence     TYPE p LENGTH 5 DECIMALS 2,
      END OF ty_extracted_data,

      BEGIN OF ty_extracted_item,
        item_number    TYPE posnr,
        description    TYPE sgtxt,
        gl_account     TYPE hkont,
        cost_center    TYPE kostl,
        amount         TYPE wrbtr,
        tax_code       TYPE mwskz,
        quantity       TYPE menge_d,
        unit           TYPE meins,
        confidence     TYPE p LENGTH 5 DECIMALS 2,
      END OF ty_extracted_item,

      tt_extracted_items TYPE STANDARD TABLE OF ty_extracted_item WITH DEFAULT KEY,

      BEGIN OF ty_extraction_result,
        success      TYPE abap_bool,
        header       TYPE ty_extracted_data,
        items        TYPE tt_extracted_items,
        error_msg    TYPE string,
        pdf_url      TYPE string,
      END OF ty_extraction_result.

    METHODS constructor.

    " Main extraction method
    METHODS extract_from_pdf
      IMPORTING
        is_pdf_upload        TYPE ty_pdf_upload
      RETURNING
        VALUE(rs_result)     TYPE ty_extraction_result.

  PRIVATE SECTION.

    " Store PDF (could be DMS, archive, or database)
    METHODS store_pdf
      IMPORTING
        iv_content           TYPE xstring
        iv_filename          TYPE string
      RETURNING
        VALUE(rv_pdf_url)    TYPE string.

    " Call OCR service (simulated for demo)
    METHODS call_ocr_service
      IMPORTING
        iv_pdf_content       TYPE xstring
      RETURNING
        VALUE(rs_result)     TYPE ty_extraction_result.

    " Simulate OCR extraction (for demo/testing)
    METHODS simulate_extraction
      IMPORTING
        iv_pdf_content       TYPE xstring
      RETURNING
        VALUE(rs_result)     TYPE ty_extraction_result.

ENDCLASS.

CLASS zcl_finn_invoice_extractor IMPLEMENTATION.

  METHOD constructor.
    " Initialize if needed
  ENDMETHOD.

  METHOD extract_from_pdf.

    " Step 1: Store PDF
    DATA(lv_pdf_url) = store_pdf(
      iv_content = is_pdf_upload-pdf_content
      iv_filename = is_pdf_upload-pdf_filename
    ).

    " Step 2: Call OCR service (or simulate)
    rs_result = simulate_extraction( is_pdf_upload-pdf_content ).
    rs_result-pdf_url = lv_pdf_url.

    " For production, replace simulate_extraction with:
    " rs_result = call_ocr_service( is_pdf_upload-pdf_content ).

  ENDMETHOD.

  METHOD store_pdf.
    " For demo: Generate a mock URL
    " In production: Store in DMS, archive, or custom table

    DATA(lv_timestamp) = sy-datum && sy-uzeit.
    rv_pdf_url = |https://finn-invoices.example.com/pdf/{ lv_timestamp }/{ iv_filename }|.

    " TODO: Implement actual storage
    " Option 1: Store in custom table ZFINN_PDF_STORE
    " Option 2: Use SAP DMS (Document Management System)
    " Option 3: Store in external storage (S3, Azure Blob)

  ENDMETHOD.

  METHOD call_ocr_service.
    " TODO: Implement real OCR service call
    " Example services:
    " - AWS Textract
    " - Azure Form Recognizer
    " - SAP Document Information Extraction
    " - Google Document AI

    " Placeholder for HTTP client call
    DATA: lo_http_client TYPE REF TO if_http_client.

    " Example structure:
    " 1. Convert XSTRING to Base64
    " 2. Call OCR API endpoint
    " 3. Parse JSON response
    " 4. Map to rs_result structure

  ENDMETHOD.

  METHOD simulate_extraction.
    " Simulate OCR extraction for demo purposes
    " Returns sample invoice data

    rs_result-success = abap_true.

    " Simulate extracted header data
    rs_result-header-invoice_number = |INV-{ sy-datum }|.
    rs_result-header-vendor_number = '104405'.  " Valid vendor from your system
    rs_result-header-vendor_name = 'Demo Supplier GmbH'.
    rs_result-header-company_code = '0001'.
    rs_result-header-invoice_date = sy-datum.
    rs_result-header-document_date = sy-datum.
    rs_result-header-posting_date = sy-datum.
    rs_result-header-currency = 'EUR'.
    rs_result-header-gross_amount = '1190.00'.
    rs_result-header-net_amount = '1000.00'.
    rs_result-header-tax_amount = '190.00'.
    rs_result-header-po_number = ''.
    rs_result-header-confidence = '0.95'.  " 95% confidence

    " Simulate extracted line items
    APPEND VALUE #(
      item_number = '0001'
      description = 'Professional Services - May 2026'
      gl_account = '202004'  " Valid GL from your system
      cost_center = ''
      amount = '500.00'
      tax_code = ''
      quantity = '1'
      unit = 'EA'
      confidence = '0.92'
    ) TO rs_result-items.

    APPEND VALUE #(
      item_number = '0002'
      description = 'Software License'
      gl_account = '202006'  " Valid GL from your system
      cost_center = ''
      amount = '500.00'
      tax_code = ''
      quantity = '1'
      unit = 'EA'
      confidence = '0.89'
    ) TO rs_result-items.

    " Add a note that this is simulated
    rs_result-error_msg = 'Demo mode: Using simulated OCR extraction'.

  ENDMETHOD.

ENDCLASS.
