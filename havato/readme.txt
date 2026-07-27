=== Havato — هواتو ===
Contributors: havato
Tags: social, matchmaking, cafe, events, woocommerce, pwa, rtl, persian
Requires at least: 5.8
Tested up to: 6.6
Requires PHP: 7.4
Stable tag: 1.0.0
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Smart social-table platform for cafés & restaurants: personality-based matching, live table chat, café owner portal and a WebView/PWA-ready bilingual (fa/en) web app.

== Description ==

Havato turns partner cafés into a network of curated social tables. Guests take a
30-second personality test, request a seat at a themed table, pay through
WooCommerce (Zarinpal / Shetab gateways), and the Smart Matcher Core seats the
best possible N-person table. After the event, guests review each other, can add
friends and keep chatting privately.

**Highlights**

* Bilingual out of the box — Persian (RTL, Jalali calendar) and English (LTR, Gregorian), switched instantly without a page reload.
* 14 dedicated InnoDB tables with a self-healing installer (missing tables are recreated on the fly).
* Two native roles: `gatherer` (guest) and `cafe_owner`, each with its own portal and profile.
* Smart Matcher Core with two execution paths: automatic on last-seat-taken, plus a cron fallback that always produces a table even with very few registrations.
* Real Google Sign-In (Google Identity Services, server-side token verification).
* Real WooCommerce checkout — no simulated wallet. Menus are display-only, no in-app ordering.
* Venue payout ledger with per-period commission split and a "mark as paid" admin action.
* Check-in / no-show tracking that feeds back into the matching score.
* PWA manifest + service worker, full-screen standalone mode (`?webview=1`) for Android/iOS WebView or Capacitor packaging.

== Installation ==

1. Upload the `havato` folder to `/wp-content/plugins/` (or install the ZIP through Plugins → Add New → Upload).
2. Activate the plugin. The 14 tables, both roles and the cron jobs are created automatically.
3. Create a page and add the shortcode `[havato_app]`.
4. Go to **Havato → Google sign-in** and paste your OAuth Client ID.
5. Optionally go to **Havato → Statistics dashboard → Generate demo content** to populate sample cafés and events.

== Frequently Asked Questions ==

= Does it require WooCommerce? =
Only for paid tables. Free events work without it.

= How do I ship it as an APK? =
Point your WebView / Capacitor `server.url` at the app page with `?webview=1`
appended. The theme header, footer and sidebar are bypassed, all navigation
happens in-page, and the hardware Back button moves between tabs.

= Where do users switch language? =
A floating button in the app header, plus the `havato_lang` user meta.

== Changelog ==

= 1.0.0 =
* Initial release.
