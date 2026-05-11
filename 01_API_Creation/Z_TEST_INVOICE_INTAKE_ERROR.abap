*&---------------------------------------------------------------------*
*& Report Z_TEST_INVOICE_INTAKE_ERROR
*&---------------------------------------------------------------------*
*& Test program to demonstrate validation errors in Invoice Intake API
*&---------------------------------------------------------------------*
REPORT z_test_invoice_intake_error.

DATA: lo_api      TYPE REF TO zcl_finn_invoice_intake_api,
      ls_request  TYPE zcl_finn_invoice_intake_api=>ty_intake_request,
      ls_payload  TYPE zcl_finn_invoice_intake_api=>ty_extraction_payload,
      ls_response TYPE zcl_finn_invoice_intake_api=>ty_intake_response.

PARAMETERS: p_test TYPE char1 DEFAULT '1'.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text001.
  SELECTION-SCREEN COMMENT /1(60) comm1.
  SELECTION-SCREEN COMMENT /1(60) comm2.
  SELECTION-SCREEN COMMENT /1(60) comm3.
  SELECTION-SCREEN COMMENT /1(60) comm4.
  SELECTION-SCREEN COMMENT /1(60) comm5.
SELECTION-SCREEN END OF BLOCK b1.

INITIALIZATION.
  text001 = 'Error Test Scenarios'.
  comm1 = '1 = Invalid Vendor Number'.
  comm2 = '2 = Invalid GL Account'.
  comm3 = '3 = Missing Mandatory Field (Company Code)'.
  comm4 = '4 = Invalid Currency'.
  comm5 = '5 = All Valid (Success Test)'.

START-OF-SELECTION.

  " Generate unique invoice number
  DATA(lv_timestamp) = sy-uzeit.
  DATA(lv_invoice_number) = |TEST-ERR-{ lv_timestamp }|.

  " Initialize API
  lo_api = NEW zcl_finn_invoice_intake_api( ).

  " Build base request
  ls_request-orchestration_id = 'TEST_ERROR_001'.
  ls_request-correlation_id = 'TEST_CORR_ERR_001'.
  ls_request-document_id = 'TEST_DOC_ERR_001'.
  ls_request-document_url = 'https://example.com/test-invoice-error.pdf'.
  ls_request-source_system = 'ERROR_TEST_RUNNER'.
  ls_request-processing_mode = 'AUTO'.
  ls_request-priority = 1.
  ls_request-callback_url = ''.

  " Build payload based on test scenario
  ls_payload-header-invoice_number = lv_invoice_number.

  CASE p_test.
    WHEN '1'.
      " Test 1: Invalid Vendor
      WRITE: / '========================================'.
      WRITE: / 'Test 1: Invalid Vendor Number'.
      WRITE: / '========================================'.
      WRITE: /.

      ls_payload-header-vendor_number = '9999999999'.  " Invalid
      ls_payload-header-vendor_name = 'Invalid Vendor'.
      ls_payload-header-company_code = '1000'.
      ls_payload-header-invoice_date = '20260510'.
      ls_payload-header-document_date = '20260510'.
      ls_payload-header-posting_date = '20260510'.
      ls_payload-header-currency = 'EUR'.
      ls_payload-header-gross_amount = '1000.00'.
      ls_payload-header-confidence_score = '0.95'.

      APPEND VALUE #(
        item_number = '0001'
        description = 'Test Item'
        gl_account = '400000'
        amount = '1000.00'
        quantity = '1'
        unit = 'EA'
      ) TO ls_payload-items.

    WHEN '2'.
      " Test 2: Invalid GL Account
      WRITE: / '========================================'.
      WRITE: / 'Test 2: Invalid GL Account'.
      WRITE: / '========================================'.
      WRITE: /.

      ls_payload-header-vendor_number = '100045'.  " Valid
      ls_payload-header-vendor_name = 'Valid Vendor'.
      ls_payload-header-company_code = '1000'.
      ls_payload-header-invoice_date = '20260510'.
      ls_payload-header-document_date = '20260510'.
      ls_payload-header-posting_date = '20260510'.
      ls_payload-header-currency = 'EUR'.
      ls_payload-header-gross_amount = '1000.00'.
      ls_payload-header-confidence_score = '0.95'.

      APPEND VALUE #(
        item_number = '0001'
        description = 'Test Item'
        gl_account = '999999'  " Invalid GL
        amount = '1000.00'
        quantity = '1'
        unit = 'EA'
      ) TO ls_payload-items.

    WHEN '3'.
      " Test 3: Missing Company Code
      WRITE: / '========================================'.
      WRITE: / 'Test 3: Missing Mandatory Field'.
      WRITE: / '========================================'.
      WRITE: /.

      ls_payload-header-vendor_number = '100045'.
      ls_payload-header-vendor_name = 'Valid Vendor'.
      ls_payload-header-company_code = ''.  " Missing!
      ls_payload-header-invoice_date = '20260510'.
      ls_payload-header-document_date = '20260510'.
      ls_payload-header-posting_date = '20260510'.
      ls_payload-header-currency = 'EUR'.
      ls_payload-header-gross_amount = '1000.00'.
      ls_payload-header-confidence_score = '0.95'.

      APPEND VALUE #(
        item_number = '0001'
        description = 'Test Item'
        gl_account = '400000'
        amount = '1000.00'
        quantity = '1'
        unit = 'EA'
      ) TO ls_payload-items.

    WHEN '4'.
      " Test 4: Invalid Currency
      WRITE: / '========================================'.
      WRITE: / 'Test 4: Invalid Currency Code'.
      WRITE: / '========================================'.
      WRITE: /.

      ls_payload-header-vendor_number = '100045'.
      ls_payload-header-vendor_name = 'Valid Vendor'.
      ls_payload-header-company_code = '1000'.
      ls_payload-header-invoice_date = '20260510'.
      ls_payload-header-document_date = '20260510'.
      ls_payload-header-posting_date = '20260510'.
      ls_payload-header-currency = 'XXX'.  " Invalid currency
      ls_payload-header-gross_amount = '1000.00'.
      ls_payload-header-confidence_score = '0.95'.

      APPEND VALUE #(
        item_number = '0001'
        description = 'Test Item'
        gl_account = '400000'
        amount = '1000.00'
        quantity = '1'
        unit = 'EA'
      ) TO ls_payload-items.

    WHEN '5'.
      " Test 5: All Valid (Success Scenario)
      WRITE: / '========================================'.
      WRITE: / 'Test 5: All Valid - Success Scenario'.
      WRITE: / '========================================'.
      WRITE: /.

      ls_payload-header-vendor_number = '100045'.  " Valid
      ls_payload-header-vendor_name = 'Valid Vendor'.
      ls_payload-header-company_code = '1000'.
      ls_payload-header-invoice_date = '20260510'.
      ls_payload-header-document_date = '20260510'.
      ls_payload-header-posting_date = '20260510'.
      ls_payload-header-currency = 'EUR'.
      ls_payload-header-gross_amount = '1000.00'.
      ls_payload-header-confidence_score = '0.95'.

      APPEND VALUE #(
        item_number = '0001'
        description = 'Test Item'
        gl_account = '400000'
        amount = '1000.00'
        quantity = '1'
        unit = 'EA'
      ) TO ls_payload-items.

    WHEN OTHERS.
      WRITE: / 'Invalid test selection!'.
      RETURN.
  ENDCASE.

  " Call API
  ls_response = lo_api->process_invoice_intake(
    is_request = ls_request
    is_extracted_data = ls_payload
  ).

  " Display results
  WRITE: /.
  WRITE: / 'Response:'.
  WRITE: / '----------------------------------------'.

  IF ls_response-success = abap_true.
    WRITE: / '✓ Success: TRUE'.
    WRITE: / 'Invoice UUID:', ls_response-invoice_uuid.
    WRITE: / 'Status:', ls_response-status.
  ELSE.
    WRITE: / '✗ Success: FALSE'.
    WRITE: / '✗ Status:', ls_response-status.
    WRITE: / '✗ Error Code:', ls_response-error_code.
    WRITE: / '✗ Error Message:', ls_response-error_message.
  ENDIF.

  WRITE: / 'Processing Time (ms):', ls_response-processing_time_ms.

  IF ls_response-validation_issues IS NOT INITIAL.
    WRITE: /.
    WRITE: / 'Validation Issues:'.
    WRITE: / ls_response-validation_issues.
  ENDIF.

  WRITE: / '----------------------------------------'.

  " Check database only if success
  IF ls_response-success = abap_true AND ls_response-invoice_uuid IS NOT INITIAL.
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
  ELSE.
    WRITE: /.
    WRITE: / 'No database record created (validation failed)'.
  ENDIF.

  WRITE: /.
  WRITE: / '========================================'.
  WRITE: / 'Test Complete'.
  WRITE: / '========================================'.
