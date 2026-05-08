sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"finn/invoice/finninvoicetracking/test/integration/pages/InvoiceHeaderList",
	"finn/invoice/finninvoicetracking/test/integration/pages/InvoiceHeaderObjectPage",
	"finn/invoice/finninvoicetracking/test/integration/pages/InvoiceItemsObjectPage"
], function (JourneyRunner, InvoiceHeaderList, InvoiceHeaderObjectPage, InvoiceItemsObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('finn/invoice/finninvoicetracking') + '/test/flp.html#app-preview',
        pages: {
			onTheInvoiceHeaderList: InvoiceHeaderList,
			onTheInvoiceHeaderObjectPage: InvoiceHeaderObjectPage,
			onTheInvoiceItemsObjectPage: InvoiceItemsObjectPage
        },
        async: true
    });

    return runner;
});

