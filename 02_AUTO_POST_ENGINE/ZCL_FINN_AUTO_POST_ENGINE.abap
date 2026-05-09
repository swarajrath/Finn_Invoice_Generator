CLASS zcl_finn_auto_post_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      " Posting method
      BEGIN OF ty_posting_method,
        method_code TYPE string,  " FB60, MIRO
        description TYPE string,
      END OF ty_posting_method,

      " FB60 - General Vendor Invoice Posting
      BEGIN OF ty_fb60_header,
        company_code       TYPE bukrs,
        posting_date       TYPE budat,
        document_date      TYPE bldat,
        reference          TYPE xblnr1,
        doc_header_text    TYPE bktxt,
        currency           TYPE waers,
        exchange_rate      TYPE kursf,
        translation_date   TYPE wwert,
        posting_period     TYPE monat,
        fiscal_year        TYPE gjahr,
      END OF ty_fb60_header,

      BEGIN OF ty_fb60_vendor_line,
        vendor_number      TYPE lifnr,
        special_gl_ind     TYPE umskz,
        amount             TYPE wrbtr,
        payment_terms      TYPE dzterm,
        baseline_date      TYPE dzfbdt,
        payment_method     TYPE dzwels,
        payment_block      TYPE dzahls,
        bank_details       TYPE bvtyp,
        assignment         TYPE dzuonr,
        text               TYPE sgtxt,
      END OF ty_fb60_vendor_line,

      BEGIN OF ty_fb60_gl_line,
        gl_account         TYPE hkont,
        amount             TYPE wrbtr,
        tax_code           TYPE mwskz,
        cost_center        TYPE kostl,
        profit_center      TYPE prctr,
        internal_order     TYPE aufnr,
        wbs_element        TYPE ps_posid,
        business_area      TYPE gsber,
        assignment         TYPE dzuonr,
        text               TYPE sgtxt,
        quantity           TYPE menge_d,
        unit               TYPE meins,
        value_date         TYPE valut,
      END OF ty_fb60_gl_line,

      tt_fb60_gl_lines TYPE STANDARD TABLE OF ty_fb60_gl_line WITH DEFAULT KEY,

      BEGIN OF ty_fb60_request,
        header             TYPE ty_fb60_header,
        vendor_line        TYPE ty_fb60_vendor_line,
        gl_lines           TYPE tt_fb60_gl_lines,
      END OF ty_fb60_request,

      " MIRO - Invoice Verification (PO-based)
      BEGIN OF ty_miro_header,
        company_code       TYPE bukrs,
        invoice_date       TYPE bldat,
        posting_date       TYPE budat,
        reference          TYPE xblnr1,
        header_text        TYPE bktxt,
        currency           TYPE waers,
        exchange_rate      TYPE kursf,
        calculate_tax      TYPE abap_bool,
        gross_invoice      TYPE abap_bool,
      END OF ty_miro_header,

      BEGIN OF ty_miro_po_item,
        po_number          TYPE ebeln,
        po_item            TYPE ebelp,
        quantity           TYPE menge_d,
        amount             TYPE wrbtr,
        ok_indicator       TYPE abap_bool,
      END OF ty_miro_po_item,

      tt_miro_po_items TYPE STANDARD TABLE OF ty_miro_po_item WITH DEFAULT KEY,

      BEGIN OF ty_miro_request,
        header             TYPE ty_miro_header,
        po_items           TYPE tt_miro_po_items,
      END OF ty_miro_request,

      " Generic posting response
      BEGIN OF ty_posting_response,
        success            TYPE abap_bool,
        document_number    TYPE belnr_d,
        fiscal_year        TYPE gjahr,
        company_code       TYPE bukrs,
        posting_date       TYPE budat,
        error_code         TYPE string,
        error_message      TYPE string,
        warning_messages   TYPE string_table,
        bapi_return        TYPE bapiret2_t,
      END OF ty_posting_response.

    " Main posting methods
    METHODS post_invoice_fb60
      IMPORTING
        is_request           TYPE ty_fb60_request
        iv_testrun           TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_response)   TYPE ty_posting_response.

    METHODS post_invoice_miro
      IMPORTING
        is_request           TYPE ty_miro_request
        iv_testrun           TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_response)   TYPE ty_posting_response.

    " Validation methods
    METHODS validate_fb60_request
      IMPORTING
        is_request           TYPE ty_fb60_request
      EXPORTING
        et_errors            TYPE bapiret2_t
      RETURNING
        VALUE(rv_valid)      TYPE abap_bool.

    METHODS validate_miro_request
      IMPORTING
        is_request           TYPE ty_miro_request
      EXPORTING
        et_errors            TYPE bapiret2_t
      RETURNING
        VALUE(rv_valid)      TYPE abap_bool.

  PRIVATE SECTION.

    METHODS build_bapi_header_fb60
      IMPORTING
        is_header            TYPE ty_fb60_header
      RETURNING
        VALUE(rs_doc_header) TYPE bapiache09.

    METHODS build_bapi_vendor_line
      IMPORTING
        is_vendor_line       TYPE ty_fb60_vendor_line
        iv_company_code      TYPE bukrs
        iv_currency          TYPE waers
      EXPORTING
        es_accountpayable    TYPE bapiacap09
        es_currency          TYPE bapiaccr09.

    METHODS build_bapi_gl_lines
      IMPORTING
        it_gl_lines          TYPE tt_fb60_gl_lines
        iv_company_code      TYPE bukrs
        iv_currency          TYPE waers
      EXPORTING
        et_accountgl         TYPE bapiacgl09_tab
        et_currency          TYPE bapiaccr09_tab.

    METHODS call_bapi_acc_document_post
      IMPORTING
        is_documentheader    TYPE bapiache09
        it_accountgl         TYPE bapiacgl09_tab
        it_accountpayable    TYPE bapiacap09_tab
        it_currencyamount    TYPE bapiaccr09_tab
        iv_testrun           TYPE abap_bool DEFAULT abap_false
      EXPORTING
        ev_document          TYPE belnr_d
        ev_fiscal_year       TYPE gjahr
        ev_success           TYPE abap_bool
        et_return            TYPE bapiret2_t.

    METHODS call_bapi_incoming_invoice
      IMPORTING
        is_header            TYPE ty_miro_header
        it_po_items          TYPE tt_miro_po_items
        iv_testrun           TYPE abap_bool DEFAULT abap_false
      EXPORTING
        ev_document          TYPE belnr_d
        ev_fiscal_year       TYPE gjahr
        ev_success           TYPE abap_bool
        et_return            TYPE bapiret2_t.

ENDCLASS.



CLASS zcl_finn_auto_post_engine IMPLEMENTATION.

  METHOD post_invoice_fb60.
    DATA: ls_doc_header    TYPE bapiache09,
          ls_accountpayable TYPE bapiacap09,
          ls_curr_ap       TYPE bapiaccr09,
          lt_accountgl     TYPE bapiacgl09_tab,
          lt_currencyamount TYPE bapiaccr09_tab,
          lt_errors        TYPE bapiret2_t.

    " Step 1: Validate request
    IF validate_fb60_request(
         EXPORTING is_request = is_request
         IMPORTING et_errors = lt_errors ) = abap_false.

      rs_response-success = abap_false.
      rs_response-error_code = 'VALIDATION_ERROR'.
      rs_response-error_message = 'FB60 request validation failed'.
      rs_response-bapi_return = lt_errors.
      RETURN.
    ENDIF.

    " Step 2: Build BAPI structures
    ls_doc_header = build_bapi_header_fb60( is_request-header ).

    build_bapi_vendor_line(
      EXPORTING is_vendor_line = is_request-vendor_line
                iv_company_code = is_request-header-company_code
                iv_currency = is_request-header-currency
      IMPORTING es_accountpayable = ls_accountpayable
                es_currency = ls_curr_ap
    ).

    build_bapi_gl_lines(
      EXPORTING it_gl_lines = is_request-gl_lines
                iv_company_code = is_request-header-company_code
                iv_currency = is_request-header-currency
      IMPORTING et_accountgl = lt_accountgl
                et_currency = lt_currencyamount
    ).

    " Add vendor currency line
    APPEND ls_curr_ap TO lt_currencyamount.

    " Step 3: Call BAPI
    DATA(lt_accountpayable) = VALUE bapiacap09_tab( ( ls_accountpayable ) ).

    call_bapi_acc_document_post(
      EXPORTING is_documentheader = ls_doc_header
                it_accountgl = lt_accountgl
                it_accountpayable = lt_accountpayable
                it_currencyamount = lt_currencyamount
                iv_testrun = iv_testrun
      IMPORTING ev_document = rs_response-document_number
                ev_fiscal_year = rs_response-fiscal_year
                ev_success = rs_response-success
                et_return = rs_response-bapi_return
    ).

    " Set response details
    rs_response-company_code = is_request-header-company_code.
    rs_response-posting_date = is_request-header-posting_date.

    IF rs_response-success = abap_false.
      rs_response-error_code = 'BAPI_POST_ERROR'.
      LOOP AT rs_response-bapi_return INTO DATA(ls_return) WHERE type CA 'AE'.
        rs_response-error_message = ls_return-message.
        EXIT.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD post_invoice_miro.
    DATA: lt_errors TYPE bapiret2_t.

    " Step 1: Validate request
    IF validate_miro_request(
         EXPORTING is_request = is_request
         IMPORTING et_errors = lt_errors ) = abap_false.

      rs_response-success = abap_false.
      rs_response-error_code = 'VALIDATION_ERROR'.
      rs_response-error_message = 'MIRO request validation failed'.
      rs_response-bapi_return = lt_errors.
      RETURN.
    ENDIF.

    " Step 2: Call BAPI for invoice verification
    call_bapi_incoming_invoice(
      EXPORTING is_header = is_request-header
                it_po_items = is_request-po_items
                iv_testrun = iv_testrun
      IMPORTING ev_document = rs_response-document_number
                ev_fiscal_year = rs_response-fiscal_year
                ev_success = rs_response-success
                et_return = rs_response-bapi_return
    ).

    " Set response details
    rs_response-company_code = is_request-header-company_code.
    rs_response-posting_date = is_request-header-posting_date.

    IF rs_response-success = abap_false.
      rs_response-error_code = 'BAPI_MIRO_ERROR'.
      LOOP AT rs_response-bapi_return INTO DATA(ls_return) WHERE type CA 'AE'.
        rs_response-error_message = ls_return-message.
        EXIT.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD validate_fb60_request.
    DATA: ls_error TYPE bapiret2.

    rv_valid = abap_true.
    CLEAR et_errors.

    " Mandatory header fields
    IF is_request-header-company_code IS INITIAL.
      ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '001'
                         message = 'Company code is mandatory' ).
      APPEND ls_error TO et_errors.
      rv_valid = abap_false.
    ENDIF.

    IF is_request-header-posting_date IS INITIAL.
      ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '002'
                         message = 'Posting date is mandatory' ).
      APPEND ls_error TO et_errors.
      rv_valid = abap_false.
    ENDIF.

    IF is_request-header-currency IS INITIAL.
      ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '003'
                         message = 'Currency is mandatory' ).
      APPEND ls_error TO et_errors.
      rv_valid = abap_false.
    ENDIF.

    " Mandatory vendor line
    IF is_request-vendor_line-vendor_number IS INITIAL.
      ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '004'
                         message = 'Vendor number is mandatory' ).
      APPEND ls_error TO et_errors.
      rv_valid = abap_false.
    ENDIF.

    IF is_request-vendor_line-amount IS INITIAL OR
       is_request-vendor_line-amount = 0.
      ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '005'
                         message = 'Vendor amount is mandatory' ).
      APPEND ls_error TO et_errors.
      rv_valid = abap_false.
    ENDIF.

    " GL lines validation
    IF is_request-gl_lines IS INITIAL.
      ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '006'
                         message = 'At least one GL line is required' ).
      APPEND ls_error TO et_errors.
      rv_valid = abap_false.
    ENDIF.

    LOOP AT is_request-gl_lines INTO DATA(ls_gl_line).
      IF ls_gl_line-gl_account IS INITIAL.
        ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '007'
                           message = |GL account is mandatory for line { sy-tabix }| ).
        APPEND ls_error TO et_errors.
        rv_valid = abap_false.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD validate_miro_request.
    DATA: ls_error TYPE bapiret2.

    rv_valid = abap_true.
    CLEAR et_errors.

    " Mandatory header fields
    IF is_request-header-company_code IS INITIAL.
      ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '001'
                         message = 'Company code is mandatory' ).
      APPEND ls_error TO et_errors.
      rv_valid = abap_false.
    ENDIF.

    IF is_request-header-invoice_date IS INITIAL.
      ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '008'
                         message = 'Invoice date is mandatory' ).
      APPEND ls_error TO et_errors.
      rv_valid = abap_false.
    ENDIF.

    " PO items validation
    IF is_request-po_items IS INITIAL.
      ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '009'
                         message = 'At least one PO item is required' ).
      APPEND ls_error TO et_errors.
      rv_valid = abap_false.
    ENDIF.

    LOOP AT is_request-po_items INTO DATA(ls_po_item).
      IF ls_po_item-po_number IS INITIAL.
        ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '010'
                           message = |PO number is mandatory for item { sy-tabix }| ).
        APPEND ls_error TO et_errors.
        rv_valid = abap_false.
      ENDIF.

      IF ls_po_item-po_item IS INITIAL.
        ls_error = VALUE #( type = 'E' id = 'ZFINN' number = '011'
                           message = |PO item number is mandatory for item { sy-tabix }| ).
        APPEND ls_error TO et_errors.
        rv_valid = abap_false.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD build_bapi_header_fb60.
    rs_doc_header-bus_act = 'RFBU'.
    rs_doc_header-username = sy-uname.
    rs_doc_header-comp_code = is_header-company_code.
    rs_doc_header-doc_date = is_header-document_date.
    rs_doc_header-pstng_date = is_header-posting_date.
    rs_doc_header-ref_doc_no = is_header-reference.
    rs_doc_header-header_txt = is_header-doc_header_text.
    rs_doc_header-doc_type = 'KR'.  " Vendor invoice

    IF is_header-posting_period IS NOT INITIAL.
      rs_doc_header-fis_period = is_header-posting_period.
    ENDIF.

    IF is_header-fiscal_year IS NOT INITIAL.
      rs_doc_header-fisc_year = is_header-fiscal_year.
    ENDIF.
  ENDMETHOD.

  METHOD build_bapi_vendor_line.
    es_accountpayable-itemno_acc = '0001'.
    es_accountpayable-vendor_no = is_vendor_line-vendor_number.
    es_accountpayable-comp_code = iv_company_code.
    es_accountpayable-sp_gl_ind = is_vendor_line-special_gl_ind.
    es_accountpayable-pmnttrms = is_vendor_line-payment_terms.
    es_accountpayable-bline_date = is_vendor_line-baseline_date.
    es_accountpayable-pmnt_block = is_vendor_line-payment_block.
    es_accountpayable-pmtmthsupl = is_vendor_line-payment_method.
    es_accountpayable-alloc_nmbr = is_vendor_line-assignment.
    es_accountpayable-item_text = is_vendor_line-text.

    " Currency amount (credit - negative)
    es_currency-itemno_acc = '0001'.
    es_currency-curr_type = '00'.
    es_currency-currency = iv_currency.
    es_currency-amt_doccur = is_vendor_line-amount * -1.
  ENDMETHOD.

  METHOD build_bapi_gl_lines.
    DATA: ls_accountgl TYPE bapiacgl09,
          ls_currency  TYPE bapiaccr09,
          lv_itemno    TYPE posnr_acc VALUE '0002'.

    LOOP AT it_gl_lines INTO DATA(ls_gl_line).
      CLEAR: ls_accountgl, ls_currency.

      " GL line
      ls_accountgl-itemno_acc = lv_itemno.
      ls_accountgl-gl_account = ls_gl_line-gl_account.
      ls_accountgl-comp_code = iv_company_code.
      ls_accountgl-item_text = ls_gl_line-text.
      ls_accountgl-tax_code = ls_gl_line-tax_code.
      ls_accountgl-costcenter = ls_gl_line-cost_center.
      ls_accountgl-profit_ctr = ls_gl_line-profit_center.
      ls_accountgl-orderid = ls_gl_line-internal_order.
      ls_accountgl-wbs_element = ls_gl_line-wbs_element.
      ls_accountgl-bus_area = ls_gl_line-business_area.
      ls_accountgl-alloc_nmbr = ls_gl_line-assignment.
      ls_accountgl-quantity = ls_gl_line-quantity.
      ls_accountgl-base_uom = ls_gl_line-unit.
      ls_accountgl-value_date = ls_gl_line-value_date.

      APPEND ls_accountgl TO et_accountgl.

      " Currency amount (debit - positive)
      ls_currency-itemno_acc = lv_itemno.
      ls_currency-curr_type = '00'.
      ls_currency-currency = iv_currency.
      ls_currency-amt_doccur = ls_gl_line-amount.

      APPEND ls_currency TO et_currency.

      lv_itemno = lv_itemno + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD call_bapi_acc_document_post.
    DATA: lv_obj_type TYPE bapiache09-obj_type,
          lv_obj_key  TYPE bapiache09-obj_key,
          lv_obj_sys  TYPE bapiache09-obj_sys,
          lt_accountgl_local TYPE bapiacgl09_tab,
          lt_accountpayable_local TYPE bapiacap09_tab,
          lt_currencyamount_local TYPE bapiaccr09_tab.

    CLEAR: ev_document, ev_fiscal_year, ev_success, et_return.

    " Create local copies of tables (BAPI modifies TABLES parameters)
    lt_accountgl_local = it_accountgl.
    lt_accountpayable_local = it_accountpayable.
    lt_currencyamount_local = it_currencyamount.

    " Call BAPI
    CALL FUNCTION 'BAPI_ACC_DOCUMENT_POST'
      EXPORTING
        documentheader = is_documentheader
      IMPORTING
        obj_type       = lv_obj_type
        obj_key        = lv_obj_key
        obj_sys        = lv_obj_sys
      TABLES
        accountgl      = lt_accountgl_local
        accountpayable = lt_accountpayable_local
        currencyamount = lt_currencyamount_local
        return         = et_return.

    " Check for errors
    READ TABLE et_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      ev_success = abap_false.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ELSE.
      " If test mode, rollback instead of commit
      IF iv_testrun = abap_true.
        ev_success = abap_true.
        ev_document = lv_obj_key+0(10).
        ev_fiscal_year = lv_obj_key+14(4).
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
        " Add info message to return table
        APPEND VALUE #(
          type = 'S'
          id = 'ZFINN'
          number = '999'
          message = 'Test mode: Document not committed (rolled back)'
        ) TO et_return.
      ELSE.
        ev_success = abap_true.
        ev_document = lv_obj_key+0(10).
        ev_fiscal_year = lv_obj_key+14(4).
        " Commit
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = 'X'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD call_bapi_incoming_invoice.
    DATA: ls_headerdata   TYPE bapi_incinv_create_header,
          lt_itemdata     TYPE TABLE OF bapi_incinv_create_item,
          ls_itemdata     TYPE bapi_incinv_create_item,
          lv_invoicedocnumber TYPE bapi_incinv_fld-inv_doc_no,
          lv_fiscalyear   TYPE bapi_incinv_fld-fisc_year.

    CLEAR: ev_document, ev_fiscal_year, ev_success, et_return.

    " Build header
    ls_headerdata-invoice_ind = 'X'.
    ls_headerdata-doc_date = is_header-invoice_date.
    ls_headerdata-pstng_date = is_header-posting_date.
    ls_headerdata-ref_doc_no = is_header-reference.
    ls_headerdata-header_txt = is_header-header_text.
    ls_headerdata-currency = is_header-currency.
    ls_headerdata-comp_code = is_header-company_code.
    ls_headerdata-calc_tax_ind = is_header-calculate_tax.
    ls_headerdata-gross_amount = is_header-gross_invoice.

    " Build items
    LOOP AT it_po_items INTO DATA(ls_po_item).
      ls_itemdata-invoice_doc_item = sy-tabix.
      ls_itemdata-po_number = ls_po_item-po_number.
      ls_itemdata-po_item = ls_po_item-po_item.
      ls_itemdata-quantity = ls_po_item-quantity.
      ls_itemdata-po_unit = 'EA'.
      ls_itemdata-item_amount = ls_po_item-amount.

      IF ls_po_item-ok_indicator = abap_true.
        ls_itemdata-de_cre_ind = 'X'.
      ENDIF.

      APPEND ls_itemdata TO lt_itemdata.
    ENDLOOP.

    " Call BAPI
    CALL FUNCTION 'BAPI_INCOMINGINVOICE_CREATE'
      EXPORTING
        headerdata       = ls_headerdata
      IMPORTING
        invoicedocnumber = lv_invoicedocnumber
        fiscalyear       = lv_fiscalyear
      TABLES
        itemdata         = lt_itemdata
        return           = et_return.

    " Check for errors
    READ TABLE et_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      ev_success = abap_false.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ELSE.
      " If test mode, rollback instead of commit
      IF iv_testrun = abap_true.
        ev_success = abap_true.
        ev_document = lv_invoicedocnumber.
        ev_fiscal_year = lv_fiscalyear.
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
        " Add info message to return table
        APPEND VALUE #(
          type = 'S'
          id = 'ZFINN'
          number = '999'
          message = 'Test mode: Document not committed (rolled back)'
        ) TO et_return.
      ELSE.
        ev_success = abap_true.
        ev_document = lv_invoicedocnumber.
        ev_fiscal_year = lv_fiscalyear.
        " Commit
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = 'X'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
