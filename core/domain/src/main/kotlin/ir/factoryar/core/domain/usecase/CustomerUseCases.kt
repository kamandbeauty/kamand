package ir.factoryar.core.domain.usecase

import ir.factoryar.core.domain.model.Customer
import ir.factoryar.core.domain.repository.CustomerRepository
import javax.inject.Inject

class ObserveCustomersUseCase @Inject constructor(private val repo: CustomerRepository) {
    operator fun invoke(query: String = "") = repo.observeCustomers(query)
}

class GetCustomerLedgerUseCase @Inject constructor(private val repo: CustomerRepository) {
    operator fun invoke(customerId: Long) = repo.observeLedger(customerId)
}

class SaveCustomerUseCase @Inject constructor(private val repo: CustomerRepository) {
    suspend operator fun invoke(customer: Customer): Long {
        require(customer.name.isNotBlank()) { "نام مشتری الزامی است" }
        return repo.saveCustomer(customer)
    }
}

class DeleteCustomerUseCase @Inject constructor(private val repo: CustomerRepository) {
    suspend operator fun invoke(id: Long) = repo.deleteCustomer(id)
}
