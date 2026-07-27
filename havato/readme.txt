=== Havato — هواتو ===
Contributors: havato
Tags: social, matchmaking, cafe, events, woocommerce, pwa, rtl, persian
Requires at least: 5.8
Tested up to: 6.6
Requires PHP: 7.4
Stable tag: 1.1.0
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

= 1.1.0 =
* A café name is now entered once. The separate Persian name field is gone —
  a venue name is a proper noun and does not need translating.
* That field is replaced by the café/restaurant manager's name, which is shown
  to the administrator in its own column of the verification table.
* Database migration: existing installs keep whichever name was filled in (a
  Persian-only venue is NOT lost), seed the manager name from the linked
  WordPress account, and then drop the legacy column. The migration is
  idempotent and safe to run repeatedly.

= 1.0.4 =
* New: a real progress bar for every photo upload (profile avatar, gallery,
  menu item, venue cover) showing true byte-level percentages, plus a cancel
  button. Uploads switched from fetch() to XHR because fetch cannot report
  upload progress.
* New: the same bar covers saves (menu, venue settings, map pin, personality
  test) in indeterminate mode.
* The bar reports success in green and failures in red, falls back to an
  animated indeterminate state when the size is unknown, mirrors its animation
  for RTL, and honours prefers-reduced-motion.

= 1.0.3 =
* Menu Builder: each product is now a single compact restaurant-style row
  (square photo | name + price | actions) instead of a tall stacked form.
  The description collapses behind a toggle.
* Fix: product photos rendered as a stretched "capsule". `.hv-menu-thumb` is
  used both on a wrapper and directly on an <img>; in the latter case
  `display: grid` made the browser ignore object-fit. Added an
  `img.hv-menu-thumb` rule so photos always crop to a square.
* Admin approvals: pending menus are now listed as restaurant-style rows with
  the product photo, name, description and price.
* Revenue is administrator-only. Added a dedicated "Revenue & settlements"
  sub-menu with per-event ticket income, the commission split and the payout
  ledger. Café owners now only ever see their own share: gross revenue and the
  platform commission are stripped from the owner API response, not just
  hidden in the UI.

= 1.0.2 =
* Fix: the "approve menu" button in wp-admin was labelled "reject". PHP casts
  numeric string array keys to integers, so `'1' === $approve` was always
  false. Both buttons now come from an explicit action list.
* Fix: bottom-navigation icons were nearly invisible. The sprite's indigo
  layer (#1B1FBF) was being drawn on the dark indigo nav bar; inside the nav
  the icons are now painted with currentColor.
* Fix: the Menu Builder image button stretched into a tall pill because a
  column flex parent stretched it. The thumbnail is now pinned to 56x56.
* Fix: the last form field could sit underneath the floating action button.
  The scroll area's bottom padding now allows for the FAB overhang via a new
  --hv-fab-size token shared with the button itself.

= 1.0.1 =
* Fix: the checkout-redirect and modal overlays stayed on screen permanently,
  covering the app with a spinner on a blue gradient. Their `.hv-redirect` /
  `.hv-modal-host` class rules declared `display: flex`, which outranks the
  browser's built-in `[hidden] { display: none }`. Added an explicit
  `#havato-app [hidden] { display: none !important }` guard.
* Add: a visible "could not reach the server" state with a retry button, so an
  unreachable REST API can never look like an endless loading spinner.
* Bumped the version so cached CSS/JS and the service-worker cache refresh.

= 1.0.0 =
* Initial release.
