import MessageBox from "sap/m/MessageBox";
import MessageToast from "sap/m/MessageToast";

/**
 * @namespace finn.invoice.finninvoicetracking.ext.controller
 */
export default class ObjectPageExt {

    /**
     * Repost action - triggers the backend repost action
     */
    public static onRepost(this: any): void {
        const context = this.getBindingContext();
        if (!context) {
            MessageBox.error("No invoice selected");
            return;
        }

        MessageBox.confirm(
            "Are you sure you want to repost this invoice?",
            {
                title: "Confirm Repost",
                onClose: (action: string | null) => {
                    if (action === MessageBox.Action.OK) {
                        ObjectPageExt._executeRepost.call(this, context);
                    }
                }
            }
        );
    }

    /**
     * Execute repost backend action
     */
    private static _executeRepost(this: any, context: any): void {
        const invoiceNumber = context.getProperty("InvoiceNumber");

        MessageToast.show(`Reposting invoice ${invoiceNumber}...`);

        // Call backend action
        const action = context.bindContext("repost(...)");

        action.execute()
            .then(() => {
                MessageBox.success(
                    `Invoice ${invoiceNumber} has been successfully reposted.`,
                    {
                        title: "Repost Successful",
                        onClose: () => {
                            // Refresh the binding
                            this.refresh();
                        }
                    }
                );
            })
            .catch((error: any) => {
                MessageBox.error(
                    `Failed to repost invoice: ${error.message}`,
                    { title: "Repost Failed" }
                );
            });
    }

    /**
     * Correct action - enables edit mode for correction
     */
    public static onCorrect(this: any): void {
        const context = this.getBindingContext();
        if (!context) {
            MessageBox.error("No invoice selected");
            return;
        }

        const invoiceNumber = context.getProperty("InvoiceNumber");

        MessageBox.confirm(
            `Do you want to correct invoice ${invoiceNumber}? After making corrections, click Save and then Repost.`,
            {
                title: "Correct Invoice",
                onClose: (action: string | null) => {
                    if (action === MessageBox.Action.OK) {
                        // Trigger edit mode via extension API
                        this.editFlow.editDocument(context);
                        MessageToast.show("Edit mode enabled. Make corrections and click Save.");
                    }
                }
            }
        );
    }

    /**
     * Cancel action - triggers the backend cancel action
     */
    public static onCancel(this: any): void {
        const context = this.getBindingContext();
        if (!context) {
            MessageBox.error("No invoice selected");
            return;
        }

        const invoiceNumber = context.getProperty("InvoiceNumber");

        MessageBox.warning(
            `Are you sure you want to cancel invoice ${invoiceNumber}? This action cannot be undone.`,
            {
                title: "Confirm Cancellation",
                actions: [MessageBox.Action.YES, MessageBox.Action.NO],
                emphasizedAction: MessageBox.Action.NO,
                onClose: (action: string | null) => {
                    if (action === MessageBox.Action.YES) {
                        ObjectPageExt._executeCancel.call(this, context);
                    }
                }
            }
        );
    }

    /**
     * Execute cancel backend action
     */
    private static _executeCancel(this: any, context: any): void {
        const invoiceNumber = context.getProperty("InvoiceNumber");

        MessageToast.show(`Cancelling invoice ${invoiceNumber}...`);

        // Call backend action
        const action = context.bindContext("cancel(...)");

        action.execute()
            .then(() => {
                MessageBox.success(
                    `Invoice ${invoiceNumber} has been cancelled.`,
                    {
                        title: "Cancellation Successful",
                        onClose: () => {
                            // Refresh and navigate back
                            this.refresh();
                            this.routing.navigateBackFromContext(context);
                        }
                    }
                );
            })
            .catch((error: any) => {
                MessageBox.error(
                    `Failed to cancel invoice: ${error.message}`,
                    { title: "Cancellation Failed" }
                );
            });
    }

    /**
     * View PDF action - opens PDF in new window
     */
    public static onViewPdf(this: any): void {
        const context = this.getBindingContext();
        if (!context) {
            MessageBox.error("No invoice selected");
            return;
        }

        const pdfUrl = context.getProperty("PdfUrl");
        const invoiceNumber = context.getProperty("InvoiceNumber");

        if (!pdfUrl) {
            MessageBox.error("PDF URL is not available for this invoice");
            return;
        }

        // Open PDF in new window
        window.open(pdfUrl, "_blank", "noopener,noreferrer");
        MessageToast.show(`Opening PDF for invoice ${invoiceNumber}`);
    }
}
