@EndUserText.label : 'Invoice header draft table'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zfinn_inv_hrd_d {

  key mandt             : mandt not null;
  key header_uuid       : sysuuid_x16 not null;
  invoice_number        : abap.char(16);
  vendor_number         : abap.char(10);
  company_code          : abap.char(4);
  invoice_date          : abap.dats;
  document_date         : abap.dats;
  posting_date          : abap.dats;
  fiscal_year           : abap.numc(4);
  currency              : abap.cuky;
  @Semantics.amount.currencyCode : 'zfinn_inv_hrd_d.currency'
  gross_amount          : abap.curr(15,2);
  @Semantics.amount.currencyCode : 'zfinn_inv_hrd_d.currency'
  net_amount            : abap.curr(15,2);
  @Semantics.amount.currencyCode : 'zfinn_inv_hrd_d.currency'
  tax_amount            : abap.curr(15,2);
  payment_terms         : abap.char(4);
  baseline_date         : abap.dats;
  payment_method        : abap.char(1);
  payment_block         : abap.char(1);
  document_type         : abap.char(2);
  header_text           : abap.char(25);
  reference             : abap.char(16);
  po_number             : abap.char(10);
  status                : abap.char(1);
  processing_type       : abap.char(1);
  sap_document          : abap.char(10);
  sap_fiscal_year       : abap.numc(4);
  error_code            : abap.char(10);
  error_message         : abap.char(220);
  error_field           : abap.char(30);
  retry_count           : abap.int4;
  retry_allowed         : abap.char(1);
  external_doc_id       : abap.char(50);
  extraction_confidence : abap.dec(3,2);
  pdf_url               : abap.char(255);
  created_by            : abap.char(12);
  created_at            : timestampl;
  changed_by            : abap.char(12);
  changed_at            : timestampl;
  posted_at             : timestampl;
  corrected_by          : abap.char(12);
  corrected_at          : timestampl;
  processing_time_ms    : abap.int4;
  business_area         : abap.char(4);
  item_count            : abap.int4;
  "%admin"              : include sych_bdl_draft_admin_inc;

}