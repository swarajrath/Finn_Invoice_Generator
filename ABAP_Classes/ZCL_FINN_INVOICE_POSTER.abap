CLASS zcl_finn_invoice_poster DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_posting_result,
        success           TYPE abap_bool,
        sap_document      TYPE belnr_d,
        fiscal_year       TYPE gjahr,
        error_code        TYPE string,
        error_message     TYPE string,
        technical_details TYPE string,
        processing_time_ms TYPE int4,
      END OF ty_posting_result.

    " Define table types for internal use
    TYPES: tt_invoice_items TYPE STANDARD TABLE OF zfinn_inv_item WITH DEFAULT KEY,
           tt_accountgl     TYPE STANDARD TABLE OF bapiacgl09 WITH DEFAULT KEY,
           tt_accountap     TYPE STANDARD TABLE OF bapiacap09 WITH DEFAULT KEY,
           tt_currency      TYPE STANDARD TABLE OF bapiaccr09 WITH DEFAULT KEY.

    METHODS constructor.

    "Main posting method
    METHODS post_invoice
      IMPORTING
        iv_header_uuid       TYPE sysuuid_x16
      RETURNING
        VALUE(rs_result)     TYPE ty_posting_result.

  PRIVATE SECTION.

    DATA: mo_logger TYPE REF TO zcl_finn_invoice_logger.

    METHODS read_invoice_data
      IMPORTING
        iv_header_uuid TYPE sysuuid_x16
      EXPORTING
        es_header      TYPE zfinn_inv_hrd
        et_items       TYPE tt_invoice_items.

    METHODS prepare_bapi_structures
  IMPORTING
    is_header           TYPE zfinn_inv_hrd
    it_items            TYPE tt_invoice_items
  EXPORTING
    es_documentheader   TYPE bapiache09
    et_accountgl        TYPE tt_accountgl
    et_accountpayable   TYPE tt_accountap
    et_currencyamount   TYPE tt_currency.

METHODS call_bapi_post
  IMPORTING
    is_documentheader TYPE bapiache09
    it_accountgl      TYPE tt_accountgl
    it_accountpayable TYPE tt_accountap
    it_currencyamount TYPE tt_currency
  EXPORTING
    ev_document       TYPE belnr_d
    ev_fiscal_year    TYPE gjahr
    ev_success        TYPE abap_bool
    ev_error_message  TYPE string
    et_return         TYPE bapiret2_t.

    METHODS update_header_success
      IMPORTING
        iv_header_uuid    TYPE sysuuid_x16
        iv_document       TYPE belnr_d
        iv_fiscal_year    TYPE gjahr
        iv_processing_ms  TYPE int4.

    METHODS update_header_error
      IMPORTING
        iv_header_uuid    TYPE sysuuid_x16
        iv_error_code     TYPE string
        iv_error_message  TYPE string
        iv_processing_ms  TYPE int4.

ENDCLASS.



CLASS zcl_finn_invoice_poster IMPLEMENTATION.

  METHOD constructor.
    mo_logger = NEW zcl_finn_invoice_logger( ).
  ENDMETHOD.

  METHOD post_invoice.
    DATA: ls_header     TYPE zfinn_inv_hrd,
          lt_items      TYPE STANDARD TABLE OF zfinn_inv_item,
          ls_doc_header TYPE bapiache09,
          lt_accountgl  TYPE TABLE OF bapiacgl09,
          lt_accountap  TYPE TABLE OF bapiacap09,
          lt_currency   TYPE TABLE OF bapiaccr09,
          lv_document   TYPE belnr_d,
          lv_fiscal_year TYPE gjahr,
          lv_success    TYPE abap_bool,
          lv_error_msg  TYPE string,
          lt_return     TYPE bapiret2_t,
          lv_start_time TYPE timestampl,
          lv_end_time   TYPE timestampl,
          lv_duration   TYPE int4.

    " Start timer
    GET TIME STAMP FIELD lv_start_time.

    " Initialize result
    CLEAR rs_result.

    " Update status to 'P' (In Progress)
    UPDATE zfinn_inv_hrd
      SET status = 'P',
          changed_at = @lv_start_time,
          changed_by = @sy-uname
      WHERE header_uuid = @iv_header_uuid.
    COMMIT WORK.

    " Log start of posting
    mo_logger->log_event(
      iv_header_uuid = iv_header_uuid
      iv_event_type = 'POSTING_STARTED'
      iv_old_status = 'P'
      iv_new_status = 'P'
    ).

    TRY.
        " 1. Read invoice data from 3 tables
        read_invoice_data(
          EXPORTING iv_header_uuid = iv_header_uuid
          IMPORTING es_header = ls_header
                    et_items = lt_items
        ).

        IF ls_header-header_uuid IS INITIAL.
          rs_result-success = abap_false.
          rs_result-error_code = 'INVOICE_NOT_FOUND'.
          rs_result-error_message = 'Invoice not found in database'.
          RETURN.
        ENDIF.

        " 2. Prepare BAPI structures
        prepare_bapi_structures(
          EXPORTING is_header = ls_header
                    it_items = lt_items
          IMPORTING es_documentheader = ls_doc_header
                    et_accountgl = lt_accountgl
                    et_accountpayable = lt_accountap
                    et_currencyamount = lt_currency
        ).

        " 3. Call BAPI to post document
        call_bapi_post(
          EXPORTING is_documentheader = ls_doc_header
                    it_accountgl = lt_accountgl
                    it_accountpayable = lt_accountap
                    it_currencyamount = lt_currency
          IMPORTING ev_document = lv_document
                    ev_fiscal_year = lv_fiscal_year
                    ev_success = lv_success
                    ev_error_message = lv_error_msg
                    et_return = lt_return
        ).

        " Calculate processing time
        GET TIME STAMP FIELD lv_end_time.
        lv_duration = cl_abap_tstmp=>subtract(
          tstmp1 = lv_end_time
          tstmp2 = lv_start_time
        ) * 1000.  " Convert to milliseconds

        " 4. Update database based on result
        IF lv_success = abap_true.
          " Success - update header with document number
          update_header_success(
            iv_header_uuid = iv_header_uuid
            iv_document = lv_document
            iv_fiscal_year = lv_fiscal_year
            iv_processing_ms = lv_duration
          ).

          " Log success
          mo_logger->log_event(
            iv_header_uuid = iv_header_uuid
            iv_event_type = 'POSTED'
            iv_old_status = 'P'
            iv_new_status = 'S'
            iv_duration_ms = lv_duration
          ).

          " Commit the posting
          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
            EXPORTING
              wait = 'X'.

          " Set result
          rs_result-success = abap_true.
          rs_result-sap_document = lv_document.
          rs_result-fiscal_year = lv_fiscal_year.
          rs_result-processing_time_ms = lv_duration.

        ELSE.
          " Error - rollback and update header
          CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

          " Build detailed error message
          DATA(lv_technical_error) = CONV string( '' ).
          LOOP AT lt_return INTO DATA(ls_return) WHERE type = 'E' OR type = 'A'.
            lv_technical_error = |{ lv_technical_error } { ls_return-message }|.
          ENDLOOP.

          update_header_error(
            iv_header_uuid = iv_header_uuid
            iv_error_code = 'BAPI_ERROR'
            iv_error_message = lv_error_msg
            iv_processing_ms = lv_duration
          ).

          " Log error
          mo_logger->log_event(
            iv_header_uuid = iv_header_uuid
            iv_event_type = 'ERROR'
            iv_old_status = 'P'
            iv_new_status = 'E'
            iv_error_code = 'BAPI_ERROR'
            iv_error_message = lv_error_msg
            iv_technical_error = lv_technical_error
            iv_duration_ms = lv_duration
          ).

          " Set result
          rs_result-success = abap_false.
          rs_result-error_code = 'BAPI_ERROR'.
          rs_result-error_message = lv_error_msg.
          rs_result-technical_details = lv_technical_error.
          rs_result-processing_time_ms = lv_duration.
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        " Exception handling
        rs_result-success = abap_false.
        rs_result-error_code = 'EXCEPTION'.
        rs_result-error_message = lx_error->get_text( ).

        update_header_error(
          iv_header_uuid = iv_header_uuid
          iv_error_code = 'EXCEPTION'
          iv_error_message = lx_error->get_text( )
          iv_processing_ms = 0
        ).

        mo_logger->log_event(
          iv_header_uuid = iv_header_uuid
          iv_event_type = 'ERROR'
          iv_old_status = 'P'
          iv_new_status = 'E'
          iv_error_code = 'EXCEPTION'
          iv_error_message = lx_error->get_text( )
          iv_technical_error = lx_error->get_longtext( )
        ).

        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ENDTRY.

  ENDMETHOD.

  METHOD read_invoice_data.
    " Read header
    SELECT SINGLE * FROM zfinn_inv_hrd
      INTO @es_header
      WHERE header_uuid = @iv_header_uuid.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Read items
    SELECT * FROM zfinn_inv_item
      INTO TABLE @et_items
      WHERE header_uuid = @iv_header_uuid
      ORDER BY item_number.
  ENDMETHOD.

  METHOD prepare_bapi_structures.
    " Document Header
    es_documentheader-bus_act = 'RFBU'.  " Posting
    es_documentheader-username = sy-uname.
    es_documentheader-header_txt = is_header-header_text.
    es_documentheader-comp_code = is_header-company_code.
    es_documentheader-doc_date = is_header-document_date.
    es_documentheader-pstng_date = is_header-posting_date.
    es_documentheader-doc_type = is_header-document_type.
    es_documentheader-ref_doc_no = is_header-invoice_number.
    " Note: BAPIACHE09 doesn't have curr_type field - currency is set per line item

    " Vendor line (Accounts Payable)
    DATA: ls_accountap TYPE bapiacap09,
          ls_currency_ap TYPE bapiaccr09.

    ls_accountap-itemno_acc = '0001'.
    ls_accountap-vendor_no = is_header-vendor_number.
    ls_accountap-comp_code = is_header-company_code.
    ls_accountap-item_text = 'Vendor Invoice'.
    ls_accountap-pmnttrms = is_header-payment_terms.
    ls_accountap-bline_date = is_header-baseline_date.
    ls_accountap-pmnt_block = is_header-payment_block.
    ls_accountap-pmtmthsupl = is_header-payment_method.
    APPEND ls_accountap TO et_accountpayable.

    " Vendor line amount (credit)
    ls_currency_ap-itemno_acc = '0001'.
    ls_currency_ap-currency = is_header-currency.
    ls_currency_ap-amt_doccur = is_header-gross_amount * -1.  " Credit
    APPEND ls_currency_ap TO et_currencyamount.

    " GL account lines (debit)
    DATA: lv_line_number TYPE numc4 VALUE '0002',
          ls_accountgl TYPE bapiacgl09,
          ls_currency_gl TYPE bapiaccr09.

    LOOP AT it_items INTO DATA(ls_item).
      ls_accountgl-itemno_acc = lv_line_number.
      ls_accountgl-gl_account = ls_item-gl_account.
      ls_accountgl-comp_code = is_header-company_code.
      ls_accountgl-item_text = ls_item-item_text.
      ls_accountgl-costcenter = ls_item-cost_center.
      ls_accountgl-profit_ctr = ls_item-profit_center.
      " BAPIACGL09 doesn't have orderid, material fields - removed
      ls_accountgl-wbs_element = ls_item-wbs_element.
      ls_accountgl-tax_code = ls_item-tax_code.
      ls_accountgl-quantity = ls_item-quantity.
      ls_accountgl-base_uom = ls_item-unit.
      ls_accountgl-plant = ls_item-plant.
      ls_accountgl-bus_area = is_header-business_area.
      APPEND ls_accountgl TO et_accountgl.

      " GL line amount (debit)
      ls_currency_gl-itemno_acc = lv_line_number.
      ls_currency_gl-currency = is_header-currency.
      ls_currency_gl-amt_doccur = ls_item-amount + ls_item-tax_amount.
      APPEND ls_currency_gl TO et_currencyamount.

      lv_line_number = lv_line_number + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD call_bapi_post.
    DATA: lv_obj_type TYPE bapiache09-obj_type,
          lv_obj_key  TYPE bapiache09-obj_key,
          lv_obj_sys  TYPE bapiache09-obj_sys,
          lt_return   TYPE TABLE OF bapiret2.

    CLEAR: ev_document, ev_fiscal_year, ev_success, ev_error_message.

    " Call BAPI
    CALL FUNCTION 'BAPI_ACC_DOCUMENT_POST'
      EXPORTING
        documentheader = is_documentheader
      IMPORTING
        obj_type       = lv_obj_type
        obj_key        = lv_obj_key
        obj_sys        = lv_obj_sys
      TABLES
        accountgl      = it_accountgl
        accountpayable = it_accountpayable
        currencyamount = it_currencyamount
        return         = lt_return.

    et_return = lt_return.

    " Check for errors
    READ TABLE lt_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      " Error occurred
      ev_success = abap_false.
      " Get first error message
      READ TABLE lt_return INTO DATA(ls_error) WITH KEY type = 'E'.
      IF sy-subrc = 0.
        ev_error_message = ls_error-message.
      ENDIF.
    ELSE.
      " Success
      ev_success = abap_true.
      ev_document = lv_obj_key+0(10).
      ev_fiscal_year = lv_obj_key+14(4).
    ENDIF.
  ENDMETHOD.

  METHOD update_header_success.
    GET TIME STAMP FIELD DATA(lv_timestamp).

    UPDATE zfinn_inv_hrd
      SET status = 'S',
          sap_document = @iv_document,
          sap_fiscal_year = @iv_fiscal_year,
          posted_at = @lv_timestamp,
          processing_time_ms = @iv_processing_ms,
          changed_at = @lv_timestamp,
          changed_by = @sy-uname,
          error_code = '',
          error_message = '',
          error_field = ''
      WHERE header_uuid = @iv_header_uuid.

    COMMIT WORK.
  ENDMETHOD.

  METHOD update_header_error.
    GET TIME STAMP FIELD DATA(lv_timestamp).

    UPDATE zfinn_inv_hrd
      SET status = 'E',
          error_code = @iv_error_code,
          error_message = @iv_error_message,
          processing_time_ms = @iv_processing_ms,
          retry_count = retry_count + 1,
          changed_at = @lv_timestamp,
          changed_by = @sy-uname
      WHERE header_uuid = @iv_header_uuid.

    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
