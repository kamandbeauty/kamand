"use client";

/**
 * Setup Wizard - from fresh deployment to verified Meta webhook, five steps:
 *  1. Create a Meta app
 *  2. Save Instagram app credentials (stored encrypted)
 *  3. Wire the Meta portal (webhook + login redirect)
 *  4. Enable the background engine (one SQL snippet)
 *  5. Understand who can trigger it (testers, going public)
 */

import { useState } from "react";
import { motion } from "framer-motion";
import {
    Wrench, KeyRound, Webhook, Clock3, CheckCircle2, Copy, Check,
    ExternalLink, Loader2, ShieldCheck, AlertTriangle, Users
} from "lucide-react";
import { useSetupStatus, useSaveSetup } from "@/hooks/useSetup";
import { cn, faNum } from "@/lib/utils";

function CopyField({ label, value }: { label: string; value: string }) {
    const [copied, setCopied] = useState(false);
    const copy = () => {
        void navigator.clipboard.writeText(value);
        setCopied(true);
        setTimeout(() => setCopied(false), 1500);
    };
    return (
        <div>
            <label className="micro-label block mb-1">{label}</label>
            <div className="flex items-center gap-1.5">
                <code className="flex-1 text-[12px] font-mono bg-muted/60 border border-border rounded-lg px-3 py-2 break-all select-all text-left" dir="ltr">
                    {value}
                </code>
                <button
                    onClick={copy}
                    className="w-8 h-8 flex items-center justify-center rounded-lg border border-border hover:bg-muted text-muted-foreground hover:text-foreground transition-colors shrink-0"
                    title="کپی"
                >
                    {copied ? <Check className="w-3.5 h-3.5 text-secondary" /> : <Copy className="w-3.5 h-3.5" />}
                </button>
            </div>
        </div>
    );
}

function NumberedList({ items }: { items: React.ReactNode[] }) {
    return (
        <ol className="space-y-2 list-none">
            {items.map((content, i) => (
                <li key={i} className="flex gap-2.5 text-[13px] text-foreground/90 leading-relaxed">
                    <span className="min-w-[18px] h-[18px] rounded-full bg-muted text-muted-foreground text-[10px] font-semibold flex items-center justify-center shrink-0 mt-0.5">{faNum(i + 1)}</span>
                    <span>{content}</span>
                </li>
            ))}
        </ol>
    );
}

function StepCard({
    step, title, icon: Icon, done, children,
}: {
    step: number;
    title: string;
    icon: React.ComponentType<{ className?: string }>;
    done?: boolean;
    children: React.ReactNode;
}) {
    return (
        <motion.section
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: step * 0.05 }}
            className="bg-card border border-border rounded-xl overflow-hidden"
        >
            <div className="flex items-center gap-3 px-5 h-12 border-b border-border">
                <div className={cn(
                    "w-7 h-7 rounded-lg flex items-center justify-center shrink-0",
                    done ? "bg-secondary/10" : "bg-muted"
                )}>
                    {done ? <CheckCircle2 className="w-4 h-4 text-secondary" /> : <Icon className="w-4 h-4 text-muted-foreground" />}
                </div>
                <span className="micro-label">مرحله {faNum(step)}</span>
                <h2 className="text-[13.5px] font-heading font-semibold text-foreground">{title}</h2>
            </div>
            <div className="p-5">{children}</div>
        </motion.section>
    );
}

const inputCls = "w-full h-9 text-[13px] font-mono bg-background border border-border rounded-lg px-3 outline-none focus:border-foreground/30 focus-visible:ring-2 focus-visible:ring-ring/30 transition-colors text-left";

export default function SetupPage() {
    const { data: setup, isLoading } = useSetupStatus();
    const saveMutation = useSaveSetup();

    const [appId, setAppId] = useState("");
    const [appSecret, setAppSecret] = useState("");
    const [fbAppSecret, setFbAppSecret] = useState("");
    const [saveError, setSaveError] = useState<string | null>(null);
    const [justSaved, setJustSaved] = useState(false);

    const handleSave = () => {
        setSaveError(null);
        saveMutation.mutate(
            {
                metaAppId: appId.trim(),
                metaAppSecret: appSecret.trim(),
                ...(fbAppSecret.trim() ? { metaFbAppSecret: fbAppSecret.trim() } : {}),
            },
            {
                onSuccess: () => { setJustSaved(true); setAppSecret(""); setFbAppSecret(""); },
                onError: (err) => setSaveError(err.message),
            }
        );
    };

    if (isLoading) {
        return (
            <div className="w-full max-w-2xl mx-auto py-24 flex justify-center">
                <Loader2 className="w-5 h-5 animate-spin text-muted-foreground" />
            </div>
        );
    }

    const configured = !!setup?.configured;

    return (
        <div className="w-full max-w-2xl mx-auto space-y-4 pb-16">
            <div className="flex items-start justify-between gap-4">
                <div>
                    <h1 className="text-xl font-heading font-semibold tracking-tight text-foreground flex items-center gap-2">
                        <Wrench className="w-[18px] h-[18px] text-muted-foreground" />
                        ویزارد راه‌اندازی
                    </h1>
                    <p className="text-[13px] text-muted-foreground mt-1 max-w-md">
                        اپ توسعه‌دهنده متای خودت را وصل کن. هر چیزی که وارد می‌کنی،
                        رمزنگاری‌شده در دیتابیس ساپابیس خودت ذخیره می‌شود.
                    </p>
                </div>
                {configured && (
                    <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-secondary bg-secondary/10 px-2.5 py-1 rounded-full shrink-0 mt-1">
                        <ShieldCheck className="w-3 h-3" /> پیکربندی‌شده
                    </span>
                )}
            </div>

            {/* Step 1 */}
            <StepCard step={1} title="اپ متای خودت را بساز" icon={ExternalLink} done={configured}>
                <NumberedList items={[
                    <>به <a href="https://developers.facebook.com/apps" target="_blank" rel="noopener noreferrer" className="text-primary font-medium underline underline-offset-2" dir="ltr">developers.facebook.com/apps</a> برو و روی <b>Create App</b> بزن.</>,
                    <>مورد استفاده (Use case) را <b>Other</b> انتخاب کن → نوع اپ <b>Business</b>.</>,
                    <>در داشبورد اپ: <b>Instagram → Set up</b> (گزینه «Instagram API with Instagram Login» اضافه می‌شود).</>,
                    <>به <b>Instagram → API setup with Instagram login → 3. Set up Instagram business login</b> برو و <b>Instagram app ID</b> و <b>Instagram app secret</b> نمایش‌داده‌شده را کپی کن. نه جفتِ زیر App settings → Basic — آن‌ها متعلق به اپ مادرِ متا هستند و لاگین اینستاگرام آن‌ها را با خطای «Invalid platform app» رد می‌کند.</>,
                    <>اینستاگرامت باید اکانت <b>بیزینس یا کریتور</b> باشد (داخل اپ اینستاگرام: Settings → Account type).</>,
                ]} />
                <div className="mt-4 flex items-start gap-2 text-[12px] text-muted-foreground bg-muted/50 rounded-lg px-3 py-2.5">
                    <AlertTriangle className="w-3.5 h-3.5 shrink-0 mt-0.5 text-amber-500" />
                    <span>
                        اپت در <b>حالت Development</b> شروع می‌شود — برای ساخت و تست ایده‌آل است. در این حالت، خودکارسازها
                        برای اکانت‌هایی کار می‌کنند که <b>نقش در اپ تو</b> دارند (خودت + تسترها — مرحله ۵ را ببین). برای اینکه
                        عموم مردم بتوانند فعالشان کنند، بعد از تست، <b>App Review</b> رایگان متا را یک بار ارسال کن.
                    </span>
                </div>
            </StepCard>

            {/* Step 2 */}
            <StepCard step={2} title="اطلاعات اپ را ذخیره کن" icon={KeyRound} done={configured && !justSaved}>
                {configured && (
                    <div className="mb-4 flex items-center gap-2 text-[12px] font-medium text-secondary bg-secondary/10 rounded-lg px-3 py-2.5">
                        <CheckCircle2 className="w-3.5 h-3.5 shrink-0" />
                        <span>برای اپ <code className="font-mono font-semibold" dir="ltr">{setup?.metaAppId}</code> ذخیره شده. فقط برای تغییر، دوباره وارد کن.</span>
                    </div>
                )}
                <div className="space-y-3">
                    <div>
                        <label className="micro-label block mb-1">Instagram app ID</label>
                        <input
                            value={appId}
                            onChange={(e) => setAppId(e.target.value)}
                            placeholder={setup?.metaAppId ?? "مثلاً 1234567890123456"}
                            dir="ltr"
                            className={inputCls}
                        />
                    </div>
                    <div>
                        <label className="micro-label block mb-1">Instagram app secret</label>
                        <input
                            type="password"
                            value={appSecret}
                            onChange={(e) => setAppSecret(e.target.value)}
                            placeholder="کلید ۳۲ کاراکتری هگز"
                            dir="ltr"
                            className={inputCls}
                        />
                        <p className="text-[11px] text-muted-foreground mt-1">
                            قبل از رسیدن به دیتابیس رمزنگاری می‌شود. هرگز لاگ نمی‌شود و دوباره نمایش داده نمی‌شود.
                        </p>
                    </div>
                    <div>
                        <label className="micro-label block mb-1">Facebook app secret <span className="normal-case font-normal opacity-70">(اختیاری)</span></label>
                        <input
                            type="password"
                            value={fbAppSecret}
                            onChange={(e) => setFbAppSecret(e.target.value)}
                            placeholder="فقط اگر بررسی امضای وبهوک شکست می‌خورد"
                            dir="ltr"
                            className={inputCls}
                        />
                        <p className="text-[11px] text-muted-foreground mt-1">
                            متا بسته به نوع اپ، وبهوک‌ها را با یکی از این دو کلید امضا می‌کند. اگر پنل دیباگ روی رویدادهای واقعی
                            «signature mismatch» نشان می‌دهد، App Secret را از App settings → Basic اینجا بچسبان.
                        </p>
                    </div>
                    {saveError && <p className="text-[12px] text-destructive font-medium">{saveError}</p>}
                    {justSaved && <p className="text-[12px] text-secondary font-medium">ذخیره شد. با مرحله ۳ ادامه بده.</p>}
                    <button
                        onClick={handleSave}
                        disabled={saveMutation.isPending || !appId.trim() || !appSecret.trim()}
                        className="inline-flex items-center gap-1.5 h-9 px-4 rounded-lg bg-foreground text-background text-[13px] font-semibold hover:opacity-90 disabled:opacity-50 transition-opacity focus:outline-none focus-visible:ring-2 focus-visible:ring-ring/40"
                    >
                        {saveMutation.isPending ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <KeyRound className="w-3.5 h-3.5" />}
                        {saveMutation.isPending ? "در حال ذخیره…" : "ذخیره اطلاعات"}
                    </button>
                </div>
            </StepCard>

            {/* Step 3 */}
            <StepCard step={3} title="پنل متا را وصل کن" icon={Webhook}>
                {!configured && !justSaved ? (
                    <p className="text-[13px] text-muted-foreground">اول مرحله ۲ را کامل کن — توکن تأیید وبهوک هنگام ذخیره اطلاعات ساخته می‌شود.</p>
                ) : (
                    <div className="space-y-5">
                        <div>
                            <p className="text-[13px] font-medium text-foreground mb-2.5">
                                الف. وبهوک‌ها — <span className="text-muted-foreground font-normal" dir="ltr">Instagram → API setup with Instagram login → 2. Configure webhooks</span>
                            </p>
                            <div className="space-y-2.5">
                                <CopyField label="Callback URL" value={setup?.webhookUrl ?? ""} />
                                <CopyField label="توکن تأیید (Verify token)" value={setup?.webhookVerifyToken ?? ""} />
                            </div>
                            <p className="text-[11px] text-muted-foreground mt-2">
                                روی <b>Verify and save</b> بزن، سپس در <b>comments</b> و <b>messages</b> مشترک شو.
                            </p>
                        </div>
                        <div className="h-px bg-border" />
                        <div>
                            <p className="text-[13px] font-medium text-foreground mb-2.5">
                                ب. ورود بیزینسی — <span className="text-muted-foreground font-normal" dir="ltr">3. Set up Instagram business login → Business login settings</span>
                            </p>
                            <CopyField label="آدرس ریدایرکت OAuth" value={setup?.oauthRedirectUri ?? ""} />
                            <p className="text-[11px] text-muted-foreground mt-2">
                                باید کاراکتر‌به‌کاراکتر یکسان باشد.
                            </p>
                        </div>
                    </div>
                )}
            </StepCard>

            {/* Step 4 */}
            <StepCard step={4} title="موتور پس‌زمینه را فعال کن" icon={Clock3}>
                <p className="text-[13px] text-muted-foreground mb-3 leading-relaxed">
                    بیشتر دایرکت‌ها بلافاصله از طریق وبهوک ارسال می‌شوند. این کرون بقیه را تحویل می‌دهد — سرریزهای
                    محدودیت نرخ، تلاش‌های مجدد و تازه‌سازی خودکار توکن. در <b>ساپابیس ← SQL Editor</b>، به‌جای{" "}
                    <code className="font-mono text-[11px] bg-muted px-1 rounded" dir="ltr">YOUR_CRON_SECRET</code> مقدار
                    CRON_SECRET دیپلویت را بگذار و اجرا کن:
                </p>
                <div className="relative">
                    <pre className="text-[11px] font-mono bg-zinc-950 text-zinc-300 rounded-lg p-3.5 overflow-x-auto whitespace-pre border border-border text-left" dir="ltr">
                        {setup?.cronSnippet ?? ""}
                    </pre>
                    <button
                        onClick={() => void navigator.clipboard.writeText(setup?.cronSnippet ?? "")}
                        className="absolute top-2 end-2 w-7 h-7 flex items-center justify-center rounded-md bg-zinc-800 hover:bg-zinc-700 text-zinc-400 transition-colors"
                        title="کپی SQL"
                    >
                        <Copy className="w-3 h-3" />
                    </button>
                </div>
                <p className="text-[11px] text-muted-foreground mt-2">
                    با <code className="font-mono bg-muted px-1 rounded" dir="ltr">select * from cron.job;</code> بررسی کن — باید <code className="font-mono bg-muted px-1 rounded" dir="ltr">open-autodm-process-jobs</code> را ببینی.
                </p>
            </StepCard>

            {/* Step 5 */}
            <StepCard step={5} title="چه کسی می‌تواند فعالش کند" icon={Users}>
                <div className="space-y-4 text-[13px] text-foreground/90 leading-relaxed">
                    <p>
                        در <b>حالت Development</b>، اینستاگرام فقط برای اکانت‌هایی رویداد می‌فرستد که در اپ تو نقش دارند —
                        و <b>از هر دو طرف</b>: هم اکانتی که وصل می‌کنی و هم اکانت‌های مخاطبی که کامنت/دایرکت/پاسخ استوری‌شان
                        خودکارساز را فعال می‌کند. کامنت یک غریبه اصلاً وبهوکی تولید نمی‌کند.
                    </p>
                    <div>
                        <p className="font-medium text-foreground mb-2">افزودن اکانت تستر:</p>
                        <NumberedList items={[
                            <>پنل متا ← اپ تو ← <b>App roles → Roles → Add people</b>.</>,
                            <>نقش <b>Instagram Tester</b> ← یوزرنیم اینستاگرامش ← دعوت را بفرست.</>,
                            <>او دعوت را <b>داخل خود اپ اینستاگرام</b> می‌پذیرد: Settings → Website permissions / Apps and websites → <b>Tester invites → Accept</b>. تا آن موقع رویدادهایش برای وبهوکت نامرئی است.</>,
                        ]} />
                    </div>
                    <div className="flex items-start gap-2 text-[12px] text-muted-foreground bg-muted/50 rounded-lg px-3 py-2.5">
                        <AlertTriangle className="w-3.5 h-3.5 shrink-0 mt-0.5 text-amber-500" />
                        <span>
                            <b>عمومی‌کردن:</b> برای اینکه روی کامنت هر کسی فعال شود، از طریق <b>App Review</b> رایگان متا درخواست
                            Advanced Access بده — یک ویدیوی کوتاه از جریان کارکردی‌ات را آپلود کن. معمولاً در چند روز تأیید می‌شود؛ بعد از آن چیزی در این اپ تغییر نمی‌کند.
                        </span>
                    </div>
                </div>
            </StepCard>

            {configured && (
                <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="rounded-xl border border-secondary/25 bg-secondary/5 p-4 flex items-start gap-3"
                >
                    <CheckCircle2 className="w-[18px] h-[18px] text-secondary shrink-0 mt-0.5" />
                    <div>
                        <p className="text-[13px] font-semibold text-foreground">راه‌اندازی کامل شد — بعدی، اتصال اینستاگرام</p>
                        <p className="text-[13px] text-muted-foreground mt-0.5">
                            به <a href="/settings" className="text-primary font-medium underline underline-offset-2">تنظیمات</a> برو و
                            روی <b>اتصال</b> بزن — با همان اکانت اینستاگرامی که مالک اپ متای توست (یا تستر آن است).
                        </p>
                    </div>
                </motion.div>
            )}
        </div>
    );
}
