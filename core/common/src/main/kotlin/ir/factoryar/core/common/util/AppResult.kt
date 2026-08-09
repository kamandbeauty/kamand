package ir.factoryar.core.common.util

/** نتیجه عملیات — برای خطاهای قابل پیش‌بینی (شبکه نداریم ولی IO/بلوتوث/چاپ خطا دارند) */
sealed interface AppResult<out T> {
    data class Success<T>(val data: T) : AppResult<T>
    data class Failure(val message: String, val cause: Throwable? = null) : AppResult<Nothing>

    val isSuccess: Boolean get() = this is Success

    fun getOrNull(): T? = (this as? Success)?.data
}

/**
 * توابع کمکی به‌صورت extension نوشته شده‌اند، نه عضو interface.
 *
 * دلیل: کاتلین اجازه نمی‌دهد متد داخل interface با `inline` علامت بخورد
 * («'inline' modifier on virtual members is prohibited») چون آن متد virtual
 * است و می‌تواند override شود. extension function این محدودیت را ندارد و
 * inline شدن آن مزیت عملکردی lambda را حفظ می‌کند.
 */
inline fun <T> AppResult<T>.onSuccess(block: (T) -> Unit): AppResult<T> {
    if (this is AppResult.Success) block(data)
    return this
}

inline fun <T> AppResult<T>.onFailure(block: (String) -> Unit): AppResult<T> {
    if (this is AppResult.Failure) block(message)
    return this
}

inline fun <T> runSafely(block: () -> T): AppResult<T> =
    try {
        AppResult.Success(block())
    } catch (e: Exception) {
        AppResult.Failure(e.message ?: "خطای ناشناخته", e)
    }
