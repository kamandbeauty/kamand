package ir.factoryar.core.domain.usecase

import ir.factoryar.core.domain.model.Expense
import ir.factoryar.core.domain.model.ProfitReport
import ir.factoryar.core.domain.repository.ExpenseRepository
import ir.factoryar.core.domain.repository.ProfitRepository
import javax.inject.Inject

class ObserveExpensesUseCase @Inject constructor(private val repo: ExpenseRepository) {
    operator fun invoke(from: Long? = null, to: Long? = null, categoryId: Long? = null, query: String = "") =
        repo.observeExpenses(from, to, categoryId, query)
}

class SaveExpenseUseCase @Inject constructor(private val repo: ExpenseRepository) {
    suspend operator fun invoke(expense: Expense): Long {
        require(expense.title.isNotBlank()) { "عنوان هزینه الزامی است" }
        require(expense.amount > 0) { "مبلغ هزینه باید بزرگ‌تر از صفر باشد" }
        return repo.saveExpense(expense)
    }
}

class DeleteExpenseUseCase @Inject constructor(private val repo: ExpenseRepository) {
    suspend operator fun invoke(id: Long) = repo.deleteExpense(id)
}

class ObserveExpenseCategoriesUseCase @Inject constructor(private val repo: ExpenseRepository) {
    operator fun invoke() = repo.observeCategories()
}

/** گزارش سود ناخالص/خالص در بازه دلخواه */
class BuildProfitReportUseCase @Inject constructor(private val repo: ProfitRepository) {
    suspend operator fun invoke(from: Long, to: Long): ProfitReport = repo.buildProfitReport(from, to)
}
