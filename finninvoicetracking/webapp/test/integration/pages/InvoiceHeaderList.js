sap.ui.define(['sap/fe/test/ListReport'], function(ListReport) {
    'use strict';

    var CustomPageDefinitions = {
        actions: {},
        assertions: {}
    };

    return new ListReport(
        {
            appId: 'finn.invoice.finninvoicetracking',
            componentId: 'InvoiceHeaderList',
            contextPath: '/InvoiceHeader'
        },
        CustomPageDefinitions
    );
});