import ExtensionAPI from 'sap/fe/core/ExtensionAPI';
import Context from 'sap/ui/model/odata/v4/Context';
import MessageToast from 'sap/m/MessageToast';
import MessageBox from 'sap/m/MessageBox';
import Dialog from 'sap/m/Dialog';
import VBox from 'sap/m/VBox';
import Label from 'sap/m/Label';
import Text from 'sap/m/Text';
import Button from 'sap/m/Button';
import FileUploader from 'sap/ui/unified/FileUploader';
import ODataModel from 'sap/ui/model/odata/v4/ODataModel';
import ODataListBinding from 'sap/ui/model/odata/v4/ODataListBinding';
import UIComponent from 'sap/ui/core/UIComponent';

/**
 * Event handler for creating invoice from PDF upload.
 *
 * @param this reference to the 'this' that the event handler is bound to.
 * @param context the context of the page on which the event was fired. `undefined` for list report page.
 * @param selectedContexts the selected contexts of the table rows.
 */
export function onClickUploadEdit(this: ExtensionAPI, context: Context | undefined, selectedContexts: Context[]) {
    const model = this.getModel() as ODataModel;

    // Create file uploader
    const fileUploader = new FileUploader({
        name: "pdfFile",
        uploadOnChange: false,
        fileType: ["pdf"],
        mimeType: ["application/pdf"],
        buttonText: "Browse...",
        tooltip: "Upload a PDF invoice"
    });

    // Create dialog for file selection
    const dialog = new Dialog({
        title: "Create Invoice from PDF",
        content: [
            new VBox({
                items: [
                    new Label({ text: "Select a PDF file to create a new invoice:" }),
                    fileUploader,
                    new Text({
                        text: "The system will extract data from the PDF and pre-fill the invoice fields."
                    }).addStyleClass("sapUiSmallMarginTop")
                ]
            })
        ],
        beginButton: new Button({
            text: "Create & Extract",
            type: "Emphasized",
            press: () => {
                const file = (fileUploader as any).oFileUpload.files[0];
                if (!file) {
                    MessageBox.error("Please select a PDF file first.");
                    return;
                }

                dialog.close();

                // Generate mock extracted data first
                const today = new Date();
                const dateStr = today.toISOString().split('T')[0];
                // Short invoice number: INV + last 6 digits of timestamp (max 16 chars for xblnr)
                const timestamp = Date.now().toString().slice(-6);
                const invoiceNumber = `INV${timestamp}`;

                // Show busy indicator
                MessageToast.show("Creating invoice from PDF...");

                // Create new invoice draft WITH all the extracted data
                const listBinding = model.bindList("/InvoiceHeader") as ODataListBinding;
                const newContext = listBinding.create({
                    Status: "P",  // Pending
                    InvoiceNumber: invoiceNumber,
                    VendorNumber: "0000104405",
                    CompanyCode: "0001",
                    InvoiceDate: dateStr,
                    DocumentDate: dateStr,
                    PostingDate: dateStr,
                    Currency: "USD",
                    GrossAmount: "1190.00",
                    NetAmount: "1000.00",
                    TaxAmount: "190.00",
                    DocumentType: "KR",
                    HeaderText: "PDF Extract",  // Max 25 chars for bktxt
                    ExtractionConfidence: "0.95"
                }) as Context;

                if (newContext) {
                    newContext.created()!.then(() => {
                        MessageToast.show("Extracting invoice data from PDF...");

                        // Read file and convert to Base64
                        const reader = new FileReader();
                        reader.onload = (e: any) => {
                            const arrayBuffer = e.target.result;
                            const bytes = new Uint8Array(arrayBuffer);
                            let binary = '';
                            for (let i = 0; i < bytes.byteLength; i++) {
                                binary += String.fromCharCode(bytes[i]);
                            }
                            const base64 = btoa(binary);

                            // Simulate extraction with mock data
                            simulateExtraction(newContext, file.name, this);
                        };

                        reader.onerror = () => {
                            MessageBox.error("Failed to read the PDF file.");
                        };

                        reader.readAsArrayBuffer(file);
                    }).catch((error: any) => {
                        MessageBox.error("Failed to create invoice: " + error.message);
                    });
                }
            }
        }),
        endButton: new Button({
            text: "Cancel",
            press: () => {
                dialog.close();
            }
        }),
        afterClose: () => {
            dialog.destroy();
        }
    });

    dialog.open();
}

/**
 * Simulates PDF extraction and populates invoice data
 */
function simulateExtraction(context: Context, filename: string, extensionAPI: ExtensionAPI) {
    const model = extensionAPI.getModel() as ODataModel;

    // Create line items
    const itemsBinding = model.bindList("_Items", context) as ODataListBinding;

    // Line item 1
    itemsBinding.create({
        ItemNumber: "0001",
        GlAccount: "0000400000",
        CostCenter: "1000",
        Amount: "500.00",
        Currency: "USD",
        TaxCode: "V0",
        ItemText: "Office supplies"
    });

    // Line item 2
    itemsBinding.create({
        ItemNumber: "0002",
        GlAccount: "0000476000",
        CostCenter: "2000",
        Amount: "500.00",
        Currency: "USD",
        TaxCode: "V0",
        ItemText: "Consulting services"
    });

    // Navigate immediately to the Object Page
    MessageToast.show("PDF extraction complete! Navigating to invoice...");

    // Get the context path and extract the key
    setTimeout(() => {
        const contextPath = context.getPath();
        // Extract key from path like /InvoiceHeader(HeaderUuid=xxx,IsActiveEntity=false)
        const keyMatch = contextPath.match(/InvoiceHeader\(([^)]+)\)/);

        if (keyMatch) {
            const fullKey = keyMatch[1]; // e.g., "HeaderUuid=xxx,IsActiveEntity=false"

            // Use the exact hash format from your app
            // Format: #app-preview&/InvoiceHeader(key)
            window.location.hash = `app-preview&/InvoiceHeader(${fullKey})`;
        }
    }, 1000); // Delay to ensure line items are saved
}