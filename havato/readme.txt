=== Havato — هواتو ===
Contributors: havato
Tags: social, matchmaking, cafe, events, woocommerce, pwa, rtl, persian
Requires at least: 5.8
Tested up to: 6.6
Requires PHP: 7.4
Stable tag: 1.11.0
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

= 1.11.0 =
* Fixed: the country and city step of the personality test was completely
  empty, so the test could never be finished. The lists are built from
  BOOT.locations, but the server only ever sent that map in the bootstrap REST
  response and never in the boot payload the screen actually reads.
* The 30-second test is now purely about personality. It asks seven traits --
  extroversion, conversation style, openness, humour, energy, planning and
  empathy -- plus the conversation vibe and interests. Every step has a
  sensible default, so no step can trap the user.
* Name, age, gender, country, city and area moved to a new "Edit my details"
  button on the profile. It stays available permanently, so these can be
  corrected whenever they change instead of being frozen at sign-up.
* Splitting the two also means a validation failure on the details can no
  longer cost somebody their test answers, and vice versa.
* The profile now shows the five new traits as labelled bars, and the matcher
  scores similar humour, similar preferred atmosphere and the presence of a
  good listener. The weights are small and adjustable under Formula weights:
  the new terms refine the existing ordering rather than competing with it.
* Schema 1.7.0 adds the five trait columns. Profiles written before the
  upgrade read as the neutral midpoint 5 rather than 0, which the matcher
  would otherwise have scored as an extreme introvert.

= 1.10.0 =
* New "Appearance & theme" page in the Havato admin menu. Five ready palettes
  ship with it — Azure Blue, Emerald, Espresso, Midnight & Amber, Sunset
  Coral — each previewed as a miniature of the real app screen, with its
  white-on-primary contrast ratio shown on the card.
* The default palette is no longer violet. Every shipped theme was checked
  against WCAG 2.1: white text clears AA on the primary colour in all five,
  and none of them sits in the 230-280 degree hue band that reads as purple.
* Custom theme: pick a main colour and an accent, every other shade is
  derived. A colour too light to carry white text is darkened automatically
  until it passes AA, so the app can never be made unreadable.
* Themes are extensible. `add_filter( 'havato_themes', ... )` registers a new
  palette and it appears in the picker with no other change; a theme only has
  to supply its base colour, the rest is filled in.
* Switching a theme costs no extra request: the palette is a small block of
  CSS custom properties inlined onto the stylesheet that is already loaded.

= 1.9.1 =
* Removed the "Café owner sign-in" button from the guest landing screen. Owners
  still reach their portal directly and wp-login.php still redirects them there.
* Signing out now really ends the session. Previously the app only re-rendered
  itself, so a refresh brought the user straight back in.
  - The service worker no longer caches HTML navigations or anything that can
    carry a session, including the plain-permalink `?rest_route=` REST form
    that the old `/wp-json/` check missed entirely.
  - Logout disables Google auto-select, clears every cache and performs a real
    top-level navigation, with wp_logout_url() as a fallback if REST fails.
  - Side effect: a browser cache clear is no longer needed after an update.
* Fixed near-black text on saturated backgrounds (profile card, auth screens,
  own chat bubbles, toasts). Those elements inherited their colour, so any
  theme rule targeting the bare tag overrode it. Every dark surface now sets
  the colour explicitly and a blanket guard stops the bug from recurring.

= 1.9.0 =
* Demo content now ships a full sample directory: 30 cafés across Tehran,
  Isfahan and Istanbul, each with tables and two upcoming events.
* Everything the seeder creates is flagged as demo, and a new "Delete demo
  content" button removes exactly that — real cafés, including ones in the
  same city and ones added through the bulk importer, are never touched.
* The dashboard shows how much demo content currently exists, and deletion
  asks for confirmation first.
* Removing demo content also cleans up the rows that hang off it (tables,
  registrations, groups, memberships and chat), so no orphans are left behind.

= 1.8.0 =
* New admin screen "Bulk import cafés": paste a JSON list and create many
  venues at once. Each row needs name, city, latitude and longitude; address,
  manager and image are optional.
* City names are accepted in Farsi or English ("تهران", "Tehran", "tehran")
  and mapped to the internal key, so a list written by hand just works.
* Re-running an import skips cafés that already exist rather than duplicating
  them, and rows with an unsupported city are reported instead of dropped.
* Imported cafés have no WordPress account attached; an owner can register
  later. They can be published immediately or left pending review.

= 1.7.1 =
* Table numbers are no longer suggested. The café types the number the table
  actually carries in the room, and saving is blocked until every table has
  one — a number we invented would not match the furniture.
* Seats per table remain fully editable and continue to drive event capacity
  and group sizes.
* Guests now see the real table: a matched group is named after the café's own
  number ("Table #6") instead of a running 1, 2, 3, the welcome message states
  it in both languages, and it appears as a badge in the chat list.

= 1.7.0 =
* Every table now has its own number ("Table #6"), so a café lists its real
  furniture one row per table instead of "3 of this kind". Numbers must be
  unique and the next free one is suggested automatically.
* Tables can be edited, added or removed at any time — unless an active event
  is still using them. The screen names the events that are holding the lock,
  and the tables unlock once those finish or are cancelled.
* Table numbers appear on the event picker and in the admin event list, so it
  is clear which physical table a group was seated at.
* Existing furniture is migrated automatically: a legacy "3 tables of 4" row
  becomes three individually numbered tables with the same total capacity.

= 1.6.0 =
* Cafés can now describe their real furniture once — "3 tables of 4, 2 tables
  of 6" — on a new "My tables" screen.
* When creating an event the owner ticks which tables to use; capacity is
  calculated from the seats instead of being typed in, and a live preview
  shows the total.
* The matcher now seats one group per PHYSICAL table. An event with 3x4 + 1x6
  produces groups of 6, 4, 4 and 4 — previously it produced a single group of
  18, which was never what a café actually has.
* Events gained a theme and an optional photo (falling back to the café cover
  when omitted). Both appear in the admin event list along with the table
  layout.
* Events created before this release keep working: with no furniture attached
  they fall back to their existing capacity as a single table.

= 1.5.0 =
* New admin screen "Events & guests": every event on the platform with the
  people registered to each one — avatar, name, rating, amount paid and
  check-in state — plus a status filter and paging.
* New admin screen "All cafés": the complete directory with search by name,
  manager or address, city and status filters, storefront photo, event count
  and an inline verify button.
* Events now have a title. Café owners can name a table ("Movie night",
  "Startup talk") and it appears in both panels; untitled events fall back to
  their date and time.
* Guests for a whole page of events are fetched in a single batched query
  rather than one lookup per event, so the screen stays fast as the platform
  grows.

= 1.4.0 =
* SECURITY: the public owner/login endpoint authenticated ANY account,
  including administrators, with no role check and no rate limiting. It now
  accepts only the cafe_owner role and is throttled to 5 attempts per IP per
  15 minutes. Registration is throttled the same way.
* New branded sign-in / sign-up page for cafe owners ([havato_owner_auth],
  created automatically on activation). Owners no longer touch wp-login.php:
  that URL redirects them to the branded page, while administrators keep an
  escape hatch at wp-login.php?havato_admin=1.
* Cafes can now self-register again; the venue stays hidden from guests until
  an administrator approves it.
* After signing up, the owner panel asks for a photo of the shopfront to speed
  up verification, and that photo is shown to the administrator right in the
  approvals table.
* The guest sign-in screen now has a large "User sign-in" heading above the
  Google button.

= 1.3.0 =
* The café owner panel moved into wp-admin as a proper desktop interface:
  dashboard, events with check-in, menu builder, venue settings (media library
  + draggable pin) and payout status. It reuses the same REST endpoints, so
  business rules live in exactly one place.
* The mobile owner portal was removed from the web-app, which is now guests
  only. Its four owner tabs and ~540 lines of code are gone.
* Café owners are locked to their own panel plus their profile: every other
  wp-admin menu is hidden, the dashboard and post editor redirect back, and
  the admin bar is trimmed. Uploads keep working. Gatherers are redirected out
  of wp-admin to the web-app entirely.
* Cafés are now onboarded by the administrator from Havato -> Approvals, since
  public owner signup was removed with the mobile portal.

= 1.2.0 =
* The personality test now asks for country and city first. Supported:
  Iran (Tehran, Isfahan) and Turkey (Istanbul). The city list is derived from
  the chosen country, so an impossible pair such as Iran/Istanbul cannot be
  submitted, and the server re-validates it.
* Guests now only see cafés and tables in their own city. Explore and the Map
  are both scoped, with an empty state that explains why. Visitors without a
  finished profile still see everything.
* Cafés declare their country and city at signup and can change it in Venue
  Settings; the city also appears in the wp-admin verification table.
* Bottom-navigation labels AND icons are now fully white on every tab.

= 1.1.3 =
* Bottom-nav labels are now pure white on every tab (9.0:1 contrast); the
  active tab is marked by weight, a brighter underline and an icon glow.
* Fix: the notch behind the floating button was cut from an SVG stretched with
  preserveAspectRatio="none", so it grew with the screen while the button did
  not — leaving a pale wedge of page background on either side. The bar is now
  painted directly and the notch is mask-cut from --hv-fab-size, giving a
  constant 5px ring on every width, with an @supports fallback.
* Fix: the green "nearby location" pill did nothing. It was a decorative
  <span> inside a pointer-events:none strip. It is now a real button that
  centres the map, drops a "you are here" marker, and reports permission
  denial, failure or an unsupported browser instead of failing silently.

= 1.1.2 =
* Fix: bottom-navigation icons were still washed out. The 1.0.2 attempt used a
  `.hv-tab svg *` rule, but <use> clones each symbol into a shadow tree and
  descendant selectors cannot pierce a shadow boundary, so that rule never
  applied. The nav now uses dedicated monochrome symbols authored with
  `currentColor` (an inherited property, which does cross the boundary).
* Inactive tabs raised to 78% white and given a soft dark halo; the active tab
  is solid white and bolder. Measured contrast is now 6.0:1 to 15.0:1 across
  the whole nav gradient, well past the 3:1 WCAG threshold for UI glyphs.
* The colourful gradient icons are unchanged everywhere else.

= 1.1.1 =
* Fix: the Map tab was unusable — a giant green pin covered the map. icon()
  injects a bare <svg> with no width/height, and an unsized inline SVG falls
  back to the browser default of 300x150. Added a global fallback size for
  every sprite icon plus explicit sizes for the map pills and the gallery
  upload tile, so this cannot happen again anywhere.
* Fix: the sign-in screen showed two "continue with Google" buttons. The
  custom button is only a fallback for when the Google SDK is blocked, so it
  now stays hidden and appears only if the official button fails to load,
  throws, or silently fails to paint.

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
