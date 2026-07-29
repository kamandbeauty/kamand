package ir.factoryar.app.navigation

import ir.factoryar.core.domain.model.InvoiceType

object Routes {
    const val DASHBOARD = "dashboard"
    const val INVOICES = "invoices"
    const val CUSTOMERS = "customers"
    const val REPORTS = "reports"
    const val SETTINGS = "settings"

    const val RECURRING = "recurring"
    const val PREMIUM = "premium"
    const val PRODUCTS = "products"
    const val EXPENSES = "expenses"
    const val DEBTORS = "debtors"

    const val INVOICE_EDIT = "invoice_edit?invoiceId={invoiceId}&type={type}"
    const val INVOICE_DETAIL = "invoice_detail/{invoiceId}"
    const val CUSTOMER_DETAIL = "customer_detail/{customerId}"
    const val PRODUCT_EDIT = "product_edit?productId={productId}&barcode={barcode}"

    fun invoiceEdit(invoiceId: Long = -1L, type: InvoiceType = InvoiceType.SALE): String =
        "invoice_edit?invoiceId=$invoiceId&type=${type.name}"

    fun invoiceDetail(id: Long): String = "invoice_detail/$id"
    fun customerDetail(id: Long): String = "customer_detail/$id"

    fun productEdit(productId: Long = -1L, barcode: String = ""): String =
        "product_edit?productId=$productId&barcode=$barcode"
}
