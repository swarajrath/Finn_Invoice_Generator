*&---------------------------------------------------------------------*
*& Report ZFINN_GENERATE_TEST_DATA
*&---------------------------------------------------------------------*
*& Purpose: Generate test data for FINN Invoice Automation tables
*& Tables: zfinn_inv_hrd, ZFINN_INV_ITEM, ZFINN_INV_LOG
*& Usage: Run in SE38 to create 10-50 test invoices with items and logs
*&---------------------------------------------------------------------*
REPORT zfinn_generate_test_data.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_count TYPE i DEFAULT 30 OBLIGATORY,      " Number of invoices
            p_bukrs TYPE bukrs DEFAULT '1000'.         " Company code
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Data Declarations
*----------------------------------------------------------------------*
DATA: lt_headers TYPE STANDARD TABLE OF zfinn_inv_hrd,
      lt_items   TYPE STANDARD TABLE OF zfinn_inv_item,
      lt_logs    TYPE STANDARD TABLE OF zfinn_inv_log,
      ls_header  TYPE zfinn_inv_hrd,
      ls_item    TYPE zfinn_inv_item,
      ls_log     TYPE zfinn_inv_log.

DATA: lv_uuid          TYPE sysuuid_x16,
      lv_item_uuid     TYPE sysuuid_x16,
      lv_log_uuid      TYPE sysuuid_x16,
      lv_timestamp     TYPE timestampl,
      lv_invoice_num   TYPE xblnr,
      lv_index         TYPE i,
      lv_item_count    TYPE i,
      lv_log_count     TYPE i,
      lv_amount        TYPE wrbtr,
      lv_success_count TYPE i VALUE 0,
      lv_error_count   TYPE i VALUE 0,
      lv_random        TYPE i.

*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
  " Initialization complete

*----------------------------------------------------------------------*
* Input Validation
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  IF p_count < 10 OR p_count > 50.
    MESSAGE 'Please enter a value between 10 and 50' TYPE 'E'.
  ENDIF.

*----------------------------------------------------------------------*
* Main Processing
*----------------------------------------------------------------------*
START-OF-SELECTION.

  WRITE: / 'FINN Invoice Test Data Generation',
         / '===================================',
         /.

  " Generate invoices
  DO p_count TIMES.
    lv_index = sy-index.

    " Generate header UUID
    TRY.
        lv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        GET TIME STAMP FIELD lv_timestamp.
        lv_uuid = lv_timestamp.
    ENDTRY.

    " Determine status (25 success, 3 validation error, 2 technical error)
    DATA(lv_status) = COND char1(
      WHEN lv_index <= 25 THEN 'S'  " Success
      WHEN lv_index <= 28 THEN 'V'  " Validation Error
      ELSE 'E'                      " Technical Error
    ).

    " Generate invoice number
    lv_invoice_num = |INV-2026-{ lv_index WIDTH = 5 PAD = '0' }|.

    " Generate random amount between 800 and 3000
    CALL FUNCTION 'QF05_RANDOM_INTEGER'
      EXPORTING
        ran_int_max = 2200
        ran_int_min = 800
      IMPORTING
        ran_int     = lv_random.
    lv_amount = lv_random.

    " Generate timestamp (last 7 days, random hour)
    GET TIME STAMP FIELD lv_timestamp.
    DATA(lv_days_ago) = ( lv_index MOD 7 ).
    DATA(lv_hours_ago) = ( lv_index MOD 10 ) + 8.  " Between 8-17 hours
    lv_timestamp = cl_abap_tstmp=>subtractsecs(
      tstmp = lv_timestamp
      secs  = ( lv_days_ago * 86400 ) + ( lv_hours_ago * 3600 )
    ).

    " Build header record
    CLEAR ls_header.
    ls_header-header_uuid = lv_uuid.
    ls_header-invoice_number = lv_invoice_num.

    " Rotate through test vendors
    ls_header-vendor_number = COND #(
      WHEN lv_index MOD 4 = 1 THEN '0000100045'
      WHEN lv_index MOD 4 = 2 THEN '0000100123'
      WHEN lv_index MOD 4 = 3 THEN '0000100078'
      ELSE '0000100099'  " This will cause "vendor blocked" error
    ).

    ls_header-company_code = p_bukrs.
    ls_header-invoice_date = sy-datum.
    ls_header-document_date = sy-datum.
    ls_header-posting_date = sy-datum.
    ls_header-fiscal_year = sy-datum(4).
    ls_header-currency = 'EUR'.
    ls_header-gross_amount = lv_amount.
    ls_header-net_amount = lv_amount * '0.84'.  " Approx 84% (before 19% tax)
    ls_header-tax_amount = lv_amount * '0.16'.
    ls_header-payment_terms = 'Z030'.
    ls_header-baseline_date = sy-datum.
    ls_header-payment_method = 'T'.
    ls_header-document_type = 'KR'.
    ls_header-header_text = 'Test Invoice - Auto Generated'.
    ls_header-reference = |REF-2026-{ lv_index WIDTH = 5 PAD = '0' }|.
    ls_header-status = lv_status.
    ls_header-processing_type = 'A'.
    ls_header-external_doc_id = |TEST-DOC-{ lv_index WIDTH = 6 PAD = '0' }|.
    ls_header-extraction_confidence = '0.98'.
    ls_header-created_by = sy-uname.
    ls_header-created_at = lv_timestamp.
    ls_header-changed_by = sy-uname.
    ls_header-changed_at = lv_timestamp.
    ls_header-processing_time_ms = ( lv_index MOD 10 + 1 ) * 150.

    " Set status-specific fields
    CASE lv_status.
      WHEN 'S'.  " Success
        ls_header-sap_document = |51000{ lv_index WIDTH = 5 PAD = '0' }|.
        ls_header-sap_fiscal_year = sy-datum(4).
        DATA(lv_posted_tstmp) = lv_timestamp + 2.
        ls_header-posted_at = lv_posted_tstmp.
        lv_success_count = lv_success_count + 1.

      WHEN 'V'.  " Validation Error
        CASE lv_index.
          WHEN 26.
            ls_header-error_code = 'VENDOR_NOT_FOUND'.
            ls_header-error_message = 'Vendor 0000100999 does not exist in company code 1000'.
            ls_header-error_field = 'invoice_header.vendor_number'.
          WHEN 27.
            ls_header-error_code = 'GL_ACCOUNT_INVALID'.
            ls_header-error_message = 'G/L account 0000999999 is not valid in company code 1000'.
            ls_header-error_field = 'invoice_items[0].gl_account'.
          WHEN 28.
            ls_header-error_code = 'PERIOD_CLOSED'.
            ls_header-error_message = 'Posting period for 2026-03-15 is closed in company code 1000'.
            ls_header-error_field = 'invoice_header.posting_date'.
        ENDCASE.
        ls_header-retry_count = 0.
        lv_error_count = lv_error_count + 1.

      WHEN 'E'.  " Technical Error
        ls_header-error_code = 'BAPI_ERROR'.
        ls_header-error_message = 'Internal server error during document posting'.
        ls_header-retry_count = 1.
        lv_error_count = lv_error_count + 1.
    ENDCASE.

    " Calculate item count (2-4 items per invoice)
    lv_item_count = ( lv_index MOD 3 ) + 2.
    ls_header-item_count = lv_item_count.

    APPEND ls_header TO lt_headers.

    " Generate line items
    DATA(lv_item_amount) = ls_header-net_amount / lv_item_count.

    DO lv_item_count TIMES.
      TRY.
          lv_item_uuid = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error.
          lv_item_uuid = lv_timestamp + sy-index.
      ENDTRY.

      CLEAR ls_item.
      ls_item-header_uuid = lv_uuid.
      ls_item-item_uuid = lv_item_uuid.
      ls_item-item_number = sy-index.

      " Rotate through GL accounts
      ls_item-gl_account = COND #(
        WHEN sy-index MOD 3 = 1 THEN '0000520000'
        WHEN sy-index MOD 3 = 2 THEN '0000520100'
        ELSE '0000520200'
      ).

      " Rotate through cost centers
      ls_item-cost_center = COND #(
        WHEN sy-index MOD 3 = 1 THEN 'CC-OPS-001'
        WHEN sy-index MOD 3 = 2 THEN 'CC-OPS-002'
        ELSE 'CC-FIN-001'
      ).

      ls_item-amount = lv_item_amount.
      ls_item-tax_code = 'V1'.
      ls_item-tax_amount = lv_item_amount * '0.19'.
      ls_item-quantity = 1.
      ls_item-unit = 'EA'.
      ls_item-item_text = |Line item { sy-index } - Test expense|.
      ls_item-assignment = |FLEET-2026-{ lv_index WIDTH = 2 PAD = '0' }|.
      ls_item-plant = '1000'.
      ls_item-validation_status = COND #( WHEN lv_status = 'S' THEN 'V' ELSE 'E' ).
      ls_item-created_at = lv_timestamp.
      ls_item-changed_at = lv_timestamp.

      APPEND ls_item TO lt_items.
    ENDDO.

    " Generate log entries (3-5 entries per invoice)
    DATA(lv_log_entries) = COND i( WHEN lv_status = 'S' THEN 4 ELSE 3 ).

    DO lv_log_entries TIMES.
      TRY.
          lv_log_uuid = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error.
          lv_log_uuid = lv_timestamp + sy-index * 1000.
      ENDTRY.

      CLEAR ls_log.
      ls_log-log_uuid = lv_log_uuid.
      ls_log-header_uuid = lv_uuid.

      " Set timestamp (sequential: +0s, +300ms, +600ms, +900ms)
      DATA(lv_secs_offset) = CONV decfloat16( ( sy-index - 1 ) * '0.3' ).
      ls_log-timestamp = cl_abap_tstmp=>add(
        tstmp = lv_timestamp
        secs  = lv_secs_offset
      ).

      ls_log-user_name = COND #( WHEN sy-index = 1 THEN 'SYSTEM' ELSE sy-uname ).
      ls_log-program_name = 'ZCL_FINN_INVOICE_API_HANDLER'.

      " Set event type based on sequence
      CASE sy-index.
        WHEN 1.
          ls_log-event_type = 'RECEIVED'.
          ls_log-new_status = 'N'.
          ls_log-duration_ms = 50.
        WHEN 2.
          ls_log-event_type = 'VALIDATED'.
          ls_log-old_status = 'N'.
          ls_log-new_status = 'P'.
          ls_log-validation_duration_ms = 150.
          ls_log-duration_ms = 150.
        WHEN 3.
          IF lv_status = 'S'.
            ls_log-event_type = 'POSTING_STARTED'.
            ls_log-old_status = 'P'.
            ls_log-new_status = 'P'.
            ls_log-duration_ms = 50.
          ELSE.
            ls_log-event_type = 'ERROR'.
            ls_log-old_status = 'P'.
            ls_log-new_status = lv_status.
            ls_log-error_code = ls_header-error_code.
            ls_log-error_message = ls_header-error_message.
            ls_log-error_severity = 'E'.
            ls_log-duration_ms = 100.
          ENDIF.
        WHEN 4.
          ls_log-event_type = 'POSTED'.
          ls_log-old_status = 'P'.
          ls_log-new_status = 'S'.
          ls_log-posting_duration_ms = 1200.
          ls_log-duration_ms = 1200.
      ENDCASE.

      ls_log-is_system = 'X'.
      ls_log-correlation_id = |CORR-2026-{ lv_index WIDTH = 6 PAD = '0' }|.

      APPEND ls_log TO lt_logs.
    ENDDO.

  ENDDO.

  " Insert all data in bulk
  WRITE: / 'Inserting data into tables...',
         /.

  " Insert headers
  INSERT zfinn_inv_hrd FROM TABLE lt_headers.
  IF sy-subrc = 0.
    WRITE: / 'Headers inserted:', p_count, 'records'.
  ELSE.
    WRITE: / 'ERROR inserting headers. SQLCODE:', sy-subrc.
    ROLLBACK WORK.
    STOP.
  ENDIF.

  " Insert items
  INSERT zfinn_inv_item FROM TABLE lt_items.
  IF sy-subrc = 0.
    WRITE: / 'Items inserted:', lines( lt_items ), 'records'.
  ELSE.
    WRITE: / 'ERROR inserting items. SQLCODE:', sy-subrc.
    ROLLBACK WORK.
    STOP.
  ENDIF.

  " Insert logs
  INSERT zfinn_inv_log FROM TABLE lt_logs.
  IF sy-subrc = 0.
    WRITE: / 'Log entries inserted:', lines( lt_logs ), 'records'.
  ELSE.
    WRITE: / 'ERROR inserting logs. SQLCODE:', sy-subrc.
    ROLLBACK WORK.
    STOP.
  ENDIF.

  " Commit all changes
  COMMIT WORK.

  " Display summary
  WRITE: /,
         / 'Test Data Generation Complete',
         / '==============================',
         / 'Invoices created:', p_count,
         /   '  - Successful (S):', lv_success_count,
         /   '  - Validation Error (V):', 3,
         /   '  - Technical Error (E):', 2,
         /,
         / 'Line items created:', lines( lt_items ),
         / 'Log entries created:', lines( lt_logs ),
         /,
         / 'Company Code:', p_bukrs,
         / 'Date range: Last 7 days',
         /,
         / 'View data:',
         /   '  SE16N → zfinn_inv_hrd',
         /   '  SE16N → ZFINN_INV_ITEM',
         /   '  SE16N → ZFINN_INV_LOG',
         /   '  Fiori App → Invoice Tracking',
         /.

END-OF-SELECTION.

*&---------------------------------------------------------------------*
*& Text Symbols
*&---------------------------------------------------------------------*
* TEXT-001: Generation Parameters
