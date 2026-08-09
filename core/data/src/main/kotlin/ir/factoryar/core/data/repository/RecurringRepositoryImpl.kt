package ir.factoryar.core.data.repository

import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.data.mapper.toEntity
import ir.factoryar.core.data.mapper.toDomain
import ir.factoryar.core.database.dao.RecurringDao
import ir.factoryar.core.domain.model.Invoice
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.model.InvoiceWithDetails
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.domain.model.RecurrenceInterval
import ir.factoryar.core.domain.model.RecurringInvoice
import ir.factoryar.core.domain.repository.InvoiceRepository
import ir.factoryar.core.domain.repository.RecurringRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RecurringRepositoryImpl @Inject constructor(
    private val recurringDao: RecurringDao,
    private val invoiceRepository: InvoiceRepository,
) : RecurringRepository {

    override fun observeAll(): Flow<List<RecurringInvoice>> =
        recurringDao.observeAll().map { list -> list.map { it.toDomain() } }

    override suspend fun save(recurring: RecurringInvoice): Long = recurringDao.upsert(recurring.toEntity())

    override suspend fun delete(id: Long) = recurringDao.deleteById(id)

    override suspend fun setActive(id: Long, active: Boolean) = recurringDao.setActive(id, active)

    override suspend fun generateDueInvoices(nowMillis: Long): Int {
        val due = recurringDao.dueItems(nowMillis)
        var generated = 0
        for (entity in due) {
            val recurring = entity.toDomain()
            invoiceRepository.saveInvoice(
                InvoiceWithDetails(
                    invoice = Invoice(
                        type = InvoiceType.SALE,
                        customerId = recurring.customerId,
                        issueDate = nowMillis,
                        dueDate = DateUtils.plusDays(nowMillis, 7),
                        status = PaymentStatus.UNPAID,
                        note = recurring.template.note,
                        terms = recurring.template.terms,
                    ),
                    items = recurring.template.items,
                ),
            )
            generated++
            var next = advance(recurring.nextRunDate, recurring.interval)
            while (next <= nowMillis) next = advance(next, recurring.interval)
            recurringDao.updateNextRun(recurring.id, next)
        }
        return generated
    }

    companion object {
        fun advance(from: Long, interval: RecurrenceInterval): Long = when (interval) {
            RecurrenceInterval.WEEKLY -> DateUtils.plusDays(from, 7)
            RecurrenceInterval.MONTHLY -> plusJalaliMonths(from, 1)
            RecurrenceInterval.YEARLY -> plusJalaliMonths(from, 12)
        }

        /** جلو بردن تاریخ به ماه‌های شمسی (با حفظ روز تا حد امکان) */
        fun plusJalaliMonths(millis: Long, months: Int): Long {
            val d = ir.factoryar.core.common.jalali.JalaliConverter.fromEpochMillis(millis)
            val totalMonths = d.year * 12 + (d.month - 1) + months
            val newYear = totalMonths / 12
            val newMonth = totalMonths % 12 + 1
            val maxDay = ir.factoryar.core.common.jalali.JalaliConverter.monthLength(newYear, newMonth)
            val newDay = d.day.coerceAtMost(maxDay)
            return ir.factoryar.core.common.jalali.JalaliConverter.toEpochMillis(
                ir.factoryar.core.common.jalali.JalaliDate(newYear, newMonth, newDay),
            ) + (millis % DateUtils.DAY_MILLIS)
        }
    }
}
