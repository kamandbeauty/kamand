export const AUTOMATION_TYPES = [
    {
        id: "comment-dm",
        name: "کامنت به دایرکت",
        description: "ارسال خودکار دایرکت به کسانی که زیر پست‌ها یا ریلزهایت کامنت می‌گذارند.",
        iconType: "message",
        available: true,
        bg: "from-[#F97316]/20 to-[#fc9c54]/10",
        border: "group-hover:border-[#F97316]/50",
        iconColor: "text-[#F97316]"
    },
    {
        id: "dm-reply",
        name: "پاسخ خودکار دایرکت",
        description: "پاسخ آنی به کلیدواژه‌های خاص در دایرکت‌هایت.",
        iconType: "send",
        available: true,
        bg: "from-blue-500/20 to-indigo-500/10",
        border: "group-hover:border-blue-500/50",
        iconColor: "text-blue-500"
    },
    {
        id: "story-reply",
        name: "پاسخ استوری",
        description: "ارسال پاسخ خودکار وقتی کسی به استوری‌ات جواب می‌دهد.",
        iconType: "image",
        available: true,
        bg: "from-green-500/20 to-emerald-500/10",
        border: "group-hover:border-green-500/50",
        iconColor: "text-green-500"
    }
];
