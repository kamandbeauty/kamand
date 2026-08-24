package com.modir.forushgah.data.local.converter

import androidx.room.TypeConverter
import com.modir.forushgah.domain.model.*

/** Every enum is stored as its `.name` string — stable, human-readable in DB
 * inspectors, and safe as long as enum constants are never renamed (only
 * added to) between app versions. */
class EnumConverters {

    @TypeConverter fun fromOrderStatus(v: OrderStatus): String = v.name
    @TypeConverter fun toOrderStatus(v: String): OrderStatus = OrderStatus.valueOf(v)

    @TypeConverter fun fromOrderKind(v: OrderKind): String = v.name
    @TypeConverter fun toOrderKind(v: String): OrderKind = OrderKind.valueOf(v)

    @TypeConverter fun fromShippingPaymentType(v: ShippingPaymentType): String = v.name
    @TypeConverter fun toShippingPaymentType(v: String): ShippingPaymentType = ShippingPaymentType.valueOf(v)

    @TypeConverter fun fromInventoryMovementType(v: InventoryMovementType): String = v.name
    @TypeConverter fun toInventoryMovementType(v: String): InventoryMovementType = InventoryMovementType.valueOf(v)

    @TypeConverter fun fromInventoryReferenceType(v: InventoryReferenceType): String = v.name
    @TypeConverter fun toInventoryReferenceType(v: String): InventoryReferenceType = InventoryReferenceType.valueOf(v)

    @TypeConverter fun fromExpenseGroup(v: ExpenseGroup): String = v.name
    @TypeConverter fun toExpenseGroup(v: String): ExpenseGroup = ExpenseGroup.valueOf(v)

    @TypeConverter fun fromCommissionBasis(v: CommissionBasis): String = v.name
    @TypeConverter fun toCommissionBasis(v: String): CommissionBasis = CommissionBasis.valueOf(v)

    @TypeConverter fun fromReceivableStatus(v: ReceivableStatus): String = v.name
    @TypeConverter fun toReceivableStatus(v: String): ReceivableStatus = ReceivableStatus.valueOf(v)

    @TypeConverter fun fromPayableStatus(v: PayableStatus): String = v.name
    @TypeConverter fun toPayableStatus(v: String): PayableStatus = PayableStatus.valueOf(v)

    @TypeConverter fun fromReturnReason(v: ReturnReason): String = v.name
    @TypeConverter fun toReturnReason(v: String): ReturnReason = ReturnReason.valueOf(v)

    @TypeConverter fun fromReturnStatus(v: ReturnStatus): String = v.name
    @TypeConverter fun toReturnStatus(v: String): ReturnStatus = ReturnStatus.valueOf(v)

    @TypeConverter fun fromTransactionType(v: TransactionType): String = v.name
    @TypeConverter fun toTransactionType(v: String): TransactionType = TransactionType.valueOf(v)

    @TypeConverter fun fromInterestMethod(v: InterestCalculationMethod): String = v.name
    @TypeConverter fun toInterestMethod(v: String): InterestCalculationMethod = InterestCalculationMethod.valueOf(v)
}
