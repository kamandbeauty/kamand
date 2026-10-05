"use client";

import Link from "next/link";
import { useMemo } from "react";
import { Bot, Send, Instagram, MessageCircle, Wrench, CheckCircle2, Circle, ArrowLeft, Plus } from "lucide-react";
import { useAutomations } from "@/hooks/useAutomations";
import { useContacts } from "@/hooks/useContacts";
import { useAnalytics } from "@/hooks/useAnalytics";
import { useActiveAccount } from "@/hooks/useActiveAccount";
import { useSetupStatus } from "@/hooks/useSetup";
import { cn, faNum } from "@/lib/utils";

export default function DashboardPage() {
    const { account: connectedAccount, accountId } = useActiveAccount();
    const { data: automations } = useAutomations(accountId);
    const { data: setup } = useSetupStatus();
    const { data: contacts } = useContacts(accountId);

    // Fixed 30-day window, computed once per mount so the query key stays stable
    const analyticsRange = useMemo(() => {
        const now = Date.now();
        return {
            from: new Date(now - 30 * 86400_000).toISOString(),
            to: new Date(now).toISOString(),
        };
    }, []);
    const { data: analytics } = useAnalytics({ ...analyticsRange, automationId: "all", accountId });

    const activeCount = automations?.filter(a => a.is_active).length ?? 0;
    const totalDms = automations?.reduce((sum, a) => sum + a.total_dms_sent, 0) ?? 0;

    const checklist = [
        { label: "ذخیره اطلاعات اپ متا", done: !!setup?.configured, href: "/setup" },
        { label: "اتصال اکانت اینستاگرام", done: !!connectedAccount, href: "/settings" },
        { label: "ساخت اولین خودکارساز", done: (automations?.length ?? 0) > 0, href: "/automations" },
        { label: "فعال‌سازی آن", done: activeCount > 0, href: "/automations" },
    ];
    const allDone = checklist.every(c => c.done);

    const stats = [
        { label: "خودکارسازهای فعال", value: faNum(activeCount), icon: Bot },
        { label: "کامنت · ۳۰ روز", value: faNum(analytics?.totals.comments ?? 0), icon: MessageCircle },
        { label: "دایرکت ارسال‌شده", value: faNum(totalDms), icon: Send },
        { label: "مخاطبان ثبت‌شده", value: faNum(contacts?.total ?? 0), icon: Instagram },
    ];

    return (
        <div className="w-full max-w-5xl mx-auto space-y-8 pb-16">

            {/* Header */}
            <div className="flex items-end justify-between gap-4">
                <div>
                    <h1 className="text-xl font-heading font-semibold tracking-tight text-foreground">
                        {connectedAccount ? <>خوش اومدی، <span className="text-transparent bg-clip-text ig-thread" dir="ltr">@{connectedAccount.username}</span></> : "خوش اومدی"}
                    </h1>
                    <p className="text-[13px] text-muted-foreground mt-1">
                        کنسول خودکارسازی اینستاگرامت، روی زیرساخت خودت.
                    </p>
                </div>
                <Link
                    href="/automations"
                    className="inline-flex items-center gap-1.5 h-9 px-3.5 rounded-lg bg-foreground text-background text-[13px] font-semibold hover:opacity-90 transition-opacity focus:outline-none focus-visible:ring-2 focus-visible:ring-ring/40"
                >
                    <Plus className="w-3.5 h-3.5" />
                    خودکارساز جدید
                </Link>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
                {stats.map((stat) => (
                    <div key={stat.label} className="bg-card border border-border rounded-xl p-4">
                        <div className="flex items-center justify-between">
                            <span className="micro-label">{stat.label}</span>
                            <stat.icon className="w-3.5 h-3.5 text-muted-foreground/60" />
                        </div>
                        <p className="text-2xl font-heading font-semibold tracking-tight text-foreground mt-2 tabular-nums">{stat.value}</p>
                    </div>
                ))}
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-5 gap-3">

                {/* Getting started */}
                <div className="lg:col-span-3 bg-card border border-border rounded-xl p-5">
                    <h2 className="text-[14px] font-heading font-semibold text-foreground">شروع سریع</h2>
                    <p className="text-[13px] text-muted-foreground mt-0.5 mb-4">
                        {allDone
                            ? "همه‌چیز پیکربندی شده — خودکارسازهایت فعال هستند."
                            : "چهار قدم تا یک خودکارساز کارا فاصله داری."}
                    </p>
                    <div className="space-y-1.5">
                        {checklist.map((item) => (
                            <Link key={item.label} href={item.href} className="block group focus:outline-none focus-visible:ring-2 focus-visible:ring-ring/40 rounded-lg">
                                <div className={cn(
                                    "flex items-center justify-between h-10 px-3 rounded-lg border transition-colors",
                                    item.done
                                        ? "border-transparent bg-muted/40"
                                        : "border-border hover:border-foreground/25"
                                )}>
                                    <div className="flex items-center gap-2.5 min-w-0">
                                        {item.done
                                            ? <CheckCircle2 className="w-4 h-4 text-secondary shrink-0" />
                                            : <Circle className="w-4 h-4 text-muted-foreground/40 shrink-0" />}
                                        <span className={cn(
                                            "text-[13px] truncate",
                                            item.done ? "text-muted-foreground line-through" : "text-foreground font-medium"
                                        )}>
                                            {item.label}
                                        </span>
                                    </div>
                                    {!item.done && (
                                        <ArrowLeft className="w-3.5 h-3.5 text-muted-foreground group-hover:text-foreground group-hover:-translate-x-0.5 transition-all shrink-0" />
                                    )}
                                </div>
                            </Link>
                        ))}
                    </div>
                </div>

                {/* System status */}
                <div className="lg:col-span-2 bg-card border border-border rounded-xl p-5">
                    <h2 className="text-[14px] font-heading font-semibold text-foreground mb-4">وضعیت سیستم</h2>
                    <div className="space-y-1.5">
                        {[
                            { label: "اپ متا", ok: !!setup?.configured, detail: setup?.configured ? "پیکربندی شده" : "در انتظار" },
                            { label: "اینستاگرام", ok: !!connectedAccount, detail: connectedAccount ? `@${connectedAccount.username}` : "متصل نیست" },
                            { label: "موتور", ok: activeCount > 0, detail: activeCount > 0 ? `${faNum(activeCount)} فعال` : "غیرفعال" },
                        ].map((row) => (
                            <div key={row.label} className="flex items-center justify-between h-10 px-3 rounded-lg bg-muted/40">
                                <div className="flex items-center gap-2.5">
                                    <span className={cn("w-1.5 h-1.5 rounded-full", row.ok ? "bg-secondary" : "bg-muted-foreground/40")} />
                                    <span className="text-[13px] font-medium text-foreground">{row.label}</span>
                                </div>
                                <span className="text-[12px] text-muted-foreground truncate max-w-[120px]">{row.detail}</span>
                            </div>
                        ))}
                    </div>

                    {!setup?.configured && (
                        <Link
                            href="/setup"
                            className="mt-4 flex items-center justify-center gap-1.5 h-9 w-full rounded-lg bg-foreground text-background text-[13px] font-semibold hover:opacity-90 transition-opacity"
                        >
                            <Wrench className="w-3.5 h-3.5" />
                            باز کردن ویزارد راه‌اندازی
                        </Link>
                    )}
                </div>
            </div>
        </div>
    );
}
