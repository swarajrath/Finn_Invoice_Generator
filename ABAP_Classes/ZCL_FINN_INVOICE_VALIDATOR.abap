CLASS zcl_finn_invoice_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_validation_error,
        field      TYPE string,
        code       TYPE string,
        message    TYPE string,
        severity   TYPE string, "ERROR, WARNING, INFO
        suggestion TYPE string,
      END OF ty_validation_error,
      tt_validation_errors TYPE STANDARD TABLE OF ty_validation_error WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_invoice_header,
        company_code          TYPE bukrs,
        vendor_number         TYPE lifnr,
        invoice_number        TYPE xblnr,
        invoice_date          TYPE bldat,
        document_date         TYPE bldat,
        posting_date          TYPE budat,
        currency              TYPE waers,
        gross_amount          TYPE wrbtr,
        net_amount            TYPE wrbtr,
        tax_amount            TYPE wrbtr,
        payment_terms         TYPE dzterm,
        baseline_date         TYPE dzfbdt,
        payment_method        TYPE dzwels,
        payment_block         TYPE dzahls,
        document_type         TYPE blart,
        header_text           TYPE bktxt,
        reference             TYPE xblnr1,
        po_number             TYPE ebeln,
        business_area         TYPE gsber,
        external_doc_id       TYPE char50,
        extraction_confidence TYPE p LENGTH 5 DECIMALS 2,
        pdf_url               TYPE string,
      END OF ty_invoice_header.

    TYPES:
      BEGIN OF ty_invoice_item,
        item_number    TYPE posnr,
        gl_account     TYPE hkont,
        amount         TYPE wrbtr,
        cost_center    TYPE kostl,
        profit_center  TYPE prctr,
        internal_order TYPE aufnr,
        wbs_element    TYPE ps_posid,
        tax_code       TYPE mwskz,
        tax_amount     TYPE wrbtr,
        item_text      TYPE sgtxt,
        assignment     TYPE dzuonr,
        reference_key  TYPE xref1,
        po_number      TYPE ebeln,
        po_item        TYPE ebelp,
        quantity       TYPE menge_d,
        unit           TYPE meins,
        material       TYPE matnr,
        plant          TYPE werks_d,
      END OF ty_invoice_item,
      tt_invoice_items TYPE STANDARD TABLE OF ty_invoice_item WITH DEFAULT KEY.

    METHODS constructor.

    "Main validation method
    METHODS validate_invoice
      IMPORTING
        is_header          TYPE ty_invoice_header
        it_items           TYPE tt_invoice_items
      EXPORTING
        et_errors          TYPE tt_validation_errors
        et_warnings        TYPE tt_validation_errors
      RETURNING
        VALUE(rv_is_valid) TYPE abap_bool.

    "Header validation methods
    METHODS validate_header
      IMPORTING
        is_header   TYPE ty_invoice_header
      CHANGING
        ct_errors   TYPE tt_validation_errors
        ct_warnings TYPE tt_validation_errors.

    METHODS validate_items
      IMPORTING
        is_header   TYPE ty_invoice_header
        it_items    TYPE tt_invoice_items
      CHANGING
        ct_errors   TYPE tt_validation_errors
        ct_warnings TYPE tt_validation_errors.

    "Specific validation checks
    METHODS check_vendor_exists
      IMPORTING
        iv_vendor       TYPE lifnr
        iv_company_code TYPE bukrs
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS check_vendor_blocked
      IMPORTING
        iv_vendor        TYPE lifnr
        iv_company_code  TYPE bukrs
      EXPORTING
        ev_blocked       TYPE abap_bool
        ev_block_reason  TYPE string.

    METHODS check_duplicate_invoice
      IMPORTING
        iv_vendor        TYPE lifnr
        iv_company_code  TYPE bukrs
        iv_invoice_num   TYPE xblnr
      EXPORTING
        ev_exists        TYPE abap_bool
        ev_document      TYPE belnr_d
        ev_fiscal_year   TYPE gjahr.

    METHODS check_gl_account_valid
      IMPORTING
        iv_gl_account   TYPE hkont
        iv_company_code TYPE bukrs
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS check_cost_center_valid
      IMPORTING
        iv_cost_center TYPE kostl
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS check_posting_period_open
      IMPORTING
        iv_company_code TYPE bukrs
        iv_posting_date TYPE budat
      RETURNING
        VALUE(rv_open)  TYPE abap_bool.

    METHODS check_tax_code_valid
      IMPORTING
        iv_tax_code    TYPE mwskz
        iv_company_code TYPE bukrs
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS validate_amount_reconciliation
      IMPORTING
        iv_gross_amount TYPE wrbtr
        iv_net_amount   TYPE wrbtr
        iv_tax_amount   TYPE wrbtr
        it_items        TYPE tt_invoice_items
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

  PRIVATE SECTION.

    DATA: mt_errors   TYPE tt_validation_errors,
          mt_warnings TYPE tt_validation_errors.

    METHODS add_error
      IMPORTING
        iv_field      TYPE string
        iv_code       TYPE string
        iv_message    TYPE string
        iv_severity   TYPE string DEFAULT 'ERROR'
        iv_suggestion TYPE string OPTIONAL.

    METHODS add_warning
      IMPORTING
        iv_field      TYPE string
        iv_code       TYPE string
        iv_message    TYPE string
        iv_severity   TYPE string DEFAULT 'WARNING'
        iv_suggestion TYPE string OPTIONAL.

ENDCLASS.



CLASS zcl_finn_invoice_validator IMPLEMENTATION.

  METHOD constructor.
    CLEAR: mt_errors, mt_warnings.
  ENDMETHOD.

  METHOD validate_invoice.
    CLEAR: mt_errors, mt_warnings.

    " Validate header
    validate_header(
      EXPORTING is_header = is_header
      CHANGING ct_errors = mt_errors ct_warnings = mt_warnings
    ).

    " Validate items
    validate_items(
      EXPORTING is_header = is_header it_items = it_items
      CHANGING ct_errors = mt_errors ct_warnings = mt_warnings
    ).

    " Return results
    et_errors = mt_errors.
    et_warnings = mt_warnings.
    rv_is_valid = COND #( WHEN lines( mt_errors ) = 0 THEN abap_true ELSE abap_false ).
  ENDMETHOD.

  METHOD validate_header.
    " 1. Mandatory field checks
    IF is_header-company_code IS INITIAL.
      add_error(
        iv_field = 'invoice_header.company_code'
        iv_code = 'MANDATORY_FIELD_MISSING'
        iv_message = 'Company code is mandatory'
        iv_severity = 'ERROR'
      ).
    ENDIF.

    IF is_header-vendor_number IS INITIAL.
      add_error(
        iv_field = 'invoice_header.vendor_number'
        iv_code = 'MANDATORY_FIELD_MISSING'
        iv_message = 'Vendor number is mandatory'
        iv_severity = 'ERROR'
      ).
    ENDIF.

    IF is_header-invoice_number IS INITIAL.
      add_error(
        iv_field = 'invoice_header.invoice_number'
        iv_code = 'MANDATORY_FIELD_MISSING'
        iv_message = 'Invoice number is mandatory'
        iv_severity = 'ERROR'
      ).
    ENDIF.

    " 2. Vendor existence check
    IF is_header-vendor_number IS NOT INITIAL AND is_header-company_code IS NOT INITIAL.
      IF check_vendor_exists( iv_vendor = is_header-vendor_number
                              iv_company_code = is_header-company_code ) = abap_false.
        add_error(
          iv_field = 'invoice_header.vendor_number'
          iv_code = 'VENDOR_NOT_FOUND'
          iv_message = |Vendor { is_header-vendor_number } does not exist in company code { is_header-company_code }|
          iv_severity = 'ERROR'
          iv_suggestion = 'Please check vendor master data or contact purchasing department'
        ).
      ENDIF.

      " 3. Vendor blocking check
      DATA(lv_blocked) = abap_false.
      DATA lv_block_reason TYPE string.
      check_vendor_blocked(
        EXPORTING iv_vendor = is_header-vendor_number
                  iv_company_code = is_header-company_code
        IMPORTING ev_blocked = lv_blocked
                  ev_block_reason = lv_block_reason
      ).

      IF lv_blocked = abap_true.
        add_error(
          iv_field = 'invoice_header.vendor_number'
          iv_code = 'VENDOR_BLOCKED'
          iv_message = |Vendor { is_header-vendor_number } is blocked: { lv_block_reason }|
          iv_severity = 'ERROR'
          iv_suggestion = 'Please contact vendor master data team to resolve blocking'
        ).
      ENDIF.
    ENDIF.

    " 4. Duplicate invoice check
    IF is_header-vendor_number IS NOT INITIAL AND is_header-invoice_number IS NOT INITIAL.
      DATA(lv_exists) = abap_false.
      DATA lv_existing_doc type belnr_d.
      DATA lv_fiscal_year type gjahr.

      check_duplicate_invoice(
        EXPORTING iv_vendor = is_header-vendor_number
                  iv_company_code = is_header-company_code
                  iv_invoice_num = is_header-invoice_number
        IMPORTING ev_exists = lv_exists
                  ev_document = lv_existing_doc
                  ev_fiscal_year = lv_fiscal_year
      ).

      IF lv_exists = abap_true.
        add_error(
          iv_field = 'invoice_header.invoice_number'
          iv_code = 'DUPLICATE_INVOICE'
          iv_message = |Invoice { is_header-invoice_number } already posted as document { lv_existing_doc }/{ lv_fiscal_year }|
          iv_severity = 'ERROR'
          iv_suggestion = 'Verify if this is a duplicate submission'
        ).
      ENDIF.
    ENDIF.

    " 5. Posting period check
    IF is_header-company_code IS NOT INITIAL AND is_header-posting_date IS NOT INITIAL.
      IF check_posting_period_open( iv_company_code = is_header-company_code
                                     iv_posting_date = is_header-posting_date ) = abap_false.
        add_error(
          iv_field = 'invoice_header.posting_date'
          iv_code = 'POSTING_PERIOD_CLOSED'
          iv_message = |Posting period for { is_header-posting_date } is closed in company code { is_header-company_code }|
          iv_severity = 'ERROR'
          iv_suggestion = 'Please contact FI team to open the posting period or adjust the posting date'
        ).
      ENDIF.
    ENDIF.

    " 6. Date logic validation
    IF is_header-invoice_date > sy-datum.
      add_error(
        iv_field = 'invoice_header.invoice_date'
        iv_code = 'FUTURE_INVOICE_DATE'
        iv_message = 'Invoice date cannot be in the future'
        iv_severity = 'ERROR'
      ).
    ENDIF.

    DATA(lv_future_date) = sy-datum + 5.
    IF is_header-posting_date > lv_future_date.
      add_error(
        iv_field = 'invoice_header.posting_date'
        iv_code = 'FUTURE_POSTING_DATE'
        iv_message = 'Posting date cannot be more than 5 days in the future'
        iv_severity = 'WARNING'
      ).
    ENDIF.

    " 7. Currency check
    IF is_header-currency IS NOT INITIAL.
      SELECT SINGLE waers FROM tcurc INTO @DATA(lv_currency)
        WHERE waers = @is_header-currency.
      IF sy-subrc <> 0.
        add_error(
          iv_field = 'invoice_header.currency'
          iv_code = 'INVALID_CURRENCY'
          iv_message = |Currency { is_header-currency } is not valid|
          iv_severity = 'ERROR'
        ).
      ENDIF.
    ENDIF.

    " 8. Amount validations
    IF is_header-gross_amount <= 0.
      add_error(
        iv_field = 'invoice_header.gross_amount'
        iv_code = 'INVALID_AMOUNT'
        iv_message = 'Gross amount must be greater than zero'
        iv_severity = 'ERROR'
      ).
    ENDIF.

    " 9. OCR confidence check
    IF is_header-extraction_confidence < '0.80'.
      add_warning(
        iv_field = 'invoice_header.extraction_confidence'
        iv_code = 'LOW_OCR_CONFIDENCE'
        iv_message = |OCR confidence is low ({ is_header-extraction_confidence }). Manual review recommended|
        iv_severity = 'WARNING'
        iv_suggestion = 'Please verify extracted data against original PDF'
      ).
    ENDIF.

  ENDMETHOD.

  METHOD validate_items.
    IF lines( it_items ) = 0.
      add_error(
        iv_field = 'invoice_items'
        iv_code = 'NO_LINE_ITEMS'
        iv_message = 'At least one line item is required'
        iv_severity = 'ERROR'
      ).
      RETURN.
    ENDIF.

    DATA(lv_item_total) = VALUE wrbtr( ).

    LOOP AT it_items INTO DATA(ls_item).
      DATA(lv_item_prefix) = |invoice_items[{ sy-tabix }]|.

      " Mandatory fields
      IF ls_item-gl_account IS INITIAL.
        add_error(
          iv_field = |{ lv_item_prefix }.gl_account|
          iv_code = 'MANDATORY_FIELD_MISSING'
          iv_message = |Line item { ls_item-item_number }: G/L account is mandatory|
          iv_severity = 'ERROR'
        ).
      ENDIF.

      " GL account validity
      IF ls_item-gl_account IS NOT INITIAL AND is_header-company_code IS NOT INITIAL.
        IF check_gl_account_valid( iv_gl_account = ls_item-gl_account
                                    iv_company_code = is_header-company_code ) = abap_false.
          add_error(
            iv_field = |{ lv_item_prefix }.gl_account|
            iv_code = 'GL_ACCOUNT_INVALID'
            iv_message = |Line item { ls_item-item_number }: G/L account { ls_item-gl_account } is not valid|
            iv_severity = 'ERROR'
            iv_suggestion = 'Please verify G/L account in master data'
          ).
        ENDIF.
      ENDIF.

      " Cost center validity
      IF ls_item-cost_center IS NOT INITIAL.
        IF check_cost_center_valid( ls_item-cost_center ) = abap_false.
          add_error(
            iv_field = |{ lv_item_prefix }.cost_center|
            iv_code = 'COST_CENTER_INVALID'
            iv_message = |Line item { ls_item-item_number }: Cost center { ls_item-cost_center } is not valid|
            iv_severity = 'ERROR'
            iv_suggestion = 'Please verify cost center in controlling module'
          ).
        ENDIF.
      ENDIF.

      " Tax code validity
      IF ls_item-tax_code IS NOT INITIAL.
        IF check_tax_code_valid( iv_tax_code = ls_item-tax_code
                                 iv_company_code = is_header-company_code ) = abap_false.
          add_error(
            iv_field = |{ lv_item_prefix }.tax_code|
            iv_code = 'TAX_CODE_INVALID'
            iv_message = |Line item { ls_item-item_number }: Tax code { ls_item-tax_code } is not valid|
            iv_severity = 'ERROR'
          ).
        ENDIF.
      ENDIF.

      " Amount check
      IF ls_item-amount = 0.
        add_error(
          iv_field = |{ lv_item_prefix }.amount|
          iv_code = 'ZERO_AMOUNT'
          iv_message = |Line item { ls_item-item_number }: Amount cannot be zero|
          iv_severity = 'WARNING'
        ).
      ENDIF.

      lv_item_total = lv_item_total + ls_item-amount + ls_item-tax_amount.
    ENDLOOP.

    " Amount reconciliation
    IF validate_amount_reconciliation(
         iv_gross_amount = is_header-gross_amount
         iv_net_amount = is_header-net_amount
         iv_tax_amount = is_header-tax_amount
         it_items = it_items ) = abap_false.
      add_error(
        iv_field = 'invoice_header.gross_amount'
        iv_code = 'AMOUNT_MISMATCH'
        iv_message = |Header gross amount ({ is_header-gross_amount }) does not match sum of line items ({ lv_item_total })|
        iv_severity = 'ERROR'
        iv_suggestion = 'Please verify amounts at header and item level'
      ).
    ENDIF.
  ENDMETHOD.

  METHOD check_vendor_exists.
    rv_valid = abap_false.

    " Convert vendor number to internal format (add leading zeros)
    DATA(lv_vendor_internal) = iv_vendor.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = iv_vendor
      IMPORTING
        output = lv_vendor_internal.

    " Check if vendor exists in general (LFA1)
    SELECT SINGLE lifnr FROM lfa1
      INTO @DATA(lv_vendor)
      WHERE lifnr = @lv_vendor_internal.

    IF sy-subrc = 0.
      " Check if vendor exists for company code (LFB1)
      SELECT SINGLE lifnr FROM lfb1
        INTO @lv_vendor
        WHERE lifnr = @lv_vendor_internal
          AND bukrs = @iv_company_code.
      IF sy-subrc = 0.
        rv_valid = abap_true.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD check_vendor_blocked.
    ev_blocked = abap_false.
    ev_block_reason = ''.

    " Convert vendor number to internal format (add leading zeros)
    DATA(lv_vendor_internal) = iv_vendor.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = iv_vendor
      IMPORTING
        output = lv_vendor_internal.

    " Check vendor blocking fields in LFB1
    " SPERR_B = Posting block for company code
    " LOEVM_B = Deletion flag
    " ZAHLS = Payment block
    SELECT SINGLE lifnr, sperr, loevm, zahls FROM lfb1
      INTO @DATA(ls_block)
      WHERE lifnr = @lv_vendor_internal
        AND bukrs = @iv_company_code.
    IF sy-subrc = 0.
      IF ls_block-sperr IS NOT INITIAL.
        ev_blocked = abap_true.
        ev_block_reason = 'Posting block active for company code'.
      ELSEIF ls_block-loevm IS NOT INITIAL.
        ev_blocked = abap_true.
        ev_block_reason = 'Vendor marked for deletion in company code'.
      ELSEIF ls_block-zahls IS NOT INITIAL.
        ev_blocked = abap_true.
        ev_block_reason = 'Payment block active'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD check_duplicate_invoice.
    ev_exists = abap_false.

    " Convert vendor number to internal format (add leading zeros)
    DATA(lv_vendor_internal) = iv_vendor.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = iv_vendor
      IMPORTING
        output = lv_vendor_internal.

    " Check in BKPF (existing posted documents)
    SELECT SINGLE belnr, gjahr FROM bkpf
      INTO (@ev_document, @ev_fiscal_year)
      WHERE bukrs = @iv_company_code
        AND xblnr = @iv_invoice_num.
    IF sy-subrc = 0.
      ev_exists = abap_true.
      RETURN.
    ENDIF.

    " Check in ZFINN_INV_HRD (pending/processed invoices)
    SELECT SINGLE sap_document, sap_fiscal_year FROM zfinn_inv_hrd
      INTO (@ev_document, @ev_fiscal_year)
      WHERE company_code = @iv_company_code
        AND invoice_number = @iv_invoice_num
        AND vendor_number = @lv_vendor_internal
        AND status IN ('S', 'P').  "Success or In Progress
    IF sy-subrc = 0.
      ev_exists = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD check_gl_account_valid.
    rv_valid = abap_false.

    " Convert GL account to internal format (add leading zeros)
    DATA(lv_gl_internal) = iv_gl_account.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = iv_gl_account
      IMPORTING
        output = lv_gl_internal.

    " Check if GL exists in chart of accounts (SKA1)
    SELECT SINGLE saknr FROM ska1
      INTO @DATA(lv_gl)
      WHERE saknr = @lv_gl_internal.

    IF sy-subrc = 0.
      " Check if GL exists for company code (SKB1)
      SELECT SINGLE saknr FROM skb1
        INTO @lv_gl
        WHERE saknr = @lv_gl_internal
          AND bukrs = @iv_company_code.
      IF sy-subrc = 0.
        rv_valid = abap_true.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD check_cost_center_valid.
    rv_valid = abap_false.
    SELECT SINGLE kostl FROM csks
      INTO @DATA(lv_costcenter)
      WHERE kostl = @iv_cost_center
        AND datbi >= @sy-datum
        AND datab <= @sy-datum.
    IF sy-subrc = 0.
      rv_valid = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD check_posting_period_open.
    " Simplified posting period check
    " In a real scenario, this would check T001B with proper interval logic
    " For now, just check if posting date is not too far in the past
    rv_open = abap_true.

    " Block if posting date is more than 90 days in the past
    DATA(lv_cutoff_date) = sy-datum - 90.
    IF iv_posting_date < lv_cutoff_date.
      rv_open = abap_false.
    ENDIF.

    " Block if posting date is more than 5 days in the future
    DATA(lv_future_date) = sy-datum + 5.
    IF iv_posting_date > lv_future_date.
      rv_open = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD check_tax_code_valid.
    rv_valid = abap_false.
    SELECT SINGLE mwskz FROM t007a
      INTO @DATA(lv_tax)
      WHERE mwskz = @iv_tax_code
        AND kalsm = ( SELECT kalsm FROM t005 WHERE land1 = 'DE' ). "Adjust for country
    IF sy-subrc = 0.
      rv_valid = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD validate_amount_reconciliation.
    rv_valid = abap_false.
    DATA(lv_item_sum) = CONV wrbtr( 0 ).
    DATA(lv_item_tax_sum) = CONV wrbtr( 0 ).

    LOOP AT it_items INTO DATA(ls_item).
      lv_item_sum = lv_item_sum + ls_item-amount.
      lv_item_tax_sum = lv_item_tax_sum + ls_item-tax_amount.
    ENDLOOP.

    DATA(lv_calculated_gross) = lv_item_sum + lv_item_tax_sum.
    DATA(lv_diff) = abs( iv_gross_amount - lv_calculated_gross ).

    " Allow small rounding differences (0.02)
    IF lv_diff <= CONV wrbtr( '0.02' ).
      rv_valid = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD add_error.
    APPEND VALUE #(
      field = iv_field
      code = iv_code
      message = iv_message
      severity = iv_severity
      suggestion = iv_suggestion
    ) TO mt_errors.
  ENDMETHOD.

  METHOD add_warning.
    APPEND VALUE #(
      field = iv_field
      code = iv_code
      message = iv_message
      severity = iv_severity
      suggestion = iv_suggestion
    ) TO mt_warnings.
  ENDMETHOD.

ENDCLASS.
