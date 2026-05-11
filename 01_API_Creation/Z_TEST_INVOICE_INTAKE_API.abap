*&---------------------------------------------------------------------*
*& Report Z_TEST_INVOICE_INTAKE_API
*&---------------------------------------------------------------------*
*& Simple test program for Invoice Intake API
*&---------------------------------------------------------------------*
REPORT z_test_invoice_intake_api.

DATA: lo_api      TYPE REF TO zcl_finn_invoice_intake_api,
      ls_request  TYPE zcl_finn_invoice_intake_api=>ty_intake_request,
      ls_payload  TYPE zcl_finn_invoice_intake_api=>ty_extraction_payload,
      ls_response TYPE zcl_finn_invoice_intake_api=>ty_intake_response.

START-OF-SELECTION.

  " Generate unique invoice number with timestamp
  DATA(lv_timestamp) = sy-uzeit.
  DATA(lv_invoice_number) = |TEST-INV-{ lv_timestamp }|.

  " Clean up any previous test data
  " First check what exists
  SELECT COUNT(*) FROM zfinn_inv_hrd WHERE invoice_number LIKE 'TEST-INV-%' INTO @DATA(lv_count).
  IF lv_count > 0.
    WRITE: / 'Found', lv_count, 'existing test invoice(s). Deleting...'.

    " Delete items first (child records)
    DELETE FROM zfinn_inv_item WHERE header_uuid IN (
      SELECT header_uuid FROM zfinn_inv_hrd WHERE invoice_number LIKE 'TEST-INV-%'
    ).
    WRITE: / 'Deleted', sy-dbcnt, 'item records.'.

    " Delete header
    DELETE FROM zfinn_inv_hrd WHERE invoice_number LIKE 'TEST-INV-%'.
    WRITE: / 'Deleted', sy-dbcnt, 'header records.'.

    COMMIT WORK.
    WRITE: / 'Cleanup complete.'.
    WRITE: /.
  ELSE.
    WRITE: / 'No existing test data found.'.
    WRITE: /.
  ENDIF.

  WRITE: / 'Using Invoice Number:', lv_invoice_number.
  WRITE: /.

  " Initialize API
  lo_api = NEW zcl_finn_invoice_intake_api( ).

  " Build test request
  ls_request-orchestration_id = 'TEST_ORCH_001'.
  ls_request-correlation_id = 'TEST_CORR_001'.
  ls_request-document_id = 'TEST_DOC_001'.
  ls_request-document_url = 'https://example.com/test-invoice.pdf'.
  ls_request-source_system = 'TEST_RUNNER'.
  ls_request-processing_mode = 'AUTO'.
  ls_request-priority = 1.
  ls_request-callback_url = 'https://webhook.site/57b2d971-492c-4ec7-8b69-1b8e563c3a03'.

  " Build test header data with unique invoice number
  " NOTE: Using valid master data from your system to ensure validation passes
  ls_payload-header-invoice_number = lv_invoice_number.
  ls_payload-header-vendor_number = '104405'.  " Valid vendor from your system
  ls_payload-header-vendor_name = 'Test Supplier Ltd'.
  ls_payload-header-company_code = '0001'.
  ls_payload-header-invoice_date = '20260511'.
  ls_payload-header-document_date = '20260511'.
  ls_payload-header-posting_date = '20260511'.
  ls_payload-header-currency = 'EUR'.
  ls_payload-header-gross_amount = '1000.00'.
  ls_payload-header-net_amount = '840.34'.
  ls_payload-header-tax_amount = '159.66'.
  ls_payload-header-payment_terms = ''.  " Empty to avoid payment term validation errors
  ls_payload-header-po_number = ''.
  ls_payload-header-reference = 'REF-TEST-001'.
  ls_payload-header-confidence_score = '0.47'.  " Numeric packed decimal

  " Build test item data with valid GL accounts
  APPEND VALUE #(
    item_number = '0001'
    description = 'Test Item 1'
    gl_account = '202004'  " Valid GL from your system
    cost_center = ''       " Empty to avoid cost center validation
    amount = '500.00'
    tax_code = ''          " Empty to avoid tax code validation
    quantity = '10'
    unit = 'EA'
    confidence_score = '0.92'  " Numeric packed decimal
  ) TO ls_payload-items.

  APPEND VALUE #(
    item_number = '0002'
    description = 'Test Item 2'
    gl_account = '202006'  " Valid GL from your system
    cost_center = ''
    amount = '500.00'
    tax_code = ''
    quantity = '5'
    unit = 'EA'
    confidence_score = '0.88'  " Numeric packed decimal
  ) TO ls_payload-items.

  " Call API
  WRITE: / '========================================'.
  WRITE: / 'Testing Invoice Intake API'.
  WRITE: / '========================================'.
  WRITE: /.

  ls_response = lo_api->process_invoice_intake(
    is_request = ls_request
    is_extracted_data = ls_payload
  ).

  " Display results
  WRITE: / 'Response:'.
  WRITE: / '----------------------------------------'.
  WRITE: / 'Success:', ls_response-success.

  IF ls_response-invoice_uuid IS NOT INITIAL.
    WRITE: / 'Invoice UUID:', ls_response-invoice_uuid.
  ELSE.
    WRITE: / 'Invoice UUID: (EMPTY - UUID Generation Failed!)'.
  ENDIF.

  WRITE: / 'Status:', ls_response-status.
  WRITE: / 'Processing Time (ms):', ls_response-processing_time_ms.

  IF ls_response-success = abap_false.
    WRITE: / 'Error Code:', ls_response-error_code.
    WRITE: / 'Error Message:', ls_response-error_message.

    " Additional debug: Check if UUID generation works
    TRY.
        DATA(lv_test_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        WRITE: / 'Test UUID Generation: SUCCESS'.
        WRITE: / 'Sample UUID:', lv_test_uuid.
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        WRITE: / 'Test UUID Generation: FAILED -', lx_uuid->get_text( ).
    ENDTRY.
  ENDIF.

  IF ls_response-validation_issues IS NOT INITIAL.
    WRITE: / 'Validation Issues:'.
    WRITE: / ls_response-validation_issues.
  ENDIF.

  IF ls_response-validation_warnings IS NOT INITIAL.
    WRITE: / 'Validation Warnings:'.
    WRITE: / ls_response-validation_warnings.
  ENDIF.

  WRITE: / '----------------------------------------'.

  " Check database
  IF ls_response-invoice_uuid IS NOT INITIAL.
    SELECT SINGLE invoice_number, status, gross_amount, item_count
      FROM zfinn_inv_hrd
      INTO @DATA(ls_invoice)
      WHERE header_uuid = @ls_response-invoice_uuid.

    IF sy-subrc = 0.
      WRITE: /.
      WRITE: / 'Database Record Created:'.
      WRITE: / '  Invoice Number:', ls_invoice-invoice_number.
      WRITE: / '  Status:', ls_invoice-status.
      WRITE: / '  Gross Amount:', ls_invoice-gross_amount.
      WRITE: / '  Item Count:', ls_invoice-item_count.
    ENDIF.
  ENDIF.

  WRITE: /.
  WRITE: / '========================================'.
  WRITE: / 'Test Complete'.
  WRITE: / '========================================'.
