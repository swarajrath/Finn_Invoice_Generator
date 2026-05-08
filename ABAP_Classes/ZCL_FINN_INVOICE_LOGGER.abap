CLASS zcl_finn_invoice_logger DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS log_event
      IMPORTING
        iv_header_uuid         TYPE sysuuid_x16
        iv_event_type          TYPE string
        iv_event_subtype       TYPE string OPTIONAL
        iv_old_status          TYPE char1 OPTIONAL
        iv_new_status          TYPE char1 OPTIONAL
        iv_status_reason       TYPE string OPTIONAL
        iv_error_code          TYPE string OPTIONAL
        iv_error_message       TYPE string OPTIONAL
        iv_technical_error     TYPE string OPTIONAL
        iv_error_severity      TYPE char1 DEFAULT 'E'
        iv_request_payload     TYPE string OPTIONAL
        iv_response_payload    TYPE string OPTIONAL
        iv_duration_ms         TYPE int4 OPTIONAL
        iv_validation_duration TYPE int4 OPTIONAL
        iv_posting_duration    TYPE int4 OPTIONAL
        iv_correlation_id      TYPE string OPTIONAL
        iv_session_id          TYPE string OPTIONAL
        iv_ip_address          TYPE string OPTIONAL
        iv_changed_fields      TYPE string OPTIONAL
        iv_comment             TYPE string OPTIONAL
        iv_is_retry            TYPE abap_bool DEFAULT abap_false
        iv_is_manual           TYPE abap_bool DEFAULT abap_false.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_finn_invoice_logger IMPLEMENTATION.

  METHOD log_event.
    DATA: ls_log TYPE zfinn_inv_log,
          lv_log_uuid TYPE sysuuid_x16,
          lv_timestamp TYPE timestampl.

    " Generate log UUID
    TRY.
        lv_log_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        " Fallback - use timestamp-based UUID
        GET TIME STAMP FIELD lv_timestamp.
        lv_log_uuid = lv_timestamp.
    ENDTRY.

    GET TIME STAMP FIELD lv_timestamp.

    " Build log entry
    ls_log-client = sy-mandt.
    ls_log-log_uuid = lv_log_uuid.
    ls_log-header_uuid = iv_header_uuid.
    ls_log-timestamp = lv_timestamp.
    ls_log-event_type = iv_event_type.
    ls_log-event_subtype = iv_event_subtype.
    ls_log-processing_step = sy-cprog.
    ls_log-user_name = sy-uname.
    ls_log-program_name = sy-cprog.

    " Status transition
    ls_log-old_status = iv_old_status.
    ls_log-new_status = iv_new_status.
    ls_log-status_reason = iv_status_reason.

    " Error information
    ls_log-error_code = iv_error_code.
    ls_log-error_message = iv_error_message.
    ls_log-technical_error = iv_technical_error.
    ls_log-error_severity = iv_error_severity.

    " Get retry count from header
    IF iv_is_retry = abap_true.
      SELECT SINGLE retry_count FROM zfinn_inv_hdr
        INTO @ls_log-retry_count
        WHERE header_uuid = @iv_header_uuid.
    ENDIF.

    " Payloads
    ls_log-request_payload = iv_request_payload.
    ls_log-response_payload = iv_response_payload.
    IF iv_request_payload IS NOT INITIAL.
      ls_log-payload_size = strlen( iv_request_payload ).
    ENDIF.

    " Performance metrics
    ls_log-duration_ms = iv_duration_ms.
    ls_log-validation_duration_ms = iv_validation_duration.
    ls_log-posting_duration_ms = iv_posting_duration.

    " Correlation & context
    ls_log-correlation_id = iv_correlation_id.
    ls_log-session_id = iv_session_id.
    ls_log-ip_address = iv_ip_address.

    " Audit information
    ls_log-changed_fields = iv_changed_fields.
    ls_log-comment = iv_comment.

    " Flags
    ls_log-is_retry = COND #( WHEN iv_is_retry = abap_true THEN 'X' ELSE '' ).
    ls_log-is_manual = COND #( WHEN iv_is_manual = abap_true THEN 'X' ELSE '' ).
    ls_log-is_system = COND #( WHEN iv_is_manual = abap_false THEN 'X' ELSE '' ).

    " Insert log entry
    INSERT zfinn_inv_log FROM ls_log.
    COMMIT WORK.

  ENDMETHOD.

ENDCLASS.
