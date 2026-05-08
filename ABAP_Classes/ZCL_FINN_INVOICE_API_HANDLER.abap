CLASS zcl_finn_invoice_api_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_http_extension.

  PRIVATE SECTION.

    DATA: mo_validator TYPE REF TO zcl_finn_invoice_validator,
          mo_poster    TYPE REF TO zcl_finn_invoice_poster,
          mo_logger    TYPE REF TO zcl_finn_invoice_logger.

    METHODS handle_post_request
      IMPORTING
        io_request       TYPE REF TO if_http_request
        io_response      TYPE REF TO if_http_response.

    METHODS parse_json_request
      IMPORTING
        iv_json          TYPE string
      EXPORTING
        es_header        TYPE zcl_finn_invoice_validator=>ty_invoice_header
        et_items         TYPE zcl_finn_invoice_validator=>tt_invoice_items
        ev_correlation_id TYPE string
        ev_success       TYPE abap_bool
        ev_error_message TYPE string.

    METHODS store_invoice_data
      IMPORTING
        is_header        TYPE zcl_finn_invoice_validator=>ty_invoice_header
        it_items         TYPE zcl_finn_invoice_validator=>tt_invoice_items
        iv_request_json  TYPE string
        iv_correlation_id TYPE string
      EXPORTING
        ev_header_uuid   TYPE sysuuid_x16.

    METHODS build_success_response
      IMPORTING
        iv_header_uuid    TYPE sysuuid_x16
        iv_sap_document   TYPE belnr_d
        iv_fiscal_year    TYPE gjahr
        iv_company_code   TYPE bukrs
        iv_posting_date   TYPE budat
        iv_processing_ms  TYPE int4
      RETURNING
        VALUE(rv_json)    TYPE string.

    METHODS build_validation_error_rspn
      IMPORTING
        iv_header_uuid    TYPE sysuuid_x16
        it_errors         TYPE zcl_finn_invoice_validator=>tt_validation_errors
        iv_processing_ms  TYPE int4
      RETURNING
        VALUE(rv_json)    TYPE string.

    METHODS build_error_response
      IMPORTING
        iv_header_uuid    TYPE sysuuid_x16 OPTIONAL
        iv_error_code     TYPE string
        iv_error_message  TYPE string
        iv_technical_details TYPE string OPTIONAL
        iv_retry_allowed  TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_json)    TYPE string.

    METHODS get_fiori_correction_url
      IMPORTING
        iv_header_uuid   TYPE sysuuid_x16
      RETURNING
        VALUE(rv_url)    TYPE string.

ENDCLASS.



CLASS zcl_finn_invoice_api_handler IMPLEMENTATION.

  METHOD if_http_extension~handle_request.
    " Initialize components
    mo_validator = NEW zcl_finn_invoice_validator( ).
    mo_poster = NEW zcl_finn_invoice_poster( ).
    mo_logger = NEW zcl_finn_invoice_logger( ).

    " Get HTTP method
    DATA(lv_method) = server->request->get_method( ).

    " Only accept POST requests
    IF lv_method <> 'POST'.
      server->response->set_status( code = 405 reason = 'Method Not Allowed' ).
      server->response->set_cdata( '{"status":"ERROR","message":"Only POST method is supported"}' ).
      RETURN.
    ENDIF.

    " Handle POST request
    handle_post_request(
      io_request = server->request
      io_response = server->response
    ).
  ENDMETHOD.

  METHOD handle_post_request.
    DATA: lv_json           TYPE string,
          ls_header         TYPE zcl_finn_invoice_validator=>ty_invoice_header,
          lt_items          TYPE zcl_finn_invoice_validator=>tt_invoice_items,
          lv_correlation_id TYPE string,
          lv_header_uuid    TYPE sysuuid_x16,
          lv_parse_success  TYPE abap_bool,
          lv_parse_error    TYPE string,
          lt_errors         TYPE zcl_finn_invoice_validator=>tt_validation_errors,
          lt_warnings       TYPE zcl_finn_invoice_validator=>tt_validation_errors,
          lv_valid          TYPE abap_bool,
          ls_post_result    TYPE zcl_finn_invoice_poster=>ty_posting_result,
          lv_response_json  TYPE string,
          lv_start_time     TYPE timestampl,
          lv_end_time       TYPE timestampl,
          lv_duration_ms    TYPE int4,
          lv_ip_address     TYPE string.

    " Start timer
    GET TIME STAMP FIELD lv_start_time.

    " Get client IP address
    lv_ip_address = io_request->get_header_field( '~remote_addr' ).

    " Get JSON payload
    lv_json = io_request->get_cdata( ).

    " 1. Parse JSON request
    parse_json_request(
      EXPORTING iv_json = lv_json
      IMPORTING es_header = ls_header
                et_items = lt_items
                ev_correlation_id = lv_correlation_id
                ev_success = lv_parse_success
                ev_error_message = lv_parse_error
    ).

    IF lv_parse_success = abap_false.
      " JSON parsing failed
      lv_response_json = build_error_response(
        iv_error_code = 'JSON_PARSE_ERROR'
        iv_error_message = lv_parse_error
      ).
      io_response->set_status( code = 400 reason = 'Bad Request' ).
      io_response->set_cdata( lv_response_json ).
      io_response->set_header_field( name = 'Content-Type' value = 'application/json' ).
      RETURN.
    ENDIF.

    " 2. Store invoice data in database (status = 'N')
    store_invoice_data(
      EXPORTING is_header = ls_header
                it_items = lt_items
                iv_request_json = lv_json
                iv_correlation_id = lv_correlation_id
      IMPORTING ev_header_uuid = lv_header_uuid
    ).

    " Log receipt
    mo_logger->log_event(
      iv_header_uuid = lv_header_uuid
      iv_event_type = 'RECEIVED'
      iv_new_status = 'N'
      iv_request_payload = lv_json
      iv_correlation_id = lv_correlation_id
      iv_ip_address = lv_ip_address
    ).

    " 3. Validate invoice
    lv_valid = mo_validator->validate_invoice(
      EXPORTING is_header = ls_header
                it_items = lt_items
      IMPORTING et_errors = lt_errors
                et_warnings = lt_warnings
    ).

    GET TIME STAMP FIELD lv_end_time.
    DATA(lv_validation_duration) = CONV int4(
      cl_abap_tstmp=>subtract(
        tstmp1 = lv_end_time
        tstmp2 = lv_start_time
      ) * 1000
    ).

    IF lv_valid = abap_false.
      " Validation failed - update header with errors
      UPDATE ZFINN_INV_HRD
        SET status = 'V',
            error_code = 'VALIDATION_FAILED',
            error_message = 'Invoice validation failed',
            processing_time_ms = @lv_validation_duration
        WHERE header_uuid = @lv_header_uuid.
      COMMIT WORK.

      " Update items with validation errors
      LOOP AT lt_errors INTO DATA(ls_error) WHERE field CS 'invoice_items'.
        " Extract item number from field path
        FIND REGEX '\[(\d+)\]' IN ls_error-field SUBMATCHES DATA(lv_item_idx).
        IF sy-subrc = 0.
          DATA(lv_item_num) = CONV posnr( lv_item_idx ).
          UPDATE zfinn_inv_item
            SET validation_status = 'E',
                error_code = @ls_error-code,
                error_message = @ls_error-message
            WHERE header_uuid = @lv_header_uuid
              AND item_number = @lv_item_num.
        ENDIF.
      ENDLOOP.
      COMMIT WORK.

      " Log validation failure
      mo_logger->log_event(
        iv_header_uuid = lv_header_uuid
        iv_event_type = 'VALIDATED'
        iv_old_status = 'N'
        iv_new_status = 'V'
        iv_error_code = 'VALIDATION_FAILED'
        iv_error_message = 'Invoice validation failed'
        iv_validation_duration = lv_validation_duration
      ).

      " Return validation error response
      lv_response_json = build_validation_error_rspn(
        iv_header_uuid = lv_header_uuid
        it_errors = lt_errors
        iv_processing_ms = lv_validation_duration
      ).
      io_response->set_status( code = 422 reason = 'Unprocessable Entity' ).
      io_response->set_cdata( lv_response_json ).
      io_response->set_header_field( name = 'Content-Type' value = 'application/json' ).
      RETURN.
    ENDIF.

    " Log successful validation
    mo_logger->log_event(
      iv_header_uuid = lv_header_uuid
      iv_event_type = 'VALIDATED'
      iv_old_status = 'N'
      iv_new_status = 'P'
      iv_validation_duration = lv_validation_duration
    ).

    " 4. Post invoice to SAP
    ls_post_result = mo_poster->post_invoice( lv_header_uuid ).

    " Calculate total processing time
    GET TIME STAMP FIELD lv_end_time.
    lv_duration_ms = cl_abap_tstmp=>subtract(
      tstmp1 = lv_end_time
      tstmp2 = lv_start_time
    ) * 1000.

    " 5. Build response based on posting result
    IF ls_post_result-success = abap_true.
      " Success
      lv_response_json = build_success_response(
        iv_header_uuid = lv_header_uuid
        iv_sap_document = ls_post_result-sap_document
        iv_fiscal_year = ls_post_result-fiscal_year
        iv_company_code = ls_header-company_code
        iv_posting_date = ls_header-posting_date
        iv_processing_ms = lv_duration_ms
      ).

      " Log response
      mo_logger->log_event(
        iv_header_uuid = lv_header_uuid
        iv_event_type = 'API_RESPONSE'
        iv_response_payload = lv_response_json
        iv_duration_ms = lv_duration_ms
      ).

      io_response->set_status( code = 201 reason = 'Created' ).
      io_response->set_cdata( lv_response_json ).
      io_response->set_header_field( name = 'Content-Type' value = 'application/json' ).

    ELSE.
      " Posting error
      lv_response_json = build_error_response(
        iv_header_uuid = lv_header_uuid
        iv_error_code = ls_post_result-error_code
        iv_error_message = ls_post_result-error_message
        iv_technical_details = ls_post_result-technical_details
        iv_retry_allowed = COND #( WHEN ls_post_result-error_code = 'BAPI_ERROR' THEN abap_true ELSE abap_false )
      ).

      " Log error response
      mo_logger->log_event(
        iv_header_uuid = lv_header_uuid
        iv_event_type = 'API_RESPONSE'
        iv_response_payload = lv_response_json
        iv_error_code = ls_post_result-error_code
        iv_error_message = ls_post_result-error_message
        iv_duration_ms = lv_duration_ms
      ).

      io_response->set_status( code = 500 reason = 'Internal Server Error' ).
      io_response->set_cdata( lv_response_json ).
      io_response->set_header_field( name = 'Content-Type' value = 'application/json' ).
    ENDIF.

  ENDMETHOD.

  METHOD parse_json_request.
    " Note: In real implementation, use /UI2/CL_JSON or xco_cp_json
    " This is a simplified version

    ev_success = abap_true.
    CLEAR: es_header, et_items, ev_error_message.

    TRY.
        " Parse JSON using SAP standard classes
        " Simplified - in production use proper JSON parser

        " For demonstration, assuming JSON is properly formatted
        " In real implementation:
        " DATA(lo_reader) = cl_sxml_string_reader=>create( iv_json ).
        " /ui2/cl_json=>deserialize( ... )

        " Extract correlation_id from metadata if present
        ev_correlation_id = |CORR-{ sy-datum }-{ sy-uzeit }|.

      CATCH cx_root INTO DATA(lx_error).
        ev_success = abap_false.
        ev_error_message = |JSON parsing error: { lx_error->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD store_invoice_data.
    DATA: ls_header_db TYPE ZFINN_INV_HRD,
          ls_item_db   TYPE zfinn_inv_item,
          lv_timestamp TYPE timestampl.

    " Generate header UUID
    TRY.
        ev_header_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        GET TIME STAMP FIELD lv_timestamp.
        ev_header_uuid = lv_timestamp.
    ENDTRY.

    GET TIME STAMP FIELD lv_timestamp.

    " Build header record
    ls_header_db-mandt = sy-mandt.
    ls_header_db-header_uuid = ev_header_uuid.
    ls_header_db-company_code = is_header-company_code.
    ls_header_db-vendor_number = is_header-vendor_number.
    ls_header_db-invoice_number = is_header-invoice_number.
    ls_header_db-invoice_date = is_header-invoice_date.
    ls_header_db-document_date = is_header-document_date.
    ls_header_db-posting_date = is_header-posting_date.
    ls_header_db-currency = is_header-currency.
    ls_header_db-gross_amount = is_header-gross_amount.
    ls_header_db-net_amount = is_header-net_amount.
    ls_header_db-tax_amount = is_header-tax_amount.
    ls_header_db-payment_terms = is_header-payment_terms.
    ls_header_db-baseline_date = is_header-baseline_date.
    ls_header_db-payment_method = is_header-payment_method.
    ls_header_db-payment_block = is_header-payment_block.
    ls_header_db-document_type = is_header-document_type.
    ls_header_db-header_text = is_header-header_text.
    ls_header_db-reference = is_header-reference.
    ls_header_db-po_number = is_header-po_number.
    ls_header_db-business_area = is_header-business_area.
    ls_header_db-external_doc_id = is_header-external_doc_id.
    ls_header_db-extraction_confidence = is_header-extraction_confidence.
    ls_header_db-pdf_url = is_header-pdf_url.
    ls_header_db-status = 'N'.  " New
    ls_header_db-processing_type = 'A'.  " Automatic
    ls_header_db-item_count = lines( it_items ).
    ls_header_db-created_by = sy-uname.
    ls_header_db-created_at = lv_timestamp.
    ls_header_db-changed_by = sy-uname.
    ls_header_db-changed_at = lv_timestamp.

    " Calculate fiscal year
    CALL FUNCTION 'FI_PERIOD_DETERMINE'
      EXPORTING
        i_budat = ls_header_db-posting_date
        i_bukrs = ls_header_db-company_code
      IMPORTING
        e_gjahr = ls_header_db-fiscal_year.

    " Insert header
    INSERT ZFINN_INV_HRD FROM ls_header_db.

    " Insert items
    LOOP AT it_items INTO DATA(ls_item).
      DATA(lv_item_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

      ls_item_db-mandt = sy-mandt.
      ls_item_db-header_uuid = ev_header_uuid.
      ls_item_db-item_uuid = lv_item_uuid.
      ls_item_db-item_number = ls_item-item_number.
      ls_item_db-gl_account = ls_item-gl_account.
      ls_item_db-amount = ls_item-amount.
      ls_item_db-cost_center = ls_item-cost_center.
      ls_item_db-profit_center = ls_item-profit_center.
      ls_item_db-order_number = ls_item-internal_order.
      ls_item_db-wbs_element = ls_item-wbs_element.
      ls_item_db-tax_code = ls_item-tax_code.
      ls_item_db-tax_amount = ls_item-tax_amount.
      ls_item_db-item_text = ls_item-item_text.
      ls_item_db-assignment = ls_item-assignment.
      ls_item_db-reference_key = ls_item-reference_key.
      ls_item_db-po_number = ls_item-po_number.
      ls_item_db-po_item = ls_item-po_item.
      ls_item_db-quantity = ls_item-quantity.
      ls_item_db-unit = ls_item-unit.
      ls_item_db-material_number = ls_item-material.
      ls_item_db-plant = ls_item-plant.
      ls_item_db-validation_status = 'V'.  " Valid (will be updated if errors)
      ls_item_db-created_at = lv_timestamp.
      ls_item_db-changed_at = lv_timestamp.

      INSERT zfinn_inv_item FROM ls_item_db.
    ENDLOOP.

    COMMIT WORK.
  ENDMETHOD.

  METHOD build_success_response.
    " Convert UUID to hex string
    DATA(lv_uuid_hex) = CONV string( iv_header_uuid ).
    TRANSLATE lv_uuid_hex TO UPPER CASE.

    " Build JSON response
    rv_json = |\{| &&
              |"status":"SUCCESS",| &&
              |"message":"Invoice posted successfully",| &&
              |"header_uuid":"{ lv_uuid_hex }",| &&
              |"sap_document":"{ iv_sap_document }",| &&
              |"fiscal_year":"{ iv_fiscal_year }",| &&
              |"company_code":"{ iv_company_code }",| &&
              |"posting_date":"{ iv_posting_date+0(4) }-{ iv_posting_date+4(2) }-{ iv_posting_date+6(2) }",| &&
              |"processing_time_ms":{ iv_processing_ms },| &&
              |"correction_url":"{ get_fiori_correction_url( iv_header_uuid ) }"| &&
              |\}|.
  ENDMETHOD.

  METHOD build_validation_error_rspn.
    DATA: lv_uuid_hex TYPE string,
          lv_errors_json TYPE string.

    lv_uuid_hex = CONV string( iv_header_uuid ).
    TRANSLATE lv_uuid_hex TO UPPER CASE.

    " Build errors array
    lv_errors_json = '['.
    LOOP AT it_errors INTO DATA(ls_error).
      IF sy-tabix > 1.
        lv_errors_json = |{ lv_errors_json },|.
      ENDIF.
      lv_errors_json = lv_errors_json && |\{| &&
        |"field":"{ ls_error-field }",| &&
        |"code":"{ ls_error-code }",| &&
        |"message":"{ ls_error-message }",| &&
        |"severity":"{ ls_error-severity }"|.
      IF ls_error-suggestion IS NOT INITIAL.
        lv_errors_json = lv_errors_json && |,"suggestion":"{ ls_error-suggestion }"|.
      ENDIF.
      lv_errors_json = lv_errors_json && |\}|.
    ENDLOOP.
    lv_errors_json = lv_errors_json && ']'.

    rv_json = |\{| &&
              |"status":"VALIDATION_ERROR",| &&
              |"message":"Invoice validation failed",| &&
              |"header_uuid":"{ lv_uuid_hex }",| &&
              |"validation_errors":{ lv_errors_json },| &&
              |"retry_allowed":true,| &&
              |"correction_url":"{ get_fiori_correction_url( iv_header_uuid ) }",| &&
              |"processing_time_ms":{ iv_processing_ms }| &&
              |\}|.
  ENDMETHOD.

  METHOD build_error_response.
    DATA: lv_uuid_hex TYPE string.

    IF iv_header_uuid IS NOT INITIAL.
      lv_uuid_hex = CONV string( iv_header_uuid ).
      TRANSLATE lv_uuid_hex TO UPPER CASE.
    ENDIF.

    rv_json = |\{| &&
              |"status":"ERROR",| &&
              |"message":"{ iv_error_message }",| &&
              |"error_code":"{ iv_error_code }"|.

    IF lv_uuid_hex IS NOT INITIAL.
      rv_json = rv_json && |,"header_uuid":"{ lv_uuid_hex }"|.
    ENDIF.

    IF iv_technical_details IS NOT INITIAL.
      rv_json = rv_json && |,"technical_details":"{ iv_technical_details }"|.
    ENDIF.

    DATA(lv_retry) = COND string( WHEN iv_retry_allowed = abap_true THEN 'true' ELSE 'false' ).
    rv_json = rv_json && |,"retry_allowed":{ lv_retry }| &&
              |,"support_contact":"sap-support@finn.com"| &&
              |\}|.
  ENDMETHOD.

  METHOD get_fiori_correction_url.
    DATA(lv_uuid_hex) = CONV string( iv_header_uuid ).
    TRANSLATE lv_uuid_hex TO UPPER CASE.
    rv_url = |https://fiori.finn.com/invoice-tracking?uuid={ lv_uuid_hex }|.
  ENDMETHOD.

ENDCLASS.
