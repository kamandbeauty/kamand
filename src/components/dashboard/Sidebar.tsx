"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
    Home,
    Bot,
    ChartNoAxesColumn,
    Settings,
    Wrench,
    Github,
    ChevronLeft,
    ChevronRight,
    X,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { motion, AnimatePresence } from "framer-motion";
import { useEffect, useState } from "react";
import { LogoMark, LogoWordmark } from "@/components/ui/Logo";
import { AccountSwitcher } from "@/components/dashboard/AccountSwitcher";
import { useUiStore } from "@/lib/store";

const NAV = {
    "فضای کار": [
        { name: "داشبورد", href: "/dashboard", icon: Home, external: false },
        { name: "خودکارسازها", href: "/automations", icon: Bot, external: false },
        { name: "تحلیل‌ها", href: "/analytics", icon: ChartNoAxesColumn, external: false },
    ],
    "سیستم": [
        { name: "ویزارد راه‌اندازی", href: "/setup", icon: Wrench, external: false },
        { name: "تنظیمات", href: "/settings", icon: Settings, external: false },
        { name: "گیت‌هاب", href: "https://github.com", icon: Github, external: true },
    ],
} as const;

/**
 * Shared nav groups. `threadId` must be unique per rendered instance -
 * desktop and mobile sidebars are both mounted (CSS-hidden), and a shared
 * framer-motion layoutId would make the active marker jump between them.
 */
function NavGroups({
    collapsed,
    threadId,
    onNavigate,
}: {
    collapsed: boolean;
    threadId: string;
    onNavigate?: () => void;
}) {
    const pathname = usePathname();

    return (
        <>
            {(Object.entries(NAV) as [string, typeof NAV["فضای کار"]][]).map(([group, items]) => (
                <div key={group} className="mb-5">
                    {!collapsed && (
                        <div className="micro-label px-4 mb-1.5 opacity-70">{group}</div>
                    )}
                    <nav className="px-2 space-y-px">
                        {items.map((item) => {
                            const isActive = !item.external && pathname.startsWith(item.href);
                            return (
                                <Link
                                    key={item.name}
                                    href={item.href}
                                    target={item.external ? "_blank" : undefined}
                                    rel={item.external ? "noopener noreferrer" : undefined}
                                    title={collapsed ? item.name : undefined}
                                    onClick={onNavigate}
                                    className={cn(
                                        "group relative flex items-center h-8 rounded-md text-[13px] transition-colors",
                                        collapsed ? "justify-center" : "px-2.5 gap-2.5",
                                        isActive
                                            ? "bg-muted text-foreground font-medium"
                                            : "text-muted-foreground hover:text-foreground hover:bg-muted/60"
                                    )}
                                >
                                    {/* Active marker - the warm thread */}
                                    {isActive && (
                                        <motion.span
                                            layoutId={threadId}
                                            className="absolute start-0 top-1/2 -translate-y-1/2 w-[2px] h-4 rounded-full ig-thread"
                                        />
                                    )}
                                    <item.icon className={cn("w-4 h-4 shrink-0", isActive ? "text-foreground" : "")} />
                                    {!collapsed && <span className="truncate">{item.name}</span>}
                                </Link>
                            );
                        })}
                    </nav>
                </div>
            ))}
        </>
    );
}

export function Sidebar() {
    const [isCollapsed, setIsCollapsed] = useState(false);

    return (
        <motion.aside
            initial={false}
            animate={{ width: isCollapsed ? 64 : 232 }}
            transition={{ duration: 0.22, ease: "easeInOut" }}
            className="flex-shrink-0 h-screen sticky top-0 start-0 hidden lg:flex flex-col bg-background border-e border-border overflow-visible z-50"
        >
            {/* Collapse toggle - sits on the boundary edge (inline-end in RTL) */}
            <button
                onClick={() => setIsCollapsed(!isCollapsed)}
                className="absolute -end-2.5 top-7 w-5 h-5 bg-card border border-border rounded-full flex items-center justify-center text-muted-foreground hover:text-foreground transition-colors z-50"
                aria-label={isCollapsed ? "باز کردن سایدبار" : "جمع کردن سایدبار"}
            >
                {isCollapsed ? <ChevronLeft className="w-3 h-3" /> : <ChevronRight className="w-3 h-3" />}
            </button>

            {/* Brand */}
            <div className={cn(
                "h-14 flex items-center border-b border-border transition-all",
                isCollapsed ? "justify-center px-0" : "gap-2.5 px-4"
            )}>
                <LogoMark className="w-6 h-6 shrink-0" />
                <AnimatePresence mode="popLayout">
                    {!isCollapsed && (
                        <motion.span
                            initial={{ opacity: 0, x: 6 }}
                            animate={{ opacity: 1, x: 0 }}
                            exit={{ opacity: 0, x: 6 }}
                            className="truncate"
                        >
                            <LogoWordmark className="text-[13px] tracking-[0.14em]" />
                        </motion.span>
                    )}
                </AnimatePresence>
            </div>

            {/* Nav */}
            <div className="flex-1 overflow-y-auto overflow-x-hidden scrollbar-none py-4">
                <NavGroups collapsed={isCollapsed} threadId="nav-thread-desktop" />
            </div>

            {/* Account switcher */}
            <div className={cn("border-t border-border p-2.5", isCollapsed && "px-2")}>
                <AccountSwitcher isCollapsed={isCollapsed} />
            </div>
        </motion.aside>
    );
}

/**
 * Mobile navigation drawer (< lg). Opened by the Topbar hamburger via
 * useUiStore; closes on backdrop tap, the X button, Escape, or navigation.
 * In RTL the drawer slides in from the right edge.
 */
export function MobileSidebar() {
    const isOpen = useUiStore((s) => s.mobileSidebarOpen);
    const close = useUiStore((s) => s.closeMobileSidebar);
    const pathname = usePathname();

    // Any route change closes the drawer
    useEffect(() => {
        close();
    }, [pathname, close]);

    useEffect(() => {
        if (!isOpen) return;
        const onKey = (e: KeyboardEvent): void => {
            if (e.key === "Escape") close();
        };
        window.addEventListener("keydown", onKey);
        return () => window.removeEventListener("keydown", onKey);
    }, [isOpen, close]);

    return (
        <AnimatePresence>
            {isOpen && (
                <div className="lg:hidden fixed inset-0 z-50">
                    {/* Backdrop */}
                    <motion.div
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        transition={{ duration: 0.18 }}
                        onClick={close}
                        className="absolute inset-0 bg-black/45 backdrop-blur-[2px]"
                    />

                    {/* Panel - anchored to the start edge (right in RTL) */}
                    <motion.aside
                        initial={{ x: 280 }}
                        animate={{ x: 0 }}
                        exit={{ x: 280 }}
                        transition={{ duration: 0.22, ease: "easeInOut" }}
                        className="absolute inset-y-0 start-0 w-[260px] flex flex-col bg-background border-e border-border shadow-2xl"
                    >
                        {/* Brand */}
                        <div className="h-14 flex items-center justify-between border-b border-border pe-2 ps-4">
                            <div className="flex items-center gap-2.5 min-w-0">
                                <LogoMark className="w-6 h-6 shrink-0" />
                                <LogoWordmark className="text-[13px] tracking-[0.14em]" />
                            </div>
                            <button
                                onClick={close}
                                className="p-1.5 rounded-md text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
                                aria-label="بستن منو"
                            >
                                <X className="w-4 h-4" />
                            </button>
                        </div>

                        {/* Nav */}
                        <div className="flex-1 overflow-y-auto overflow-x-hidden scrollbar-none py-4">
                            <NavGroups collapsed={false} threadId="nav-thread-mobile" onNavigate={close} />
                        </div>

                        {/* Account switcher */}
                        <div className="border-t border-border p-2.5">
                            <AccountSwitcher isCollapsed={false} />
                        </div>
                    </motion.aside>
                </div>
            )}
        </AnimatePresence>
    );
}
