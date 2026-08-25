package com.modir.forushgah.presentation.onboarding

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.entity.StoreProfileEntity
import com.modir.forushgah.data.repository.DashboardRepository
import com.modir.forushgah.data.repository.StoreProfileRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.resetMain

/**
 * Phase 4.2.1 hotfix regression tests: the onboarding "موجودی اولیه فروشگاه"
 * field is OPTIONAL — empty/whitespace/zero input must complete onboarding
 * with a zero starting balance (never a crash, null or negative value),
 * Persian digits must parse, and the app must start normally afterwards.
 */
@RunWith(RobolectricTestRunner::class)
class OnboardingViewModelTest {

    private lateinit var db: AppDatabase
    private lateinit var storeProfileRepository: StoreProfileRepository
    private lateinit var viewModel: OnboardingViewModel

    @Before
    fun setup() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        db = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        storeProfileRepository = StoreProfileRepository(db.storeProfileDao())
        viewModel = OnboardingViewModel(storeProfileRepository)
    }

    @After
    fun teardown() {
        Dispatchers.resetMain()
        db.close()
    }

    // ---------- helpers ----------

    /** Drives the whole onboarding form (steps 1–3) and finishes it. */
    private fun completeOnboarding(startingCash: String) {
        viewModel.onStoreNameChanged("فروشگاه تست")
        viewModel.onOwnerNameChanged("صاحب تست")
        viewModel.onCategoryChanged("آرایشی و بهداشتی")
        viewModel.onStartingCashChanged(startingCash)
        viewModel.finishOnboarding(onDone = {})
    }

    /** Waits for the profile row written by the ViewModel coroutine. */
    private suspend fun awaitProfile(): StoreProfileEntity {
        val deadline = System.currentTimeMillis() + 10_000
        while (true) {
            db.storeProfileDao().get()?.let { return it }
            if (System.currentTimeMillis() > deadline) error("timeout waiting for store profile")
            delay(10)
        }
    }

    // ---------- 1. empty initial inventory ----------

    @Test
    fun `empty initial inventory completes onboarding with zero balance`() = runBlocking {
        completeOnboarding("")
        val profile = awaitProfile()
        assertThat(profile.onboardingCompleted).isTrue()
        assertThat(profile.startingCashBalance).isEqualTo(Money.ZERO)
    }

    // ---------- 2. whitespace-only ----------

    @Test
    fun `whitespace-only initial inventory becomes zero`() = runBlocking {
        assertThat(parseStartingCashToman("   ")).isEqualTo(Money.ZERO)
        completeOnboarding("   ")
        assertThat(awaitProfile().startingCashBalance).isEqualTo(Money.ZERO)
    }

    // ---------- 3. latin zero ----------

    @Test
    fun `latin zero input becomes zero`() = runBlocking {
        completeOnboarding("0")
        assertThat(awaitProfile().startingCashBalance).isEqualTo(Money.ZERO)
    }

    // ---------- 4. Persian zero ----------

    @Test
    fun `persian zero input becomes zero`() = runBlocking {
        assertThat(parseStartingCashToman("۰")).isEqualTo(Money.ZERO)
        completeOnboarding("۰")
        assertThat(awaitProfile().startingCashBalance).isEqualTo(Money.ZERO)
    }

    // ---------- 5. valid positive value ----------

    @Test
    fun `valid positive value becomes the correct money`() = runBlocking {
        assertThat(parseStartingCashToman("5000")).isEqualTo(Money(5_000))
        assertThat(parseStartingCashToman("۵۰۰")).isEqualTo(Money(500))
        completeOnboarding("۵۰۰")
        assertThat(awaitProfile().startingCashBalance).isEqualTo(Money(500))
    }

    // ---------- 6. invalid negative value ----------

    @Test
    fun `negative input keeps the existing digits-only rule and never stores negative`() = runBlocking {
        // The existing field filter accepts digits only — the sign is dropped
        // like any other character (existing business rule).
        viewModel.onStartingCashChanged("-500")
        assertThat(viewModel.formState.value.startingCash).isEqualTo("500")
        // The parser is the boundary: non-digits are dropped, and the result
        // can never be negative.
        assertThat(parseStartingCashToman("-500")).isEqualTo(Money(500))
        completeOnboarding("-500")
        val stored = awaitProfile().startingCashBalance
        assertThat(stored.amountInToman).isAtLeast(0L)
        assertThat(stored).isEqualTo(Money(500))
    }

    // ---------- 7. startup after onboarding with empty inventory ----------

    @Test
    fun `app startup after onboarding with empty inventory does not crash`() = runBlocking {
        completeOnboarding("")
        awaitProfile()

        // The first-screen (dashboard) read path must emit a snapshot without
        // throwing once onboarding data (zero starting cash) exists.
        val snapshot = DashboardRepository(
            orderDao = db.orderDao(),
            productDao = db.productDao(),
            receivableDao = db.receivableDao(),
            payableDao = db.payableDao(),
        ).observeSnapshot().first()
        assertThat(snapshot.totalReceivables).isEqualTo(Money.ZERO)
        assertThat(snapshot.totalPayables).isEqualTo(Money.ZERO)
        assertThat(snapshot.inventoryValue).isEqualTo(Money.ZERO)
    }
}
