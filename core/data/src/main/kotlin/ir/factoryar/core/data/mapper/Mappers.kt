package ir.factoryar.core.data.mapper

import ir.factoryar.core.database.entity.BusinessProfileEntity
import ir.factoryar.core.database.entity.CustomerEntity
import ir.factoryar.core.database.entity.InvoiceEntity
import ir.factoryar.core.database.entity.InvoiceItemEntity
import ir.factoryar.core.database.entity.InvoiceWithItemsEntity
import ir.factoryar.core.database.entity.RecurringInvoiceEntity
import ir.factoryar.core.domain.model.BusinessProfile
import ir.factoryar.core.domain.model.Customer
import ir.factoryar.core.domain.model.Invoice
import ir.factoryar.core.domain.model.InvoiceItem
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.model.InvoiceWithDetails
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.domain.model.RecurringInvoice
import ir.factoryar.core.domain.model.RecurringTemplate
import ir.factoryar.core.domain.model.RecurrenceInterval
import kotlinx.serialization.json.Json

fun CustomerEntity.toDomain() = Customer(id, name, phone, email, address, note, createdAt)
fun Customer.toEntity() = CustomerEntity(id, name, phone, email, address, note, createdAt)

fun InvoiceItemEntity.toDomain() = InvoiceItem(
    id = id,
    invoiceId = invoiceId,
    title = title,
    quantity = quantity,
    unitPrice = unitPrice,
    discountPercent = discountPercent,
    taxPercent = taxPercent,
    sortOrder = sortOrder,
    productId = productId,
    costPrice = costPrice,
)

fun InvoiceItem.toEntity() = InvoiceItemEntity(
    id = id,
    invoiceId = invoiceId,
    title = title,
    quantity = quantity,
    unitPrice = unitPrice,
    discountPercent = discountPercent,
    taxPercent = taxPercent,
    sortOrder = sortOrder,
    productId = productId,
    costPrice = costPrice,
)

fun InvoiceEntity.toDomain() = Invoice(
    id = id,
    number = number,
    type = InvoiceType.fromName(type),
    customerId = customerId,
    issueDate = issueDate,
    dueDate = dueDate,
    status = PaymentStatus.fromName(status),
    paidAmount = paidAmount,
    globalDiscount = globalDiscount,
    note = note,
    terms = terms,
    signaturePath = signaturePath,
    subtotal = subtotal,
    discountTotal = discountTotal,
    taxTotal = taxTotal,
    grandTotal = grandTotal,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun Invoice.toEntity() = InvoiceEntity(
    id = id,
    number = number,
    type = type.name,
    customerId = customerId,
    issueDate = issueDate,
    dueDate = dueDate,
    status = status.name,
    paidAmount = paidAmount,
    globalDiscount = globalDiscount,
    note = note,
    terms = terms,
    signaturePath = signaturePath,
    subtotal = subtotal,
    discountTotal = discountTotal,
    taxTotal = taxTotal,
    grandTotal = grandTotal,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun InvoiceWithItemsEntity.toDomain(customer: Customer? = null) = InvoiceWithDetails(
    invoice = invoice.toDomain(),
    items = items.sortedBy { it.sortOrder }.map { it.toDomain() },
    customer = customer,
)

// ---------------- Recurring (قالب JSON) ----------------

private val json = Json { ignoreUnknownKeys = true }

private val templateSerializer = RecurringTemplate.serializer()

fun RecurringInvoiceEntity.toDomain(): RecurringInvoice = RecurringInvoice(
    id = id,
    title = title,
    customerId = customerId,
    interval = RecurrenceInterval.fromName(interval),
    startDate = startDate,
    nextRunDate = nextRunDate,
    active = active,
    template = runCatching { json.decodeFromString(templateSerializer, templateJson) }
        .getOrDefault(RecurringTemplate()),
)

fun RecurringInvoice.toEntity() = RecurringInvoiceEntity(
    id = id,
    title = title,
    customerId = customerId,
    interval = interval.name,
    startDate = startDate,
    nextRunDate = nextRunDate,
    active = active,
    templateJson = json.encodeToString(RecurringTemplate.serializer(), template),
)

fun BusinessProfileEntity.toDomain() =
    BusinessProfile(id, name, phone, address, email, logoPath, defaultTaxPercent, defaultTerms, isActive)

fun BusinessProfile.toEntity() =
    BusinessProfileEntity(id, name, phone, address, email, logoPath, defaultTaxPercent, defaultTerms, isActive)
