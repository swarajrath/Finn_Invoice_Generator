@EndUserText.label : 'Draft table for Invoice Items'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zfinn_inv_item_d {

  key mandt            : mandt not null;
  key headeruuid       : sysuuid_x16 not null;
  key itemuuid         : sysuuid_x16 not null;
  itemnumber           : posnr;
  glaccount            : abap.char(10);
  costcenter           : abap.char(10);
  profitcenter         : abap.char(10);
  internalorder        : abap.char(12);
  wbselement           : abap.char(24);
  currency             : abap.cuky;
  @Semantics.amount.currencyCode : 'zfinn_inv_item_d.currency'
  amount               : abap.curr(15,2);
  taxcode              : abap.char(2);
  @Semantics.amount.currencyCode : 'zfinn_inv_item_d.currency'
  taxamount            : abap.curr(15,2);
  @Semantics.quantity.unitOfMeasure : 'zfinn_inv_item_d.unit'
  quantity             : abap.quan(13,3);
  unit                 : abap.unit(3);
  itemtext             : abap.char(50);
  assignment           : abap.char(18);
  referencekey         : abap.char(12);
  ponumber             : abap.char(10);
  poitem               : abap.char(5);
  po_history           : abap.char(1);
  material             : abap.char(18);
  plant                : abap.char(4);
  validationstatus     : abap.char(1);
  error_code           : abap.char(10);
  error_message        : abap.char(220);
  createdat            : timestampl;
  changedat            : timestampl;
  "%admin"             : include sych_bdl_draft_admin_inc;

}