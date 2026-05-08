@EndUserText.label : 'Draft table for Invoice Items'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zfinn_inv_item_d {

  key mandt         : mandt not null;
  key header_uuid   : sysuuid_x16 not null;
  key item_uuid     : sysuuid_x16 not null;
  item_number       : posnr;
  gl_account        : abap.char(10);
  cost_center       : abap.char(10);
  profit_center     : abap.char(10);
  order_number      : abap.char(12);
  wbs_element       : abap.char(24);
  @Semantics.amount.currencyCode : 'zfinn_inv_item_d.currency'
  amount            : abap.curr(15,2);
  currency          : abap.cuky;
  tax_code          : abap.char(2);
  @Semantics.amount.currencyCode : 'zfinn_inv_item_d.currency'
  tax_amount        : abap.curr(15,2);
  @Semantics.quantity.unitOfMeasure : 'zfinn_inv_item_d.unit'
  quantity          : abap.quan(13,3);
  unit              : abap.unit(3);
  item_text         : abap.char(50);
  assignment        : abap.char(18);
  reference_key     : abap.char(12);
  po_number         : abap.char(10);
  po_item           : abap.char(5);
  po_history        : abap.char(1);
  material_number   : abap.char(18);
  plant             : abap.char(4);
  validation_status : abap.char(1);
  error_code        : abap.char(10);
  error_message     : abap.char(220);
  created_at        : timestampl;
  changed_at        : timestampl;
  "%admin"          : include sych_bdl_draft_admin_inc;

}