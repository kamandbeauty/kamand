import type { Metadata } from "next";
import localFont from "next/font/local";
import { AppProviders } from "@/components/providers/Providers";
import "./globals.css";

/**
 * Vazirmatn (SIL OFL 1.1) - bundled locally so the app never depends on
 * Google Fonts at build time, on Vercel, or on Cloudflare Workers.
 * Source: https://github.com/rastikerdar/vazirmatn (v33.0.3)
 */
const vazirmatn = localFont({
  src: [
    { path: "./fonts/Vazirmatn-Regular.woff2", weight: "400", style: "normal" },
    { path: "./fonts/Vazirmatn-Medium.woff2", weight: "500", style: "normal" },
    { path: "./fonts/Vazirmatn-SemiBold.woff2", weight: "600", style: "normal" },
    { path: "./fonts/Vazirmatn-Bold.woff2", weight: "700", style: "normal" },
    { path: "./fonts/Vazirmatn-ExtraBold.woff2", weight: "800", style: "normal" },
  ],
  variable: "--font-vazirmatn",
  display: "swap",
});

export const metadata: Metadata = {
  title: "open-autoDM",
  description:
    "اتوماسیون متن‌باز کامنت‌به‌دایرکت اینستاگرام — با اپ متای خودت، ساپابیس خودت و دیپلوی خودت.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fa" dir="rtl" suppressHydrationWarning>
      <body
        className={`${vazirmatn.variable} font-sans antialiased bg-background text-foreground transition-colors duration-300`}
      >
        <AppProviders>
          {children}
        </AppProviders>
      </body>
    </html>
  );
}
