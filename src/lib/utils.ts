import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
    return twMerge(clsx(inputs))
}

/* ─── Persian (fa-IR) formatting helpers ───
 * Numbers → Persian digits with fa-IR grouping.
 * Dates   → Jalali calendar via Intl (no extra deps). */

const FA_DIGITS = "۰۱۲۳۴۵۶۷۸۹";

/** Format a number with Persian digits + separators: 12500 → ۱۲٬۵۰۰ */
export function faNum(n: number | string | null | undefined): string {
    if (n === null || n === undefined) return "";
    if (typeof n === "number") return n.toLocaleString("fa-IR");
    return String(n).replace(/[0-9]/g, (d) => FA_DIGITS[Number(d)]!);
}

/** Jalali date: faDate("2026-08-01") → ۱۰ مرداد ۱۴۰۵ */
export function faDate(iso: string | Date, opts?: Intl.DateTimeFormatOptions): string {
    const d = typeof iso === "string" ? new Date(iso) : iso;
    if (isNaN(d.getTime())) return "";
    return d.toLocaleDateString("fa-IR", opts);
}

/** Jalali date + time: used for pause banners etc. */
export function faDateTime(iso: string | Date): string {
    const d = typeof iso === "string" ? new Date(iso) : iso;
    if (isNaN(d.getTime())) return "";
    return d.toLocaleString("fa-IR");
}

/** Time only (fa-IR, 24h): for the debug log stream. */
export function faTime(iso: string | Date): string {
    const d = typeof iso === "string" ? new Date(iso) : iso;
    if (isNaN(d.getTime())) return "";
    return d.toLocaleTimeString("fa-IR", { hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false });
}
