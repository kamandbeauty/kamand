package com.forushyar.app.data.repository

import androidx.room.withTransaction
import com.forushyar.app.data.local.AppDatabase
import com.forushyar.app.data.local.dao.CustomerDao
import com.forushyar.app.data.local.dao.OrderDao
import com.forushyar.app.data.local.dao.OrderItemDao
import com.forushyar.app.data.local.dao.ProductDao
import com.forushyar.app.data.local.entity.Customer
import com.forushyar.app.data.local.entity.Order
import com.forushyar.app.data.local.entity.OrderItem
import com.forushyar.app.data.local.entity.OrderStatus
import com.forushyar.app.data.local.entity.Product
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.first
import org.json.JSONArray
import org.json.JSONObject

/** ساخت و بازیابی نسخه پشتیبان JSON با اعتبارسنجی کامل پیش از تغییر پایگاه داده. */
@Singleton
class BackupRepository @Inject constructor(
    private val database: AppDatabase,
    private val customerDao: CustomerDao,
    private val productDao: ProductDao,
    private val orderDao: OrderDao,
    private val orderItemDao: OrderItemDao,
    private val settingsRepository: SettingsRepository
) {
    suspend fun exportJson(): String {
        val settings = settingsRepository.settings.first()
        return JSONObject().apply {
            put("backupVersion", BACKUP_VERSION)
            put("exportedAt", System.currentTimeMillis())
            put("settings", JSONObject().apply {
                put("shopName", settings.shopName)
                put("confirmDeletion", settings.confirmDeletion)
            })
            put("customers", JSONArray().apply {
                customerDao.getAll().forEach { customer -> put(customer.toJson()) }
            })
            put("products", JSONArray().apply {
                productDao.getAll().forEach { product -> put(product.toJson()) }
            })
            put("orders", JSONArray().apply {
                orderDao.getAll().forEach { order -> put(order.toJson()) }
            })
            put("orderItems", JSONArray().apply {
                orderItemDao.getAll().forEach { item -> put(item.toJson()) }
            })
        }.toString(2)
    }

    suspend fun importJson(content: String) {
        val root = JSONObject(content)
        require(root.getInt("backupVersion") == BACKUP_VERSION) { "unsupported_version" }

        val customers = root.getJSONArray("customers").mapObjects { it.toCustomer() }
        val products = root.getJSONArray("products").mapObjects { it.toProduct() }
        val orders = root.getJSONArray("orders").mapObjects { it.toOrder() }
        val orderItems = root.getJSONArray("orderItems").mapObjects { it.toOrderItem() }
        validate(customers, products, orders, orderItems)

        val settingsJson = root.optJSONObject("settings")
        val settings = settingsJson?.let {
            AppSettings(
                shopName = it.optString("shopName", ""),
                confirmDeletion = it.optBoolean("confirmDeletion", true)
            )
        }

        database.withTransaction {
            orderItemDao.clearAll()
            orderDao.clearAll()
            productDao.clearAll()
            customerDao.clearAll()
            customers.forEach { customerDao.insert(it) }
            products.forEach { productDao.insert(it) }
            orders.forEach { orderDao.insert(it) }
            if (orderItems.isNotEmpty()) orderItemDao.insertAll(orderItems)
        }
        if (settings != null) settingsRepository.restore(settings)
    }

    private fun validate(
        customers: List<Customer>,
        products: List<Product>,
        orders: List<Order>,
        items: List<OrderItem>
    ) {
        require(customers.all { it.id > 0 && it.name.isNotBlank() }) { "invalid_customers" }
        require(products.all {
            it.id > 0 && it.name.isNotBlank() && it.buyPrice >= 0 && it.sellPrice >= 0 && it.stock >= 0
        }) { "invalid_products" }
        require(customers.map { it.id }.distinct().size == customers.size) { "duplicate_customer" }
        require(products.map { it.id }.distinct().size == products.size) { "duplicate_product" }
        val customerIds = customers.mapTo(mutableSetOf()) { it.id }
        require(orders.all { it.id > 0 && it.customerId in customerIds }) { "invalid_orders" }
        require(orders.map { it.id }.distinct().size == orders.size) { "duplicate_order" }
        val orderIds = orders.mapTo(mutableSetOf()) { it.id }
        require(items.all {
            it.id > 0 && it.orderId in orderIds && it.productId > 0 && it.quantity > 0 &&
                it.buyPrice >= 0 && it.sellPrice >= 0
        }) { "invalid_items" }
        require(items.map { it.id }.distinct().size == items.size) { "duplicate_item" }
    }

    private companion object {
        const val BACKUP_VERSION = 1
    }
}

private fun <T> JSONArray.mapObjects(transform: (JSONObject) -> T): List<T> =
    List(length()) { index -> transform(getJSONObject(index)) }

private fun Customer.toJson() = JSONObject().apply {
    put("id", id); put("name", name); put("phone", phone); put("instagramId", instagramId)
    put("address", address); put("note", note); put("createdDate", createdDate)
}

private fun Product.toJson() = JSONObject().apply {
    put("id", id); put("name", name); put("category", category); put("buyPrice", buyPrice)
    put("sellPrice", sellPrice); put("stock", stock); put("createdDate", createdDate)
}

private fun Order.toJson() = JSONObject().apply {
    put("id", id); put("customerId", customerId); put("status", status.name)
    put("createdAt", createdAt); put("note", note)
}

private fun OrderItem.toJson() = JSONObject().apply {
    put("id", id); put("orderId", orderId); put("productId", productId); put("quantity", quantity)
    put("buyPrice", buyPrice); put("sellPrice", sellPrice)
}

private fun JSONObject.toCustomer() = Customer(
    id = getLong("id"), name = getString("name"), phone = optString("phone", ""),
    instagramId = optString("instagramId", ""), address = optString("address", ""),
    note = optString("note", ""), createdDate = getLong("createdDate")
)

private fun JSONObject.toProduct() = Product(
    id = getLong("id"), name = getString("name"), category = optString("category", ""),
    buyPrice = getLong("buyPrice"), sellPrice = getLong("sellPrice"), stock = getInt("stock"),
    createdDate = getLong("createdDate")
)

private fun JSONObject.toOrder() = Order(
    id = getLong("id"), customerId = getLong("customerId"),
    status = OrderStatus.valueOf(getString("status")), createdAt = getLong("createdAt"),
    note = optString("note", "")
)

private fun JSONObject.toOrderItem() = OrderItem(
    id = getLong("id"), orderId = getLong("orderId"), productId = getLong("productId"),
    quantity = getInt("quantity"), buyPrice = getLong("buyPrice"), sellPrice = getLong("sellPrice")
)
