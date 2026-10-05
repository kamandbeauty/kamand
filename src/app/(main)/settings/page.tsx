"use client";

import { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Instagram, CheckCircle2, XCircle, Loader2, Unlink, AlertTriangle, RefreshCw, Wrench, PauseCircle } from "lucide-react";
import { cn, faNum, faDate, faDateTime } from "@/lib/utils";
import { createBrowserClient } from "@/lib/supabase";
import { apiClient, ApiError } from "@/lib/api/client";
import { useInstagramAccounts, useRefreshInstagramToken, useResubscribeWebhook, useCheckSubscription } from "@/hooks/useInstagramAccounts";
import { useSetupStatus } from "@/hooks/useSetup";
import { useQueryClient } from "@tanstack/react-query";

export default function SettingsPage() {
    return (
        <Suspense fallback={<div className="w-full max-w-3xl mx-auto py-24 flex justify-center"><Loader2 className="w-5 h-5 animate-spin text-muted-foreground" /></div>}>
            <SettingsContent />
        </Suspense>
    );
}

function SettingsContent() {
    const searchParams = useSearchParams();
    const queryClient = useQueryClient();
    const { data: accounts, isLoading } = useInstagramAccounts();
    const { data: setup } = useSetupStatus();

    const refreshMutation = useRefreshInstagramToken();
    const resubscribeMutation = useResubscribeWebhook();
    const checkSubscriptionMutation = useCheckSubscription();
    const [connectingIG, setConnectingIG] = useState(false);
    const [disconnectingId, setDisconnectingId] = useState<string | null>(null);
    const [refreshingId, setRefreshingId] = useState<string | null>(null);
    const [resubscribingId, setResubscribingId] = useState<string | null>(null);
    const [checkingSubId, setCheckingSubId] = useState<string | null>(null);
    const [subStatus, setSubStatus] = useState<Record<string, { subscribedFields: string[]; hasComments: boolean; hasMessages: boolean } | null>>({});
    const [banner, setBanner] = useState<{ type: "success" | "error"; message: string } | null>(null);

    useEffect(() => {
        const igConnected = searchParams.get("instagram_connected");
        const igError = searchParams.get("instagram_error");

        if (igConnected === "true") {
            setBanner({ type: "success", message: "اکانت اینستاگرام متصل شد." });
            void queryClient.invalidateQueries({ queryKey: ["instagram-accounts"] });
            window.history.replaceState({}, "", "/settings");
        } else if (igError) {
            const errorMessages: Record<string, string> = {
                access_denied: "اتصال اینستاگرام لغو شد.",
                no_instagram_business_account: "هیچ اکانت بیزینس یا کریتورِ اینستاگرامی پیدا نشد. اول اکانتت را به اکانت حرفه‌ای تبدیل کن.",
                account_already_connected: "این اکانت اینستاگرام قبلاً به کاربر دیگری در این نمونه متصل شده است.",
                state_mismatch: "اتصال منقضی شد. دوباره تلاش کن.",
                setup_required: "اول اطلاعات اپ متا را در ویزارد راه‌اندازی ذخیره کن.",
                server_error: "مشکلی پیش آمد. جزئیات را بررسی کن و دوباره تلاش کن.",
                invalid_callback: "کال‌بک نامعتبر است. دوباره تلاش کن.",
                test_user_required: "برای استفاده از ابزار، این اکانت اینستاگرام را به‌عنوان تستر اضافه کن. در اپ متا به App Roles > Roles > Add People > Instagram Tester برو، سپس دعوت را در اینستاگرام بپذیر (Settings > Apps and websites > Tester invites) و دوباره متصل شو.",
            };
            const debugDetail = searchParams.get("debug");
            setBanner({
                type: "error",
                message: (errorMessages[igError] ?? `خطا: ${igError}`) + (debugDetail ? ` — ${debugDetail}` : ""),
            });
            window.history.replaceState({}, "", "/settings");
        }
    }, [searchParams, queryClient]);

    useEffect(() => {
        if (!banner) return;
        const timer = setTimeout(() => setBanner(null), 8000);
        return () => clearTimeout(timer);
    }, [banner]);

    const handleConnectInstagram = async () => {
        setConnectingIG(true);
        try {
            const { url } = await apiClient<{ url: string }>("/instagram/connect");
            window.location.href = url;
        } catch (err) {
            const message = err instanceof ApiError ? err.message : "شروع اتصال ممکن نشد";
            setBanner({ type: "error", message });
            setConnectingIG(false);
        }
    };

    const handleDisconnect = async (accountId: string) => {
        if (!confirm("این اکانت اینستاگرام قطع شود؟ تمام خودکارسازهای متصل به آن حذف خواهند شد.")) return;
        setDisconnectingId(accountId);
        try {
            await apiClient(`/instagram/disconnect/${accountId}`, { method: "DELETE" });
            void queryClient.invalidateQueries({ queryKey: ["instagram-accounts"] });
            setBanner({ type: "success", message: "اکانت اینستاگرام قطع شد." });
        } catch (err) {
            const message = err instanceof ApiError ? err.message : "قطع اتصال اکانت ممکن نشد";
            setBanner({ type: "error", message });
        } finally {
            setDisconnectingId(null);
        }
    };

    const handleCheckSubscription = async (accountId: string) => {
        setCheckingSubId(accountId);
        try {
            const result = await checkSubscriptionMutation.mutateAsync(accountId);
            setSubStatus(prev => ({ ...prev, [accountId]: result }));
        } catch {
            setSubStatus(prev => ({ ...prev, [accountId]: null }));
        } finally {
            setCheckingSubId(null);
        }
    };

    const handleResubscribe = async (accountId: string) => {
        setResubscribingId(accountId);
        try {
            const result = await resubscribeMutation.mutateAsync(accountId);
            setBanner({ type: "success", message: `اشتراک وبهوک تازه‌سازی شد (${result.subscribedFields}). برای تست، زیر یکی از پست‌هایت کامنت بگذار.` });
            void handleCheckSubscription(accountId);
        } catch (err) {
            const message = err instanceof ApiError ? err.message : "تازه‌سازی اشتراک وبهوک ممکن نشد";
            setBanner({ type: "error", message });
        } finally {
            setResubscribingId(null);
        }
    };

    const handleRefreshToken = async (accountId: string) => {
        setRefreshingId(accountId);
        try {
            await refreshMutation.mutateAsync(accountId);
            setBanner({ type: "success", message: "توکن تازه‌سازی شد — ۶۰ روز دیگر معتبر است." });
        } catch (err) {
            const apiErr = err instanceof ApiError ? err : null;
            if (apiErr?.status === 400) {
                setBanner({ type: "error", message: "توکن منقضی شده است. اکانت اینستاگرامت را دوباره متصل کن." });
            } else {
                setBanner({ type: "error", message: "تازه‌سازی توکن ممکن نشد. دوباره تلاش کن." });
            }
        } finally {
            setRefreshingId(null);
        }
    };

    const handleSignOut = async () => {
        const supabase = createBrowserClient();
        await supabase.auth.signOut();
        window.location.href = "/";
    };

    return (
        <div className="w-full max-w-3xl mx-auto space-y-5 pb-16">
            <div>
                <h1 className="text-xl font-heading font-semibold tracking-tight text-foreground">تنظیمات</h1>
                <p className="text-[13px] text-muted-foreground mt-1">اکانت‌های متصل و این نمونه.</p>
            </div>

            {banner && (
                <div className={cn(
                    "flex items-center gap-2.5 px-3.5 py-2.5 rounded-lg text-[13px] font-medium",
                    banner.type === "success"
                        ? "bg-secondary/10 text-secondary"
                        : "bg-destructive/10 text-destructive"
                )}>
                    {banner.type === "success"
                        ? <CheckCircle2 className="w-4 h-4 shrink-0" />
                        : <XCircle className="w-4 h-4 shrink-0" />}
                    <span className="min-w-0">{banner.message}</span>
                </div>
            )}

            {/* Meta app */}
            <section className="bg-card border border-border rounded-xl p-5 flex items-center justify-between gap-4">
                <div className="min-w-0">
                    <h2 className="text-[14px] font-heading font-semibold text-foreground">اپ متا</h2>
                    <p className="text-[13px] text-muted-foreground mt-0.5 truncate">
                        {setup?.configured
                            ? <>پیکربندی شده — اپ <code className="font-mono text-[11px] bg-muted px-1.5 py-0.5 rounded" dir="ltr">{setup.metaAppId}</code></>
                            : "پیکربندی نشده — تا تکمیل راه‌اندازی، موتور خاموش است."}
                    </p>
                </div>
                <Link
                    href="/setup"
                    className={cn(
                        "inline-flex items-center gap-1.5 h-8 px-3 rounded-lg text-[13px] font-medium transition-colors shrink-0 focus:outline-none focus-visible:ring-2 focus-visible:ring-ring/40",
                        setup?.configured
                            ? "border border-border hover:bg-muted text-foreground"
                            : "bg-foreground text-background font-semibold hover:opacity-90"
                    )}
                >
                    <Wrench className="w-3.5 h-3.5" />
                    {setup?.configured ? "ویزارد راه‌اندازی" : "تکمیل راه‌اندازی"}
                </Link>
            </section>

            {/* Instagram accounts */}
            <section className="bg-card border border-border rounded-xl p-5 space-y-4">
                <div className="flex items-center justify-between gap-4">
                    <div>
                        <h2 className="text-[14px] font-heading font-semibold text-foreground">اکانت‌های اینستاگرام</h2>
                        <p className="text-[13px] text-muted-foreground mt-0.5">
                            فقط اکانت‌های بیزینس یا کریتور.
                        </p>
                    </div>
                    <button
                        onClick={handleConnectInstagram}
                        disabled={connectingIG}
                        className="inline-flex items-center gap-1.5 h-8 px-3 rounded-lg bg-foreground text-background text-[13px] font-semibold hover:opacity-90 disabled:opacity-60 transition-opacity shrink-0 focus:outline-none focus-visible:ring-2 focus-visible:ring-ring/40"
                    >
                        {connectingIG ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Instagram className="w-3.5 h-3.5" />}
                        {connectingIG ? "در حال اتصال…" : "اتصال"}
                    </button>
                </div>

                <div className="space-y-2">
                    {isLoading ? (
                        <div className="space-y-2">
                            {[1, 2].map((i) => (
                                <div key={i} className="h-16 rounded-lg bg-muted/50 animate-pulse" />
                            ))}
                        </div>
                    ) : accounts && accounts.length > 0 ? (
                        accounts.map((account) => (
                            <div key={account.id} className="space-y-2">
                                {account.is_paused && (
                                    <div className="flex items-start gap-2 px-3 py-2.5 rounded-lg text-[12px] font-medium bg-destructive/10 text-destructive">
                                        <PauseCircle className="w-3.5 h-3.5 shrink-0 mt-0.5" />
                                        <span>
                                            <b>توقف ایمنی</b> — اینستاگرام ارسال‌ها را فلگ کرده، پس دایرکت‌ها تا
                                            {" "}{account.paused_until ? faDateTime(account.paused_until) : "بعدتر"}{" "}
                                            برای حفاظت از این اکانت متوقف شده‌اند.
                                        </span>
                                    </div>
                                )}

                                {account.token_status !== "ok" && (
                                    <div className={cn(
                                        "flex items-center justify-between gap-3 px-3 py-2.5 rounded-lg text-[12px] font-medium",
                                        account.token_status === "expired"
                                            ? "bg-destructive/10 text-destructive"
                                            : "bg-amber-500/10 text-amber-600 dark:text-amber-400"
                                    )}>
                                        <div className="flex items-center gap-2 min-w-0">
                                            <AlertTriangle className="w-3.5 h-3.5 shrink-0" />
                                            <span className="truncate">
                                                {account.token_status === "expired"
                                                    ? "توکن منقضی شده — خودکارسازها متوقف‌اند. برای ادامه دوباره متصل شو."
                                                    : `توکن در ${faNum(account.token_days_remaining ?? 0)} روز منقضی می‌شود — کرون خودکار تازه‌سازی می‌کند، یا همین حالا تازه کن.`}
                                            </span>
                                        </div>
                                        {account.token_status === "expiring" ? (
                                            <button
                                                onClick={() => handleRefreshToken(account.id)}
                                                disabled={refreshingId === account.id}
                                                className="inline-flex items-center gap-1 font-semibold shrink-0 hover:opacity-80"
                                            >
                                                {refreshingId === account.id ? <Loader2 className="w-3 h-3 animate-spin" /> : <RefreshCw className="w-3 h-3" />}
                                                تازه‌سازی
                                            </button>
                                        ) : (
                                            <button
                                                onClick={handleConnectInstagram}
                                                disabled={connectingIG}
                                                className="inline-flex items-center gap-1 font-semibold shrink-0 hover:opacity-80"
                                            >
                                                اتصال مجدد
                                            </button>
                                        )}
                                    </div>
                                )}

                                <div className="flex items-center justify-between p-3 rounded-lg border border-border">
                                    <div className="flex items-center gap-3 min-w-0">
                                        <div className="relative w-9 h-9 rounded-full ig-ring p-[1.5px] shrink-0">
                                            <div className="w-full h-full rounded-full bg-background overflow-hidden flex items-center justify-center">
                                                {account.profile_picture_url ? (
                                                    <img src={account.profile_picture_url} alt={account.username} className="w-full h-full object-cover" />
                                                ) : (
                                                    <Instagram className="w-4 h-4 text-muted-foreground" />
                                                )}
                                            </div>
                                        </div>
                                        <div className="min-w-0">
                                            <div className="flex items-center gap-1.5">
                                                <span className="text-[13px] font-semibold text-foreground truncate" dir="ltr">@{account.username}</span>
                                                {account.token_status === "ok" && !account.is_paused
                                                    ? <CheckCircle2 className="w-3.5 h-3.5 text-secondary shrink-0" />
                                                    : <AlertTriangle className={cn("w-3.5 h-3.5 shrink-0", account.token_status === "expired" ? "text-destructive" : "text-amber-500")} />}
                                            </div>
                                            <span className="text-[11px] text-muted-foreground">
                                                متصل در {faDate(account.created_at, { month: "long", day: "numeric", year: "numeric" })}
                                            </span>
                                        </div>
                                    </div>

                                    <div className="flex items-center gap-0.5 shrink-0">
                                        <button
                                            onClick={() => handleCheckSubscription(account.id)}
                                            disabled={checkingSubId === account.id}
                                            title="بررسی اینکه متا برای این اکانت چه فیلدهای وبهوکی را فعال دارد"
                                            className="inline-flex items-center gap-1 h-7 px-2 text-[12px] font-medium text-muted-foreground hover:text-foreground hover:bg-muted rounded-md transition-colors"
                                        >
                                            {checkingSubId === account.id ? <Loader2 className="w-3 h-3 animate-spin" /> : null}
                                            {checkingSubId === account.id ? "در حال بررسی…" : "بررسی وضعیت"}
                                        </button>
                                        <button
                                            onClick={() => handleResubscribe(account.id)}
                                            disabled={resubscribingId === account.id}
                                            title="همگام‌سازی مجدد اشتراک وبهوک"
                                            className="inline-flex items-center gap-1 h-7 px-2 text-[12px] font-medium text-muted-foreground hover:text-foreground hover:bg-muted rounded-md transition-colors"
                                        >
                                            {resubscribingId === account.id ? <Loader2 className="w-3 h-3 animate-spin" /> : <RefreshCw className="w-3 h-3" />}
                                            {resubscribingId === account.id ? "در حال همگام‌سازی…" : "تعمیر وبهوک"}
                                        </button>
                                        <button
                                            onClick={() => handleDisconnect(account.id)}
                                            disabled={disconnectingId === account.id}
                                            className="inline-flex items-center gap-1 h-7 px-2 text-[12px] font-medium text-muted-foreground hover:text-destructive hover:bg-destructive/10 rounded-md transition-colors"
                                        >
                                            {disconnectingId === account.id ? <Loader2 className="w-3 h-3 animate-spin" /> : <Unlink className="w-3 h-3" />}
                                            قطع اتصال
                                        </button>
                                    </div>
                                </div>

                                {subStatus[account.id] !== undefined && (
                                    <div className={cn(
                                        "px-3 py-2.5 rounded-lg text-[12px] font-mono",
                                        subStatus[account.id] === null
                                            ? "bg-destructive/10 text-destructive"
                                            : subStatus[account.id]?.hasComments
                                            ? "bg-secondary/10 text-secondary"
                                            : "bg-amber-500/10 text-amber-600 dark:text-amber-400"
                                    )}>
                                        {subStatus[account.id] === null ? (
                                            <span>دریافت وضعیت اشتراک از متا ممکن نشد.</span>
                                        ) : (
                                            <div className="space-y-1">
                                                <div className="flex items-center gap-3">
                                                    <span className="font-bold">{subStatus[account.id]?.hasComments ? "✓ کامنت‌ها" : "✗ کامنت‌ها"}</span>
                                                    <span className="font-bold">{subStatus[account.id]?.hasMessages ? "✓ پیام‌ها" : "✗ پیام‌ها"}</span>
                                                </div>
                                                <div className="text-muted-foreground text-[10px]" dir="ltr">
                                                    {subStatus[account.id]?.subscribedFields.join(", ") || "none"}
                                                </div>
                                                {!subStatus[account.id]?.hasComments && (
                                                    <div className="text-[10px]">
                                                        کامنت‌ها مشترک نشده‌اند — از «تعمیر وبهوک» استفاده کن و مطمئن شو Callback URL در پنل متا تأیید شده است.
                                                    </div>
                                                )}
                                            </div>
                                        )}
                                    </div>
                                )}
                            </div>
                        ))
                    ) : (
                        <div className="text-center py-8 text-[13px] text-muted-foreground">
                            <Instagram className="w-6 h-6 mx-auto mb-2 opacity-30" />
                            <p>هنوز اکانتی متصل نشده است.</p>
                        </div>
                    )}
                </div>
            </section>

            {/* Account */}
            <section className="bg-card border border-border rounded-xl p-5 flex items-center justify-between">
                <h2 className="text-[14px] font-heading font-semibold text-foreground">نشست</h2>
                <button
                    onClick={handleSignOut}
                    className="h-8 px-3 rounded-lg text-[13px] font-medium text-muted-foreground border border-border hover:text-destructive hover:border-destructive/40 transition-colors"
                >
                    خروج از حساب
                </button>
            </section>
        </div>
    );
}
