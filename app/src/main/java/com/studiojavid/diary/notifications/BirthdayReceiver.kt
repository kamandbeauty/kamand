package com.studiojavid.diary.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.studiojavid.diary.core.date.BirthdayMath
import com.studiojavid.diary.data.local.DiaryDatabase
import com.studiojavid.diary.data.repo.BirthdayRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Delivers a birthday reminder, then re-arms the next one.
 *
 * The person is re-read from the database so a deleted or edited entry cannot
 * fire a stale notification, and the countdown is recomputed at delivery time
 * rather than trusting the value captured when the alarm was set.
 */
class BirthdayReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_BIRTHDAY) return
        val personId = intent.getLongExtra(EXTRA_PERSON_ID, -1L)
        if (personId <= 0) return

        val appContext = context.applicationContext
        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                val person = DiaryDatabase.get(appContext).birthdayDao().findById(personId)
                if (person != null && person.reminderEnabled) {
                    val daysUntil = BirthdayMath.daysUntil(person.birthMonth, person.birthDay)
                    Notifications.showBirthday(appContext, person.id, person.name, daysUntil)
                }
                // Arm next year's alarm now that this one has fired.
                BirthdayRepository(appContext).rescheduleAll()
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        const val ACTION_BIRTHDAY = "com.studiojavid.diary.action.BIRTHDAY"
        const val EXTRA_PERSON_ID = "person_id"
        const val EXTRA_NAME = "person_name"
        const val EXTRA_DAYS_BEFORE = "days_before"
        const val EXTRA_DAYS_UNTIL = "days_until"
    }
}
