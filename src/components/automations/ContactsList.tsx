"use client";

import { useMemo, useState } from "react";
import { motion } from "framer-motion";
import { Search, Users, MessageCircle, Send, Image as ImageIcon, MousePointerClick, RefreshCw, Download, Loader2 } from "lucide-react";
import { cn, faNum, faDate } from "@/lib/utils";
import { useContactsInfinite, type ContactFromDB } from "@/hooks/useContacts";
import { useActiveAccount } from "@/hooks/useActiveAccount";
import { createBrowserClient } from "@/lib/supabase";

/**
 * Contacts - every unique audience member captured through an automation:
 * they commented a trigger keyword, DM'd one, story-replied one, or tapped a
 * flow button. Enriched with username + follow status from Instagram's
 * profile API as the engine interacts with them.
 */

const TRIGGER_CONFIG: Record<string, { label: string; icon: React.ComponentType<{ className?: string }>; className: string }> = {
    comment: { label: "کامنت", icon: MessageCircle, className: "bg-[#F97316]/10 text-[#F97316] border-[#F97316]/20" },
    dm: { label: "کلیدواژه دایرکت", icon: Send, className: "bg-blue-500/10 text-blue-500 border-blue-500/20" },
    story_reply: { label: "پاسخ استوری", icon: ImageIcon, className: "bg-green-500/10 text-green-500 border-green-500/20" },
    button: { label: "لمس دکمه", icon: MousePointerClick, className: "bg-purple-500/10 text-purple-400 border-purple-500/20" },
};

const AVATAR_GRADIENTS = [
    "from-pink-500 to-orange-400",
    "from-violet-500 to-indigo-400",
    "from-emerald-500 to-teal-400",
    "from-amber-500 to-red-400",
    "from-sky-500 to-blue-500",
];

function avatarGradient(seed: string): string {
    let hash = 0;
    for (let i = 0; i < seed.length; i++) hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
    return AVATAR_GRADIENTS[hash % AVATAR_GRADIENTS.length]!;
}

function relationshipBadge(contact: ContactFromDB) {
    if (contact.follows_business === true) {
        return <span className="inline-flex items-center px-2.5 py-1 rounded-md text-[10px] font-bold border bg-green-500/10 text-green-500 border-green-500/20">فالو کرده</span>;
    }
    if (contact.follows_business === false) {
        return <span className="inline-flex items-center px-2.5 py-1 rounded-md text-[10px] font-bold border bg-amber-500/10 text-amber-500 border-amber-500/20">فالو نکرده</span>;
    }
    return <span className="inline-flex items-center px-2.5 py-1 rounded-md text-[10px] font-bold border bg-muted/40 text-muted-foreground border-border/50">نامشخص</span>;
}

function formatDate(iso: string): string {
    return faDate(iso, { month: "long", day: "numeric", year: "numeric" });
}

export function ContactsList() {
    const { accountId } = useActiveAccount();
    const { data, isLoading, refetch, isFetching, fetchNextPage, hasNextPage, isFetchingNextPage } = useContactsInfinite(accountId);
    const [search, setSearch] = useState("");
    const [exporting, setExporting] = useState(false);
    const [exportError, setExportError] = useState<string | null>(null);

    const allContacts = useMemo(
        () => data?.pages.flatMap((p) => p.contacts) ?? [],
        [data]
    );
    const total = data?.pages[0]?.total ?? 0;

    const filtered = useMemo(() => {
        const q = search.trim().toLowerCase();
        if (!q) return allContacts;
        return allContacts.filter((c) =>
            (c.username ?? "").toLowerCase().includes(q) ||
            c.audience_ig_user_id.includes(q) ||
            (c.automations?.name ?? "").toLowerCase().includes(q)
        );
    }, [allContacts, search]);

    const handleExport = async () => {
        setExporting(true);
        setExportError(null);
        try {
            // Raw fetch (not apiClient - the response is a CSV file, not JSON)
            const supabase = createBrowserClient();
            const { data: { session } } = await supabase.auth.getSession();
            const res = await fetch(
                `/api/contacts/export${accountId ? `?accountId=${encodeURIComponent(accountId)}` : ""}`,
                { headers: session?.access_token ? { Authorization: `Bearer ${session.access_token}` } : {} }
            );
            if (!res.ok) throw new Error("export failed");
            const blob = await res.blob();
            const url = URL.createObjectURL(blob);
            const a = document.createElement("a");
            a.href = url;
            a.download = `contacts-${new Date().toISOString().slice(0, 10)}.csv`;
            a.click();
            URL.revokeObjectURL(url);
        } catch {
            setExportError("خروجی گرفتن ممکن نشد. دوباره تلاش کن.");
        } finally {
            setExporting(false);
        }
    };

    if (isLoading) {
        return (
            <div className="flex flex-col space-y-4">
                {[1, 2, 3].map((i) => (
                    <div key={i} className="h-20 rounded-xl bg-muted/30 border border-border/40 animate-pulse" />
                ))}
            </div>
        );
    }

    if (total === 0) {
        return (
            <div className="flex flex-col items-center justify-center p-12 text-center border border-border border-dashed rounded-xl">
                <div className="w-16 h-16 rounded-xl bg-primary/10 flex items-center justify-center mb-6">
                    <Users className="w-8 h-8 text-primary" />
                </div>
                <h3 className="text-xl font-heading font-bold mb-2 text-foreground">هنوز مخاطبی نداری</h3>
                <p className="text-muted-foreground max-w-sm">
                    هر کسی که یکی از خودکارسازهایت را فعال کند — با کامنت، کلیدواژه دایرکت، پاسخ استوری
                    یا لمس دکمه — اینجا به‌صورت خودکار همراه با وضعیت فالوش ثبت می‌شود.
                </p>
            </div>
        );
    }

    return (
        <div className="flex flex-col space-y-4 w-full animate-in fade-in duration-500">
            {/* Toolbar */}
            <div className="flex flex-col sm:flex-row gap-4 items-center justify-between bg-card p-3 rounded-xl border border-border">
                <div className="relative w-full sm:max-w-xs">
                    <Search className="absolute start-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                    <input
                        type="text"
                        placeholder="جستجوی نام کاربری یا خودکارساز…"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        className="w-full bg-background border border-border/50 rounded-xl ps-9 pe-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                    />
                </div>
                <div className="flex items-center gap-3 w-full sm:w-auto justify-between sm:justify-end">
                    <span className="text-xs font-semibold text-muted-foreground">
                        {faNum(filtered.length)} از {faNum(total)} مخاطب
                    </span>
                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => void handleExport()}
                            disabled={exporting}
                            className="flex items-center justify-center gap-2 px-4 py-2 border border-border/50 rounded-xl bg-background hover:bg-muted/50 transition-colors text-sm font-medium disabled:opacity-60"
                            title="دانلود CSV (اکسل)"
                        >
                            {exporting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Download className="w-4 h-4" />}
                            <span>خروجی CSV</span>
                        </button>
                        <button
                            onClick={() => void refetch()}
                            className="flex items-center justify-center gap-2 px-4 py-2 border border-border/50 rounded-xl bg-background hover:bg-muted/50 transition-colors text-sm font-medium"
                        >
                            <RefreshCw className={cn("w-4 h-4", isFetching && "animate-spin")} />
                            <span>به‌روزرسانی</span>
                        </button>
                    </div>
                </div>
            </div>

            {exportError && (
                <div className="px-3.5 py-2.5 rounded-lg bg-destructive/10 text-[13px] text-destructive font-medium">
                    {exportError}
                </div>
            )}

            {/* Table */}
            <div className="w-full overflow-x-auto bg-card border border-border rounded-xl">
                <table className="w-full text-start text-sm whitespace-nowrap">
                    <thead className="bg-muted/30 text-muted-foreground text-[10px] font-bold border-b border-border/50">
                        <tr>
                            <th className="px-5 py-3">کاربر</th>
                            <th className="px-5 py-3">رابطه</th>
                            <th className="px-5 py-3">راه ثبت</th>
                            <th className="px-5 py-3">خودکارساز</th>
                            <th className="px-5 py-3">تعاملات</th>
                            <th className="px-5 py-3">آخرین فعالیت</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-border/30">
                        {filtered.map((contact, i) => {
                            const trigger = contact.last_trigger_type ? TRIGGER_CONFIG[contact.last_trigger_type] : null;
                            const TriggerIcon = trigger?.icon ?? MessageCircle;
                            const display = contact.username ? `@${contact.username}` : `کاربر IG ${contact.audience_ig_user_id.slice(-6)}`;
                            const initial = (contact.username ?? contact.audience_ig_user_id).charAt(0).toUpperCase();

                            return (
                                <motion.tr
                                    key={contact.id}
                                    initial={{ opacity: 0, y: 10 }}
                                    animate={{ opacity: 1, y: 0 }}
                                    transition={{ delay: Math.min(i * 0.04, 0.4) }}
                                    className="group hover:bg-muted/30 transition-colors"
                                >
                                    <td className="px-5 py-3">
                                        <div className="flex items-center gap-3">
                                            <div className={cn("w-8 h-8 rounded-full bg-gradient-to-tr flex items-center justify-center shrink-0", avatarGradient(contact.audience_ig_user_id))}>
                                                <span className="text-white font-bold text-[11px]">{initial}</span>
                                            </div>
                                            <div className="flex flex-col">
                                                <span className="font-bold text-foreground group-hover:text-primary transition-colors" dir="ltr">{display}</span>
                                                <span className="text-muted-foreground text-[10px] font-mono" dir="ltr">IGSID …{contact.audience_ig_user_id.slice(-8)}</span>
                                            </div>
                                        </div>
                                    </td>
                                    <td className="px-5 py-3">{relationshipBadge(contact)}</td>
                                    <td className="px-5 py-3">
                                        {trigger ? (
                                            <span className={cn("inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-[10px] font-bold border", trigger.className)}>
                                                <TriggerIcon className="w-3 h-3" />
                                                {trigger.label}
                                            </span>
                                        ) : (
                                            <span className="text-muted-foreground text-xs">-</span>
                                        )}
                                    </td>
                                    <td className="px-5 py-3 font-medium text-foreground/80 max-w-[220px] truncate">
                                        {contact.automations?.name ?? "-"}
                                    </td>
                                    <td className="px-5 py-3">
                                        <span className="font-bold font-heading">{faNum(contact.total_triggers)}</span>
                                    </td>
                                    <td className="px-5 py-3 text-muted-foreground">{formatDate(contact.last_interaction_at)}</td>
                                </motion.tr>
                            );
                        })}
                    </tbody>
                </table>
            </div>

            {/* Load more */}
            {(hasNextPage || isFetchingNextPage) && (
                <div className="flex justify-center">
                    <button
                        onClick={() => void fetchNextPage()}
                        disabled={isFetchingNextPage}
                        className="inline-flex items-center gap-2 h-9 px-5 text-[13px] font-medium border border-border hover:bg-muted rounded-lg transition-colors disabled:opacity-60"
                    >
                        {isFetchingNextPage ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : null}
                        {isFetchingNextPage ? "در حال بارگذاری…" : "نمایش بیشتر"}
                    </button>
                </div>
            )}
        </div>
    );
}
