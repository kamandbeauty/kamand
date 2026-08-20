package com.studiojavid.memory.data.repo

import androidx.annotation.StringRes
import com.studiojavid.memory.R

/**
 * Offline birthday greetings.
 *
 * Kept in string resources rather than seeded into the database so they can be
 * localized and updated with the app, and so a restore can never wipe them.
 * Ids are stable: a person's chosen greeting is stored by id and must survive
 * reordering, so new messages are only ever appended.
 */
enum class MessageCategory(val emoji: String, @StringRes val labelRes: Int) {
    WARM("❤️", R.string.msg_cat_warm),
    EMOTIONAL("💝", R.string.msg_cat_emotional),
    HAPPY("🎉", R.string.msg_cat_happy),
    FUNNY("😂", R.string.msg_cat_funny),
    FAMILY("👨‍👩‍👧", R.string.msg_cat_family),
    FORMAL("💼", R.string.msg_cat_formal),
    ROMANTIC("💑", R.string.msg_cat_romantic),
    SHORT("✨", R.string.msg_cat_short)
}

data class BirthdayMessage(
    val id: Int,
    val category: MessageCategory,
    @StringRes val textRes: Int
)

object BirthdayMessages {

    /**
     * Placeholder replaced with the person's name. Defined in resources
     * (R.string.name_token) so it always matches the greeting text; callers
     * pass it in rather than this file hardcoding Persian.
     */

    val all: List<BirthdayMessage> = listOf(
        // ❤️ warm
        BirthdayMessage(1, MessageCategory.WARM, R.string.bmsg_1),
        BirthdayMessage(2, MessageCategory.WARM, R.string.bmsg_2),
        BirthdayMessage(3, MessageCategory.WARM, R.string.bmsg_3),
        BirthdayMessage(4, MessageCategory.WARM, R.string.bmsg_4),
        BirthdayMessage(5, MessageCategory.WARM, R.string.bmsg_5),
        BirthdayMessage(6, MessageCategory.WARM, R.string.bmsg_6),
        BirthdayMessage(7, MessageCategory.WARM, R.string.bmsg_7),
        BirthdayMessage(8, MessageCategory.WARM, R.string.bmsg_8),
        // 💝 emotional
        BirthdayMessage(9, MessageCategory.EMOTIONAL, R.string.bmsg_9),
        BirthdayMessage(10, MessageCategory.EMOTIONAL, R.string.bmsg_10),
        BirthdayMessage(11, MessageCategory.EMOTIONAL, R.string.bmsg_11),
        BirthdayMessage(12, MessageCategory.EMOTIONAL, R.string.bmsg_12),
        BirthdayMessage(13, MessageCategory.EMOTIONAL, R.string.bmsg_13),
        BirthdayMessage(14, MessageCategory.EMOTIONAL, R.string.bmsg_14),
        BirthdayMessage(15, MessageCategory.EMOTIONAL, R.string.bmsg_15),
        // 🎉 happy
        BirthdayMessage(16, MessageCategory.HAPPY, R.string.bmsg_16),
        BirthdayMessage(17, MessageCategory.HAPPY, R.string.bmsg_17),
        BirthdayMessage(18, MessageCategory.HAPPY, R.string.bmsg_18),
        BirthdayMessage(19, MessageCategory.HAPPY, R.string.bmsg_19),
        BirthdayMessage(20, MessageCategory.HAPPY, R.string.bmsg_20),
        BirthdayMessage(21, MessageCategory.HAPPY, R.string.bmsg_21),
        BirthdayMessage(22, MessageCategory.HAPPY, R.string.bmsg_22),
        // 😂 funny
        BirthdayMessage(23, MessageCategory.FUNNY, R.string.bmsg_23),
        BirthdayMessage(24, MessageCategory.FUNNY, R.string.bmsg_24),
        BirthdayMessage(25, MessageCategory.FUNNY, R.string.bmsg_25),
        BirthdayMessage(26, MessageCategory.FUNNY, R.string.bmsg_26),
        BirthdayMessage(27, MessageCategory.FUNNY, R.string.bmsg_27),
        BirthdayMessage(28, MessageCategory.FUNNY, R.string.bmsg_28),
        BirthdayMessage(29, MessageCategory.FUNNY, R.string.bmsg_29),
        // 👨‍👩‍👧 family
        BirthdayMessage(30, MessageCategory.FAMILY, R.string.bmsg_30),
        BirthdayMessage(31, MessageCategory.FAMILY, R.string.bmsg_31),
        BirthdayMessage(32, MessageCategory.FAMILY, R.string.bmsg_32),
        BirthdayMessage(33, MessageCategory.FAMILY, R.string.bmsg_33),
        BirthdayMessage(34, MessageCategory.FAMILY, R.string.bmsg_34),
        BirthdayMessage(35, MessageCategory.FAMILY, R.string.bmsg_35),
        // 💑 romantic
        BirthdayMessage(36, MessageCategory.ROMANTIC, R.string.bmsg_36),
        BirthdayMessage(37, MessageCategory.ROMANTIC, R.string.bmsg_37),
        BirthdayMessage(38, MessageCategory.ROMANTIC, R.string.bmsg_38),
        BirthdayMessage(39, MessageCategory.ROMANTIC, R.string.bmsg_39),
        BirthdayMessage(40, MessageCategory.ROMANTIC, R.string.bmsg_40),
        // 💼 formal
        BirthdayMessage(41, MessageCategory.FORMAL, R.string.bmsg_41),
        BirthdayMessage(42, MessageCategory.FORMAL, R.string.bmsg_42),
        BirthdayMessage(43, MessageCategory.FORMAL, R.string.bmsg_43),
        BirthdayMessage(44, MessageCategory.FORMAL, R.string.bmsg_44),
        BirthdayMessage(45, MessageCategory.FORMAL, R.string.bmsg_45),
        // ✨ short
        BirthdayMessage(46, MessageCategory.SHORT, R.string.bmsg_46),
        BirthdayMessage(47, MessageCategory.SHORT, R.string.bmsg_47),
        BirthdayMessage(48, MessageCategory.SHORT, R.string.bmsg_48),
        BirthdayMessage(49, MessageCategory.SHORT, R.string.bmsg_49),
        BirthdayMessage(50, MessageCategory.SHORT, R.string.bmsg_50)
    )

    fun byId(id: Int): BirthdayMessage? = all.firstOrNull { it.id == id }

    fun inCategory(category: MessageCategory): List<BirthdayMessage> =
        all.filter { it.category == category }

    /**
     * Substitutes the person's name into a greeting.
     *
     * When the name is unknown the placeholder is removed rather than left
     * visible, and the leftover spacing/punctuation is tidied so the sentence
     * still reads naturally.
     */
    fun personalize(
        text: String,
        name: String?,
        token: String,
        suffixes: List<String> = emptyList()
    ): String {
        if (!name.isNullOrBlank()) return text.replace(token, name.trim())

        // No name: drop the placeholder along with its vocative suffix, then
        // tidy the leftover spacing so the sentence still reads naturally.
        var result = text
        suffixes.forEach { suffix ->
            result = result.replace("$token $suffix", "")
        }
        return result
            .replace(token, "")
            .replace(Regex("\\s{2,}"), " ")
            .replace(Regex("^[\\s\\u060C]+"), "")
            .trim()
    }
}
