*&---------------------------------------------------------------------*
*& Report Z_TEST_AUTO_POST_ENGINE
*&---------------------------------------------------------------------*
*& Test program for Invoice Auto-Posting Engine
*& Tests both FB60 (General Vendor Invoice) and MIRO (PO-based) posting
*&---------------------------------------------------------------------*
REPORT z_test_auto_post_engine.

" Selection screen
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE t001.
PARAMETERS: p_method TYPE char4 DEFAULT 'FB60' OBLIGATORY.  " FB60 or MIRO
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE t002.
PARAMETERS: p_compcd TYPE bukrs DEFAULT '1000' OBLIGATORY,
            p_vendor TYPE lifnr,  " Remove default - user must enter valid vendor
            p_curr   TYPE waers DEFAULT 'EUR' OBLIGATORY,
            p_testmd TYPE abap_bool AS CHECKBOX DEFAULT abap_true.  " Test mode
SELECTION-SCREEN END OF BLOCK b2.

" FB60 specific parameters
SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE t003.
PARAMETERS: p_glacc1 TYPE hkont,  " Remove default - user must enter valid GL
            p_amt1   TYPE wrbtr DEFAULT '500.00',
            p_glacc2 TYPE hkont,  " Remove default - user must enter valid GL
            p_amt2   TYPE wrbtr DEFAULT '500.00',
            p_costc  TYPE kostl.  " Remove default - user must enter valid cost center
SELECTION-SCREEN END OF BLOCK b3.

" MIRO specific parameters
SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE t004.
PARAMETERS: p_po     TYPE ebeln DEFAULT '4500012345',
            p_poitem TYPE ebelp DEFAULT '00010',
            p_qty    TYPE menge_d DEFAULT '10'.
SELECTION-SCREEN END OF BLOCK b4.

INITIALIZATION.
  t001 = 'Posting Method'.
  t002 = 'General Parameters'.
  t003 = 'FB60 Parameters (Non-PO Invoice)'.
  t004 = 'MIRO Parameters (PO-based Invoice)'.

START-OF-SELECTION.

  DATA: lo_engine TYPE REF TO zcl_finn_auto_post_engine,
        lv_timestamp TYPE char15.

  " Generate timestamp for unique references
  CONCATENATE sy-datum sy-uzeit INTO lv_timestamp.

  " Create posting engine instance
  lo_engine = NEW zcl_finn_auto_post_engine( ).

  WRITE: / '========================================'.
  WRITE: / 'Invoice Auto-Posting Engine - Test'.
  WRITE: / '========================================'.
  WRITE: /.
  WRITE: / 'Test Mode:', p_testmd.
  WRITE: / 'Posting Method:', p_method.
  WRITE: / 'Timestamp:', lv_timestamp.
  WRITE: /.

  " Validate parameters before posting
  IF p_method = 'FB60'.
    IF p_vendor IS INITIAL.
      WRITE: / '✗ ERROR: Vendor number is required'.
      WRITE: / '  Use FK03 to find a valid vendor in your system'.
      RETURN.
    ENDIF.
    IF p_glacc1 IS INITIAL OR p_glacc2 IS INITIAL.
      WRITE: / '✗ ERROR: GL accounts are required'.
      WRITE: / '  Use FS00 to find valid GL accounts in your system'.
      RETURN.
    ENDIF.
  ENDIF.

  CASE p_method.
    WHEN 'FB60'.
      PERFORM test_fb60_posting USING lo_engine lv_timestamp.

    WHEN 'MIRO'.
      PERFORM test_miro_posting USING lo_engine lv_timestamp.

    WHEN OTHERS.
      WRITE: / 'ERROR: Invalid posting method. Use FB60 or MIRO'.
  ENDCASE.

*&---------------------------------------------------------------------*
*& Form test_fb60_posting
*&---------------------------------------------------------------------*
FORM test_fb60_posting USING io_engine TYPE REF TO zcl_finn_auto_post_engine
                             iv_timestamp TYPE char15.

  DATA: ls_request TYPE zcl_finn_auto_post_engine=>ty_fb60_request,
        ls_response TYPE zcl_finn_auto_post_engine=>ty_posting_response,
        lv_total_amt TYPE wrbtr.

  WRITE: / '========================================'.
  WRITE: / 'Testing FB60 - General Vendor Invoice'.
  WRITE: / '========================================'.
  WRITE: /.

  " Calculate total amount
  lv_total_amt = p_amt1 + p_amt2.

  " Build header
  ls_request-header = VALUE #(
    company_code    = p_compcd
    posting_date    = sy-datum
    document_date   = sy-datum
    reference       = |TEST-FB60-{ iv_timestamp }|
    doc_header_text = 'Test FB60 Posting'
    currency        = p_curr
  ).

  " Build vendor line
  ls_request-vendor_line = VALUE #(
    vendor_number = p_vendor
    amount        = lv_total_amt
    assignment    = |TEST-{ iv_timestamp }|
    text          = 'Test vendor invoice'
  ).

  " Build GL lines (without tax code and cost center to avoid errors)
  APPEND VALUE #(
    gl_account  = p_glacc1
    amount      = p_amt1
    text        = 'Test GL line 1'
  ) TO ls_request-gl_lines.

  APPEND VALUE #(
    gl_account  = p_glacc2
    amount      = p_amt2
    text        = 'Test GL line 2'
  ) TO ls_request-gl_lines.

  " Display request data
  WRITE: / 'Request Data:'.
  WRITE: / '  Company Code:', ls_request-header-company_code.
  WRITE: / '  Vendor:', ls_request-vendor_line-vendor_number.
  WRITE: / '  Total Amount:', lv_total_amt, ls_request-header-currency.
  WRITE: / '  Reference:', ls_request-header-reference.
  WRITE: / '  GL Lines:', lines( ls_request-gl_lines ).
  WRITE: /.

  IF p_testmd = abap_true.
    WRITE: / '*** TEST MODE - BAPI will be called but rolled back ***'.
    WRITE: / 'All validations and BAPI logic will execute.'.
    WRITE: / 'Document number will be returned but NOT committed.'.
    WRITE: /.
  ENDIF.

  " Call posting engine
  WRITE: / 'Calling FB60 Posting Engine...'.
  WRITE: /.

  ls_response = io_engine->post_invoice_fb60(
    is_request = ls_request
    iv_testrun = p_testmd
  ).

  " Display results
  WRITE: / '========================================'.
  WRITE: / 'Posting Result:'.
  WRITE: / '========================================'.
  WRITE: /.

  IF ls_response-success = abap_true.
    WRITE: / '✓ SUCCESS - Document Posted'.
    IF p_testmd = abap_true.
      WRITE: / '  (TEST MODE: Changes rolled back)'.
    ENDIF.
    WRITE: /.
    WRITE: / '  Document Number:', ls_response-document_number.
    WRITE: / '  Fiscal Year:', ls_response-fiscal_year.
    WRITE: / '  Company Code:', ls_response-company_code.
    WRITE: / '  Posting Date:', ls_response-posting_date.
    WRITE: /.

    " Display BAPI return messages
    IF ls_response-bapi_return IS NOT INITIAL.
      WRITE: / 'BAPI Messages:'.
      LOOP AT ls_response-bapi_return INTO DATA(ls_return).
        WRITE: / '  [', ls_return-type, ']', ls_return-message.
      ENDLOOP.
    ENDIF.

    " Verification query
    IF p_testmd = abap_false.
      WRITE: /.
      WRITE: / 'Verification:'.
      WRITE: / '  Use transaction FB03 to display document'.
      WRITE: / '  Document Number:', ls_response-document_number.
      WRITE: / '  Company Code:', ls_response-company_code.
      WRITE: / '  Fiscal Year:', ls_response-fiscal_year.
    ELSE.
      WRITE: /.
      WRITE: / 'NOTE: Document was NOT saved (test mode)'.
      WRITE: / '      Set Test Mode OFF to actually post'.
    ENDIF.

  ELSE.
    WRITE: / '✗ FAILURE - Posting Failed'.
    WRITE: /.
    WRITE: / '  Error Code:', ls_response-error_code.
    WRITE: / '  Error Message:', ls_response-error_message.
    WRITE: /.

    " Display BAPI return messages
    IF ls_response-bapi_return IS NOT INITIAL.
      WRITE: / 'BAPI Error Messages:'.
      LOOP AT ls_response-bapi_return INTO ls_return WHERE type CA 'EAW'.
        WRITE: / '  [', ls_return-type, ']', ls_return-message.
      ENDLOOP.
    ENDIF.
  ENDIF.

  WRITE: /.
  WRITE: / '========================================'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form test_miro_posting
*&---------------------------------------------------------------------*
FORM test_miro_posting USING io_engine TYPE REF TO zcl_finn_auto_post_engine
                             iv_timestamp TYPE char15.

  DATA: ls_request TYPE zcl_finn_auto_post_engine=>ty_miro_request,
        ls_response TYPE zcl_finn_auto_post_engine=>ty_posting_response.

  WRITE: / '========================================'.
  WRITE: / 'Testing MIRO - PO-based Invoice'.
  WRITE: / '========================================'.
  WRITE: /.

  " Build header
  ls_request-header = VALUE #(
    company_code   = p_compcd
    invoice_date   = sy-datum
    posting_date   = sy-datum
    reference      = |TEST-MIRO-{ iv_timestamp }|
    header_text    = 'Test MIRO Posting'
    currency       = p_curr
    calculate_tax  = abap_true
    gross_invoice  = abap_false
  ).

  " Build PO items
  APPEND VALUE #(
    po_number    = p_po
    po_item      = p_poitem
    quantity     = p_qty
    ok_indicator = abap_true
  ) TO ls_request-po_items.

  " Display request data
  WRITE: / 'Request Data:'.
  WRITE: / '  Company Code:', ls_request-header-company_code.
  WRITE: / '  PO Number:', p_po.
  WRITE: / '  PO Item:', p_poitem.
  WRITE: / '  Quantity:', p_qty.
  WRITE: / '  Reference:', ls_request-header-reference.
  WRITE: /.

  IF p_testmd = abap_true.
    WRITE: / '*** TEST MODE - BAPI will be called but rolled back ***'.
    WRITE: / 'All validations and BAPI logic will execute.'.
    WRITE: / 'Document number will be returned but NOT committed.'.
    WRITE: /.
  ENDIF.

  " Call posting engine
  WRITE: / 'Calling MIRO Posting Engine...'.
  WRITE: /.

  ls_response = io_engine->post_invoice_miro(
    is_request = ls_request
    iv_testrun = p_testmd
  ).

  " Display results
  WRITE: / '========================================'.
  WRITE: / 'Posting Result:'.
  WRITE: / '========================================'.
  WRITE: /.

  IF ls_response-success = abap_true.
    WRITE: / '✓ SUCCESS - Document Posted'.
    IF p_testmd = abap_true.
      WRITE: / '  (TEST MODE: Changes rolled back)'.
    ENDIF.
    WRITE: /.
    WRITE: / '  Document Number:', ls_response-document_number.
    WRITE: / '  Fiscal Year:', ls_response-fiscal_year.
    WRITE: / '  Company Code:', ls_response-company_code.
    WRITE: / '  Posting Date:', ls_response-posting_date.
    WRITE: /.

    " Display BAPI return messages
    IF ls_response-bapi_return IS NOT INITIAL.
      WRITE: / 'BAPI Messages:'.
      LOOP AT ls_response-bapi_return INTO DATA(ls_return).
        WRITE: / '  [', ls_return-type, ']', ls_return-message.
      ENDLOOP.
    ENDIF.

    " Verification query
    IF p_testmd = abap_false.
      WRITE: /.
      WRITE: / 'Verification:'.
      WRITE: / '  Use transaction MIR4 to display invoice'.
      WRITE: / '  Document Number:', ls_response-document_number.
      WRITE: / '  Fiscal Year:', ls_response-fiscal_year.
    ELSE.
      WRITE: /.
      WRITE: / 'NOTE: Document was NOT saved (test mode)'.
      WRITE: / '      Set Test Mode OFF to actually post'.
    ENDIF.

  ELSE.
    WRITE: / '✗ FAILURE - Posting Failed'.
    WRITE: /.
    WRITE: / '  Error Code:', ls_response-error_code.
    WRITE: / '  Error Message:', ls_response-error_message.
    WRITE: /.

    " Display BAPI return messages
    IF ls_response-bapi_return IS NOT INITIAL.
      WRITE: / 'BAPI Error Messages:'.
      LOOP AT ls_response-bapi_return INTO ls_return WHERE type CA 'EAW'.
        WRITE: / '  [', ls_return-type, ']', ls_return-message.
      ENDLOOP.
    ENDIF.
  ENDIF.

  WRITE: /.
  WRITE: / '========================================'.

ENDFORM.
