CLASS zcl_finn_invoice_intake_api DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      " Request structure from orchestrator
      BEGIN OF ty_intake_request,
        orchestration_id   TYPE string,       " Unique ID from orchestrator
        correlation_id     TYPE string,       " For tracking across systems
        document_id        TYPE string,       " Document ID in DMS/storage
        document_url       TYPE string,       " URL to PDF document
        source_system      TYPE string,       " Source system identifier
        processing_mode    TYPE string,       " AUTO, MANUAL, HYBRID
        priority           TYPE int4,         " 1=High, 2=Medium, 3=Low
        callback_url       TYPE string,       " Webhook URL for status updates
        metadata           TYPE string,       " JSON metadata
      END OF ty_intake_request,

      " Extracted invoice data from OCR/AI
      BEGIN OF ty_extracted_header,
        invoice_number     TYPE xblnr,
        vendor_number      TYPE lifnr,
        vendor_name        TYPE string,
        company_code       TYPE bukrs,
        invoice_date       TYPE bldat,
        document_date      TYPE bldat,
        posting_date       TYPE budat,
        currency           TYPE waers,
        gross_amount       TYPE wrbtr,
        net_amount         TYPE wrbtr,
        tax_amount         TYPE wrbtr,
        payment_terms      TYPE dzterm,
        po_number          TYPE ebeln,
        reference          TYPE xblnr1,
        confidence_score   TYPE p LENGTH 5 DECIMALS 2,
      END OF ty_extracted_header,

      BEGIN OF ty_extracted_item,
        item_number        TYPE posnr,
        description        TYPE sgtxt,
        gl_account         TYPE hkont,
        cost_center        TYPE kostl,
        amount             TYPE wrbtr,
        tax_code           TYPE mwskz,
        quantity           TYPE menge_d,
        unit               TYPE meins,
        po_number          TYPE ebeln,
        po_item            TYPE ebelp,
        confidence_score   TYPE p LENGTH 5 DECIMALS 2,
      END OF ty_extracted_item,

      tt_extracted_items TYPE STANDARD TABLE OF ty_extracted_item WITH DEFAULT KEY,

      BEGIN OF ty_extraction_payload,
        header             TYPE ty_extracted_header,
        items              TYPE tt_extracted_items,
      END OF ty_extraction_payload,

      " Response structure
      BEGIN OF ty_intake_response,
        success            TYPE abap_bool,
        invoice_uuid       TYPE sysuuid_x16,
        status             TYPE string,       " ACCEPTED, VALIDATION_PENDING, ERROR
        validation_issues  TYPE string,       " JSON array of validation errors
        validation_warnings TYPE string,      " JSON array of validation warnings
        processing_time_ms TYPE int4,
        error_code         TYPE string,
        error_message      TYPE string,
      END OF ty_intake_response.

    " Main API method - called by orchestrator
    METHODS process_invoice_intake
      IMPORTING
        is_request           TYPE ty_intake_request
        is_extracted_data    TYPE ty_extraction_payload
      RETURNING
        VALUE(rs_response)   TYPE ty_intake_response.

    " Webhook callback for status updates
    METHODS send_status_callback
      IMPORTING
        iv_callback_url      TYPE string
        iv_orchestration_id  TYPE string
        iv_invoice_uuid      TYPE sysuuid_x16
        iv_status            TYPE string
        iv_message           TYPE string.

  PRIVATE SECTION.

    DATA: mo_validator TYPE REF TO zcl_finn_invoice_validator,
          mo_logger    TYPE REF TO zcl_finn_invoice_logger.

    METHODS create_invoice_record
      IMPORTING
        is_request        TYPE ty_intake_request
        is_extracted_data TYPE ty_extraction_payload
      EXPORTING
        ev_invoice_uuid   TYPE sysuuid_x16
        ev_success        TYPE abap_bool
        ev_error_message  TYPE string.

    METHODS validate_extracted_data
      IMPORTING
        is_extracted_data TYPE ty_extraction_payload
      EXPORTING
        et_errors         TYPE zcl_finn_invoice_validator=>tt_validation_errors
        et_warnings       TYPE zcl_finn_invoice_validator=>tt_validation_errors
        ev_is_valid       TYPE abap_bool.

    METHODS map_to_internal_structure
      IMPORTING
        is_request        TYPE ty_intake_request
        is_extracted_data TYPE ty_extraction_payload
      EXPORTING
        es_header         TYPE zfinn_inv_hrd
        et_items          TYPE STANDARD TABLE.

ENDCLASS.



CLASS zcl_finn_invoice_intake_api IMPLEMENTATION.

  METHOD process_invoice_intake.
    DATA: lv_invoice_uuid  TYPE sysuuid_x16,
          lv_start_time    TYPE timestampl,
          lv_end_time      TYPE timestampl,
          lv_success       TYPE abap_bool,
          lv_error_msg     TYPE string,
          lt_val_errors    TYPE zcl_finn_invoice_validator=>tt_validation_errors,
          lt_val_warnings  TYPE zcl_finn_invoice_validator=>tt_validation_errors,
          lv_is_valid      TYPE abap_bool.

    " Start timer
    GET TIME STAMP FIELD lv_start_time.

    " Initialize
    mo_validator = NEW zcl_finn_invoice_validator( ).
    mo_logger = NEW zcl_finn_invoice_logger( ).

    " Log intake request
    DATA(lv_log_message) = |Intake API called - Orchestration ID: { is_request-orchestration_id }|.

    TRY.
        " Step 1: Validate extracted data
        validate_extracted_data(
          EXPORTING is_extracted_data = is_extracted_data
          IMPORTING et_errors = lt_val_errors
                    et_warnings = lt_val_warnings
                    ev_is_valid = lv_is_valid
        ).

        " Calculate processing time
        GET TIME STAMP FIELD lv_end_time.
        DATA(lv_duration) = cl_abap_tstmp=>subtract(
          tstmp1 = lv_end_time
          tstmp2 = lv_start_time
        ) * 1000.

        " Check if validation failed - REJECT invoice if errors exist
        IF lv_is_valid = abap_false.
          " Validation failed - do NOT create invoice
          rs_response-success = abap_false.
          rs_response-status = 'REJECTED'.
          rs_response-error_code = 'VALIDATION_FAILED'.
          rs_response-processing_time_ms = lv_duration.

          " Build error message from validation errors
          IF lt_val_errors IS NOT INITIAL.
            DATA(lv_first_error) = lt_val_errors[ 1 ].
            rs_response-error_message = lv_first_error-message.

            " Convert all validation errors to JSON
            DATA(lv_errors_json) = '['.
            LOOP AT lt_val_errors INTO DATA(ls_error).
              IF sy-tabix > 1.
                lv_errors_json = lv_errors_json && ','.
              ENDIF.
              lv_errors_json = lv_errors_json &&
                |{ '{"field":"' }{ ls_error-field }{ '",' }| &&
                |{ '"code":"' }{ ls_error-code }{ '",' }| &&
                |{ '"message":"' }{ ls_error-message }{ '",' }| &&
                |{ '"severity":"' }{ ls_error-severity }{ '"}' }|.
            ENDLOOP.
            lv_errors_json = lv_errors_json && ']'.
            rs_response-validation_issues = lv_errors_json.
          ELSE.
            rs_response-error_message = 'Validation failed with unknown errors'.
          ENDIF.

          " Send error callback
          IF is_request-callback_url IS NOT INITIAL.
            send_status_callback(
              iv_callback_url = is_request-callback_url
              iv_orchestration_id = is_request-orchestration_id
              iv_invoice_uuid = lv_invoice_uuid
              iv_status = 'REJECTED'
              iv_message = rs_response-error_message
            ).
          ENDIF.

          RETURN.  " Exit - do not create invoice
        ENDIF.

        " Step 2: Validation passed - Create invoice record in database
        create_invoice_record(
          EXPORTING is_request = is_request
                    is_extracted_data = is_extracted_data
          IMPORTING ev_invoice_uuid = lv_invoice_uuid
                    ev_success = lv_success
                    ev_error_message = lv_error_msg
        ).

        " Build response
        IF lv_success = abap_true.
          " Invoice created successfully
          rs_response-success = abap_true.
          rs_response-invoice_uuid = lv_invoice_uuid.
          rs_response-status = 'ACCEPTED'.
          rs_response-processing_time_ms = lv_duration.

          " Convert warnings to JSON (if any exist)
          IF lt_val_warnings IS NOT INITIAL.
            DATA: lv_warnings_json TYPE string VALUE '[',
                  ls_warning TYPE zcl_finn_invoice_validator=>ty_validation_error.

            LOOP AT lt_val_warnings INTO ls_warning.
              IF sy-tabix > 1.
                CONCATENATE lv_warnings_json ',' INTO lv_warnings_json.
              ENDIF.

              CONCATENATE lv_warnings_json
                          '{"field":"' ls_warning-field '",'
                          '"code":"' ls_warning-code '",'
                          '"message":"' ls_warning-message '",'
                          '"severity":"' ls_warning-severity '"}'
                          INTO lv_warnings_json.
            ENDLOOP.

            CONCATENATE lv_warnings_json ']' INTO lv_warnings_json.
            rs_response-validation_warnings = lv_warnings_json.
          ENDIF.

          " Send success callback
          IF is_request-callback_url IS NOT INITIAL.
            send_status_callback(
              iv_callback_url = is_request-callback_url
              iv_orchestration_id = is_request-orchestration_id
              iv_invoice_uuid = lv_invoice_uuid
              iv_status = 'ACCEPTED'
              iv_message = 'Invoice successfully received and validated'
            ).
          ENDIF.

        ELSE.
          " Error creating invoice
          rs_response-success = abap_false.
          rs_response-status = 'ERROR'.
          rs_response-error_code = 'INVOICE_CREATE_ERROR'.
          rs_response-error_message = lv_error_msg.
          rs_response-processing_time_ms = lv_duration.

          " Send error callback
          IF is_request-callback_url IS NOT INITIAL.
            send_status_callback(
              iv_callback_url = is_request-callback_url
              iv_orchestration_id = is_request-orchestration_id
              iv_invoice_uuid = lv_invoice_uuid
              iv_status = 'ERROR'
              iv_message = lv_error_msg
            ).
          ENDIF.
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        " Exception handling
        GET TIME STAMP FIELD lv_end_time.
        lv_duration = cl_abap_tstmp=>subtract(
          tstmp1 = lv_end_time
          tstmp2 = lv_start_time
        ) * 1000.

        rs_response-success = abap_false.
        rs_response-status = 'ERROR'.
        rs_response-error_code = 'EXCEPTION'.
        rs_response-error_message = lx_error->get_text( ).
        rs_response-processing_time_ms = lv_duration.

        " Send error callback
        IF is_request-callback_url IS NOT INITIAL.
          send_status_callback(
            iv_callback_url = is_request-callback_url
            iv_orchestration_id = is_request-orchestration_id
            iv_invoice_uuid = lv_invoice_uuid
            iv_status = 'ERROR'
            iv_message = lx_error->get_text( )
          ).
        ENDIF.
    ENDTRY.

  ENDMETHOD.

  METHOD create_invoice_record.
    DATA: ls_header TYPE zfinn_inv_hrd,
          lt_items  TYPE STANDARD TABLE OF zfinn_inv_item.

    TRY.
        " Generate UUID
        ev_invoice_uuid = cl_system_uuid=>create_uuid_x16_static( ).

        " Map extracted data to internal structure
        map_to_internal_structure(
          EXPORTING is_request = is_request
                    is_extracted_data = is_extracted_data
          IMPORTING es_header = ls_header
                    et_items = lt_items
        ).

        " Set UUID and metadata
        ls_header-header_uuid = ev_invoice_uuid.
        ls_header-external_doc_id = is_request-document_id.
        ls_header-pdf_url = is_request-document_url.
        ls_header-extraction_confidence = is_extracted_data-header-confidence_score.
        ls_header-status = 'N'.  " New
        ls_header-processing_type = COND #(
          WHEN is_request-processing_mode = 'AUTO' THEN 'A'
          WHEN is_request-processing_mode = 'MANUAL' THEN 'M'
          ELSE 'H'  " Hybrid
        ).

        GET TIME STAMP FIELD DATA(lv_timestamp).
        ls_header-created_by = sy-uname.
        ls_header-created_at = lv_timestamp.
        ls_header-changed_by = sy-uname.
        ls_header-changed_at = lv_timestamp.

        " Debug: Check if MANDT and UUID are set
        IF ls_header-mandt IS INITIAL.
          ev_success = abap_false.
          ev_error_message = |MANDT not set in header structure! MANDT={ ls_header-mandt }, UUID={ ls_header-header_uuid }|.
          RETURN.
        ENDIF.

        IF ls_header-header_uuid IS INITIAL.
          ev_success = abap_false.
          ev_error_message = |Header UUID not set in structure! MANDT={ ls_header-mandt }, UUID={ ls_header-header_uuid }|.
          RETURN.
        ENDIF.

        " Insert header
        INSERT zfinn_inv_hrd FROM ls_header.
        IF sy-subrc <> 0.
          ev_success = abap_false.
          ev_error_message = 'Failed to insert invoice header'.
          RETURN.
        ENDIF.

        " Insert items
        LOOP AT lt_items INTO DATA(ls_item).
          " Generate unique item UUID
          TRY.
              ls_item-item_uuid = cl_system_uuid=>create_uuid_x16_static( ).
            CATCH cx_uuid_error.
              " Continue with empty UUID - will fail but caught below
          ENDTRY.

          ls_item-header_uuid = ev_invoice_uuid.
          ls_item-created_at = lv_timestamp.
          ls_item-changed_at = lv_timestamp.
          MODIFY lt_items FROM ls_item.
        ENDLOOP.

        INSERT zfinn_inv_item FROM TABLE lt_items.
        IF sy-subrc <> 0.
          ev_success = abap_false.
          ev_error_message = 'Failed to insert invoice items'.
          RETURN.
        ENDIF.

        COMMIT WORK.

        " Log event
        mo_logger->log_event(
          iv_header_uuid = ev_invoice_uuid
          iv_event_type = 'INTAKE_API'
          iv_event_subtype = 'DOCUMENT_RECEIVED'
          iv_old_status = ''
          iv_new_status = 'N'
          iv_correlation_id = is_request-correlation_id
          iv_comment = |Orchestration ID: { is_request-orchestration_id }|
        ).

        ev_success = abap_true.

      CATCH cx_uuid_error INTO DATA(lx_uuid).
        ev_success = abap_false.
        ev_error_message = |UUID Generation Error: { lx_uuid->get_text( ) }|.

      CATCH cx_sy_open_sql_db INTO DATA(lx_db).
        ev_success = abap_false.
        ev_error_message = |Database Error: { lx_db->get_text( ) }|.
        ROLLBACK WORK.

      CATCH cx_root INTO DATA(lx_error).
        ev_success = abap_false.
        ev_error_message = |Unexpected Error: { lx_error->get_text( ) }|.
        ROLLBACK WORK.
    ENDTRY.

  ENDMETHOD.

  METHOD validate_extracted_data.
    " Use existing validator
    DATA: ls_header_val TYPE zcl_finn_invoice_validator=>ty_invoice_header,
          lt_items_val  TYPE zcl_finn_invoice_validator=>tt_invoice_items.

    " Map to validator structure
    ls_header_val = CORRESPONDING #( is_extracted_data-header ).

    " Manually map confidence_score to extraction_confidence (field name mismatch)
    ls_header_val-extraction_confidence = is_extracted_data-header-confidence_score.

    lt_items_val = CORRESPONDING #( is_extracted_data-items ).

    " Validate - capture both errors and warnings
    ev_is_valid = mo_validator->validate_invoice(
      EXPORTING is_header = ls_header_val
                it_items = lt_items_val
      IMPORTING et_errors = et_errors
                et_warnings = et_warnings
    ).

  ENDMETHOD.

  METHOD map_to_internal_structure.
    DATA: ls_item TYPE zfinn_inv_item.

    " Map header
    es_header = CORRESPONDING #( is_extracted_data-header ).

    " Set client (mandatory key field)
    es_header-mandt = sy-mandt.

    " Map items manually to ensure all fields are set
    LOOP AT is_extracted_data-items INTO DATA(ls_extracted_item).
      CLEAR ls_item.

      ls_item-mandt = sy-mandt.
      ls_item-item_number = ls_extracted_item-item_number.
      ls_item-item_text = ls_extracted_item-description.
      ls_item-gl_account = ls_extracted_item-gl_account.
      ls_item-cost_center = ls_extracted_item-cost_center.
      ls_item-amount = ls_extracted_item-amount.
      ls_item-tax_code = ls_extracted_item-tax_code.
      ls_item-quantity = ls_extracted_item-quantity.
      ls_item-unit = ls_extracted_item-unit.
      ls_item-po_number = ls_extracted_item-po_number.
      ls_item-po_item = ls_extracted_item-po_item.

      APPEND ls_item TO et_items.
    ENDLOOP.

    " Set item count
    es_header-item_count = lines( et_items ).

  ENDMETHOD.

  METHOD send_status_callback.
    " Build JSON payload with timestamp
    DATA: lv_timestamp TYPE string,
          lv_payload TYPE string.

    GET TIME STAMP FIELD DATA(lv_ts).
    lv_timestamp = |{ lv_ts TIMESTAMP = ISO }|.

    lv_payload = |\{|
  & |"orchestration_id": "{ iv_orchestration_id }", |
  & |"invoice_uuid": "{ iv_invoice_uuid }", |
  & |"status": "{ iv_status }", |
  & |"message": "{ iv_message }", |
  & |"timestamp": "{ lv_timestamp }"|
  & |\}|.

    " Send HTTP POST to callback URL
    DATA: lo_http_client TYPE REF TO if_http_client,
          lv_status_code TYPE i,
          lv_status_text TYPE string,
          lv_response_body TYPE string,
          lv_log_message TYPE string.

    TRY.
        " Create HTTP client
        cl_http_client=>create_by_url(
          EXPORTING
            url                = iv_callback_url
          IMPORTING
            client             = lo_http_client
          EXCEPTIONS
            argument_not_found = 1
            plugin_not_active  = 2
            internal_error     = 3
            OTHERS             = 4
        ).

        IF sy-subrc <> 0.
          " Could not create HTTP client - exit
          RETURN.
        ENDIF.

        " Set request properties
        lo_http_client->request->set_method( 'POST' ).
        lo_http_client->request->set_content_type( 'application/json' ).
        lo_http_client->request->set_cdata( lv_payload ).

        " Send request with timeout handling
        lo_http_client->send(
          EXCEPTIONS
            http_communication_failure = 1
            http_invalid_state         = 2
            http_processing_failed     = 3
            OTHERS                     = 4
        ).

        IF sy-subrc <> 0.
          " Send failed - log will happen in CATCH block
          lv_log_message = |Webhook send failed: HTTP send error (sy-subrc={ sy-subrc })|.
          mo_logger->log_event(
            iv_header_uuid = iv_invoice_uuid
            iv_event_type = 'CALLBACK_FAILED'
            iv_event_subtype = 'SEND_ERROR'
            iv_error_message = lv_log_message
          ).
          lo_http_client->close( ).
          RETURN.
        ENDIF.

        " Receive response
        lo_http_client->receive(
          EXCEPTIONS
            http_communication_failure = 1
            http_invalid_state         = 2
            http_processing_failed     = 3
            OTHERS                     = 4
        ).

        IF sy-subrc <> 0.
          " Receive failed
          lv_log_message = |Webhook receive failed: HTTP receive error (sy-subrc={ sy-subrc })|.
          mo_logger->log_event(
            iv_header_uuid = iv_invoice_uuid
            iv_event_type = 'CALLBACK_FAILED'
            iv_event_subtype = 'RECEIVE_ERROR'
            iv_error_message = lv_log_message
          ).
          lo_http_client->close( ).
          RETURN.
        ENDIF.

        " Get response status
        lo_http_client->response->get_status(
          IMPORTING
            code = lv_status_code
            reason = lv_status_text
        ).

        " Get response body
        lv_response_body = lo_http_client->response->get_cdata( ).

        " Close connection
        lo_http_client->close( ).

        " Log success or failure based on HTTP status
        IF lv_status_code >= 200 AND lv_status_code < 300.
          " Success (2xx status codes)
          lv_log_message = |Webhook sent successfully to { iv_callback_url }. | &&
                          |HTTP { lv_status_code } { lv_status_text }. | &&
                          |Status: { iv_status }. | &&
                          |Response: { lv_response_body }|.

          mo_logger->log_event(
            iv_header_uuid = iv_invoice_uuid
            iv_event_type = 'CALLBACK_SUCCESS'
            iv_event_subtype = iv_status
            iv_comment = lv_log_message
          ).

        ELSE.
          " Non-success status codes (4xx, 5xx)
          lv_log_message = |Webhook failed with HTTP { lv_status_code } { lv_status_text }. | &&
                          |URL: { iv_callback_url }. | &&
                          |Response: { lv_response_body }|.

          mo_logger->log_event(
            iv_header_uuid = iv_invoice_uuid
            iv_event_type = 'CALLBACK_FAILED'
            iv_event_subtype = 'HTTP_ERROR'
            iv_error_message = lv_log_message
          ).
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        " Exception during webhook call
        lv_log_message = |Webhook exception: { lx_error->get_text( ) }. | &&
                        |URL: { iv_callback_url }. | &&
                        |Status attempted: { iv_status }|.

        mo_logger->log_event(
          iv_header_uuid = iv_invoice_uuid
          iv_event_type = 'CALLBACK_FAILED'
          iv_event_subtype = 'EXCEPTION'
          iv_error_message = lv_log_message
        ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
