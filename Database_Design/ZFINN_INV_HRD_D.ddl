@EndUserText.label : 'Invoice header draft table'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zfinn_inv_hrd_d {

  key mandt                : mandt not null;
  key headeruuid           : sysuuid_x16 not null;
  invoicenumber            : abap.char(16);
  vendornumber             : abap.char(10);
  companycode              : abap.char(4);
  invoicedate              : abap.dats;
  documentdate             : abap.dats;
  postingdate              : abap.dats;
  fiscalyear               : abap.numc(4);
  currency                 : abap.cuky;
  @Semantics.amount.currencyCode : 'zfinn_inv_hrd_d.currency'
  grossamount              : abap.curr(15,2);
  @Semantics.amount.currencyCode : 'zfinn_inv_hrd_d.currency'
  netamount                : abap.curr(15,2);
  @Semantics.amount.currencyCode : 'zfinn_inv_hrd_d.currency'
  taxamount                : abap.curr(15,2);
  paymentterms             : abap.char(4);
  baselinedate             : abap.dats;
  paymentmethod            : abap.char(1);
  paymentblock             : abap.char(1);
  documenttype             : abap.char(2);
  headertext               : abap.char(25);
  reference                : abap.char(16);
  ponumber                 : abap.char(10);
  status                   : abap.char(1);
  processingtype           : abap.char(1);
  sapdocument              : abap.char(10);
  sapfiscalyear            : abap.numc(4);
  errorcode                : abap.char(10);
  errormessage             : abap.char(220);
  errorfield               : abap.char(30);
  retrycount               : abap.int4;
  retryallowed             : abap.char(1);
  externaldocid            : abap.char(50);
  extractionconfidence     : abap.dec(3,2);
  pdfurl                   : abap.char(255);
  createdby                : abap.char(12);
  createdat                : timestampl;
  changedby                : abap.char(12);
  changedat                : timestampl;
  postedat                 : timestampl;
  correctedby              : abap.char(12);
  correctedat              : timestampl;
  processingtimems         : abap.int4;
  businessarea             : abap.char(4);
  itemcount                : abap.int4;
  "%admin"                 : include sych_bdl_draft_admin_inc;

}