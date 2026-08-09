package ir.factoryar.core.domain.model

data class BusinessProfile(
    val id: Long = 0,
    val name: String = "",
    val phone: String = "",
    val address: String = "",
    val email: String = "",
    /** مسیر لوگو (فایل داخلی اپ) */
    val logoPath: String? = null,
    val defaultTaxPercent: Double = 10.0,
    val defaultTerms: String = "",
    /** فعال بودن پروفایل (پشتیبانی چند کسب‌وکار — اشتراک طلایی) */
    val isActive: Boolean = true,
)
