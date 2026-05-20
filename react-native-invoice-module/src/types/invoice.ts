export type InvoiceItem = {
  productId: string;
  name: string;
  hsnSac: string;
  quantity: number;
  unitPrice: number;
  discount: number;
  taxableValue: number;
  gstRate: number;
  cgstAmount: number;
  sgstAmount: number;
  igstAmount: number;
  total: number;
};

export type Invoice = {
  id: string;
  invoiceNumber: string;
  orderId: string;
  customerId: string;
  vendorId: string;
  items: InvoiceItem[];
  subtotal: number;
  discount: number;
  tax: number;
  cgst: number;
  sgst: number;
  igst: number;
  shippingCharge: number;
  grandTotal: number;
  paymentMethod: string;
  paymentStatus: string;
  invoicePdfUrl: string;
  generatedAt: string;
  status: string;
  creditNoteNumber?: string;
};
