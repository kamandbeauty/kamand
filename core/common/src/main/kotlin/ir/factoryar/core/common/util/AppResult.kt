package ir.factoryar.core.common.util

/** نتیجه عملیات — برای خطاهای قابل پیش‌بینی (شبکه نداریم ولی IO/بلوتوث/چاپ خطا دارند) */
sealed interface AppResult<out T> {
    data class Success<T>(val data: T) : AppResult<T>
    data class Failure(val message: String, val cause: Throwable? = null) : AppResult<Nothing>

    val isSuccess: Boolean get() = this is Success

    fun getOrNull(): T? = (this as? Success)?.data

    inline fun onSuccess(block: (T) -> Unit): AppResult<T> {
        if (this is Success) block(data)
        return this
    }

    inline fun onFailure(block: (String) -> Unit): AppResult<T> {
        if (this is Failure) block(message)
        return this
    }
}

inline fun <T> runSafely(block: () -> T): AppResult<T> =
    try {
        AppResult.Success(block())
    } catch (e: Exception) {
        AppResult.Failure(e.message ?: "خطای ناشناخته", e)
    }
