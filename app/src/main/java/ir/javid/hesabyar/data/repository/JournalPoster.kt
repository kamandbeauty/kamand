package ir.javid.hesabyar.data.repository

import ir.javid.hesabyar.data.local.dao.AccountingDao
import ir.javid.hesabyar.data.local.entity.JournalEntryEntity
import ir.javid.hesabyar.data.local.entity.JournalItemEntity

/** Centralised posting engine. Every financial workflow calls this inside its Room transaction. */
internal class JournalPoster(private val accountingDao: AccountingDao) {
    data class Line(val accountCode: String, val debit: Long = 0, val credit: Long = 0, val description: String = "")

    suspend fun post(
        sourceType: String,
        referenceId: Long?,
        dateEpochDay: Long,
        description: String,
        lines: List<Line>
    ): Long {
        val useful = lines.filter { it.debit != 0L || it.credit != 0L }
        require(useful.isNotEmpty()) { "سند حسابداری بدون ردیف قابل ثبت نیست" }
        require(useful.sumOf { it.debit } == useful.sumOf { it.credit }) { "سند حسابداری تراز نیست" }
        require(useful.all { it.debit >= 0 && it.credit >= 0 && !(it.debit > 0 && it.credit > 0) }) { "مقادیر بدهکار و بستانکار نامعتبرند" }
        val sequence = accountingDao.countForDay(dateEpochDay) + 1
        val entryId = accountingDao.insertEntry(
            JournalEntryEntity(
                entryNumber = "$sourceType-$dateEpochDay-$sequence",
                dateEpochDay = dateEpochDay,
                description = description,
                sourceType = sourceType,
                referenceId = referenceId
            )
        )
        accountingDao.insertItems(useful.map { line ->
            val account = requireNotNull(accountingDao.findByCode(line.accountCode)) { "حساب سیستمی ${line.accountCode} یافت نشد" }
            JournalItemEntity(journalEntryId = entryId, accountId = account.id, debit = line.debit, credit = line.credit, description = line.description)
        })
        return entryId
    }
}
