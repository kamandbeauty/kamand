package com.javidstudio.app2.notifications

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import com.javidstudio.app2.core.date.BirthdayMath
import com.javidstudio.app2.data.local.App2Database

/**
 * WorkManager backstop for a birthday reminder, mirroring the alarm.
 * Notifications are keyed per person, so whichever path fires first wins.
 */
class BirthdayReminderWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    override suspend fun doWork(): ListenableWorker.Result {
        val personId = inputData.getLong(KEY_PERSON_ID, -1L)
        if (personId <= 0) return ListenableWorker.Result.success()

        return try {
            val person = App2Database.get(applicationContext).birthdayDao().findById(personId)
            if (person != null && person.reminderEnabled) {
                val daysUntil = BirthdayMath.daysUntil(person.birthMonth, person.birthDay)
                Notifications.showBirthday(applicationContext, person.id, person.name, daysUntil)
            }
            ListenableWorker.Result.success()
        } catch (t: Throwable) {
            ListenableWorker.Result.retry()
        }
    }

    companion object {
        const val KEY_PERSON_ID = "person_id"
    }
}
