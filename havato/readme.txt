=== Havato — هواتو ===
Contributors: havato
Tags: social, matchmaking, cafe, events, community, pwa, rtl, persian
Requires at least: 5.8
Tested up to: 6.6
Requires PHP: 7.4
Stable tag: 1.37.0
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Smart social-table platform for cafés & restaurants: personality-based matching, live table chat, café owner portal and a WebView/PWA-ready bilingual (fa/en) web app.

== Description ==

Havato turns partner cafés into a network of curated social tables. Guests take a
short personality test, fill in their details, request a seat at a themed table,
and the Smart Matcher Core seats the best possible N-person table. Everything is
free for guests: the plugin handles no money and has no payment step at all.
After the event, guests review each other, can add friends and keep chatting
privately.

**Highlights**

* Bilingual out of the box — Persian (RTL, Jalali calendar) and English (LTR, Gregorian), switched instantly without a page reload.
* 15 dedicated InnoDB tables with a self-healing installer (missing tables are recreated on the fly).
* Two native roles: `gatherer` (guest) and `cafe_owner`, each with its own portal and profile.
* Smart Matcher Core with two execution paths: automatic on last-seat-taken, plus a cron fallback that always produces a table even with very few registrations.
* Real Google Sign-In (Google Identity Services, server-side token verification).
* Completely free to join: no payments, no tickets, no wallet, no gateway. Menus are display-only, no in-app ordering.
* Seats are gated on a finished profile instead — the personality test plus name, age and city.
* Check-in / no-show tracking that feeds back into the matching score.
* PWA manifest + service worker, full-screen standalone mode (`?webview=1`) for Android/iOS WebView or Capacitor packaging.

== Installation ==

1. Upload the `havato` folder to `/wp-content/plugins/` (or install the ZIP through Plugins → Add New → Upload).
2. Activate the plugin. The 15 tables, both roles and the cron jobs are created automatically.
3. Create a page and add the shortcode `[havato_app]`.
4. Go to **Havato → Google sign-in** and paste your OAuth Client ID.
5. Optionally go to **Havato → Statistics dashboard → Generate demo content** to populate sample cafés and events.

== Frequently Asked Questions ==

= Does it require WooCommerce or any payment gateway? =
No. Havato never handles money — joining a gathering is always free.

= How do I ship it as an APK? =
Point your WebView / Capacitor `server.url` at the app page with `?webview=1`
appended. The theme header, footer and sidebar are bypassed, all navigation
happens in-page, and the hardware Back button moves between tabs.

= Where do users switch language? =
A floating button in the app header, plus the `havato_lang` user meta.

== Changelog ==

= 1.37.0 =
* Fixed: the app was very slow to appear. The Persian font was loaded from
  jsDelivr and the map library from unpkg, and both were declared as
  DEPENDENCIES of the app's own stylesheet. A stylesheet blocks rendering, so
  the browser refused to paint anything until both third-party hosts replied.
  From Iran — most of the audience — those hosts are frequently unreachable,
  so every single page load sat waiting out the full connection timeout before
  showing anything, whether or not the visitor ever opened the map.
* Vazirmatn is now served from the plugin itself: four weights, Arabic subset
  only (Latin text uses the system UI font, so Vazirmatn's Latin glyphs were
  never used), 84 KB in total, with font-display:swap so text is readable
  immediately. No visitor IP is handed to a third-party CDN any more either.
* Leaflet is fetched the first time the map is actually opened instead of on
  every page load. If it cannot be fetched at all, the map area now says so
  and the café list underneath keeps working, rather than leaving a blank box.
  Two new filters, havato_leaflet_css and havato_leaflet_js, let a site behind
  a firewall point them at a local copy or a mirror.
* A page load that never opens the map now makes zero blocking requests to any
  third party.
* Fixed: signing in reported that cookies could not be loaded, and only worked
  after refreshing the page several times. A WordPress REST nonce is tied to
  the user id and session token. The page is rendered while nobody is signed
  in, so the nonce embedded in it belongs to the logged-out state; completing
  Google sign-in replaces the auth cookie and invalidates that nonce
  instantly. Every request the app made afterwards was rejected with
  rest_cookie_invalid_nonce until a manual reload regenerated the page.
  Sign-in and sign-out now return a nonce minted for the new session, and the
  app adopts it before making any further request.

= 1.36.0 =
* The no-show warning on your profile now reads as two tidy blocks — the
  sentence, then the three figures — instead of one run of text in which a
  label could wrap onto a different line from its own number. Each
  label/value pair is now unbreakable.
* The personality-test RESULT is no longer shown to anyone. The profile used
  to print an introvert/extrovert score out of ten, talker vs listener, the
  vibe and five trait bars. The test exists so the matcher can seat
  compatible people together; showing the numbers turns a matching input into
  a verdict the guest reads about themselves. The scores still drive matching
  exactly as before — they are simply no longer published.
* Security: those scores were also being sent to ANY viewer, not just the
  owner, so opening someone's profile handed you a psychological read of them
  over the network even before this change hid the card. The REST response now
  includes them only when you are viewing your own profile, which is still
  needed so "edit" can re-open the test with your stored answers.
* The card is retitled "Interests" and shows what it actually contains: your
  interests, plus age and city. Ten now-orphaned strings and forty lines of
  dead trait-bar CSS were removed with it.
* The interest list grew from 36 to 86 tags, covering music and live gigs,
  anime, dance, museums, architecture, podcasts, politics, economics,
  astronomy, environment, design, crypto, freelancing, medicine, law,
  engineering, six more sports, camping, skiing, tea, baking, cafés,
  vegetarian food, chess, cards, puzzles, escape rooms, karaoke, stand-up,
  gardening, décor, parenting, wellbeing, collecting and more.
* Because 86 chips in one heap is not a list anyone reads to the end, the
  picker now groups them under seven headings and adds a search box. Search
  matches all three languages at once, so a Persian speaker using the English
  interface can still find a tag by its Persian name. A live counter shows how
  many you have chosen.
* Every one of the 36 original interest keys was kept. Choices are stored by
  key, so renaming or dropping one would have silently erased that interest
  from every profile that had it; the test suite asserts all 36 survive.

= 1.35.1 =
* Fixed: the bottom navigation came out too small in every language after
  1.35.0 — both the labels and the icons. Two causes, and the first had been
  hiding in the stylesheet since the very first release:
* The unsized-SVG safety net was written
  `#havato-app svg:not(.hv-sprite):not(.hv-wave)`. The arguments of `:not()`
  count toward specificity, so that selector scores 1-2-1 and outranked every
  rule meant to override it — `.hv-tab svg` is only 0-1-1. All 14 icon sizes
  in the app were therefore dead code, and every icon rendered at the net's
  `1.25em`, a size tied to the font rather than a fixed one. Nobody noticed
  because buttons were separately (and wrongly) inheriting the 16px body size,
  which made the icons 20px by accident — close enough to the intended 22px to
  look correct. Repairing that inheritance in 1.35.0 removed the accident and
  the icons collapsed to about 12px. The net is now wrapped in `:where()`, so
  it scores 0-0-0 and every component rule finally applies. Nav icons are
  24px; the other thirteen sizes take effect for the first time.
* The tab label multiplier was likewise never applied, so nobody had noticed
  it was set far too low. Applied literally it produced ~9.9px, below both
  platform baselines (iOS tab bars 10px, Android bottom navigation 12px). It
  now resolves to 12px in Persian and 11.3px in Latin, and all five labels
  still fit a 320px screen in all three languages — Turkish, the longest,
  needs 50.6px of a 62px column.
* The narrow-screen rule that shrank tab labels further on phones under 380px
  has been removed for the same reason; only the icon steps down there now.
* tests/icon-sizing.js now models CSS specificity properly, including the
  `:not()`/`:where()` asymmetry, and asserts that all 14 icon rules outrank
  the safety net rather than pinning the sizes the bug happened to produce.

= 1.35.0 =
* Fixed: in the English and Turkish builds the type was oversized and the
  layout looked scattered, with bottom-bar labels truncated to "MY TABL…" and
  "MY PROF…". Four separate faults were stacking up, all of them invisible in
  Persian, which is why the report only ever mentioned the English version:
* 1. `#havato-app button { font: inherit }` used the font SHORTHAND, which
  also resets font-size. At id weight (1-0-1) it outranked every component
  rule in the stylesheet (`.hv-tab`, `.hv-btn`, `.hv-chip` … all 0-1-0), so
  every button in the app ignored its own size and rendered at full body
  size — nav labels included. Controls now inherit only the family and colour
  at id weight; size, weight and line-height come through a zero-specificity
  `:where()` rule that any component can still override.
* 2. Every size was written in `rem`, which resolves against the host theme's
  `<html>`, not against the plugin. A theme that sets `html{font-size:112.5%}`
  — or Chrome's own text-scaling setting — inflated the whole app, and a
  `clamp()` whose floor is in `rem` cannot clamp that, because the floor rises
  along with the root. All 104 sizes now resolve against an internal token,
  so the app renders identically whatever the surrounding page does.
* 3. The host theme's `button { text-transform: uppercase }` was uppercasing
  our labels. Persian has no letter case, so the rule was a no-op there and
  the damage never showed; in Latin it made every label roughly 15% wider
  before the theme's extra tracking was counted. The app now refuses
  text-transform, small-caps, and stray word/letter-spacing inside its own
  shell, while keeping the four places that set tracking deliberately.
* 4. The five-tab bar carried the possessive labels "My Tables" and
  "My Profile", which do not fit one fifth of a phone screen. The bar now uses
  short forms (Tables / Profile, میزها / پروفایل, Masalar / Profil); the
  screens themselves keep their full titles.
* Latin text is also set one step smaller than Persian (15px against 16px).
  Vazirmatn and the system UI stack have different x-heights, so matching them
  by em made English look larger than Persian at the same nominal size.
* Persian rendering is byte-for-byte unchanged: the new token is 16px, exactly
  what `rem` resolved to on a default page, and the test suite asserts that
  each converted size still computes to its previous value.

= 1.34.0 =
* Fixed: the profile photo could not be changed from anywhere in the app. The
  upload code was intact, but the button it binds to disappeared in 1.17.0
  when the profile header was consolidated, leaving the feature unreachable.
  Your own profile now has a photo card showing the current picture, or your
  initials if you have none, with a "Change photo" button beside it.
* Cafés can now write a description of themselves, shown on the event page
  above the address. Previously the page described the gathering but said
  nothing about the venue beyond a street address, which is thin for someone
  deciding whether to spend an evening there. Schema 1.16.0 adds the column.
* The event page therefore now carries both descriptions: what the gathering
  is, and what the café is like. Either is left out if empty, rather than
  printing a heading over nothing.

= 1.33.0 =
* The event page now shows the café's written address in its own block,
  together with a Directions button that hands the venue to whatever
  navigation app the phone has — Google Maps, Waze or Neshan on Android, and
  Apple or Google Maps on iOS. Previously the address was a single grey line
  with no way to act on it, so a guest had to copy it out by hand.
* A café that has not been placed on the map yet still gets a working button:
  the typed address is handed over as a search instead of coordinates. Only a
  café with neither a pin nor an address shows no button, and in that case
  the page says the address is missing rather than leaving a blank space.
* Persian addresses are percent-encoded before going into the URL. A raw
  right-to-left string in a `geo:` link is mishandled by some Android
  launchers, which would open the map app on nothing.

= 1.32.0 =
* The Home screen gains a "Quick actions" block: four cards in a 2x2 grid —
  browse gatherings, host one, my tables, chats — each with an arrow, so they
  read as somewhere to go rather than buttons that act. The arrow points the
  way the language runs, so it never appears to send a Persian reader
  backwards.
* Below it, an "Activity summary": how many gatherings are coming up, and how
  many have actually been attended. The second figure is counted when a café
  checks the guest in rather than when they book, so it cannot flatter
  somebody who reserves a seat and never turns up.
* A missing figure shows zero rather than an empty space, and the two numbers
  use tabular figures so they line up between rows.

= 1.31.1 =
* Fixed: the bottom bar still divided itself into four columns after gaining
  a fifth tab, so Profile wrapped onto a second row underneath the others.
  The tabs now share the width between however many there are, and a label
  too long for its share is trimmed with an ellipsis instead of wrapping.
* Event cards are rebuilt in reading order: the name of the gathering, then
  the weekday, date and time, then the café and its address, then the faces
  of the people who have already taken a seat. The cover image sits across
  the top instead of as a small square beside the text.
* Cards now show up to four attendee avatars with a "+N" for the rest. Only
  the avatar is sent — no names, no ids — because a card is read by anyone
  browsing.
* Fixed: a gathering in Iran was dated in the Gregorian calendar for anyone
  reading the app in English or Turkish. The date now follows the country the
  café trades in, so an Iranian gathering is always shown in Jalali — the
  same date the café has on its door, and the one everyone at the table will
  say out loud. The same reasoning already governs prices.

= 1.31.0 =
* New "Galaxy" theme: a dark violet night palette, added alongside the six
  light ones rather than replacing them. Azure remains the default, so
  nothing changes until an administrator picks Galaxy on the Appearance
  screen — and switching back is one click.
* The theme engine now supports dark palettes properly. A palette can declare
  itself dark (or be detected from a dark canvas) and the surfaces invert:
  cards become lighter than the page instead of white, borders become
  visible, and body text is corrected for contrast against the card it sits
  on rather than the page behind it. Twenty hardcoded white backgrounds in
  the stylesheet became tokens, so every panel follows the palette.
* The bottom bar has five tabs — Home, Explore, My Tables, Chats, Profile —
  and the floating round button is gone. That button changed meaning on every
  tab with nothing on screen to say what it would do; its last job, the
  dashboard, is now a labelled tab. The notch it sat in has been removed too,
  since with five tabs it would cut a hole above the middle one.
* The map is no longer a tab of its own. It is the same tables seen another
  way, so it is a sub-tab of Explore. Old links to it still work and light up
  the Explore tab rather than none of them.
* New Home screen: your next table as a full card, a horizontal rail of
  tables to discover, and three shortcuts. Tables you have already booked are
  not offered again in the rail.
* New "My Tables" tab: your upcoming bookings and the suggestions you have
  sent, with the café's reply.
* Events are now boxed cards throughout, with the topic labelled.

= 1.30.0 =
* The booking cutoff is now a setting on the Matching weights screen, next to
  the other timing values, instead of only a code filter. It still defaults to
  five hours, and 0 keeps a table listed until the moment it starts. The
  `havato_booking_cutoff_hours` filter still overrides it.
* Fixed: a finished gathering was still reachable by its own link. The listing
  hid it, but the event page took an id straight from the URL, so a bookmark
  or a shared link opened last week's gathering with a working "reserve"
  button. That page now answers "no longer available".
* Fixed: the profile listed every gathering the guest had ever attended,
  newest first, under a heading that reads as upcoming. It now shows only
  what still lies ahead, soonest first, and drops cancelled ones.
* Someone who holds a seat is exempt from both: they can still open their own
  gathering — with its address and directions — right up to the moment they
  sit down, and afterwards. What you may still join and what you have already
  booked are different questions.
* The café and administrator panels are unaffected: a café needs to see this
  evening's tables and the administrator needs the full history.

= 1.29.0 =
* Fixed: the language dropdown showed white text on a white panel, so the list
  was invisible. The menu is a light panel living inside the dark header, and
  the rule that forces white text on everything inside the header caught it
  too — that rule is id-scoped, so it outranked the menu's own colour. The
  menu is now excluded from it and its colours are pinned at the same weight,
  which also means a site theme cannot undo them.
* The per-tab action button now sits underneath the language button instead of
  beside it. Side by side the two took enough width to truncate the page title
  on a narrow phone.
* Gatherings that have already started, or start within the next five hours,
  are no longer listed. The old filter compared the date only, so a table from
  earlier the same morning stayed on the board. A table nobody can reach in
  time is worse than no table: the matcher would seat a party that never
  arrives, and every empty seat costs the others a penalty.
* The same cutoff is enforced when booking, not just when listing — a tab left
  open since the morning still holds a working event id.
* The window is filterable via `havato_booking_cutoff_hours`.
* Your own dashboard still shows a seat you already hold today, including one
  starting within the cutoff, with its directions button. What you can no
  longer join is a different question from what you have already booked.

= 1.28.1 =
* Fixed: a guest whose city was not set yet could suggest a gathering to any
  café on the platform, including one in another country. The check read
  "if a city is known and it differs, refuse", so an unset city skipped it
  entirely — and an unset city is exactly the state a new account is in. The
  city is now required and validated before the café is compared, and the
  comparison is exact.
* The café picker no longer lists every café to such a guest. It shows the
  cafés of their own city or nothing at all, so the form can never offer a
  café the server would then refuse.
* An empty picker now tells the guest which of the two reasons applies —
  "no cafés in your city yet" versus "set your city first" — and the second
  takes them to their details, where they can fix it.
* Refusing a café in another city now says so, instead of a generic error.

= 1.28.0 =
* Corrects how an accepted suggestion becomes a gathering. A guest asks for a
  day and a subject; how many seats to open is the café's decision, not
  something to be inferred. 1.27.0 built the event automatically from every
  table the café owned, which quietly made that choice on their behalf.
* Accepting now takes the café to the event form with the guest's subject,
  day, time and note already filled in, and the table picker empty. Ticking
  tables is what sets the number of seats, exactly as when the café creates a
  gathering itself. A short note on the form explains where the values came
  from.
* The suggestion is read back scoped to the café, so another café's queue
  cannot be read by guessing an id in the URL.
* Nothing else changed about the flow: the event still lands as "pending
  review" and reaches Explore only after an administrator approves it.
* Fixed: the start-time field on the event form was labelled "Quiet hours",
  which is a café-wide setting rather than this event's start time.

= 1.27.0 =
* The administrator now sees guest suggestions from every café, on the
  Approvals screen. It opens on the pending ones with a count, and a toggle
  shows the rest. The café's city is listed beside its name so two cafés with
  similar names are told apart. This is the only place the pattern is visible:
  a café that keeps receiving suggestions and never creates a gathering is
  worth a phone call. The screen is read-only — the decision stays with the
  café.
* Accepting a suggestion now creates the gathering, rather than only marking
  the suggestion answered. It is built from the café's current tables and
  carries the guest's subject, note, day and time.
* The new gathering lands as "pending review" and does not appear in Explore
  until an administrator approves it, exactly like any other new table. A café
  that has not defined any tables yet gets a clear message instead of an event
  with nowhere to sit.
* The suggestion is re-read scoped to the café before anything is written, so
  a café cannot answer another café's queue, and only a still-pending one can
  be answered — a stale double-submit cannot create the same event twice.
* The language button opens a list instead of cycling. Reaching Turkish from
  Persian used to take two taps and a pass through English; every language is
  now one tap, shown in its own script. The closed button now shows the
  language you are reading rather than the one it would switch to, which is
  what a dropdown is expected to display. Tapping elsewhere or pressing Escape
  closes it.

= 1.26.0 =
* The round button in the bottom bar changed meaning with every tab — filter
  on Explore, locate on the map, upload on the profile — with nothing on
  screen saying which. That per-tab action has moved into the header, beside
  the language switch, where it now carries a name for screen readers and a
  tooltip for everyone else. No action was dropped in the move.
* The round button now has one fixed job: it opens the guest's own dashboard.
* The dashboard shows the guest's name, photo and behaviour score, their
  upcoming bookings soonest-first, and their suggestions. Tapping a booking
  opens that event's page. Past and cancelled bookings are left out — a
  dashboard is about what happens next.
* Each booking carries a Directions button that hands the café's coordinates
  to the phone's own navigation app: a `geo:` URI on Android, which Google
  Maps, Waze and Neshan all answer, and a Google Maps URL on iOS, which
  ignores `geo:`. A café with no coordinates simply shows no button.
* New "Suggest a gathering": a guest picks a café in their city, a subject, a
  day and a time, and asks for it. This is explicitly not a booking — nothing
  is seated and no seat is held. The café sees the suggestion on its own
  dashboard and can accept or decline; accepting does not create the event,
  the café still builds it on the Events screen where the tables are chosen.
* A suggestion is refused if the date has passed, the café is unverified or in
  another city, or the same guest already has a pending suggestion for that
  café on that day. Schema 1.15.0 adds the event_requests table.
* Fixed: the round button never set a text colour, so the dashboard glyph —
  which paints with currentColor — could have inherited a colour from the
  surrounding theme and disappeared against the blue.

= 1.25.0 =
* The line under the café name on an Explore card now says what the gathering
  is about. It uses the event's title, falling back to its theme when the café
  left the title blank, so a card is never just a café name and a date.
* Reserving a seat now opens the event's own page first, instead of jumping
  straight to the seat picker. Booking carries a no-show penalty, so the guest
  should be able to read what they are committing to beforehand: the café and
  its address, the full menu with prices, a description of the gathering, the
  weekday, date and time, how many seats are left, and a live countdown to the
  start. The reserve button sits at the bottom of that page.
* The countdown runs from a figure the server works out against the site's own
  clock, so a phone with a wrong clock or in another timezone still shows the
  same number of hours as everyone else. It switches to "already started"
  rather than counting upwards, and its interval is cleared when the page
  closes.
* Events can now carry a description. Cafés write it when creating an event
  and administrators can edit it; it is clamped like every other free-text
  field. Schema 1.14.0 adds the column.
* Demo events used to be created with an empty title, which is why every
  evening at a café looked identical on the cards. Each now has a real subject
  and description, paired with its theme.
* Fixed two `wpdb->insert()` calls on the events table whose format arrays had
  one entry more than they had columns. Because wpdb pairs them by position,
  everything after that point was written with the wrong type — `status`
  would have been stored as a number, turning "open" into 0. Found by a test
  that counts both sides rather than reading the code.

= 1.24.0 =
* New "Blocklists" section on the Chats & reports screen. It lists every block
  currently on file, names both people, and lets the administrator lift one.
* This exists because of the change in 1.23.0: blocks placed from a table chat
  before that release are still stored, and a blocklist entry is a hard
  constraint in the matcher — those two guests are never seated together
  again. A block made with one tap at a shared table can now be reviewed
  rather than staying in force forever.
* Each row states the consequence in plain words and marks a block as mutual
  when both sides have blocked each other, so lifting one direction is not
  mistaken for clearing the pair.
* Lifting removes only that one entry and leaves the guest's other blocks
  intact. The action is nonce-protected, asks for confirmation, and is
  written to the log.

= 1.23.0 =
* Blocking is now offered only in a private conversation. At a shared table it
  made little sense: it would silently tear a hole in a room everybody else
  still sees, between people who were seated together for one sitting rather
  than befriended.
* Reporting is unchanged and available in both kinds of room — at a table it
  is the right tool, since it brings a moderator in without altering the
  conversation for anyone else.
* The same rule is enforced on the server, not just hidden in the interface:
  the block endpoint now refuses a target who is not an accepted friend and
  says why. This matters because the blocklist is a hard constraint in the
  matcher, so blocking a stranger you merely sat beside would quietly shrink
  who the engine can ever seat you with.
* Unaffected: the post-event feedback form still lets you block a table-mate
  after the gathering, which is a considered decision rather than a reaction
  to a single message.

= 1.22.1 =
* Fixed a second, separate way a message could be duplicated. 1.21.0 stopped
  the same row being *displayed* twice; this stops it being *created* twice.
  Tapping a sticker twice before the first request came back posted the emoji
  twice — two real rows, which no amount of display-side de-duplication can
  undo. Typed messages were already safe because the input is cleared the
  moment you send, but a sticker takes its text from the button, so that guard
  never applied to it. The send path now refuses a second write until the
  first settles, and releases the moment it does.
* A message that fails to send is put back in the input instead of being lost.

= 1.22.0 =
* The temporary review behaviour introduced in 1.17.0 is now limited to cafés
  outside Iran. Booking a seat at a café in Iran again does what it always
  should: the guest stays on Explore, and the table forms when the event fills
  or when the cron fallback runs before it starts. Cafés in other countries
  keep seating immediately and opening the chat, so the chat features can
  still be reviewed.
* The decision is made once, on the server, from the country of the café
  hosting the event, and the answer is sent back with the booking. The app
  branches on that value rather than deciding for itself, so the two halves
  cannot disagree and leave a guest looking at an empty chat list for a table
  that was never seated.
* A café whose country cannot be resolved is treated as Iran — the cautious
  side, since it means nothing happens behind the guest's back.
* The `havato_match_immediately` filter now receives the country as a third
  argument, so a site can still override the rule per country.

= 1.21.0 =
* Fixed: every message a guest sent appeared twice. Sending triggered a
  refresh while the three-second poll fired independently; both read the same
  cursor and both appended the same rows. Only one chat request is now in
  flight at a time, and a message id already on screen is never rendered
  again.
* Fixed: the "your table is ready" line showed Persian and English glued
  together with a pipe. System messages are now stored as one string per
  language and the app shows only the active one. Lines written before this
  release still display exactly as they did.
* Chat messages now carry the sender's photo and name. Your own messages and
  system lines stay plain, since there is nothing to identify.
* New sticker tray in the chat. Plain Unicode emoji: nothing to host, no extra
  request, and they render in every WebView. A sticker travels through the
  same endpoint, moderation and archive as any other message.
* New administrator controls on each event: view details, edit, and cancel.
  The detail screen lists the venue, address, table layout and the full guest
  list with attendance. Cancelling sets the status and releases the seats
  rather than deleting anything, so the history stays intact; a confirmation
  names the number of bookings affected first. Capacity is not editable by
  hand because it is derived from the café's real tables.
* Fixed: a café in Turkey priced its menu in Toman. Prices now follow the
  country the café trades in, not the language it is being read in, so an
  Istanbul menu shows Lira even to a Persian-speaking guest. The mapping is
  filterable via `havato_country_currencies`.
* Fixed: the Turkish word for Toman was "Lira", which would have made an
  Iranian café look as though it charged Turkish money.
* Fixed: `join_event` never checked the event status, so a stale tab or a
  direct API call could book a seat at an event that was cancelled or over.
* Fixed: the café owner's events table printed a price cell that no longer
  exists in the schema — a leftover from the payment removal — which shifted
  every column one place against its header.
* Demo menus are now priced per country. The seeder rotated one Toman price
  list across every café, so an Istanbul filter coffee would have been shown
  as 95,000 Lira. Turkish demo cafés carry Lira-sized figures and Turkish
  item names.
* The owner's menu editor now names the currency beside the price column and
  steps by 1 for Lira instead of the 1,000 that suits Toman. The column label
  no longer hard-codes a currency, which used to tell an Iranian owner
  reading the Turkish interface that prices were in Lira.
* Fixed: three admin and café-owner screens labelled a figure "seats left"
  when it was the opposite or something else entirely — "taken / capacity" on
  the event lists, and the total chair count in the café panel. Each now says
  what it means. The guest-facing card, which really does show remaining
  seats, is unchanged.

= 1.20.0 =
* Fixed: on a site that also runs WooCommerce, a café owner who signed in was
  dropped on the shop's "My account" page instead of the owner panel.
  WooCommerce locks every account without `edit_posts`, `manage_woocommerce`
  or `view_admin_dashboard` out of wp-admin, and the `cafe_owner` role
  deliberately holds none of those. Havato now answers WooCommerce's
  `woocommerce_prevent_admin_access` and `woocommerce_disable_admin_bar`
  filters for owners and administrators only. This widens nothing: every
  admin screen outside the owner panel still redirects back to it, so the
  owner sees exactly the five pages they always could.
* Fixed: the administrator could not reach /wp-admin. WordPress answers that
  URL by sending the visitor to wp-login.php with `redirect_to` set, and the
  café-page guard forwarded that to the café portal — so the login form was
  never reachable and the redirect looked like a loop. Any sign-in already
  aimed at wp-admin on this site now goes to WordPress untouched, as do the
  logged-out, `reauth` and interim-login screens.
* The wp-admin exemption is matched on host and path, so an off-site or
  lookalike URL carrying a "/wp-admin/" path cannot use it as an open
  redirect. A bare visit to wp-login.php still goes to the branded café page,
  which is what the guard is for.
* New switch on the Language & region screen turns the wp-login.php redirect
  off entirely. `wp-login.php?havato_admin=1` still works regardless.
* Gatherers are now bounced out of wp-admin at priority 1, before WooCommerce
  runs, so they reach the web-app instead of the shop account page.

= 1.19.0 =
* Removed the notice telling guests that conversations are stored.
* Messages containing offensive language are now flagged for the
  administrator. The flag is completely silent: the message is delivered
  exactly as written, nothing is blocked or altered, and the sender is told
  nothing. Only the admin panel shows the marker.
* The word list covers Persian, English and Turkish and is filterable via
  `havato_profanity_terms`. Matching folds Arabic letter variants, undoes
  letter-for-symbol tricks ("sh1t", "@sshole") and catches deliberately split
  words ("f.u.c.k", "b i t c h"), while ordinary words that merely contain a
  rude substring — "Shitake", "Scunthorpe" — stay clean.
* The Chats & reports screen now opens with a count of flagged messages,
  links straight to a filtered view, highlights flagged rows and shows which
  term matched.
* New "Ban user" control for the administrator, on the chat archive and
  reflected in the WordPress users list. A ban is stored as user meta rather
  than deleting the account, so it is reversible and the person's history
  stays intact for moderation.
* A ban is enforced at three independent points: the login filter, Google
  sign-in (which sets its cookie directly and bypasses that filter), and
  every authenticated REST call, since an already-issued cookie would
  otherwise keep working. Existing sessions are destroyed the moment the ban
  is applied. Administrator accounts cannot be banned from this screen.
* Schema 1.13.0 adds the flag columns to both chat tables.

= 1.18.0 =
* Conversations were already stored on the server; there is now a "Chats &
  reports" screen in the admin menu to read them. It covers both table chats
  and private threads, is searchable and paginated.
* Guests can report a message or block its sender from inside the chat: tap
  any message that is not your own. Reporting asks for a reason; blocking
  asks for confirmation first and also ends the friendship.
* Reports land in a moderation queue. Removing a message blanks its text
  rather than deleting the row, so the rest of the conversation keeps its
  order and context.
* A report is only accepted if the reporter could actually see the message —
  group reports require membership of that group, private reports require
  being one of the two participants — so a guessed message id returns 403.
  One report per person per message, and you cannot report yourself.
* Blocking now also hides the messages that person already posted to a table.
  Previously a block hid them everywhere except the existing chat history.
* The message list returns a cursor so polling advances past filtered
  messages instead of re-requesting them on every poll.
* Guests are told in the app that conversations are stored and may be
  reviewed if reported.
* Fixed: the "col_date" string was referenced in four table headers but never
  defined, so those headers printed the raw key.
* Schema 1.12.0 adds the message_reports table.

= 1.17.0 =
* Fixed "[object Object]" appearing among the behaviour tags. havato_city_label()
  returned the whole city row, which now also carries lat/lng/zoom, and the app
  passed it straight to esc() instead of pick(). Both sides fixed.
* Your own name and behaviour score now appear in the page header; the card
  underneath that repeated them has been removed. Other people's profiles keep
  the card, together with the add-friend button.
* The map opens on the guest's own city. Each city carries its own centre and
  zoom, so an Istanbul guest no longer lands on Tehran; the administrator's
  default is used only when the city is unknown.
* "Prefer not to say" removed from gender. The matcher uses gender for its soft
  balance term, so an opted-out guest never benefited from it. The server now
  rejects any other value rather than storing it.
* New "Delete my account" button in a separate danger zone, with two
  confirmations: an explanation, then typing a word. Removes the profile,
  bookings, photos, friendships, private messages and feedback; group chat
  lines are anonymised rather than deleted so other guests' conversations do
  not develop holes. Administrator accounts are refused.
* The behaviour profile is editable: the test reopens pre-filled with the
  stored answers instead of starting from scratch.
* Interests expanded from 12 to 36, all trilingual.
* TEMPORARY, for review only: after reserving a seat the app now opens the
  chat, and the matcher seats the table immediately instead of waiting for the
  last seat. Both are clearly marked in the code and the server side is behind
  the `havato_match_immediately` filter, so normal behaviour is one line away.

= 1.16.0 =
* Full code and security audit. Two real bugs found and fixed.
* Fixed: a party could be seated at a table smaller than itself. A booking is
  validated against the café's largest table, but the matcher walks the plan
  largest-first and could reach a two-seater while a party of three was still
  unseated. Reproduced with a minimal case, then fixed by re-homing such a
  booking onto a table in the plan that fits and swapping the displaced table
  back in. 10,000 randomised seatings now run with no table over capacity and
  nobody dropped.
* Hardened: free text was sanitised but never length-limited, so chat
  messages, feedback comments, addresses and menu descriptions could each
  write megabytes into a TEXT column on every request. All are now clamped,
  the number of menu items is capped, and menu prices cannot be negative.
* Audited and confirmed correct, with regression tests added for each:
  authorisation on all 48 endpoints, cross-café isolation, group-chat and
  private-chat membership checks, photo ownership, SQL preparation and
  esc_like on search, client-side escaping, CSS-injection resistance of the
  custom theme colour, login and registration throttling, upload allow-list,
  and that no guest-facing payload carries an e-mail or phone number.
* The Persian presentation has been rewritten for this release; every figure
  in it is extracted from the source rather than written by hand.

= 1.15.0 =
* New "Raspberry" theme, taken from a food-delivery reference: vivid pink with
  a violet accent. The reference pink only reaches 4.15:1 on white, so it is
  used as the gradient highlight while a slightly deeper tone (5.71:1) carries
  the white text.
* Turkish is now a full third language — all 298 strings translated, not a
  partial pass with English gaps. The JS bundle is generated from the language
  registry, so a fourth language needs no further wiring.
* Guests who choose Turkey get a Turkish panel by default. It is only a
  default: an explicit language switch is stored per user and always wins.
  The mapping is filterable via `havato_country_languages`.
* The header language button now cycles fa → en → tr and shows the language it
  will switch to; text direction comes from the language table rather than an
  is-it-Persian guess.
* Cafés now provide a contact number in their panel. It is stored normalised
  and shown only to the site administrator — it is added to the private venue
  payload, so it never reaches a guest.
* Fixed the café name and city running together in the map list. The card is
  built from <span>s, and as inline elements the margin, nowrap and ellipsis
  rules were all being ignored; they are block-level now, and the card shows
  the city alongside the address.
* Removed a duplicated `event_theme` string, where the second definition was
  silently overriding the first.
* Schema 1.11.0.

= 1.14.0 =
* Reliability penalties. Not turning up costs behaviour score, and every seat
  a guest reserved but left empty costs more on top — a party of three where
  nobody arrives is charged three times as much as a solo no-show.
* Penalties are stored in their own column, not in rating_score.
  recalculate_rating() rewrites that column wholesale from peer feedback, so a
  penalty written there would have been silently erased by the next review.
  The score shown and matched on is now peer average minus penalties, with a
  configurable floor so nobody can be driven to zero.
* Cafés can record a partial arrival: registrations now store how many of the
  booked seats actually turned up, and the check-in screen offers a picker
  whenever more than one seat was reserved. Older rows keep working from the
  original checked_in flag.
* Three new tunables under Formula weights: no-show penalty, per-empty-seat
  penalty and the score floor.
* Mobile number is now required in the profile details, with the dialling
  code taken from the selected country. Numbers are normalised before being
  stored, so "0912…", "+98912…" and "0098912…" are one number and not three;
  duplicates are rejected. It is only ever visible to the guest themselves and
  the café, never to other guests.
* The neighbourhood field has been removed.
* Schema 1.10.0.

= 1.13.0 =
* Fixed the grey square left behind after tapping a bottom-nav item. It was
  the UA focus ring, which -webkit-tap-highlight-color does not cover because
  it is painted on :focus after the touch ends. Only the pointer-driven ring
  is suppressed; :focus-visible still shows one for keyboard users.
* Bottom-nav labels and solid buttons are now white with a dark halo in every
  theme. Their rules were single-class selectors, so a theme rule targeting
  the bare tag could out-rank them; they are now inside the id-scoped
  dark-surface guard, same as the profile card fixed in 1.9.1.
* "Request a themed seat" is now simply "Reserve a seat".
* A guest can reserve up to 3 seats and bring companions. Tapping the button
  opens a small picker, capped by both HAVATO_MAX_SEATS (filterable via
  havato_max_seats) and the seats actually left.
  - Capacity is now counted in SEATS rather than rows everywhere: explore,
    map, my-events, the admin and owner listings, the matcher's trigger and
    the sign-up stat. One booking is no longer one person.
  - The matcher seats a party together and charges its chairs against the
    table, so a large booking can never overfill a table or be split up.
  - A party bigger than the café's largest single table is refused with a
    clear message, and asking for more seats than remain reports how many
    are left instead of silently seating fewer people.
* Event cards now show the gathering's own title and its theme. The server
  was already sending both; only the card was not rendering them.
* Schema 1.9.0 adds event_registrations.seats.

= 1.12.0 =
* Money is gone from the plugin entirely. Every gathering is free to join and
  nothing anywhere mentions payment, tickets, a wallet, revenue or a payout.
* Removed the WooCommerce integration and the settlement ledger, the admin
  "Revenue & settlements" page, the café "Payout status" page, the profile
  wallet card, the event ticket price, the commission and default-price
  settings, and the payouts table with the order_id/amount/price columns.
* Also removed the pending_payment seat hold and the 30-minute hold expiry:
  with no checkout to wait for, a seat is either taken or free.
* Joining now requires a finished profile instead of a payment — the
  personality test AND the personal details, because the matcher needs the
  answers and events are scoped to the guest's city. A guest who is missing
  either is told which one and sent to the right screen.
* Demo content is free too.
* The café price filter is now an atmosphere filter (Cosy / Everyday /
  Upscale). The stored keys are unchanged, so no migration is needed.
* Café menu prices are kept on purpose: those belong to the café and are shown
  for information only, exactly like the rest of the menu.
* Schema 1.8.0.

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
