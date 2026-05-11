CLASS zcl_finn_invoice_intake_http DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

  PRIVATE SECTION.
    METHODS parse_intake_request
      IMPORTING
        iv_json              TYPE string
      RETURNING
        VALUE(rs_request)    TYPE zcl_finn_invoice_intake_api=>ty_intake_request.

    METHODS parse_extraction_payload
      IMPORTING
        iv_json              TYPE string
      RETURNING
        VALUE(rs_payload)    TYPE zcl_finn_invoice_intake_api=>ty_extraction_payload.

    METHODS build_json_response
      IMPORTING
        is_response          TYPE zcl_finn_invoice_intake_api=>ty_intake_response
      RETURNING
        VALUE(rv_json)       TYPE string.

    METHODS escape_json
      IMPORTING
        iv_text              TYPE string
      RETURNING
        VALUE(rv_escaped)    TYPE string.

ENDCLASS.



CLASS zcl_finn_invoice_intake_http IMPLEMENTATION.

  METHOD if_http_extension~handle_request.

    DATA: lv_request_body  TYPE string,
          lv_response_body TYPE string,
          lv_http_method   TYPE string.

    " Get HTTP method
    lv_http_method = server->request->get_method( ).

    " Only accept POST requests
    IF lv_http_method <> 'POST'.
      server->response->set_status( code = 405 reason = 'Method Not Allowed' ).
      server->response->set_cdata( '{"error":"Method not allowed. Use POST."}' ).
      RETURN.
    ENDIF.

    TRY.
        " Read request body
        lv_request_body = server->request->get_cdata( ).

        " Parse JSON request
        DATA(ls_intake_request) = parse_intake_request( lv_request_body ).
        DATA(ls_extracted_data) = parse_extraction_payload( lv_request_body ).

        " Process invoice intake
        DATA(lo_intake_api) = NEW zcl_finn_invoice_intake_api( ).
        DATA(ls_response) = lo_intake_api->process_invoice_intake(
          is_request = ls_intake_request
          is_extracted_data = ls_extracted_data
        ).

        " Build JSON response
        lv_response_body = build_json_response( ls_response ).

        " Set response
        IF ls_response-success = abap_true.
          server->response->set_status( code = 200 reason = 'OK' ).
        ELSE.
          server->response->set_status( code = 400 reason = 'Bad Request' ).
        ENDIF.

        server->response->set_header_field( name = 'Content-Type' value = 'application/json' ).
        server->response->set_cdata( lv_response_body ).

      CATCH cx_root INTO DATA(lx_error).
        " Error handling
        server->response->set_status( code = 500 reason = 'Internal Server Error' ).
        lv_response_body = |{ '{"success":false,' }|
                        && |{ '"status":"ERROR",' }|
                        && |{ '"error_code":"INTERNAL_ERROR",' }|
                        && |{ '"error_message":"' }{ escape_json( lx_error->get_text( ) ) }{ '"}' }|.
        server->response->set_cdata( lv_response_body ).
    ENDTRY.

  ENDMETHOD.

  METHOD parse_intake_request.
    " Parse JSON - simplified example, use /ui2/cl_json for production
    DATA: ls_request TYPE zcl_finn_invoice_intake_api=>ty_intake_request.

    /ui2/cl_json=>deserialize(
      EXPORTING json = iv_json
      CHANGING data = ls_request
    ).

    rs_request = ls_request.

  ENDMETHOD.

  METHOD parse_extraction_payload.
    " Parse extraction data from JSON
    DATA: ls_payload TYPE zcl_finn_invoice_intake_api=>ty_extraction_payload.

    /ui2/cl_json=>deserialize(
      EXPORTING json = iv_json
      CHANGING data = ls_payload
    ).

    rs_payload = ls_payload.

  ENDMETHOD.

  METHOD build_json_response.
    DATA: lv_json TYPE string.

    /ui2/cl_json=>serialize(
      EXPORTING data = is_response
                pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      RECEIVING r_json = lv_json
    ).

    rv_json = lv_json.

  ENDMETHOD.

  METHOD escape_json.
    " Escape special characters for JSON
    rv_escaped = iv_text.
    REPLACE ALL OCCURRENCES OF '\' IN rv_escaped WITH '\\'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_escaped WITH '\"'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN rv_escaped WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN rv_escaped WITH '\t'.
  ENDMETHOD.

ENDCLASS.
