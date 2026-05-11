CLASS zbp_c_invoicetracking DEFINITION
  PUBLIC
  ABSTRACT
  FINAL FOR BEHAVIOR OF z_c_invoicetracking.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF c_status,
        new       TYPE c LENGTH 1 VALUE 'N',
        pending   TYPE c LENGTH 1 VALUE 'P',
        posted    TYPE c LENGTH 1 VALUE 'S',
        error     TYPE c LENGTH 1 VALUE 'E',
        cancelled TYPE c LENGTH 1 VALUE 'C',
      END OF c_status.

ENDCLASS.

CLASS zbp_c_invoicetracking IMPLEMENTATION.

ENDCLASS.

*"* Local Classes
CLASS lhc_invoiceheader DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR invoiceheader RESULT result.

    METHODS validateheader FOR VALIDATE ON SAVE
      IMPORTING keys FOR invoiceheader~validateheader.

    METHODS checkduplicate FOR VALIDATE ON SAVE
      IMPORTING keys FOR invoiceheader~checkduplicate.

    METHODS repost FOR MODIFY
      IMPORTING keys FOR ACTION invoiceheader~repost RESULT result.

    METHODS correct FOR MODIFY
      IMPORTING keys FOR ACTION invoiceheader~correct RESULT result.

    METHODS cancel FOR MODIFY
      IMPORTING keys FOR ACTION invoiceheader~cancel RESULT result.

ENDCLASS.

CLASS lhc_invoiceheader IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Global authorization - allow all operations by default
    " Add authorization checks here if needed (e.g., check authorization objects)

    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.

  ENDMETHOD.

  METHOD validateheader.
    " Validate header fields on save

    READ ENTITIES OF z_c_invoicetracking IN LOCAL MODE
      ENTITY invoiceheader
        FIELDS ( HeaderUuid VendorNumber CompanyCode InvoiceNumber PostingDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices).

    LOOP AT invoices INTO DATA(invoice).
      " Check mandatory fields
      IF invoice-VendorNumber IS INITIAL.
        APPEND VALUE #( %tky = invoice-%tky ) TO failed-invoiceheader.
        APPEND VALUE #(
          %tky = invoice-%tky
          %state_area = 'VALIDATE_VENDOR'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Vendor number is mandatory'
          )
          %element-VendorNumber = if_abap_behv=>mk-on
        ) TO reported-invoiceheader.
      ENDIF.

      IF invoice-CompanyCode IS INITIAL.
        APPEND VALUE #( %tky = invoice-%tky ) TO failed-invoiceheader.
        APPEND VALUE #(
          %tky = invoice-%tky
          %state_area = 'VALIDATE_COMPANY'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Company code is mandatory'
          )
          %element-CompanyCode = if_abap_behv=>mk-on
        ) TO reported-invoiceheader.
      ENDIF.

      IF invoice-InvoiceNumber IS INITIAL.
        APPEND VALUE #( %tky = invoice-%tky ) TO failed-invoiceheader.
        APPEND VALUE #(
          %tky = invoice-%tky
          %state_area = 'VALIDATE_INVOICE'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Invoice number is mandatory'
          )
          %element-InvoiceNumber = if_abap_behv=>mk-on
        ) TO reported-invoiceheader.
      ENDIF.

      " Check if vendor exists
      IF invoice-VendorNumber IS NOT INITIAL AND invoice-CompanyCode IS NOT INITIAL.
        DATA(lv_vendor) = invoice-VendorNumber.
        " Alpha conversion
        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
          EXPORTING
            input  = lv_vendor
          IMPORTING
            output = lv_vendor.

        SELECT SINGLE lifnr FROM lfb1
          WHERE lifnr = @lv_vendor
            AND bukrs = @invoice-CompanyCode
          INTO @DATA(lv_vendor_check).

        IF sy-subrc <> 0.
          APPEND VALUE #( %tky = invoice-%tky ) TO failed-invoiceheader.
          APPEND VALUE #(
            %tky = invoice-%tky
            %state_area = 'VALIDATE_VENDOR'
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text = |Vendor { invoice-VendorNumber } does not exist in company code { invoice-CompanyCode }|
            )
            %element-VendorNumber = if_abap_behv=>mk-on
          ) TO reported-invoiceheader.
        ENDIF.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD checkduplicate.
    " Check for duplicate invoices

    READ ENTITIES OF z_c_invoicetracking IN LOCAL MODE
      ENTITY invoiceheader
        FIELDS ( HeaderUuid VendorNumber InvoiceNumber CompanyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(invoices).

    LOOP AT invoices INTO DATA(invoice).
      IF invoice-VendorNumber IS NOT INITIAL
       AND invoice-InvoiceNumber IS NOT INITIAL
       AND invoice-CompanyCode IS NOT INITIAL.

        " Check in custom table
        SELECT SINGLE header_uuid FROM zfinn_inv_hrd
          WHERE vendor_number = @invoice-VendorNumber
            AND invoice_number = @invoice-InvoiceNumber
            AND company_code = @invoice-CompanyCode
            AND header_uuid <> @invoice-HeaderUuid
          INTO @DATA(lv_existing_uuid).

        IF sy-subrc = 0.
          APPEND VALUE #( %tky = invoice-%tky ) TO failed-invoiceheader.
          APPEND VALUE #(
            %tky = invoice-%tky
            %state_area = 'VALIDATE_DUPLICATE'
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text = |Duplicate invoice: { invoice-InvoiceNumber } already exists for vendor { invoice-VendorNumber }|
            )
            %element-InvoiceNumber = if_abap_behv=>mk-on
          ) TO reported-invoiceheader.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD repost.
    " Repost failed invoice
    READ ENTITIES OF z_c_invoicetracking IN LOCAL MODE
      ENTITY invoiceheader
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(invoices).

    LOOP AT invoices INTO DATA(invoice).
      " TODO: Call posting engine
      " For now, just update status to PENDING
      MODIFY ENTITIES OF z_c_invoicetracking IN LOCAL MODE
        ENTITY invoiceheader
          UPDATE FIELDS ( Status RetryCount )
          WITH VALUE #( (
            %tky = invoice-%tky
            Status = zbp_c_invoicetracking=>c_status-pending
            RetryCount = invoice-RetryCount + 1
          ) )
        FAILED failed
        REPORTED reported.

      " Add to result if successful
      APPEND VALUE #(
        %tky = invoice-%tky
        %param = invoice
      ) TO result.

      " Add success message
      APPEND VALUE #(
        %tky = invoice-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-success
          text = 'Invoice reposted successfully'
        )
      ) TO reported-invoiceheader.

    ENDLOOP.

  ENDMETHOD.

  METHOD correct.
    " Mark invoice for manual correction
    READ ENTITIES OF z_c_invoicetracking IN LOCAL MODE
      ENTITY invoiceheader
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(invoices).

    result = VALUE #( FOR invoice IN invoices (
      %tky = invoice-%tky
      %param = invoice
    ) ).

    " Switch to edit mode automatically
    reported-invoiceheader = VALUE #( FOR invoice IN invoices (
      %tky = invoice-%tky
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-information
        text = 'Invoice ready for correction. Please edit the fields and save.'
      )
    ) ).

  ENDMETHOD.

  METHOD cancel.
    " Cancel invoice
    MODIFY ENTITIES OF z_c_invoicetracking IN LOCAL MODE
      ENTITY invoiceheader
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys (
          %tky = key-%tky
          Status = zbp_c_invoicetracking=>c_status-cancelled
        ) )
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF z_c_invoicetracking IN LOCAL MODE
      ENTITY invoiceheader
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(invoices).

    result = VALUE #( FOR invoice IN invoices (
      %tky = invoice-%tky
      %param = invoice
    ) ).

  ENDMETHOD.

ENDCLASS.

*"* Item local class
CLASS lhc_invoiceitem DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS validateitem FOR VALIDATE ON SAVE
      IMPORTING keys FOR invoiceitem~validateitem.

ENDCLASS.

CLASS lhc_invoiceitem IMPLEMENTATION.

  METHOD validateitem.
    " Validate item fields

    READ ENTITIES OF z_c_invoicetracking IN LOCAL MODE
      ENTITY invoiceitem
        FIELDS ( ItemUuid GlAccount Amount ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT items INTO DATA(item).
      " Check mandatory fields
      IF item-GlAccount IS INITIAL.
        APPEND VALUE #( %tky = item-%tky ) TO failed-invoiceitem.
        APPEND VALUE #(
          %tky = item-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'G/L Account is mandatory'
          )
          %element-GlAccount = if_abap_behv=>mk-on
        ) TO reported-invoiceitem.
      ENDIF.

      IF item-Amount IS INITIAL OR item-Amount <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-invoiceitem.
        APPEND VALUE #(
          %tky = item-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Amount must be greater than zero'
          )
          %element-Amount = if_abap_behv=>mk-on
        ) TO reported-invoiceitem.
      ENDIF.

      " Validate GL account exists
      IF item-GlAccount IS NOT INITIAL.
        DATA(lv_gl) = item-GlAccount.
        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
          EXPORTING
            input  = lv_gl
          IMPORTING
            output = lv_gl.

        SELECT SINGLE saknr FROM ska1
          WHERE saknr = @lv_gl
          INTO @DATA(lv_gl_check).

        IF sy-subrc <> 0.
          APPEND VALUE #( %tky = item-%tky ) TO failed-invoiceitem.
          APPEND VALUE #(
            %tky = item-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text = |G/L Account { item-GlAccount } does not exist|
            )
            %element-GlAccount = if_abap_behv=>mk-on
          ) TO reported-invoiceitem.
        ENDIF.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.