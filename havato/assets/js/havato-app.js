/**
 * Havato web-app — single-page controller.
 *
 * Design goals:
 *   • Zero full page reloads (WebView friendly): every navigation is a fetch +
 *     re-render, tab state is mirrored into the History API so the hardware
 *     Back button moves between tabs instead of leaving the app.
 *   • Instant bilingual switch: all strings live in HAVATO_BOOT.i18n, dates and
 *     dates are pre-rendered by PHP in both calendars, so switching language
 *     only re-renders the current view.
 *   • Guests only. The cafe owner panel now lives in wp-admin.
 */
(function () {
	'use strict';

	if (typeof window.HAVATO_BOOT === 'undefined') {
		return;
	}

	var BOOT = window.HAVATO_BOOT;

	/* =====================================================================
	 * State
	 * ================================================================== */
	var S = {
		lang: BOOT.lang || 'fa',
		dir: BOOT.dir || 'rtl',
		loggedIn: !!BOOT.loggedIn,
		role: BOOT.role || 'guest',
		user: null,
		venue: null,
		city: '',        // the viewer's city; results are scoped to it
		tab: null,
		tabs: [],
		data: {},
		authView: 'wall',
		chatMode: 'groups',
		chatRoom: null, // {type:'group'|'private', id}
		viewingUser: 0, // >0 while looking at somebody else's public profile
		returnTab: null,
		pollTimer: null,
		lastMsgId: 0,
		chatFetching: false, // one chat read in flight at a time
		chatSending: false,  // …and one write, so a double-tap cannot post twice
		countdownTimer: null, // ticks on the event page only
		map: null,
		mapMarkers: [],
		meMarker: null,   // "you are here" dot, recreated with each map
		ownerMap: null,
		testStep: 0,
		// The test is psychometric only. Name/age/gender/location live in
		// detailsData and are edited from the profile screen.
		testData: {
			extroversion: 5, talkative: 5, openness: 5, humor: 5,
			energy: 5, planning: 5, empathy: 5,
			vibe: 'fun', interests: []
		},
		detailsData: { name: '', age: 27, gender: '', country: '', city: '', phone: '' },
		booted: false
	};

	var el = {};

	/* =====================================================================
	 * Tiny helpers
	 * ================================================================== */
	function $(sel, root) { return (root || document).querySelector(sel); }
	function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

	// Chat stickers. Plain Unicode emoji rather than images: nothing to host,
	// nothing to upload, no extra request, and they render in every WebView.
	// Deliberately warm and neutral — nothing that could read as an insult or
	// a come-on between strangers who have just met.
	var STICKERS = [
		'😀', '😂', '🙂', '😍', '😎', '🤗',
		'👍', '👏', '🙏', '🤝', '💪', '✌️',
		'☕', '🍰', '🎉', '🔥', '💯', '❤️',
		'😮', '🤔', '😴', '🙈', '🌹', '⭐'
	];

	function t(key) {
		var pack = BOOT.i18n[S.lang] || BOOT.i18n.fa || {};
		return pack[key] !== undefined ? pack[key] : key;
	}

	function pick(value) {
		// Bilingual value objects coming from PHP: {fa:'…', en:'…'}
		if (value && typeof value === 'object' && (value.fa !== undefined || value.en !== undefined)) {
			return value[S.lang] !== undefined ? value[S.lang] : (value.en || value.fa || '');
		}
		return value === undefined || value === null ? '' : value;
	}

	/**
	 * A gathering's date, in the calendar the venue's country actually uses.
	 *
	 * pick() follows the reader's language, which is right for labels and
	 * wrong for a date: a Tehran café prints a Jalali date on its door, and
	 * showing an English reader "Aug 1" for it names a different day from
	 * the one everyone at the table will say out loud. Same reasoning as
	 * prices, which follow the till rather than the interface.
	 */
	function eventDate(ev) {
		if (!ev || !ev.date) { return ''; }
		if ('ir' === String(ev.country || '').toLowerCase()) {
			return ev.date.fa || pick(ev.date);
		}
		return pick(ev.date);
	}

	function eventWeekday(ev) {
		if (!ev || !ev.weekday) { return ''; }
		if ('ir' === String(ev.country || '').toLowerCase()) {
			return ev.weekday.fa || pick(ev.weekday);
		}
		return pick(ev.weekday);
	}

	function esc(str) {
		return String(str === undefined || str === null ? '' : str)
			.replace(/&/g, '&amp;')
			.replace(/</g, '&lt;')
			.replace(/>/g, '&gt;')
			.replace(/"/g, '&quot;')
			.replace(/'/g, '&#39;');
	}

	function num(value) {
		var out = String(value);
		if (S.lang !== 'fa') { return out; }
		var fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
		return out.replace(/[0-9]/g, function (d) { return fa[+d]; });
	}

	function icon(id, cls) {
		return '<svg class="' + (cls || '') + '" aria-hidden="true"><use href="#hv-i-' + id + '"></use></svg>';
	}

	function initials(name) {
		var clean = String(name || 'H').trim();
		return clean ? clean.charAt(0).toUpperCase() : 'H';
	}

	/* =====================================================================
	 * REST client
	 * ================================================================== */
	function api(path, options) {
		options = options || {};

		var url = BOOT.rest + '/' + path.replace(/^\//, '');
		var params = options.params || {};
		params.lang = S.lang;

		var query = Object.keys(params)
			.filter(function (k) { return params[k] !== undefined && params[k] !== null; })
			.map(function (k) { return encodeURIComponent(k) + '=' + encodeURIComponent(params[k]); })
			.join('&');

		if (query) { url += (url.indexOf('?') === -1 ? '?' : '&') + query; }

		var init = {
			method: options.method || 'GET',
			credentials: 'same-origin',
			headers: { 'X-WP-Nonce': BOOT.nonce }
		};

		if (options.body instanceof FormData) {
			init.body = options.body;
		} else if (options.body) {
			init.headers['Content-Type'] = 'application/json';
			init.body = JSON.stringify(options.body);
		}

		// fetch() cannot report upload progress, so file uploads go through
		// XHR instead — that is the only way to get real byte-level percentages
		// rather than a fake animation. Everything else stays on fetch.
		if (options.onProgress && options.body instanceof FormData) {
			return apiUpload(url, options);
		}

		return fetch(url, init).then(function (res) {
			return res.json().catch(function () { return {}; }).then(function (json) {
				if (!res.ok) {
					var err = new Error((json && json.message) || t('error_generic'));
					err.data = json;
					err.status = res.status;
					throw err;
				}
				return json;
			});
		});
	}

	/**
	 * XHR-based POST used for file uploads so we can report real progress.
	 *
	 * Resolves/rejects exactly like the fetch path in api(), so callers do not
	 * need to know which transport was used.
	 *
	 * @param {string} url     Absolute REST URL.
	 * @param {object} options { body: FormData, onProgress(percent|null) }
	 */
	function apiUpload(url, options) {
		return new Promise(function (resolve, reject) {
			var xhr = new XMLHttpRequest();
			xhr.open(options.method || 'POST', url, true);
			xhr.withCredentials = true;
			xhr.setRequestHeader('X-WP-Nonce', BOOT.nonce);

			if (xhr.upload) {
				xhr.upload.onprogress = function (event) {
					if (!event.lengthComputable) {
						options.onProgress(null); // unknown size -> indeterminate
						return;
					}
					// Cap the transfer at 95%: the last 5% represents the server
					// still resizing/storing the image after the bytes landed.
					var pct = Math.round((event.loaded / event.total) * 95);
					options.onProgress(Math.max(1, Math.min(95, pct)));
				};
				// Bytes are away; WordPress is now generating thumbnails.
				xhr.upload.onload = function () { options.onProgress(97); };
			}

			xhr.onload = function () {
				var json = {};
				try { json = JSON.parse(xhr.responseText) || {}; } catch (e) { json = {}; }

				if (xhr.status >= 200 && xhr.status < 300) {
					options.onProgress(100);
					resolve(json);
					return;
				}
				var err = new Error(json.message || t('error_generic'));
				err.data = json;
				err.status = xhr.status;
				reject(err);
			};

			xhr.onerror = function () { reject(new Error(t('error_generic'))); };
			xhr.ontimeout = function () { reject(new Error(t('error_generic'))); };
			xhr.onabort = function () {
				var err = new Error(t('upload_cancelled'));
				err.aborted = true;
				reject(err);
			};

			// Let the caller cancel a slow upload.
			if (options.onStart) { options.onStart(xhr); }

			xhr.send(options.body);
		});
	}

	/* =====================================================================
	 * UI primitives
	 * ================================================================== */
	function toast(message, kind) {
		var host = el.toastHost;
		if (!host) { return; }
		var node = document.createElement('div');
		node.className = 'hv-toast is-' + (kind || 'info');
		node.textContent = message;
		host.appendChild(node);
		setTimeout(function () {
			node.style.opacity = '0';
			node.style.transform = 'translateY(-8px)';
			node.style.transition = 'all .25s ease';
			setTimeout(function () { node.remove(); }, 260);
		}, 2800);
	}

	/**
	 * Full-width progress overlay used by uploads and saves.
	 *
	 * show(label)            -> open, indeterminate
	 * set(percent|null)      -> null keeps it indeterminate
	 * done(okMessage) / fail(message)
	 */
	var progress = (function () {
		var host = null;
		var bar = null;
		var pctEl = null;
		var labelEl = null;
		var cancelEl = null;
		var hideTimer = null;
		var xhr = null;

		function build() {
			if (host) { return; }
			host = document.createElement('div');
			host.className = 'hv-progress-host';
			host.innerHTML =
				'<div class="hv-progress-card">' +
					'<div class="hv-progress-top">' +
						'<span class="hv-progress-label"></span>' +
						'<span class="hv-progress-pct"></span>' +
					'</div>' +
					'<div class="hv-progress-track"><span class="hv-progress-fill"></span></div>' +
					'<button type="button" class="hv-progress-cancel"></button>' +
				'</div>';
			el.root.appendChild(host);

			bar = host.querySelector('.hv-progress-fill');
			pctEl = host.querySelector('.hv-progress-pct');
			labelEl = host.querySelector('.hv-progress-label');
			cancelEl = host.querySelector('.hv-progress-cancel');

			cancelEl.onclick = function () {
				if (xhr) { xhr.abort(); }
			};
		}

		return {
			show: function (label, cancellable) {
				build();
				clearTimeout(hideTimer);
				xhr = null;
				host.className = 'hv-progress-host is-open';
				labelEl.textContent = label || t('uploading');
				pctEl.textContent = '';
				bar.style.width = '0%';
				bar.classList.add('is-indeterminate');
				cancelEl.textContent = t('cancel');
				cancelEl.hidden = !cancellable;
			},
			attach: function (activeXhr) { xhr = activeXhr; },
			set: function (percent) {
				if (!host) { return; }
				if (percent === null || percent === undefined) {
					bar.classList.add('is-indeterminate');
					pctEl.textContent = '';
					return;
				}
				bar.classList.remove('is-indeterminate');
				bar.style.width = percent + '%';
				pctEl.textContent = num(percent) + (S.lang === 'fa' ? '٪' : '%');
			},
			done: function (message) {
				if (!host) { return; }
				xhr = null;
				bar.classList.remove('is-indeterminate');
				bar.style.width = '100%';
				host.classList.add('is-done');
				labelEl.textContent = message || t('saved');
				pctEl.textContent = num(100) + (S.lang === 'fa' ? '٪' : '%');
				cancelEl.hidden = true;
				hideTimer = setTimeout(function () {
					host.className = 'hv-progress-host';
				}, 900);
			},
			fail: function (message) {
				if (!host) { return; }
				xhr = null;
				host.classList.add('is-error');
				labelEl.textContent = message || t('error_generic');
				cancelEl.hidden = true;
				hideTimer = setTimeout(function () {
					host.className = 'hv-progress-host';
				}, 2200);
			},
			hide: function () {
				if (!host) { return; }
				xhr = null;
				clearTimeout(hideTimer);
				host.className = 'hv-progress-host';
			}
		};
	})();

	/**
	 * Upload a file with a live progress bar.
	 *
	 * @param {string}   path     REST path.
	 * @param {File}     file     The chosen file.
	 * @param {string}   label    Progress label.
	 * @returns {Promise}
	 */
	function uploadWithProgress(path, file, label) {
		var form = new FormData();
		form.append('file', file);

		progress.show(label || t('uploading'), true);

		return api(path, {
			method: 'POST',
			body: form,
			onStart: progress.attach,
			onProgress: progress.set
		});
	}

	/**
	 * Shared failure handler for uploads: a user-initiated cancel is not an
	 * error, so it dismisses the bar quietly instead of showing a red state.
	 */
	function uploadFailed(err) {
		if (err && err.aborted) {
			progress.hide();
			toast(t('upload_cancelled'), 'info');
			return;
		}
		progress.fail(err && err.message ? err.message : t('error_generic'));
	}

	/**
	 * Wrap any save request in the same progress bar (indeterminate, since a
	 * JSON POST has no meaningful byte progress).
	 *
	 * @param {Promise} request  The api() promise.
	 * @param {string}  label    Optional label.
	 */
	function saveWithProgress(request, label) {
		progress.show(label || t('saving'), false);
		return request.then(function (res) {
			progress.done(t('saved'));
			return res;
		}).catch(function (err) {
			progress.fail(err && err.message ? err.message : t('error_generic'));
			throw err;
		});
	}

	function openModal(html) {
		el.modalBody.innerHTML = html;
		el.modalHost.hidden = false;
		el.modalHost.querySelector('.hv-modal-card').scrollTop = 0;
	}

	function closeModal() {
		// The event page runs a one-second timer. Closing the modal destroys
		// the node it writes into, so the interval has to go with it or it
		// keeps firing against nothing for the rest of the session.
		stopCountdown();
		el.modalHost.hidden = true;
		el.modalBody.innerHTML = '';
	}

	function setStatusStrip(text, kind) {
		if (!el.strip) { return; }
		if (!text) {
			el.strip.hidden = true;
			el.strip.className = 'hv-status-strip';
			el.strip.innerHTML = '';
			return;
		}
		el.strip.hidden = false;
		el.strip.className = 'hv-status-strip hv-strip-' + (kind || 'blue');
		el.strip.innerHTML = '<span class="hv-strip-dot"></span><span>' + esc(text) + '</span>';
	}

	function setHeader(title, eyebrow) {
		el.headerTitle.textContent = title || t('app_name');
		el.headerEyebrow.textContent = eyebrow || '';
	}

	function loading() {
		el.main.innerHTML = '<div class="hv-boot-loader"><div class="hv-spinner"></div></div>';
	}

	function emptyState(text, iconId) {
		return '<div class="hv-empty">' + icon(iconId || 'explore') + '<p>' + esc(text || t('empty_state')) + '</p></div>';
	}

	/** Atmosphere label. The stored keys are historical. */
	function budgetLabel(tier) {
		if (tier === 'low') { return t('budget_low'); }
		if (tier === 'high') { return t('budget_high'); }
		return t('budget_medium');
	}

	function statusBadge(status) {
		var map = {
			open: ['green', t('status_open')],
			matched: ['blue', t('status_matched')],
			completed: ['gray', t('status_completed')],
			pending_admin: ['orange', t('status_pending_admin')]
		};
		var conf = map[status] || map.open;
		return '<span class="hv-badge hv-badge-' + conf[0] + '">' + esc(conf[1]) + '</span>';
	}

	/* =====================================================================
	 * Language switching (instant, no reload)
	 * ================================================================== */

	// Order defines the cycle of the header button. `dir` drives the RTL flip.
	var LANGS = [
		{ code: 'fa', dir: 'rtl', short: 'فا', name: 'فارسی' },
		{ code: 'en', dir: 'ltr', short: 'EN', name: 'English' },
		{ code: 'tr', dir: 'ltr', short: 'TR', name: 'Türkçe' }
	];

	function langInfo(code) {
		for (var i = 0; i < LANGS.length; i++) {
			if (LANGS[i].code === code) { return LANGS[i]; }
		}
		return LANGS[0];
	}

	/**
	 * The button used to show the language it would switch TO, because one tap
	 * cycled. It opens a list now, so it shows the language you are actually
	 * reading — which is what a closed dropdown is expected to display.
	 */
	function nextLang(code) {
		for (var i = 0; i < LANGS.length; i++) {
			if (LANGS[i].code === code) { return LANGS[(i + 1) % LANGS.length]; }
		}
		return LANGS[1];
	}

	function setLangAttrs(lang) {
		var info = langInfo(lang);
		S.lang = info.code;
		S.dir = info.dir;
		el.root.setAttribute('dir', S.dir);
		el.root.setAttribute('data-lang', S.lang);
		el.root.classList.toggle('hv-dir-rtl', S.dir === 'rtl');
		el.root.classList.toggle('hv-dir-ltr', S.dir === 'ltr');
		if (el.langLabel) { el.langLabel.textContent = info.short; }
		renderLangMenu();
	}

	/** Fill the dropdown and mark the active entry. */
	function renderLangMenu() {
		if (!el.langMenu) { return; }

		el.langMenu.innerHTML = LANGS.map(function (lang) {
			var active = lang.code === S.lang;
			return '<li role="option" aria-selected="' + (active ? 'true' : 'false') + '">' +
				'<button type="button" class="hv-lang-option' + (active ? ' is-active' : '') + '" ' +
					'data-lang="' + esc(lang.code) + '" dir="' + esc(lang.dir) + '">' +
					'<span>' + esc(lang.name) + '</span>' +
					(active ? '<span aria-hidden="true">✓</span>' : '') +
				'</button></li>';
		}).join('');

		$$('[data-lang]', el.langMenu).forEach(function (btn) {
			btn.onclick = function () {
				closeLangMenu();
				// Re-rendering while the same language is already active would
				// throw away the current screen for nothing.
				if (btn.dataset.lang === S.lang) { return; }
				chooseLang(btn.dataset.lang);
			};
		});
	}

	function openLangMenu() {
		if (!el.langMenu) { return; }
		el.langMenu.hidden = false;
		el.langBtn.setAttribute('aria-expanded', 'true');
		el.langBtn.classList.add('is-open');
	}

	function closeLangMenu() {
		if (!el.langMenu) { return; }
		el.langMenu.hidden = true;
		el.langBtn.setAttribute('aria-expanded', 'false');
		el.langBtn.classList.remove('is-open');
	}

	function toggleLangMenu() {
		if (el.langMenu && el.langMenu.hidden) { openLangMenu(); } else { closeLangMenu(); }
	}

	function applyLang(lang) {
		setLangAttrs(lang);
		document.cookie = 'havato_lang=' + S.lang + ';path=/;max-age=31536000;samesite=lax';
		buildTabs();
		render();
	}

	function chooseLang(code) {
		applyLang(code);
		api('lang', { method: 'POST', body: { value: code } }).catch(function () {});
	}

	/** Kept for the auth wall, which has no room for a dropdown. */
	function toggleLang() {
		chooseLang(nextLang(S.lang).code);
	}

	/* =====================================================================
	 * Tabs & routing
	 * ================================================================== */
	function tabsFor(role) {
		// nav-* icons are the monochrome variants: they paint with
		// currentColor so the tab state (translucent vs solid white) actually
		// drives them on the dark indigo bar.
		//
		// Five tabs since v1.31.0. Home took over from the round floating
		// button, which changed meaning per tab and said nothing about what
		// it would do. Map is no longer a tab of its own — it is a sub-tab of
		// Explore, so the two ways of browsing the same tables sit together.
		return [
			{ id: 'home', label: 'tab_home', icon: 'nav-dashboard' },
			{ id: 'explore', label: 'tab_explore', icon: 'nav-explore' },
			{ id: 'tables', label: 'tab_my_tables', icon: 'nav-calendar' },
			{ id: 'chats', label: 'tab_chats', icon: 'nav-chat' },
			{ id: 'profile', label: 'tab_profile', icon: 'nav-profile' }
		];
	}

	/**
	 * Views that are reachable but own no tab of their own.
	 *
	 * The map is browsed from inside Explore, so it has to be routable while
	 * lighting up the Explore tab rather than none of them.
	 */
	var TAB_ALIASES = { map: 'explore' };

	function navTabFor(id) {
		return TAB_ALIASES[id] || id;
	}

	function buildTabs() {
		S.tabs = tabsFor(S.role);
		if (!S.tab || !isRoutable(S.tab)) {
			S.tab = S.tabs[0].id;
		}

		var active = navTabFor(S.tab);

		el.tabs.innerHTML = S.tabs.map(function (tab) {
			return '<button type="button" class="hv-tab' + (tab.id === active ? ' is-active' : '') +
				'" data-tab="' + tab.id + '" role="tab">' +
				icon(tab.icon) + '<span>' + esc(t(tab.label)) + '</span></button>';
		}).join('');
	}

	function isRoutable(id) {
		if (TAB_ALIASES[id]) { return true; }
		return S.tabs.some(function (tab) { return tab.id === id; });
	}

	function setTab(id, push) {
		if (!isRoutable(id)) { return; }
		S.tab = id;
		S.chatRoom = null;
		if ('profile' !== id) { S.viewingUser = 0; }
		stopPolling();

		var active = navTabFor(id);
		$$('.hv-tab', el.tabs).forEach(function (btn) {
			btn.classList.toggle('is-active', btn.dataset.tab === active);
		});

		if (push !== false) {
			try {
				history.pushState({ havatoTab: id }, '', '#hv-' + id);
			} catch (e) { /* WebView without history support */ }
		}

		el.main.scrollTop = 0;
		render();
	}

	function initHistory() {
		window.addEventListener('popstate', function (event) {
			// Never let the hardware Back button leave the web-app.
			if (!el.modalHost.hidden) {
				closeModal();
				history.pushState({ havatoTab: S.tab }, '', '#hv-' + S.tab);
				return;
			}
			if (S.chatRoom) {
				S.chatRoom = null;
				stopPolling();
				render();
				history.pushState({ havatoTab: S.tab }, '', '#hv-' + S.tab);
				return;
			}
			var state = event.state;
			if (state && state.havatoTab) {
				setTab(state.havatoTab, false);
			} else if (S.tab !== S.tabs[0].id) {
				setTab(S.tabs[0].id, false);
			} else {
				history.pushState({ havatoTab: S.tab }, '', '#hv-' + S.tab);
			}
		});

		var hash = (window.location.hash || '').replace('#hv-', '');
		if (hash) { S.tab = hash; }
		try {
			history.replaceState({ havatoTab: S.tab }, '', '#hv-' + S.tab);
		} catch (e) { /* noop */ }
	}

	/* =====================================================================
	 * Header action + dashboard button
	 *
	 * The round button in the bottom bar used to change meaning with every
	 * tab, with nothing on screen saying what it would do. That per-tab
	 * action now lives in the header, next to the language switch, and the
	 * round button has one fixed job: open the guest's dashboard.
	 * ================================================================== */
	function updateHeaderAction() {
		var conf = {
			explore: { icon: 'filter', label: 'filter', action: showFilters },
			map: { icon: 'map', label: 'locate_me', action: locateMe },
			chats: { icon: 'chat', label: 'chats_title', action: function () { S.chatRoom = null; render(); } },
			profile: { icon: 'plus', label: 'upload_photo', action: pickGalleryPhoto }
		}[S.tab];

		if (!el.headerAction) { return; }

		if (!conf || !S.loggedIn) {
			el.headerAction.hidden = true;
			el.headerAction.onclick = null;
			return;
		}

		el.headerAction.hidden = false;
		el.headerAction.querySelector('use').setAttribute('href', '#hv-i-' + conf.icon);
		// The icon alone is not self-explanatory, so give it a real label for
		// screen readers and a tooltip for everyone else.
		el.headerAction.setAttribute('aria-label', t(conf.label));
		el.headerAction.title = t(conf.label);
		el.headerAction.onclick = conf.action;
	}


	/* =====================================================================
	 * Renderer
	 * ================================================================== */
	function render() {
		if (!S.loggedIn) {
			renderAuthWall();
			return;
		}
		if (el.authwall) {
			el.authwall.remove();
			el.authwall = null;
		}

		el.bottomNav.style.display = '';
		el.header.style.display = '';
		updateHeaderAction();
		renderHeaderUser();
		loadTab(false);
	}

	function renderHeaderUser() {
		var user = S.user;
		if (user && user.avatar) {
			el.headerAvatar.src = user.avatar;
			el.headerAvatar.hidden = false;
			el.avatarFallback.hidden = true;
		} else {
			el.headerAvatar.hidden = true;
			el.avatarFallback.hidden = false;
			el.avatarFallback.textContent = initials(user ? user.name : 'H');
		}
	}

	function loadTab(force) {
		var tab = S.tab;
		loading();

		var loaders = {
			home: viewHome,
			explore: viewExplore,
			// Reachable as a sub-tab of Explore, and still routable directly
			// so an old bookmark to #hv-map keeps working.
			map: viewMap,
			tables: viewMyTables,
			chats: viewChats,
			profile: viewProfile
		};

		var fn = loaders[tab] || viewHome;
		fn(force).catch(function (err) {
			el.main.innerHTML = emptyState(err.message || t('error_generic'));
		});
	}

	/* =====================================================================
	 * AUTH WALL
	 * ================================================================== */
	function renderAuthWall() {
		el.bottomNav.style.display = 'none';
		el.header.style.display = 'none';
		setStatusStrip('');

		if (!el.authwall) {
			el.authwall = document.createElement('div');
			el.authwall.className = 'hv-authwall';
			el.root.appendChild(el.authwall);
		}

		var body;
		body = authWallMarkup();

		el.authwall.innerHTML =
			'<button type="button" class="hv-lang-btn hv-auth-lang" id="hv-auth-lang">' +
				nextLang(S.lang).short +
			'</button>' + body;

		$('#hv-auth-lang').onclick = toggleLang;
		bindAuthEvents();
	}

	function authWallMarkup() {
		var googleBlock;

		if (BOOT.googleReady) {
			// The official Google Identity button renders into the slot. The
			// custom button is only a FALLBACK for when the SDK is blocked or
			// slow (common in Iran), so it stays hidden until initGoogle()
			// decides it is needed — otherwise the user sees two sign-in
			// buttons stacked on top of each other.
			googleBlock =
				'<div class="hv-google-slot" id="hv-google-slot"></div>' +
				'<button type="button" class="hv-btn hv-btn-google hv-btn-block" id="hv-google-fallback" hidden>' +
					icon('google') + '<span>' + esc(t('login_google')) + '</span>' +
				'</button>';
		} else {
			googleBlock =
				'<div class="hv-alert hv-alert-orange" style="text-align:start">' +
					esc(t('google_not_configured')) +
				'</div>';
		}

		// NOTE: the auth wall deliberately carries NO café-owner link. Owners
		// reach their portal directly at the [havato_owner_auth] page (and
		// wp-login.php redirects them there), so surfacing a second door on
		// the guest screen only confused gatherers.
		return '' +
			'<div class="hv-auth-card hv-glass">' +
				'<div class="hv-auth-logo">' + icon('cup') + '</div>' +
				'<h2 class="hv-auth-title">' + esc(t('auth_title')) + '</h2>' +
				'<p class="hv-auth-sub">' + esc(t('auth_sub')) + '</p>' +
				'<h3 class="hv-auth-heading">' + esc(t('user_login_heading')) + '</h3>' +
				googleBlock +
			'</div>';
	}





	function bindAuthEvents() {
		$$('[data-auth]', el.authwall).forEach(function (btn) {
			btn.onclick = function () {
				S.authView = btn.dataset.auth;
				renderAuthWall();
			};
		});

		var fallback = $('#hv-google-fallback');
		if (fallback) {
			fallback.onclick = function () {
				if (window.google && window.google.accounts && window.google.accounts.id) {
					window.google.accounts.id.prompt();
				} else {
					toast(t('google_not_configured'), 'error');
				}
			};
		}

		if (BOOT.googleReady) { initGoogle(); }
	}

	/**
	 * Reveal the custom Google button. Only called when the official Identity
	 * Services button could not be rendered, so the two never appear together.
	 */
	function showGoogleFallback() {
		var fallback = $('#hv-google-fallback');
		if (fallback) { fallback.hidden = false; }
	}

	function initGoogle() {
		var tries = 0;
		(function wait() {
			if (window.google && window.google.accounts && window.google.accounts.id) {
				try {
					window.google.accounts.id.initialize({
						client_id: BOOT.googleClient,
						callback: onGoogleCredential,
						ux_mode: 'popup',
						auto_select: false
					});
					var slot = $('#hv-google-slot');
					if (!slot) { return; }

					window.google.accounts.id.renderButton(slot, {
						theme: 'filled_blue',
						size: 'large',
						shape: 'pill',
						width: Math.min(340, Math.floor(slot.getBoundingClientRect().width || 300)),
						locale: S.lang === 'fa' ? 'fa' : 'en'
					});

					// renderButton() is asynchronous and fails silently when the
					// iframe is blocked, so confirm something was actually
					// painted before trusting it.
					setTimeout(function () {
						if (!slot.firstChild || slot.getBoundingClientRect().height < 10) {
							showGoogleFallback();
						}
					}, 1200);
				} catch (e) {
					showGoogleFallback();
				}
				return;
			}
			// SDK never loaded (blocked / offline): offer the manual button.
			if (tries++ < 40) {
				setTimeout(wait, 150);
			} else {
				showGoogleFallback();
			}
		})();
	}

	function onGoogleCredential(response) {
		if (!response || !response.credential) { return; }
		api('auth/google', { method: 'POST', body: { credential: response.credential } })
			.then(function (res) {
				S.loggedIn = true;
				S.user = res.user;
				S.role = res.role || 'gatherer';
				S.tab = null;
				buildTabs();
				render();
			})
			.catch(function (err) { toast(err.message, 'error'); });
	}

	/* =====================================================================
	 * TAB: HOME
	 *
	 * The landing screen: the guest's next table in full, then a horizontal
	 * rail of tables to discover, then the shortcuts. Everything here is a
	 * summary — each card leads to the screen that owns the detail.
	 * ================================================================== */
	function viewHome() {
		setHeader(t('home_greeting').replace('%s', (S.user && S.user.name) || ''), t('app_name'));
		setStatusStrip('');

		// One request each: the dashboard already knows the guest's bookings,
		// and Explore knows what is open. Asking in parallel keeps the screen
		// from drawing in two stages.
		return Promise.all([
			api('dashboard').catch(function () { return {}; }),
			api('events').catch(function () { return {}; })
		]).then(function (res) {
			var dash = res[0] || {};
			var events = (res[1] && res[1].events) || [];

			S.data.dashboard = dash;
			S.data.events = events;

			var next = (dash.upcoming || [])[0] || null;

			// Tables the guest has not already booked — no point offering a
			// seat they are already holding.
			var discover = events.filter(function (ev) { return !ev.joined; }).slice(0, 8);

			el.main.innerHTML =
				(next
					? '<h3 class="hv-home-title">' + esc(t('home_next_table')) + '</h3>' +
						nextTableCard(next)
					: '<h3 class="hv-home-title">' + esc(t('home_next_table')) + '</h3>' +
						'<div class="hv-card hv-home-empty">' +
							'<p class="hv-muted">' + esc(t('dash_no_events')) + '</p>' +
							'<button type="button" class="hv-btn hv-btn-primary hv-btn-sm hv-mt" data-go-explore>' +
								esc(t('tab_explore')) + '</button>' +
						'</div>') +

				'<div class="hv-home-head">' +
					'<h3 class="hv-home-title">' + esc(t('home_discover')) + '</h3>' +
					'<button type="button" class="hv-home-viewall" data-go-explore>' +
						esc(t('view_all')) + ' ›</button>' +
				'</div>' +
				(discover.length
					? '<div class="hv-rail">' + discover.map(discoverTile).join('') + '</div>'
					: '<p class="hv-muted">' + esc(S.city ? t('city_empty') : t('explore_empty')) + '</p>') +

				'<div class="hv-quick">' +
					'<button type="button" class="hv-quick-btn" data-quick="suggest">' +
						icon('plus') + '<span>' + esc(t('suggest_event')) + '</span></button>' +
					'<button type="button" class="hv-quick-btn" data-quick="tables">' +
						icon('calendar') + '<span>' + esc(t('tab_my_tables')) + '</span></button>' +
					'<button type="button" class="hv-quick-btn" data-quick="chats">' +
						icon('chat') + '<span>' + esc(t('tab_chats')) + '</span></button>' +
				'</div>';

			$$('[data-go-explore]').forEach(function (b) {
				b.onclick = function () { setTab('explore'); };
			});
			$$('[data-open-event]').forEach(function (node) {
				node.onclick = function () { openEvent(node.dataset.openEvent); };
			});
			$$('[data-quick]').forEach(function (b) {
				b.onclick = function () {
					if ('suggest' === b.dataset.quick) {
						openSuggestEvent((S.data.dashboard && S.data.dashboard.venues) || []);
						return;
					}
					setTab(b.dataset.quick);
				};
			});
		});
	}

	/**
	 * The row of faces already coming, plus a "+N" for the rest.
	 *
	 * Overlapping circles, so a full table still fits the width of a card.
	 */
	function faceStack(ev) {
		var faces = (ev.faces && ev.faces.avatars) || [];
		var total = (ev.faces && ev.faces.total) || 0;
		if (!faces.length) { return ''; }

		var extra = total - faces.length;

		return '<div class="hv-faces">' +
			faces.map(function (src) {
				return '<span class="hv-face"><img src="' + esc(src) + '" alt="" loading="lazy"></span>';
			}).join('') +
			(extra > 0 ? '<span class="hv-face is-more">+' + num(extra) + '</span>' : '') +
		'</div>';
	}

	/**
	 * The event card, laid out in the order the information is read:
	 * what it is, when, where, and who is already going.
	 */
	function nextTableCard(ev) {
		var subject = (ev.title && String(ev.title).trim()) || ev.theme || '';
		var cover = ev.image
			? '<img src="' + esc(ev.image) + '" alt="">'
			: icon('cup');

		return '' +
			'<article class="hv-next-card" data-open-event="' + esc(ev.id) + '">' +
				'<div class="hv-next-cover">' + cover + '</div>' +
				'<div class="hv-next-body">' +

					// 1. the name of the gathering
					'<h4 class="hv-next-name">' + esc(subject || pick(ev.venue)) + '</h4>' +

					// 2. weekday, date and time on one line
					'<div class="hv-next-row">' +
						icon('calendar', 'hv-next-icon') +
						'<span>' + esc(eventWeekday(ev)) + ' · ' + esc(eventDate(ev)) +
							' · ' + num(ev.time) + '</span>' +
					'</div>' +

					// 3. the café and its address
					'<div class="hv-next-row">' +
						icon('map', 'hv-next-icon') +
						'<span>' + esc(pick(ev.venue)) +
							(ev.address ? '، ' + esc(ev.address) : '') + '</span>' +
					'</div>' +

					// 4. who has already taken a seat
					faceStack(ev) +

					'<div class="hv-next-foot">' +
						'<span class="hv-badge hv-badge-green">' + esc(t('joined_event')) + '</span>' +
						(ev.my_seats > 1
							? '<span class="hv-muted">' + esc(t('seats_booked').replace('%s', num(ev.my_seats))) + '</span>'
							: '') +
					'</div>' +
				'</div>' +
			'</article>';
	}

	/** One tile in the horizontal Discover rail. */
	function discoverTile(ev) {
		var subject = (ev.title && String(ev.title).trim()) || ev.theme || '';
		var full = ev.seats_left <= 0;

		return '' +
			'<article class="hv-tile">' +
				'<div class="hv-tile-top">' +
					(ev.image
						? '<img class="hv-tile-img" src="' + esc(ev.image) + '" alt="">'
						: '<span class="hv-tile-img is-empty">' + icon('cup') + '</span>') +
				'</div>' +
				'<div class="hv-tile-body">' +
					'<h4 class="hv-tile-title">' + esc(subject || pick(ev.venue)) + '</h4>' +
					'<div class="hv-tile-meta">' +
						esc(eventWeekday(ev)) + ' · ' + esc(eventDate(ev)) + ' · ' + num(ev.time) +
					'</div>' +
					'<div class="hv-tile-meta">' + esc(pick(ev.venue)) + '</div>' +
					faceStack(ev) +
					(full
						? '<button type="button" class="hv-btn hv-btn-ghost hv-btn-sm hv-tile-btn" disabled>' +
							esc(t('event_full')) + '</button>'
						: '<button type="button" class="hv-btn hv-btn-primary hv-btn-sm hv-tile-btn" ' +
							'data-open-event="' + esc(ev.id) + '">' + esc(t('join_event')) + '</button>') +
				'</div>' +
			'</article>';
	}

	/* =====================================================================
	 * TAB: MY TABLES
	 * ================================================================== */
	function viewMyTables() {
		setHeader(t('tab_my_tables'), t('app_name'));
		setStatusStrip('');

		return api('dashboard').then(function (res) {
			S.data.dashboard = res;
			var upcoming = res.upcoming || [];
			var requests = res.requests || [];

			el.main.innerHTML =
				'<h3 class="hv-home-title">' + esc(t('dash_upcoming')) + '</h3>' +
				(upcoming.length
					? upcoming.map(nextTableCard).join('')
					: '<div class="hv-card"><p class="hv-muted">' + esc(t('dash_no_events')) + '</p></div>') +

				'<button type="button" class="hv-btn hv-btn-primary hv-btn-block hv-mt" data-quick="suggest">' +
					esc(t('suggest_event')) + '</button>' +

				(requests.length
					? '<h3 class="hv-home-title hv-mt">' + esc(t('dash_requests')) + '</h3>' +
						requests.map(function (rq) {
							var badge = 'hv-badge-orange';
							if ('accepted' === rq.status) { badge = 'hv-badge-green'; }
							if ('declined' === rq.status) { badge = 'hv-badge-gray'; }
							return '<div class="hv-dash-request">' +
								'<div>' +
									'<div class="hv-dash-event-name">' + esc(rq.venue) + '</div>' +
									'<div class="hv-dash-event-when">' + esc(rq.subject) + ' · ' +
										esc(pick(rq.date)) + ' · ' + num(rq.time) + '</div>' +
								'</div>' +
								'<span class="hv-badge ' + badge + '">' + esc(t('request_' + rq.status)) + '</span>' +
							'</div>';
						}).join('')
					: '');

			$$('[data-open-event]').forEach(function (node) {
				node.onclick = function () { openEvent(node.dataset.openEvent); };
			});
			$$('[data-quick]').forEach(function (b) {
				b.onclick = function () { openSuggestEvent(res.venues || []); };
			});
		});
	}

	/* =====================================================================
	 * TAB: EXPLORE
	 *
	 * The map used to be a tab of its own. It is the same set of tables seen
	 * a different way, so it lives here as a sub-tab instead of costing a
	 * slot in a nav bar that now has five.
	 * ================================================================== */
	function exploreSubtabs(active) {
		return '<div class="hv-subtabs">' +
			'<button type="button" class="hv-subtab' + ('list' === active ? ' is-active' : '') +
				'" data-exploreview="list">' + esc(t('tab_explore')) + '</button>' +
			'<button type="button" class="hv-subtab' + ('map' === active ? ' is-active' : '') +
				'" data-exploreview="map">' + esc(t('tab_map')) + '</button>' +
		'</div>';
	}

	function bindExploreSubtabs() {
		$$('[data-exploreview]').forEach(function (btn) {
			btn.onclick = function () {
				// Routed through setTab so the Back button and the address
				// hash stay in step with what is on screen.
				setTab('map' === btn.dataset.exploreview ? 'map' : 'explore');
			};
		});
	}

	function viewExplore() {
		setHeader(t('explore_title'), t('app_name'));
		setStatusStrip('');

		var params = {};
		if (S.data.exploreFilter) { params.budget = S.data.exploreFilter; } // atmosphere tier

		return api('events', { params: params }).then(function (res) {
			S.data.events = res.events || [];

			if (!S.data.events.length) {
				// Results are scoped to the user's city, so say so. The
				// sub-tabs stay, or there would be no way back to the map.
				el.main.innerHTML = exploreSubtabs('list') +
					emptyState(S.city ? t('city_empty') : t('explore_empty'), 'explore');
				bindExploreSubtabs();
				return;
			}

			el.main.innerHTML =
				exploreSubtabs('list') +
				'<div class="hv-section">' +
					S.data.events.map(eventCard).join('') +
				'</div>';

			bindExploreSubtabs();

			$$('[data-event-join]').forEach(function (btn) {
				// Opens the event's own page. Booking a seat is a commitment
				// with a no-show penalty attached, so the guest should be able
				// to read what the evening is, see the café and its menu, and
				// know how long they have — before the seat picker appears.
				btn.onclick = function () { openEvent(btn.dataset.eventJoin); };
			});
			$$('[data-venue-open]').forEach(function (node) {
				node.onclick = function () { openVenue(node.dataset.venueOpen); };
			});
		});
	}

	function eventCard(event) {
		var full = event.seats_left <= 0;
		var pct = event.capacity ? Math.round((event.taken / event.capacity) * 100) : 0;
		var subject = (event.title && String(event.title).trim()) || event.theme || '';

		var action;
		if (event.joined) {
			action = '<span class="hv-badge hv-badge-green">' + esc(t('joined_event')) + '</span>';
		} else if (full || event.status !== 'open') {
			action = '<button class="hv-btn hv-btn-ghost hv-btn-sm" disabled>' + esc(t('event_full')) + '</button>';
		} else {
			action = '<button class="hv-btn hv-btn-primary hv-btn-sm" data-event-join="' + esc(event.id) +
				'" data-seats-left="' + (parseInt(event.seats_left, 10) || 0) + '">' +
				esc(t('join_event')) + '</button>';
		}

		var thumb = event.image
			? '<img src="' + esc(event.image) + '" alt="">'
			: icon('cup');

		return '' +
			'<article class="hv-event-card">' +
				'<div class="hv-event-top">' +
					'<div class="hv-event-thumb" data-venue-open="' + esc(event.venue_id) + '">' + thumb + '</div>' +
					'<div class="hv-event-info">' +
						'<h3 class="hv-event-name" data-venue-open="' + esc(event.venue_id) + '">' + esc(pick(event.venue)) + '</h3>' +
						// The line under the café name says what the gathering
						// is actually about. The theme is the fallback: a café
						// may leave the title blank, but every event has one or
						// the other, and "Board games" alone told the guest
						// nothing about which evening they were looking at.
						(subject ? '<p class="hv-event-title">' + esc(t('event_subject')) + ': ' + esc(subject) + '</p>' : '') +
						'<p class="hv-event-when">' + esc(eventWeekday(event)) + ' · ' + esc(eventDate(event)) + ' · ' + num(event.time) + '</p>' +
						'<div class="hv-row" style="margin-top:7px">' +
							statusBadge(event.status) +
							(event.theme ? '<span class="hv-badge hv-badge-pink">' + esc(event.theme) + '</span>' : '') +
							'<span class="hv-badge hv-badge-indigo">' + esc(budgetLabel(event.budget_tier)) + '</span>' +
						'</div>' +
					'</div>' +
				'</div>' +
				'<div class="hv-seatbar"><span style="width:' + pct + '%"></span></div>' +
				'<div class="hv-event-foot">' +
					'<div>' +
						'<div class="hv-muted">' + num(event.seats_left) + ' ' + esc(t('seats_left')) + '</div>' +
						'<div class="hv-free">' + esc(t('free')) + '</div>' +
					'</div>' +
					action +
				'</div>' +
			'</article>';
	}

	/* =====================================================================
	 * The guest's dashboard — behind the round button in the bottom bar
	 * ================================================================== */

	/**
	 * Turn a venue's coordinates into a link the phone's own map app opens.
	 *
	 * A `geo:` URI is the Android convention and Google Maps, Waze and Neshan
	 * all register for it. iOS ignores geo:, so fall back to a plain Google
	 * Maps URL there, which iOS hands to Apple Maps or Google Maps.
	 */
	function directionsUrl(lat, lng, label) {
		lat = parseFloat(lat);
		lng = parseFloat(lng);
		if (!lat || !lng) { return ''; }

		var isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent || '');
		if (isIOS) {
			return 'https://maps.google.com/?q=' + lat + ',' + lng;
		}
		return 'geo:' + lat + ',' + lng + '?q=' + lat + ',' + lng +
			(label ? '(' + encodeURIComponent(label) + ')' : '');
	}

	function openDashboard() {
		api('dashboard').then(function (res) {
			S.data.dashboard = res;

			var user = res.user || {};
			var stats = res.stats || {};

			var upcoming = (res.upcoming || []).length
				? (res.upcoming || []).map(function (ev) {
					var subject = (ev.title && String(ev.title).trim()) || ev.theme || '';
					var maps = directionsUrl(ev.lat, ev.lng, pick(ev.venue));

					return '<div class="hv-dash-event">' +
						'<div class="hv-dash-event-main" data-dash-event="' + esc(ev.id) + '">' +
							'<div class="hv-dash-event-name">' + esc(pick(ev.venue)) + '</div>' +
							(subject
								? '<div class="hv-dash-event-subject">' + esc(t('event_subject')) + ': ' + esc(subject) + '</div>'
								: '') +
							'<div class="hv-dash-event-when">' +
								esc(eventWeekday(ev)) + ' · ' + esc(eventDate(ev)) + ' · ' + num(ev.time) +
							'</div>' +
							(ev.my_seats > 1
								? '<div class="hv-dash-event-seats">' + esc(t('seats_booked').replace('%s', num(ev.my_seats))) + '</div>'
								: '') +
						'</div>' +
						'<div class="hv-dash-event-actions">' +
							(maps
								// Opens the phone's own navigation app rather
								// than a map inside the web-app.
								? '<a class="hv-btn hv-btn-ghost hv-btn-sm" href="' + esc(maps) + '" ' +
									'target="_blank" rel="noopener">' + esc(t('directions')) + '</a>'
								: '') +
						'</div>' +
					'</div>';
				}).join('')
				: '<p class="hv-muted">' + esc(t('dash_no_events')) + '</p>';

			var requests = (res.requests || []).length
				? (res.requests || []).map(function (rq) {
					var badge = 'hv-badge-orange';
					if ('accepted' === rq.status) { badge = 'hv-badge-green'; }
					if ('declined' === rq.status) { badge = 'hv-badge-gray'; }

					return '<div class="hv-dash-request">' +
						'<div>' +
							'<div class="hv-dash-event-name">' + esc(rq.venue) + '</div>' +
							'<div class="hv-dash-event-when">' + esc(rq.subject) + ' · ' +
								esc(pick(rq.date)) + ' · ' + num(rq.time) + '</div>' +
						'</div>' +
						'<span class="hv-badge ' + badge + '">' + esc(t('request_' + rq.status)) + '</span>' +
					'</div>';
				}).join('')
				: '';

			openModal(
				'<div class="hv-dash-head">' +
					(user.avatar ? '<img class="hv-dash-avatar" src="' + esc(user.avatar) + '" alt="">' : '') +
					'<div>' +
						'<h3 class="hv-modal-title">' + esc(user.name || '') + '</h3>' +
						'<p class="hv-muted">★ ' + num(user.rating) + '</p>' +
					'</div>' +
				'</div>' +

				'<div class="hv-dash-stats">' +
					'<div class="hv-dash-stat"><b>' + num(stats.upcoming || 0) + '</b>' +
						'<span>' + esc(t('dash_upcoming')) + '</span></div>' +
					'<div class="hv-dash-stat"><b>' + num(stats.rating || 0) + '</b>' +
						'<span>' + esc(t('rating_score')) + '</span></div>' +
					'<div class="hv-dash-stat"><b>' + num(stats.requests || 0) + '</b>' +
						'<span>' + esc(t('dash_requests')) + '</span></div>' +
				'</div>' +

				'<button type="button" class="hv-btn hv-btn-primary hv-btn-block hv-mt" id="hv-dash-suggest">' +
					esc(t('suggest_event')) + '</button>' +

				'<h4 class="hv-section-title">' + esc(t('dash_upcoming')) + '</h4>' +
				upcoming +

				(requests
					? '<h4 class="hv-section-title">' + esc(t('dash_requests')) + '</h4>' + requests
					: '') +

				'<button type="button" class="hv-btn hv-btn-ghost hv-btn-block hv-mt" data-close="1">' +
					esc(t('close')) + '</button>'
			);

			$('#hv-dash-suggest').onclick = function () { openSuggestEvent(res.venues || []); };

			$$('[data-dash-event]').forEach(function (node) {
				node.onclick = function () { openEvent(node.dataset.dashEvent); };
			});
		}).catch(function (err) { toast(err.message, 'error'); });
	}

	/**
	 * Suggest a gathering to a café on a particular day.
	 *
	 * This is a wish, not a booking: nothing is seated and no seat is held.
	 * The café decides whether to turn it into a real gathering.
	 */
	function openSuggestEvent(venues) {
		if (!venues.length) {
			// Two different reasons for an empty list, and telling them apart
			// matters: "no cafés in your city yet" is nothing the guest can
			// act on, while "set your city first" is.
			var known = S.data.dashboard && S.data.dashboard.city;
			toast(t(known ? 'dash_no_venues' : 'dash_set_city_first'), 'error');
			if (!known) { setTab('profile'); }
			return;
		}

		// A date input speaks ISO, so bound it to today at the earliest.
		var today = new Date();
		var min = today.getFullYear() + '-' +
			String(today.getMonth() + 1).padStart(2, '0') + '-' +
			String(today.getDate()).padStart(2, '0');

		openModal(
			'<h3 class="hv-modal-title">' + esc(t('suggest_event')) + '</h3>' +
			'<p class="hv-muted">' + esc(t('suggest_hint')) + '</p>' +

			'<div class="hv-field hv-mt">' +
				'<label for="hv-sg-venue">' + esc(t('venue_name')) + '</label>' +
				'<select class="hv-select" id="hv-sg-venue">' +
					venues.map(function (v) {
						return '<option value="' + esc(v.id) + '">' + esc(v.name) + '</option>';
					}).join('') +
				'</select>' +
			'</div>' +

			'<div class="hv-field hv-mt">' +
				'<label for="hv-sg-subject">' + esc(t('event_subject')) + '</label>' +
				'<input type="text" class="hv-input" id="hv-sg-subject" maxlength="191">' +
			'</div>' +

			'<div class="hv-field hv-mt">' +
				'<label for="hv-sg-date">' + esc(t('col_date')) + '</label>' +
				'<input type="date" class="hv-input" id="hv-sg-date" min="' + esc(min) + '">' +
			'</div>' +

			'<div class="hv-field hv-mt">' +
				'<label for="hv-sg-time">' + esc(t('event_time')) + '</label>' +
				'<input type="time" class="hv-input" id="hv-sg-time" value="18:00">' +
			'</div>' +

			'<div class="hv-field hv-mt">' +
				'<label for="hv-sg-note">' + esc(t('event_about')) + '</label>' +
				'<textarea class="hv-textarea" id="hv-sg-note" rows="3" maxlength="1000"></textarea>' +
			'</div>' +

			'<button type="button" class="hv-btn hv-btn-primary hv-btn-block hv-mt" id="hv-sg-send">' +
				esc(t('send_request')) + '</button>' +
			'<button type="button" class="hv-btn hv-btn-ghost hv-btn-block hv-mt" data-close="1">' +
				esc(t('cancel')) + '</button>'
		);

		$('#hv-sg-send').onclick = function () {
			var go = $('#hv-sg-send');
			var subject = $('#hv-sg-subject').value.trim();
			var date = $('#hv-sg-date').value;
			var time = $('#hv-sg-time').value;

			if (!subject || !date || !time) {
				toast(t('error_generic'), 'error');
				return;
			}

			go.disabled = true;
			api('event/request', {
				method: 'POST',
				body: {
					venue_id: $('#hv-sg-venue').value,
					subject: subject,
					preferred_date: date,
					preferred_time: time,
					note: $('#hv-sg-note').value.trim()
				}
			}).then(function (res) {
				closeModal();
				toast(res.message || t('saved'), 'ok');
			}).catch(function (err) {
				go.disabled = false;
				toast(err.message, 'error');
			});
		};
	}

	/**
	 * The event's own page: what the evening is, which café is hosting it,
	 * their menu, when it starts, how long is left, and the reserve button.
	 *
	 * Booking carries a no-show penalty, so the guest should be able to read
	 * all of this before committing rather than after.
	 */
	function openEvent(eventId) {
		if (!eventId) { return; }

		api('event', { params: { id: eventId } }).then(function (res) {
			var event = res.event || {};
			var venue = res.venue || {};
			var subject = (event.title && String(event.title).trim()) || event.theme || '';

			var hero = event.image
				? '<img class="hv-modal-hero" src="' + esc(event.image) + '" alt="">'
				: '<div class="hv-modal-hero"></div>';

			var menu = (venue.menu || []).length
				? (venue.menu || []).map(function (item) {
					return '<div class="hv-menu-item">' +
						(item.image
							? '<img class="hv-menu-thumb" src="' + esc(item.image) + '" alt="">'
							: '<span class="hv-menu-thumb">' + icon('cup') + '</span>') +
						'<div class="hv-menu-body">' +
							'<div class="hv-menu-name">' + esc(item.name) + '</div>' +
							(item.desc ? '<div class="hv-menu-desc">' + esc(item.desc) + '</div>' : '') +
						'</div>' +
						'<div class="hv-menu-price">' + esc(pick(item.price_label)) + '</div>' +
					'</div>';
				}).join('')
				: '<p class="hv-muted">' + esc(t('empty_state')) + '</p>';

			var full = event.seats_left <= 0;
			var action;
			if (event.joined) {
				action = '<div class="hv-alert hv-alert-green hv-mt">' + esc(t('joined_event')) + '</div>';
			} else if (full || event.status !== 'open') {
				action = '<button type="button" class="hv-btn hv-btn-ghost hv-btn-block hv-mt" disabled>' +
					esc(t('event_full')) + '</button>';
			} else {
				action = '<button type="button" class="hv-btn hv-btn-primary hv-btn-block hv-mt" id="hv-event-reserve">' +
					esc(t('join_event')) + '</button>';
			}

			openModal(
				hero +
				'<h3 class="hv-modal-title">' + esc(pick(venue.name) || pick(event.venue)) + '</h3>' +
				(subject
					? '<p class="hv-event-subject">' + esc(t('event_subject')) + ': ' + esc(subject) + '</p>'
					: '') +

				'<div class="hv-row" style="margin:10px 0 12px">' +
					statusBadge(event.status) +
					(venue.verified ? '<span class="hv-badge hv-badge-green">✓ ' + esc(t('verified_venue')) + '</span>' : '') +
					'<span class="hv-badge hv-badge-indigo">' + esc(budgetLabel(event.budget_tier)) + '</span>' +
				'</div>' +

				// When
				'<div class="hv-event-when-box">' +
					'<div class="hv-when-line">' +
						esc(eventWeekday(event)) + ' · ' + esc(eventDate(event)) + ' · ' + num(event.time) +
					'</div>' +
					'<div class="hv-countdown" id="hv-countdown" data-starts-in="' +
						(parseInt(event.starts_in, 10) || 0) + '"></div>' +
				'</div>' +

				// Seats
				'<p class="hv-muted hv-mt">' + num(event.seats_left) + ' ' + esc(t('seats_left')) +
					' · <span class="hv-free">' + esc(t('free')) + '</span></p>' +

				// About this gathering
				(event.description
					? '<h4 class="hv-section-title">' + esc(t('event_about')) + '</h4>' +
						'<p class="hv-event-desc">' + esc(event.description) + '</p>'
					: '') +

				// The café
				'<h4 class="hv-section-title">' + esc(t('about_venue')) + '</h4>' +
				(venue.address ? '<p class="hv-muted">' + esc(venue.address) + '</p>' : '') +
				(venue.quiet_hours
					? '<p class="hv-muted">' + esc(t('quiet_hours')) + ': ' + num(venue.quiet_hours) + '</p>'
					: '') +

				// Menu
				'<h4 class="hv-section-title">' + esc(t('venue_menu')) + '</h4>' +
				'<div class="hv-alert hv-alert-blue">' + esc(t('menu_display_only')) + '</div>' +
				menu +

				action +
				'<button type="button" class="hv-btn hv-btn-ghost hv-btn-block hv-mt" data-close="1">' +
					esc(t('close')) + '</button>'
			);

			startCountdown();

			var go = $('#hv-event-reserve');
			if (go) {
				go.onclick = function () {
					stopCountdown();
					openReserve(event.id, parseInt(event.seats_left, 10) || 0);
				};
			}
		}).catch(function (err) { toast(err.message, 'error'); });
	}

	/**
	 * Live countdown to the start of an event.
	 *
	 * Counts down from the server's own figure rather than from a timestamp,
	 * so a phone with a wrong clock or a different timezone still shows the
	 * same number of hours as everyone else.
	 */
	function startCountdown() {
		stopCountdown();

		var node = $('#hv-countdown');
		if (!node) { return; }

		var left = parseInt(node.dataset.startsIn, 10) || 0;

		function paint() {
			if (left <= 0) {
				node.textContent = t('event_started');
				node.classList.add('is-live');
				stopCountdown();
				return;
			}

			var days = Math.floor(left / 86400);
			var hours = Math.floor((left % 86400) / 3600);
			var mins = Math.floor((left % 3600) / 60);
			var secs = left % 60;

			var parts = [];
			if (days) { parts.push(num(days) + ' ' + t('unit_day')); }
			if (days || hours) { parts.push(num(hours) + ' ' + t('unit_hour')); }
			parts.push(num(mins) + ' ' + t('unit_minute'));
			// Seconds only matter once the wait is short enough to watch.
			if (!days && !hours) { parts.push(num(secs) + ' ' + t('unit_second')); }

			node.textContent = t('starts_in') + ': ' + parts.join(' ');
		}

		paint();
		S.countdownTimer = setInterval(function () {
			left -= 1;
			paint();
		}, 1000);
	}

	function stopCountdown() {
		if (S.countdownTimer) {
			clearInterval(S.countdownTimer);
			S.countdownTimer = null;
		}
	}

	/**
	 * Ask how many seats before booking. A guest may bring companions, so the
	 * count is chosen here and charged against the table's capacity server-side.
	 */
	function openReserve(eventId, seatsLeft) {
		var max = Math.max(1, Math.min(BOOT.maxSeats || 3, seatsLeft || 1));
		var choice = 1;

		var options = '';
		for (var n = 1; n <= max; n++) {
			options += '<button type="button" class="hv-choice' + (n === 1 ? ' is-active' : '') +
				'" data-seats="' + n + '">' +
				esc(n === 1 ? t('seat_one') : t('seat_n').replace('%s', num(n))) +
			'</button>';
		}

		openModal(
			'<h3 class="hv-modal-title">' + esc(t('reserve_title')) + '</h3>' +
			'<div class="hv-step-q">' + esc(t('how_many_seats')) + '</div>' +
			'<div class="hv-choice-grid">' + options + '</div>' +
			'<p class="hv-muted hv-mt">' + esc(t('seats_hint').replace('%s', num(max))) + '</p>' +
			'<div class="hv-alert hv-alert-orange hv-mt">' + esc(t('penalty_notice')) + '</div>' +
			'<button type="button" class="hv-btn hv-btn-primary hv-btn-block hv-mt" id="hv-reserve-go">' +
				esc(t('confirm_reserve')) + '</button>'
		);

		$$('[data-seats]').forEach(function (b) {
			b.onclick = function () {
				choice = parseInt(b.dataset.seats, 10);
				$$('[data-seats]').forEach(function (o) { o.classList.toggle('is-active', o === b); });
			};
		});

		$('#hv-reserve-go').onclick = function () {
			var go = $('#hv-reserve-go');
			go.disabled = true;
			submitJoin(eventId, choice, function () { go.disabled = false; });
		};
	}

	function submitJoin(eventId, seats, onFail) {
		api('events/join', { method: 'POST', body: { event_id: eventId, seats: seats } })
			.then(function (res) {
				closeModal();
				var msg = res.matched ? t('status_matched')
					: (seats > 1 ? t('seats_booked').replace('%s', num(seats)) : t('joined_event'));
				toast(msg, 'ok');

				// TEMPORARY (requested for review), and only for cafés outside
				// Iran: jump straight into Chats after reserving so the chat
				// features can be inspected without waiting for the matcher.
				// Iranian cafés keep the normal behaviour — stay on Explore
				// until a table is actually formed. Revert by replacing this
				// whole block with viewExplore().
				//
				// The country comes from the server, which applies the same
				// rule when deciding whether to seat the table right away, so
				// the two halves can never disagree.
				if (res.country && res.country !== 'ir') {
					S.chatMode = 'groups';
					// If the table was seated, open its room directly;
					// otherwise land on the chat list.
					S.chatRoom = res.group_id ? { type: 'group', id: res.group_id } : null;
					S.lastMsgId = 0;
					S.chatFetching = false;
					setTab('chats');
				} else {
					viewExplore();
				}
			})
			.catch(function (err) {
				if (onFail) { onFail(); }
				toast(err.message, 'error');
				if (err.data && (err.data.code === 'havato_no_profile' || err.data.code === 'havato_no_details')) {
					closeModal();
					setTab('profile');
				}
			});
	}


	function showFilters() {
		var options = [
			{ key: '', label: t('filter') },
			{ key: 'low', label: t('budget_low') },
			{ key: 'medium', label: t('budget_medium') },
			{ key: 'high', label: t('budget_high') }
		];

		openModal(
			'<h3 class="hv-modal-title">' + esc(t('filter')) + '</h3>' +
			'<div class="hv-chips">' +
				options.map(function (opt) {
					var active = (S.data.exploreFilter || '') === opt.key ? ' is-active' : '';
					return '<button type="button" class="hv-chip' + active + '" data-filter="' + esc(opt.key) + '">' +
						esc(opt.label) + '</button>';
				}).join('') +
			'</div>'
		);

		$$('[data-filter]').forEach(function (btn) {
			btn.onclick = function () {
				S.data.exploreFilter = btn.dataset.filter;
				closeModal();
				if (S.tab !== 'explore') { setTab('explore'); } else { viewExplore(); }
			};
		});
	}

	/* =====================================================================
	 * TAB: MAP
	 * ================================================================== */
	function viewMap() {
		setHeader(t('map_title'), t('app_name'));
		setStatusStrip('');

		return api('venues').then(function (res) {
			S.data.venues = res.venues || [];

			el.main.innerHTML =
				exploreSubtabs('map') +
				'<div class="hv-map-wrap">' +
					'<div class="hv-map-strip">' +
						// The green pill is a real control: tapping it centres the
						// map on the visitor. The orange one is just a count.
						'<button type="button" class="hv-map-pill is-green" id="hv-locate-btn">' +
							icon('map') + '<span>' + esc(t('nearby_location')) + '</span>' +
						'</button>' +
						'<span class="hv-map-pill is-orange">' + icon('cup') + num(S.data.venues.length) + '</span>' +
					'</div>' +
					'<div id="hv-map"></div>' +
				'</div>' +
				'<p class="hv-muted hv-mt">' + esc(t('map_hint')) + '</p>' +
				'<div class="hv-section hv-mt">' +
					S.data.venues.map(venueListCard).join('') +
				'</div>';

			bindExploreSubtabs();

			$$('[data-venue-open]').forEach(function (node) {
				node.onclick = function () { openVenue(node.dataset.venueOpen); };
			});

			initLeaflet();

			var locateBtn = $('#hv-locate-btn');
			if (locateBtn) { locateBtn.onclick = locateMe; }
		});
	}

	function venueListCard(venue) {
		var thumb = venue.image
			? '<img src="' + esc(venue.image) + '" alt="">'
			: icon('cup');

		return '' +
			'<button type="button" class="hv-list-card" data-venue-open="' + esc(venue.id) + '">' +
				'<span class="hv-list-thumb">' + thumb + '</span>' +
				'<span class="hv-list-body">' +
					'<span class="hv-list-title">' + esc(pick(venue.name)) + '</span>' +
					'<span class="hv-list-sub">' +
						(venue.city_label ? esc(pick(venue.city_label)) : '') +
						((venue.city_label && venue.address) ? ' · ' : '') +
						esc(venue.address || '') +
					'</span>' +
				'</span>' +
				'<span class="hv-list-meta">' +
					(venue.verified ? '<span class="hv-badge hv-badge-green">✓</span>' : '') +
					'<span class="hv-badge hv-badge-blue">' + num(venue.guests_routed) + '</span>' +
				'</span>' +
			'</button>';
	}

	function initLeaflet() {
		if (typeof window.L === 'undefined') { return; }

		var node = $('#hv-map');
		if (!node) { return; }

		// bootstrap() returns a centre already resolved to the viewer's city,
		// so an Istanbul guest does not open the map on Tehran. BOOT.map is the
		// admin default and is only the fallback for a first paint.
		var centre = S.mapCenter || BOOT.map;

		S.map = window.L.map(node, {
			zoomControl: false,
			attributionControl: false
		}).setView([centre.lat, centre.lng], centre.zoom);

		window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
			maxZoom: 19
		}).addTo(S.map);

		S.mapMarkers = [];
		S.meMarker = null; // belongs to the previous map instance
		(S.data.venues || []).forEach(function (venue) {
			if (!venue.lat || !venue.lng) { return; }
			var marker = window.L.marker([venue.lat, venue.lng], {
				icon: window.L.divIcon({ className: '', html: '<div class="hv-pin"></div>', iconSize: [34, 34], iconAnchor: [17, 32] })
			}).addTo(S.map);

			marker.bindPopup(
				'<strong>' + esc(pick(venue.name)) + '</strong><br>' +
				'<span style="opacity:.7">' + esc(venue.address || '') + '</span><br>' +
				'<button type="button" class="hv-btn hv-btn-blue hv-btn-sm" style="margin-top:8px" ' +
					'onclick="window.HavatoOpenVenue(\'' + esc(venue.id) + '\')">' +
					esc(t('view_venue_profile')) +
				'</button>'
			);

			S.mapMarkers.push(marker);
		});

		setTimeout(function () { if (S.map) { S.map.invalidateSize(); } }, 220);
	}

	function locateMe() {
		if (!S.map) { return; }

		var btn = $('#hv-locate-btn');
		// Geolocation needs HTTPS and is unavailable in some in-app browsers,
		// so say why instead of doing nothing.
		if (!navigator.geolocation) {
			toast(t('geo_unsupported'), 'error');
			return;
		}

		if (btn) { btn.classList.add('is-busy'); }
		toast(t('locating'), 'info');

		navigator.geolocation.getCurrentPosition(function (pos) {
			if (btn) { btn.classList.remove('is-busy'); }
			var here = [pos.coords.latitude, pos.coords.longitude];
			S.map.setView(here, 14);

			// Drop / move a marker so the user can see where "here" is.
			if (S.meMarker) {
				S.meMarker.setLatLng(here);
			} else if (window.L) {
				S.meMarker = window.L.marker(here, {
					icon: window.L.divIcon({
						className: '',
						html: '<div class="hv-me-dot"></div>',
						iconSize: [22, 22],
						iconAnchor: [11, 11]
					})
				}).addTo(S.map);
			}
		}, function (err) {
			if (btn) { btn.classList.remove('is-busy'); }
			// 1 = PERMISSION_DENIED
			toast(err && err.code === 1 ? t('geo_denied') : t('geo_failed'), 'error');
		}, { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 });
	}

	window.HavatoOpenVenue = function (id) { openVenue(id); };

	function openVenue(venueId) {
		if (!venueId) { return; }
		api('venue', { params: { id: venueId } }).then(function (res) {
			var venue = res.venue;
			var hero = venue.image
				? '<img class="hv-modal-hero" src="' + esc(venue.image) + '" alt="">'
				: '<div class="hv-modal-hero"></div>';

			var menu = (venue.menu || []).length
				? (venue.menu || []).map(function (item) {
					return '<div class="hv-menu-item">' +
						(item.image
							? '<img class="hv-menu-thumb" src="' + esc(item.image) + '" alt="">'
							: '<span class="hv-menu-thumb">' + icon('cup') + '</span>') +
						'<div class="hv-menu-body">' +
							'<div class="hv-menu-name">' + esc(item.name) + '</div>' +
							(item.desc ? '<div class="hv-menu-desc">' + esc(item.desc) + '</div>' : '') +
						'</div>' +
						'<div class="hv-menu-price">' + esc(pick(item.price_label)) + '</div>' +
					'</div>';
				}).join('')
				: emptyState(t('empty_state'), 'menu');

			openModal(
				hero +
				'<h3 class="hv-modal-title">' + esc(pick(venue.name)) + '</h3>' +
				'<div class="hv-row" style="margin-bottom:12px">' +
					(venue.verified ? '<span class="hv-badge hv-badge-green">✓ ' + esc(t('verified_venue')) + '</span>' : '') +
					'<span class="hv-badge hv-badge-indigo">' + esc(budgetLabel(venue.budget_tier)) + '</span>' +
					'<span class="hv-badge hv-badge-blue">' + num(venue.guests_routed) + ' ' + esc(t('guests_routed')) + '</span>' +
				'</div>' +
				'<p class="hv-muted">' + esc(venue.address || '') + '</p>' +
				(venue.quiet_hours ? '<p class="hv-muted">' + esc(t('quiet_hours')) + ': ' + num(venue.quiet_hours) + '</p>' : '') +
				'<div class="hv-alert hv-alert-blue hv-mt">' + esc(t('menu_display_only')) + '</div>' +
				'<h4 class="hv-section-title">' + esc(t('venue_menu')) + '</h4>' +
				menu
			);
		}).catch(function (err) { toast(err.message, 'error'); });
	}

	/* =====================================================================
	 * TAB: CHATS
	 * ================================================================== */
	function viewChats() {
		setHeader(t('chats_title'), t('app_name'));
		setStatusStrip('');

		if (S.chatRoom) {
			return renderChatRoom();
		}

		return api('chat/threads').then(function (res) {
			S.data.threads = res;

			var list = S.chatMode === 'groups'
				? (res.groups || []).map(groupThreadCard).join('') || emptyState(t('no_groups'), 'users')
				: (res.friends || []).map(friendThreadCard).join('') || emptyState(t('no_friends'), 'profile');

			el.main.innerHTML =
				'<div class="hv-subtabs">' +
					'<button type="button" class="hv-subtab' + (S.chatMode === 'groups' ? ' is-active' : '') + '" data-chatmode="groups">' +
						esc(t('chat_groups')) + '</button>' +
					'<button type="button" class="hv-subtab' + (S.chatMode === 'friends' ? ' is-active' : '') + '" data-chatmode="friends">' +
						esc(t('chat_friends')) + '</button>' +
				'</div>' + list;

			$$('[data-chatmode]').forEach(function (btn) {
				btn.onclick = function () { S.chatMode = btn.dataset.chatmode; viewChats(); };
			});
			$$('[data-open-group]').forEach(function (btn) {
				btn.onclick = function () { openChatRoom('group', btn.dataset.openGroup); };
			});
			$$('[data-open-friend]').forEach(function (btn) {
				btn.onclick = function () { openChatRoom('private', parseInt(btn.dataset.openFriend, 10)); };
			});
		});
	}

	function groupThreadCard(thread) {
		return '' +
			'<button type="button" class="hv-list-card" data-open-group="' + esc(thread.id) + '">' +
				'<span class="hv-list-thumb">' +
					(thread.image ? '<img src="' + esc(thread.image) + '" alt="">' : icon('users')) +
				'</span>' +
				'<span class="hv-list-body">' +
					'<span class="hv-list-title">' + esc(pick(thread.name)) + '</span>' +
					'<span class="hv-list-sub">' + esc(thread.last_message || pick(thread.date)) + '</span>' +
				'</span>' +
				'<span class="hv-list-meta">' +
					(thread.table_name
						? '<span class="hv-badge hv-badge-blue">' + esc(thread.table_name) + '</span>'
						: '') +
					'<span class="hv-badge hv-badge-indigo">' + num(thread.members) + '</span>' +
					'<span class="hv-muted">' + num(thread.time || '') + '</span>' +
				'</span>' +
			'</button>';
	}

	function friendThreadCard(thread) {
		return '' +
			'<button type="button" class="hv-list-card" data-open-friend="' + thread.user.id + '">' +
				'<span class="hv-list-thumb"><img src="' + esc(thread.user.avatar) + '" alt=""></span>' +
				'<span class="hv-list-body">' +
					'<span class="hv-list-title">' + esc(thread.user.name) + '</span>' +
					'<span class="hv-list-sub">' + esc(thread.last_message || t('chat_placeholder')) + '</span>' +
				'</span>' +
				'<span class="hv-list-meta">' +
					(thread.unread ? '<span class="hv-badge hv-badge-pink">' + num(thread.unread) + '</span>' : '') +
					'<span class="hv-muted">' + num(thread.last_time || '') + '</span>' +
				'</span>' +
			'</button>';
	}

	function openChatRoom(type, id) {
		S.chatRoom = { type: type, id: id };
		S.lastMsgId = 0;
		// A request still in flight from the previous room must not keep the
		// new one locked out.
		S.chatFetching = false;
		S.chatSending = false;
		renderChatRoom();
	}

	function renderChatRoom() {
		var room = S.chatRoom;

		el.main.innerHTML =
			'<div class="hv-chat-room">' +
				'<div class="hv-chat-head">' +
					'<button type="button" class="hv-btn hv-btn-ghost hv-btn-sm" id="hv-chat-back">' + esc(t('back')) + '</button>' +
					'<div class="hv-list-body"><div class="hv-list-title" id="hv-chat-title">' + esc(t('loading')) + '</div></div>' +
				'</div>' +
				'<div class="hv-chat-log" id="hv-chat-log"></div>' +
				'<div class="hv-sticker-tray" id="hv-sticker-tray" hidden>' +
					STICKERS.map(function (s) {
						return '<button type="button" class="hv-sticker" data-sticker="' + esc(s) + '">' + esc(s) + '</button>';
					}).join('') +
				'</div>' +
				'<div class="hv-chat-form">' +
					'<button type="button" class="hv-chat-sticker" id="hv-chat-sticker" ' +
						'aria-label="' + esc(t('stickers')) + '" title="' + esc(t('stickers')) + '" ' +
						'aria-expanded="false">☺</button>' +
					'<input type="text" class="hv-input" id="hv-chat-input" placeholder="' + esc(t('chat_placeholder')) + '">' +
					'<button type="button" class="hv-chat-send" id="hv-chat-send">➤</button>' +
				'</div>' +
			'</div>';

		$('#hv-chat-back').onclick = function () {
			S.chatRoom = null;
			stopPolling();
			viewChats();
		};

		$('#hv-chat-send').onclick = sendMessage;
		$('#hv-chat-input').onkeydown = function (e) {
			if (e.key === 'Enter') { sendMessage(); }
		};

		var tray = $('#hv-sticker-tray');
		var stickerBtn = $('#hv-chat-sticker');
		stickerBtn.onclick = function () {
			var open = tray.hidden;
			tray.hidden = !open;
			stickerBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
			stickerBtn.classList.toggle('is-open', open);
		};

		$$('[data-sticker]', tray).forEach(function (btn) {
			btn.onclick = function () {
				// A sticker is just a message whose body is the emoji, so it
				// travels through the same endpoint, the same moderation and
				// the same archive as any other line — nothing new to secure.
				sendMessage(btn.dataset.sticker);
				tray.hidden = true;
				stickerBtn.setAttribute('aria-expanded', 'false');
				stickerBtn.classList.remove('is-open');
			};
		});

		fetchMessages(true);
		startPolling();

		return Promise.resolve();
	}

	function fetchMessages(initial) {
		var room = S.chatRoom;
		if (!room) { return; }

		// Only one request may be in flight. Sending a message triggers a
		// fetch, and the 3-second poll fires independently: both used to read
		// the same `since` and both appended the same rows, so every message
		// appeared twice. Dropping the overlapping call is safe because the
		// poll comes round again immediately afterwards.
		if (S.chatFetching) { return; }
		S.chatFetching = true;

		var path = room.type === 'group' ? 'chat/group' : 'chat/private';
		var params = room.type === 'group'
			? { group_id: room.id, since: S.lastMsgId }
			: { user_id: room.id, since: S.lastMsgId };

		api(path, { params: params }).then(function (res) {
			var log = $('#hv-chat-log');
			if (!log) { return; }

			// The room may have changed while the request was in the air.
			if (!S.chatRoom || S.chatRoom.id !== room.id) { return; }

			var title = $('#hv-chat-title');
			if (title) {
				if (room.type === 'group') {
					title.textContent = (res.members || []).map(function (m) { return m.name; }).join('، ') || t('chat_groups');
				} else if (res.peer) {
					title.textContent = res.peer.name;
				}
			}

			if (initial) { log.innerHTML = ''; }

			(res.messages || []).forEach(function (msg) {
				// Second guard: never render an id that is already on screen.
				// The cursor makes this rare, but a retried request or a
				// re-entrant render must not be able to duplicate a line.
				if (log.querySelector('[data-msg-key="' + msg.id + '"]')) { return; }

				S.lastMsgId = Math.max(S.lastMsgId, msg.id);
				var node = document.createElement('div');
				node.setAttribute('data-msg-key', msg.id);
				node.className = 'hv-msg' + (msg.is_system ? ' is-system' : (msg.mine ? ' is-mine' : ''));

				// Somebody else's message can be reported or its sender
				// blocked. Your own and system lines cannot.
				var actionable = !msg.mine && !msg.is_system && msg.sender_id;
				if (actionable) {
					node.classList.add('is-actionable');
					node.setAttribute('role', 'button');
					node.setAttribute('tabindex', '0');
					node.title = t('msg_actions');
					node.dataset.msgId = msg.id;
					node.dataset.msgUser = msg.sender_id;
					node.dataset.msgName = msg.name || '';
				}

				// A system line arrives as a language map; anything a guest
				// typed arrives as one too, holding the same text in each key.
				var body = (msg.text && typeof msg.text === 'object') ? pick(msg.text) : msg.text;

				var bubble =
					(!msg.mine && !msg.is_system && msg.name ? '<span class="hv-msg-name">' + esc(msg.name) + '</span>' : '') +
					'<span class="hv-msg-text">' + esc(body) + '</span>' +
					'<span class="hv-msg-time">' + num(msg.time) + '</span>' +
					(actionable ? '<span class="hv-msg-flag" aria-hidden="true">⋯</span>' : '');

				// Show who is talking. Without a face beside the bubble a busy
				// table reads as one anonymous stream. Own and system lines
				// need no avatar: there is no ambiguity about either.
				if (!msg.mine && !msg.is_system && msg.avatar) {
					node.innerHTML =
						'<img class="hv-msg-avatar" src="' + esc(msg.avatar) + '" alt="" loading="lazy">' +
						'<span class="hv-msg-bubble">' + bubble + '</span>';
					node.classList.add('has-avatar');
				} else {
					node.innerHTML = bubble;
				}

				if (actionable) {
					node.onclick = function () {
						openMessageActions(node.dataset.msgId, parseInt(node.dataset.msgUser, 10), node.dataset.msgName);
					};
				}

				log.appendChild(node);
			});

			// Prefer the server's cursor: it counts messages that were filtered
			// out (e.g. from a blocked sender), so polling cannot get stuck
			// re-requesting them.
			if (typeof res.cursor === 'number') {
				S.lastMsgId = Math.max(S.lastMsgId, res.cursor);
			}

			if ((res.messages || []).length) {
				log.scrollTop = log.scrollHeight;
			}

			if (initial && room.type === 'group' && (res.members || []).length) {
				renderGroupMembers(res.members);
			}
		}).catch(function () {
			/* silent during polling */
		}).then(function () {
			// Always clear the flag, success or failure, or one dropped
			// request would freeze the chat for good.
			S.chatFetching = false;
		});
	}

	/**
	 * Report a message, or block its sender.
	 *
	 * Reporting sends the message id; the server re-checks that the reporter
	 * was allowed to see it, so a guessed id gets a 403.
	 */
	function openMessageActions(messageId, senderId, senderName) {
		var scope = (S.chatRoom && S.chatRoom.type === 'private') ? 'private' : 'group';

		// Blocking is a one-to-one act, so it only belongs in a one-to-one
		// conversation. At a shared table it would silently tear a hole in a
		// group everybody else still sees — and the people at that table were
		// seated together for one sitting, not befriended. Reporting is what
		// a table needs: it brings a moderator in without altering the room.
		var canBlock = ('private' === scope);

		var reasons = [
			{ key: 'nudity', label: t('reason_nudity') },
			{ key: 'fake', label: t('reason_fake') },
			{ key: 'spam', label: t('reason_spam') },
			{ key: 'other', label: t('reason_other') }
		];

		openModal(
			'<h3 class="hv-modal-title">' + esc(t('msg_actions')) + '</h3>' +
			(senderName ? '<p class="hv-muted" style="margin-bottom:12px">' + esc(senderName) + '</p>' : '') +
			'<div class="hv-step-q">' + esc(t('report_reason')) + '</div>' +
			'<div class="hv-choice-grid">' +
				reasons.map(function (r) {
					return '<button type="button" class="hv-choice" data-report-reason="' + esc(r.key) + '">' +
						esc(r.label) + '</button>';
				}).join('') +
			'</div>' +
			(canBlock
				? '<button type="button" class="hv-btn hv-btn-danger hv-btn-block hv-mt" id="hv-msg-block">' +
					esc(t('block_user')) + '</button>'
				: '') +
			'<button type="button" class="hv-btn hv-btn-ghost hv-btn-block hv-mt" data-close="1">' +
				esc(t('cancel')) + '</button>'
		);

		$$('[data-report-reason]').forEach(function (btn) {
			btn.onclick = function () {
				btn.disabled = true;
				api('chat/report', {
					method: 'POST',
					body: { scope: scope, message_id: messageId, reason: btn.dataset.reportReason }
				}).then(function () {
					closeModal();
					toast(t('message_reported'), 'ok');
				}).catch(function (err) {
					btn.disabled = false;
					toast(err.message, 'error');
				});
			};
		});

		// Not rendered at a table, so there is nothing to wire up there.
		if (!canBlock) { return; }

		$('#hv-msg-block').onclick = function () {
			openModal(
				'<h3 class="hv-modal-title">' + esc(t('block_user')) + '</h3>' +
				(senderName ? '<p style="font-weight:800;margin-bottom:8px">' + esc(senderName) + '</p>' : '') +
				'<div class="hv-alert hv-alert-orange">' + esc(t('block_confirm')) + '</div>' +
				'<button type="button" class="hv-btn hv-btn-danger hv-btn-block hv-mt" id="hv-block-go">' +
					esc(t('block_user')) + '</button>' +
				'<button type="button" class="hv-btn hv-btn-ghost hv-btn-block hv-mt" data-close="1">' +
					esc(t('cancel')) + '</button>'
			);

			$('#hv-block-go').onclick = function () {
				var go = $('#hv-block-go');
				go.disabled = true;
				api('chat/block', { method: 'POST', body: { user_id: senderId } })
					.then(function () {
						closeModal();
						toast(t('blocked_done'), 'ok');
						// The thread may no longer be readable, so go back to
						// the list rather than leaving a dead room open.
						S.chatRoom = null;
						stopPolling();
						viewChats();
					})
					.catch(function (err) {
						go.disabled = false;
						toast(err.message, 'error');
					});
			};
		};
	}

	function renderGroupMembers(members) {
		var wrap = document.createElement('div');
		wrap.className = 'hv-section hv-mt';
		wrap.innerHTML =
			'<h4 class="hv-section-title">' + esc(t('members_at_table')) + '</h4>' +
			members.map(function (member) {
				var action = '';
				if (member.friend_status === 'none' && !member.blocked) {
					action = '<button type="button" class="hv-btn hv-btn-blue hv-btn-sm" data-friend-add="' + member.id + '">' +
						esc(t('add_friend')) + '</button>';
				} else if (member.friend_status === 'accepted') {
					action = '<span class="hv-badge hv-badge-green">' + esc(t('friend_accepted')) + '</span>';
				} else if (member.friend_status === 'pending_out') {
					action = '<span class="hv-badge hv-badge-orange">' + esc(t('friend_pending')) + '</span>';
				} else if (member.friend_status === 'self') {
					action = '<span class="hv-badge hv-badge-gray">•</span>';
				}

				var clickable = ('self' === member.friend_status || member.blocked) ? '' : ' data-open-user="' + member.id + '"';

				return '<div class="hv-list-card"' + clickable + '>' +
					'<span class="hv-list-thumb"><img src="' + esc(member.avatar) + '" alt=""></span>' +
					'<span class="hv-list-body">' +
						'<span class="hv-list-title">' + esc(member.name) + '</span>' +
						'<span class="hv-list-sub">★ ' + num(member.rating) + '</span>' +
					'</span>' +
					'<span class="hv-list-meta">' + action + '</span>' +
				'</div>';
			}).join('');

		el.main.appendChild(wrap);
		bindFriendButtons();
		bindUserLinks();
	}

	function sendMessage(sticker) {
		var input = $('#hv-chat-input');
		var room = S.chatRoom;
		if (!room) { return; }

		var text;
		if (typeof sticker === 'string' && sticker) {
			text = sticker;
		} else {
			if (!input) { return; }
			text = input.value.trim();
			if (!text) { return; }
			input.value = '';
		}

		// Typing is protected by clearing the field above: a second tap finds
		// it empty and returns. A sticker takes its text from the argument, so
		// nothing stopped an impatient double-tap from posting the same emoji
		// twice — two real rows in the database, which no amount of
		// render-side de-duplication can undo. Hold the send path shut until
		// the request settles.
		if (S.chatSending) { return; }
		S.chatSending = true;

		var path = room.type === 'group' ? 'chat/group/send' : 'chat/private/send';
		var body = room.type === 'group' ? { group_id: room.id, text: text } : { user_id: room.id, text: text };

		api(path, { method: 'POST', body: body })
			.then(function () { fetchMessages(false); })
			.catch(function (err) {
				toast(err.message, 'error');
				// Put a typed message back so the guest does not lose it.
				if (!sticker && input) { input.value = text; }
			})
			.then(function () { S.chatSending = false; });
	}

	function startPolling() {
		stopPolling();
		// 3-second polling straight from the database, exactly as specified.
		S.pollTimer = setInterval(function () {
			if (document.hidden || !S.chatRoom) { return; }
			fetchMessages(false);
		}, 3000);
	}

	function stopPolling() {
		if (S.pollTimer) {
			clearInterval(S.pollTimer);
			S.pollTimer = null;
		}
	}

	/* =====================================================================
	 * TAB: PROFILE
	 * ================================================================== */
	function viewProfile(force, userId) {
		// `userId` renders the PUBLIC profile of another gatherer (add-friend
		// button, gallery, no stats / no feedback / no logout).
		userId = userId || S.viewingUser || 0;
		S.viewingUser = userId || 0;

		setHeader(t('profile_title'), t('app_name'));
		setStatusStrip('');

		var params = userId ? { user_id: userId } : {};

		return Promise.all([
			api('profile', { params: params }),
			userId ? Promise.resolve({ items: [] }) : api('feedback/pending'),
			userId ? Promise.resolve({ requests: [] }) : api('friends'),
			userId ? Promise.resolve({ events: [] }) : api('events/mine')
		]).then(function (results) {
			var profile = results[0];
			var feedback = results[1];
			var friends = results[2];
			var mine = results[3];

			S.data.profile = profile;
			if (profile.is_self) {
				S.user = profile.user;
				renderHeaderUser();
				// Your own name and rating live in the page header; the card
				// below used to repeat them, which read as a duplicate.
				setHeader(
					profile.user.name || t('profile_title'),
					'★ ' + num(profile.rating) + ' · ' + num(profile.attended) + ' ' + t('events_attended')
				);
			}

			var html = '';

			if (!profile.is_self) {
				html += '<button type="button" class="hv-btn hv-btn-ghost hv-btn-sm" id="hv-profile-back">' +
					esc(t('back')) + '</button><div class="hv-mt"></div>';
			}

			html += profileHeadMarkup(profile);

			if (profile.is_self) {
				html += statsMarkup(profile);

				// "Edit my details" is permanent: name/age/city change over
				// time and the user must be able to correct them. The test
				// button only shows until the personality profile exists.
				var needsDetails = !profile.city;

				html += '<div class="hv-card">';

				if (needsDetails) {
					html += '<div class="hv-alert hv-alert-orange">' + esc(t('details_needed')) + '</div>';
				}

				html += '<button type="button" class="hv-btn ' +
					(needsDetails ? 'hv-btn-primary' : 'hv-btn-ghost') +
					' hv-btn-block" id="hv-edit-details">' +
					esc(t('edit_details')) + '</button>';

				if (!profile.completed) {
					html += '<button type="button" class="hv-btn hv-btn-primary hv-btn-block hv-mt" id="hv-start-test">' +
						icon('brain', 'hv-fab-icon') + esc(t('start_test')) + '</button>';
				}

				html += '</div>';
			}

			if (profile.is_self && (profile.penalty > 0)) {
				html += '<div class="hv-card"><div class="hv-alert hv-alert-orange">' +
					esc(t('penalty_notice')) +
					'<br><strong>' + esc(t('stat_no_shows')) + ': ' + num(profile.no_shows) +
					' · ' + esc(t('stat_empty_seats')) + ': ' + num(profile.empty_seats) +
					' · ' + esc(t('penalty_points')) + ': ' + num(profile.penalty) + '</strong>' +
					'</div></div>';
			}

			if (profile.completed) {
				html += behaviourMarkup(profile);
			}

			if ((friends.requests || []).length) {
				html += friendRequestsMarkup(friends.requests);
			}

			if ((feedback.items || []).length) {
				html += feedbackMarkup(feedback.items);
			}

			html += galleryMarkup(profile);

			if (profile.is_self && (mine.events || []).length) {
				html += myEventsMarkup(mine.events);
			}

			if (profile.is_self) {
				html += '<div class="hv-card hv-mt"><button type="button" class="hv-btn hv-btn-ghost hv-btn-block" id="hv-logout">' +
					esc(t('logout')) + '</button></div>';

				// Deleting an account is irreversible, so it is visually
				// separated and asks twice (see confirmDeleteAccount).
				html += '<div class="hv-card hv-mt hv-danger">' +
					'<h3 class="hv-section-title hv-danger-title">' + esc(t('danger_zone')) + '</h3>' +
					'<p class="hv-muted" style="margin:6px 0 12px">' + esc(t('delete_confirm_1')) + '</p>' +
					'<button type="button" class="hv-btn hv-btn-danger hv-btn-block" id="hv-delete-account">' +
						esc(t('delete_account')) + '</button>' +
				'</div>';
			}

			el.main.innerHTML = html;
			bindProfileEvents(profile);
		});
	}

	function profileHeadMarkup(profile) {
		var user = profile.user;
		var addFriend = '';

		if (!profile.is_self) {
			if (profile.friend_status === 'none') {
				addFriend = '<button type="button" class="hv-btn hv-btn-blue hv-btn-sm" data-friend-add="' + user.id + '">' +
					esc(t('add_friend')) + '</button>';
			} else if (profile.friend_status === 'accepted') {
				addFriend = '<span class="hv-badge hv-badge-green">' + esc(t('friend_accepted')) + '</span>';
			} else if (profile.friend_status === 'pending_out') {
				addFriend = '<span class="hv-badge hv-badge-orange">' + esc(t('friend_pending')) + '</span>';
			}
		}

		// On your OWN profile the name and rating are shown in the page header
		// instead, so this card would just repeat them. Someone else's profile
		// still needs it, together with the add-friend button.
		if (profile.is_self) {
			return '';
		}

		return '' +
			'<div class="hv-profile-head">' +
				'<img class="hv-profile-avatar" src="' + esc(user.avatar) + '" alt="">' +
				'<div style="flex:1 1 auto;min-width:0">' +
					'<h2 class="hv-profile-name">' + esc(user.name) + '</h2>' +
					'<p class="hv-profile-meta">★ ' + num(profile.rating) + ' · ' +
						num(profile.attended) + ' ' + esc(t('events_attended')) + '</p>' +
				'</div>' +
				addFriend +
			'</div>';
	}

	/** Three headline numbers. Everything is free, so none of them is money. */
	function statsMarkup(profile) {
		return '' +
			'<div class="hv-stat-grid">' +
				'<div class="hv-stat">' +
					'<div class="hv-stat-icon is-blue">' + icon('users') + '</div>' +
					'<div class="hv-stat-value">' + num(profile.attended || 0) + '</div>' +
					'<div class="hv-stat-label">' + esc(t('stat_attended')) + '</div>' +
				'</div>' +
				'<div class="hv-stat">' +
					'<div class="hv-stat-icon is-green">' + icon('star') + '</div>' +
					'<div class="hv-stat-value">' + num(profile.rating) + '</div>' +
					'<div class="hv-stat-label">' + esc(t('rating_score')) + '</div>' +
				'</div>' +
				'<div class="hv-stat">' +
					'<div class="hv-stat-icon is-orange">' + icon('chat') + '</div>' +
					'<div class="hv-stat-value">' + num(profile.rating_count || 0) + '</div>' +
					'<div class="hv-stat-label">' + esc(t('rating_count')) + '</div>' +
				'</div>' +
			'</div>';
	}

	function behaviourMarkup(profile) {
		var tags = (profile.interests || []).map(function (item) {
			return '<span class="hv-behaviour-tag">' + esc(pick(item)) + '</span>';
		}).join('');

		var extro = profile.extroversion >= 7 ? t('extrovert') : (profile.extroversion <= 4 ? t('introvert') : 'Ambivert');
		var talk = profile.talkative >= 7 ? t('speaker') : (profile.talkative <= 4 ? t('listener') : '—');

		// The five traits added with the longer test, each shown as a small
		// labelled bar so the result reads as a profile rather than numbers.
		var bars = [
			{ label: t('trait_openness'), value: profile.openness },
			{ label: t('trait_humor'),    value: profile.humor },
			{ label: t('trait_energy'),   value: profile.energy },
			{ label: t('trait_planning'), value: profile.planning },
			{ label: t('trait_empathy'),  value: profile.empathy }
		].filter(function (row) {
			return typeof row.value === 'number' && row.value > 0;
		}).map(function (row) {
			return '<div class="hv-trait">' +
				'<span class="hv-trait-label">' + esc(row.label) + '</span>' +
				'<span class="hv-trait-bar"><i style="inline-size:' + (row.value * 10) + '%"></i></span>' +
				'<span class="hv-trait-value">' + num(row.value) + '</span>' +
			'</div>';
		}).join('');

		return '' +
			'<div class="hv-card">' +
				'<div class="hv-section-head">' +
					'<h3 class="hv-section-title">' + esc(t('behaviour_id')) + '</h3>' +
					(profile.is_self
						? '<button type="button" class="hv-btn hv-btn-ghost hv-btn-sm" id="hv-edit-behaviour">' +
							esc(t('edit')) + '</button>'
						: '') +
				'</div>' +
				'<div class="hv-behaviour-tags">' +
					'<span class="hv-behaviour-tag">' + esc(extro) + ' · ' + num(profile.extroversion) + '/' + num(10) + '</span>' +
					'<span class="hv-behaviour-tag">' + esc(talk) + '</span>' +
					'<span class="hv-behaviour-tag">' + esc(profile.vibe === 'deep' ? t('vibe_deep') : t('vibe_fun')) + '</span>' +
					(profile.age ? '<span class="hv-behaviour-tag">' + num(profile.age) + '</span>' : '') +
					(pick(profile.city_label) ? '<span class="hv-behaviour-tag">' + esc(pick(profile.city_label)) + '</span>' : '') +
					tags +
				'</div>' +
				(bars ? '<div class="hv-traits">' + bars + '</div>' : '') +
			'</div>';
	}

	function friendRequestsMarkup(requests) {
		return '' +
			'<div class="hv-card">' +
				'<h3 class="hv-section-title">' + esc(t('friend_requests')) + '</h3>' +
				requests.map(function (req) {
					return '<div class="hv-list-card" data-open-user="' + req.user.id + '">' +
						'<span class="hv-list-thumb"><img src="' + esc(req.user.avatar) + '" alt=""></span>' +
						'<span class="hv-list-body"><span class="hv-list-title">' + esc(req.user.name) + '</span></span>' +
						'<span class="hv-list-meta hv-row">' +
							'<button type="button" class="hv-btn hv-btn-green hv-btn-sm" data-friend-yes="' + req.user.id + '">' + esc(t('accept')) + '</button>' +
							'<button type="button" class="hv-btn hv-btn-ghost hv-btn-sm" data-friend-no="' + req.user.id + '">' + esc(t('reject')) + '</button>' +
						'</span>' +
					'</div>';
				}).join('') +
			'</div>';
	}

	function feedbackMarkup(items) {
		return items.map(function (item) {
			return '<div class="hv-card">' +
				'<div class="hv-alert hv-alert-orange">' + esc(t('feedback_pending')) + '</div>' +
				'<h3 class="hv-section-title">' + esc(pick(item.venue)) + ' · ' + esc(pick(item.date)) + '</h3>' +
				'<p class="hv-muted">' + esc(t('feedback_intro')) + '</p>' +
				item.mates.map(function (mate) {
					return feedbackRow(item.group_id, mate);
				}).join('') +
			'</div>';
		}).join('');
	}

	function feedbackRow(groupId, mate) {
		var addFriend = '';
		if (mate.friend_status === 'none' && !mate.blocked) {
			addFriend = '<button type="button" class="hv-btn hv-btn-blue hv-btn-sm" data-friend-add="' + mate.id + '">' +
				esc(t('add_friend')) + '</button>';
		} else if (mate.friend_status === 'accepted') {
			addFriend = '<span class="hv-badge hv-badge-green">' + esc(t('friend_accepted')) + '</span>';
		} else if (mate.friend_status === 'pending_out') {
			addFriend = '<span class="hv-badge hv-badge-orange">' + esc(t('friend_pending')) + '</span>';
		}

		return '' +
			'<div class="hv-card" style="background:var(--hv-card-2);box-shadow:none;margin-top:12px" data-feedback-row="' + esc(groupId) + '|' + mate.id + '">' +
				'<div class="hv-row-between">' +
					'<div class="hv-row"' + (mate.blocked ? '' : ' data-open-user="' + mate.id + '" style="cursor:pointer"') + '>' +
						'<img class="hv-list-thumb" style="width:40px;height:40px" src="' + esc(mate.avatar) + '" alt="">' +
						'<strong>' + esc(mate.name) + '</strong>' +
					'</div>' +
					addFriend +
				'</div>' +
				'<div class="hv-stars hv-mt" data-stars>' +
					[1, 2, 3, 4, 5].map(function (i) {
						return '<button type="button" class="hv-star" data-star="' + i + '">★</button>';
					}).join('') +
				'</div>' +
				'<textarea class="hv-textarea hv-mt" data-comment placeholder="' + esc(t('feedback_comment')) + '"></textarea>' +
				'<label class="hv-row hv-mt" style="font-size:.8rem">' +
					'<input type="checkbox" data-block> <span>' + esc(t('feedback_block')) + '</span>' +
				'</label>' +
				'<button type="button" class="hv-btn hv-btn-primary hv-btn-block hv-mt" data-feedback-send>' + esc(t('submit')) + '</button>' +
			'</div>';
	}

	function myEventsMarkup(events) {
		return '' +
			'<div class="hv-card">' +
				'<h3 class="hv-section-title">' + esc(t('my_events')) + '</h3>' +
				events.map(function (event) {
					return '<div class="hv-list-card" style="cursor:default">' +
						'<span class="hv-list-thumb">' +
							(event.image ? '<img src="' + esc(event.image) + '" alt="">' : icon('cup')) +
						'</span>' +
						'<span class="hv-list-body">' +
							'<span class="hv-list-title">' + esc(pick(event.venue)) + '</span>' +
							'<span class="hv-list-sub">' + esc(eventDate(event)) + ' · ' + num(event.time) + '</span>' +
						'</span>' +
						'<span class="hv-list-meta">' +
							statusBadge(event.status) +
							(event.checked_in ? '<span class="hv-badge hv-badge-green">✓</span>' : '') +
						'</span>' +
					'</div>';
				}).join('') +
			'</div>';
	}

	function galleryMarkup(profile) {
		// Section 4.5: somebody else's gallery stays locked until the
		// friendship is accepted — show why instead of an empty grid.
		if (!profile.is_self && !profile.gallery_open) {
			return '' +
				'<div class="hv-card">' +
					'<h3 class="hv-section-title">' + esc(t('gallery')) + '</h3>' +
					'<div class="hv-empty">' + icon('profile') +
						'<p>' + esc(t('gallery_locked')) + '</p>' +
					'</div>' +
				'</div>';
		}

		var photos = (profile.photos || []).map(function (photo) {
			var pending = photo.status === 'pending'
				? '<span class="hv-photo-badge hv-badge hv-badge-orange">' + esc(t('photo_pending')) + '</span>'
				: '';

			return '<div class="hv-photo">' +
				pending +
				'<img src="' + esc(photo.url) + '" alt="" loading="lazy">' +
				'<div class="hv-photo-actions">' +
					'<button type="button" class="hv-photo-btn' + (photo.liked ? ' is-liked' : '') + '" data-like="' + photo.id + '">' +
						'❤️ <span>' + num(photo.likes) + '</span></button>' +
					(photo.mine
						? '<button type="button" class="hv-photo-btn" data-photo-del="' + photo.id + '">🗑</button>'
						: '<button type="button" class="hv-photo-btn" data-report="' + photo.id + '">🚩</button>') +
				'</div>' +
			'</div>';
		}).join('');

		var uploader = profile.is_self
			? '<button type="button" class="hv-photo-upload" id="hv-photo-upload">' + icon('plus', 'hv-fab-icon') +
				'<span>' + esc(t('upload_photo')) + '</span></button>'
			: '';

		return '' +
			'<div class="hv-card">' +
				'<h3 class="hv-section-title">' + esc(t('gallery')) + '</h3>' +
				'<div class="hv-gallery hv-mt">' + uploader + photos + '</div>' +
			'</div>';
	}

	function bindProfileEvents(profile) {
		var back = $('#hv-profile-back');
		if (back) {
			back.onclick = function () {
				S.viewingUser = 0;
				setTab(S.returnTab || 'profile');
				S.returnTab = null;
			};
		}

		var startTest = $('#hv-start-test');
		if (startTest) {
			startTest.onclick = function () { S.testStep = 0; renderTestStep(); };
		}

		var editDetails = $('#hv-edit-details');
		if (editDetails) { editDetails.onclick = openDetails; }

		var editBehaviour = $('#hv-edit-behaviour');
		if (editBehaviour) {
			editBehaviour.onclick = function () {
				// Re-open the same test, pre-filled with the stored answers so
				// it edits rather than starting from scratch.
				var p = S.data.profile || {};
				S.testData = {
					extroversion: p.extroversion || 5,
					talkative: p.talkative || 5,
					openness: p.openness || 5,
					humor: p.humor || 5,
					energy: p.energy || 5,
					planning: p.planning || 5,
					empathy: p.empathy || 5,
					vibe: p.vibe || 'fun',
					interests: (p.interests || []).map(function (i) { return i.key; })
				};
				S.testStep = 0;
				renderTestStep();
			};
		}

		var del = $('#hv-delete-account');
		if (del) { del.onclick = confirmDeleteAccount; }

		var logout = $('#hv-logout');
		if (logout) {
			logout.onclick = function () {
				logout.disabled = true;
				doLogout();
			};
		}

		var upload = $('#hv-photo-upload');
		if (upload) { upload.onclick = pickGalleryPhoto; }

		var avatar = $('#hv-avatar-upload');
		if (avatar) {
			avatar.onclick = function () {
				pickFile(function (file) {
					uploadWithProgress('profile/avatar', file, t('uploading_avatar'))
						.then(function () { progress.done(t('saved')); viewProfile(); })
						.catch(function (err) { uploadFailed(err); });
				});
			};
		}

		$$('[data-like]').forEach(function (btn) {
			btn.onclick = function () {
				api('photos/like', { method: 'POST', body: { photo_id: parseInt(btn.dataset.like, 10) } })
					.then(function (res) {
						btn.classList.toggle('is-liked', res.liked);
						btn.querySelector('span').textContent = num(res.likes);
					})
					.catch(function (err) { toast(err.message, 'error'); });
			};
		});

		$$('[data-report]').forEach(function (btn) {
			btn.onclick = function () { openReportForm(parseInt(btn.dataset.report, 10)); };
		});

		$$('[data-photo-del]').forEach(function (btn) {
			btn.onclick = function () {
				api('photos/delete', { method: 'POST', body: { photo_id: parseInt(btn.dataset.photoDel, 10) } })
					.then(function () { viewProfile(); });
			};
		});

		bindFriendButtons();
		bindFeedbackForms();
		bindUserLinks();
	}

	function openUserProfile(userId) {
		if (!userId || userId === (S.user && S.user.id)) { return; }
		S.returnTab = S.tab;
		S.viewingUser = userId;
		S.chatRoom = null;
		stopPolling();
		setTab('profile');
	}

	function bindUserLinks() {
		$$('[data-open-user]').forEach(function (node) {
			node.onclick = function (event) {
				event.stopPropagation();
				openUserProfile(parseInt(node.dataset.openUser, 10));
			};
		});
	}

	function bindFriendButtons() {
		$$('[data-friend-add]').forEach(function (btn) {
			btn.onclick = function () {
				btn.disabled = true;
				api('friends/request', { method: 'POST', body: { user_id: parseInt(btn.dataset.friendAdd, 10) } })
					.then(function (res) {
						toast(res.status === 'accepted' ? t('friend_accepted') : t('friend_pending'), 'ok');
						btn.outerHTML = '<span class="hv-badge hv-badge-orange">' +
							esc(res.status === 'accepted' ? t('friend_accepted') : t('friend_pending')) + '</span>';
					})
					.catch(function (err) { btn.disabled = false; toast(err.message, 'error'); });
			};
		});

		$$('[data-friend-yes]').forEach(function (btn) {
			btn.onclick = function () {
				api('friends/respond', { method: 'POST', body: { user_id: parseInt(btn.dataset.friendYes, 10), accept: true } })
					.then(function () { viewProfile(); });
			};
		});

		$$('[data-friend-no]').forEach(function (btn) {
			btn.onclick = function () {
				api('friends/respond', { method: 'POST', body: { user_id: parseInt(btn.dataset.friendNo, 10), accept: false } })
					.then(function () { viewProfile(); });
			};
		});
	}

	function bindFeedbackForms() {
		$$('[data-feedback-row]').forEach(function (row) {
			var rating = 5;

			$$('[data-star]', row).forEach(function (star) {
				star.onclick = function () {
					rating = parseInt(star.dataset.star, 10);
					$$('[data-star]', row).forEach(function (other) {
						other.classList.toggle('is-on', parseInt(other.dataset.star, 10) <= rating);
					});
				};
			});
			$$('[data-star]', row).forEach(function (star) {
				star.classList.toggle('is-on', parseInt(star.dataset.star, 10) <= rating);
			});

			var send = $('[data-feedback-send]', row);
			send.onclick = function () {
				var parts = row.dataset.feedbackRow.split('|');
				send.disabled = true;
				api('feedback/submit', {
					method: 'POST',
					body: {
						group_id: parts[0],
						user_id: parseInt(parts[1], 10),
						rating: rating,
						comment: $('[data-comment]', row).value,
						block: $('[data-block]', row).checked
					}
				}).then(function (res) {
					toast(res.message || t('feedback_sent'), 'ok');
					viewProfile();
				}).catch(function (err) { send.disabled = false; toast(err.message, 'error'); });
			};
		});
	}

	function openReportForm(photoId) {
		var reasons = [
			{ key: 'nudity', label: t('reason_nudity') },
			{ key: 'fake', label: t('reason_fake') },
			{ key: 'spam', label: t('reason_spam') },
			{ key: 'other', label: t('reason_other') }
		];

		openModal(
			'<h3 class="hv-modal-title">' + esc(t('report_reason')) + '</h3>' +
			'<div class="hv-stack">' +
				reasons.map(function (r) {
					return '<button type="button" class="hv-btn hv-btn-outline hv-btn-block" data-reason="' + esc(r.key) + '">' +
						esc(r.label) + '</button>';
				}).join('') +
			'</div>'
		);

		$$('[data-reason]').forEach(function (btn) {
			btn.onclick = function () {
				api('photos/report', { method: 'POST', body: { photo_id: photoId, reason: btn.dataset.reason } })
					.then(function (res) {
						closeModal();
						toast(res.message || t('report_sent'), 'ok');
					})
					.catch(function (err) { toast(err.message, 'error'); });
			};
		});
	}

	function pickGalleryPhoto() {
		pickFile(function (file) {
			uploadWithProgress('photos/upload', file, t('uploading_photo'))
				.then(function () { progress.done(t('saved')); viewProfile(); })
				.catch(function (err) { uploadFailed(err); });
		});
	}

	function pickFile(callback) {
		var input = document.createElement('input');
		input.type = 'file';
		input.accept = 'image/*';
		input.onchange = function () {
			if (input.files && input.files[0]) { callback(input.files[0]); }
		};
		input.click();
	}

	/* =====================================================================
	 * Personality test (6-step stepper)
	 * ================================================================== */
	/* =====================================================================
	 * PERSONALITY TEST  (psychometric only — see openDetails for the rest)
	 * ================================================================== */

	/**
	 * The seven sliders/choices, in order. Declaring them as data rather than
	 * seven near-identical functions keeps the labels, the state keys and the
	 * server's trait list in one place.
	 */
	var TEST_STEPS = [
		{ key: 'extroversion', q: 'q_extroversion', lo: 'introvert',     hi: 'extrovert' },
		{ key: 'talkative',    q: 'q_talkative',    lo: 'listener',      hi: 'speaker' },
		{ key: 'openness',     q: 'q_openness',     lo: 'openness_low',  hi: 'openness_high' },
		{ key: 'humor',        q: 'q_humor',        lo: 'humor_low',     hi: 'humor_high' },
		{ key: 'energy',       q: 'q_energy',       lo: 'energy_low',    hi: 'energy_high' },
		{ key: 'planning',     q: 'q_planning',     lo: 'planning_low',  hi: 'planning_high' },
		{ key: 'empathy',      q: 'q_empathy',      lo: 'empathy_low',   hi: 'empathy_high' },
		{ vibe: true },
		{ interests: true }
	];

	function renderTestStep() {
		var steps = TEST_STEPS.length;
		var step = TEST_STEPS[S.testStep];
		var dots = '';
		for (var i = 0; i < steps; i++) {
			dots += '<i class="' + (i <= S.testStep ? 'is-done' : '') + '"></i>';
		}

		var body;
		if (step.vibe) {
			body = stepVibe();
		} else if (step.interests) {
			body = stepInterests();
		} else {
			body = stepSlider(step);
		}

		var intro = S.testStep === 0
			? '<p class="hv-muted" style="margin:0 0 12px">' + esc(t('test_intro_body')) + '</p>'
			: '';

		openModal(
			'<h3 class="hv-modal-title">' + esc(t('test_intro_title')) + '</h3>' +
			'<div class="hv-stepper-dots">' + dots + '</div>' +
			intro +
			'<div id="hv-step-body">' + body + '</div>' +
			'<div class="hv-row hv-mt">' +
				(S.testStep > 0 ? '<button type="button" class="hv-btn hv-btn-ghost" id="hv-step-prev">' + esc(t('prev')) + '</button>' : '') +
				'<button type="button" class="hv-btn hv-btn-primary" style="flex:1 1 auto" id="hv-step-next">' +
					esc(S.testStep === steps - 1 ? t('finish') : t('next')) + '</button>' +
			'</div>'
		);

		bindStepEvents();
	}

	/** One 1..10 trait slider. */
	function stepSlider(step) {
		var value = S.testData[step.key];
		return '<div class="hv-step-q">' + esc(t(step.q)) + '</div>' +
			'<div class="hv-row-between"><span class="hv-muted">' + esc(t(step.lo)) + '</span>' +
				'<span class="hv-range-value" id="hv-trait-value">' + num(value) + '</span>' +
				'<span class="hv-muted">' + esc(t(step.hi)) + '</span></div>' +
			'<input type="range" min="1" max="10" step="1" class="hv-range" id="hv-step-trait" ' +
				'data-trait="' + esc(step.key) + '" value="' + value + '">';
	}

	function stepVibe() {
		return '<div class="hv-step-q">' + esc(t('q_vibe')) + '</div>' +
			'<div class="hv-choice-grid">' +
				'<button type="button" class="hv-choice' + (S.testData.vibe === 'deep' ? ' is-active' : '') + '" data-vibe="deep">' +
					esc(t('vibe_deep')) + '</button>' +
				'<button type="button" class="hv-choice' + (S.testData.vibe === 'fun' ? ' is-active' : '') + '" data-vibe="fun">' +
					esc(t('vibe_fun')) + '</button>' +
			'</div>';
	}

	function stepInterests() {
		var tags = BOOT.interests || {};
		return '<div class="hv-step-q">' + esc(t('q_interests')) + '</div>' +
			'<div class="hv-chips">' +
				Object.keys(tags).map(function (key) {
					var active = S.testData.interests.indexOf(key) !== -1 ? ' is-active' : '';
					return '<button type="button" class="hv-chip' + active + '" data-interest="' + esc(key) + '">' +
						esc(pick(tags[key])) + '</button>';
				}).join('') +
			'</div>';
	}

	function bindStepEvents() {
		var slider = $('#hv-step-trait');
		if (slider) {
			slider.oninput = function () {
				S.testData[slider.dataset.trait] = parseInt(slider.value, 10);
				$('#hv-trait-value').textContent = num(S.testData[slider.dataset.trait]);
			};
		}

		$$('[data-vibe]').forEach(function (btn) {
			btn.onclick = function () {
				S.testData.vibe = btn.dataset.vibe;
				$$('[data-vibe]').forEach(function (o) { o.classList.toggle('is-active', o === btn); });
			};
		});

		$$('[data-interest]').forEach(function (btn) {
			btn.onclick = function () {
				var key = btn.dataset.interest;
				var idx = S.testData.interests.indexOf(key);
				if (idx === -1) { S.testData.interests.push(key); } else { S.testData.interests.splice(idx, 1); }
				btn.classList.toggle('is-active', idx === -1);
			};
		});

		var prev = $('#hv-step-prev');
		if (prev) { prev.onclick = function () { S.testStep = Math.max(0, S.testStep - 1); renderTestStep(); }; }

		$('#hv-step-next').onclick = function () {
			// Every step has a usable default, so the test can always be
			// finished — nothing here can trap the user on a step.
			if (S.testStep < TEST_STEPS.length - 1) { S.testStep++; renderTestStep(); return; }
			saveTest();
		};
	}

	function saveTest() {
		saveWithProgress(api('profile/test', { method: 'POST', body: S.testData }))
			.then(function () {
				closeModal();
				toast(t('test_done'), 'ok');
				viewProfile();
			})
			.catch(function () { /* reported by the progress bar */ });
	}

	/* =====================================================================
	 * PERSONAL DETAILS  (name, age, gender, country, city, area)
	 * ================================================================== */

	/**
	 * Open the details editor, pre-filled from the profile already on screen.
	 * Reachable at any time from the profile page, so these can be corrected
	 * later instead of being frozen at sign-up.
	 */
	/** Dialling prefix of the selected country, e.g. "+98". */
	function dialCode(country) {
		var loc = (BOOT.locations || {})[country];
		return (loc && loc.dial) ? loc.dial : '';
	}

	function phonePlaceholder(country) {
		return country === 'tr' ? '5xx xxx xx xx' : '912 345 6789';
	}

	function openDetails() {
		var profile = S.data.profile || {};
		var user = profile.user || {};

		S.detailsData = {
			name: user.name || '',
			age: profile.age || 27,
			gender: profile.gender || '',
			country: profile.country || '',
			city: profile.city || '',
			phone: profile.phone || ''
		};

		renderDetails();
	}

	function renderDetails() {
		var d = S.detailsData;
		var locations = BOOT.locations || {};

		var ages = '';
		for (var age = 18; age <= 75; age++) {
			ages += '<option value="' + age + '"' + (d.age === age ? ' selected' : '') + '>' + num(age) + '</option>';
		}

		// "Prefer not to say" was removed: the matcher uses gender for the
		// soft balance term, and an opted-out guest simply never benefits.
		var genders = [
			{ key: 'male', label: t('gender_male') },
			{ key: 'female', label: t('gender_female') }
		].map(function (opt) {
			return '<button type="button" class="hv-choice' + (d.gender === opt.key ? ' is-active' : '') +
				'" data-dgender="' + opt.key + '">' + esc(opt.label) + '</button>';
		}).join('');

		var countryBtns = Object.keys(locations).map(function (key) {
			return '<button type="button" class="hv-choice' + (d.country === key ? ' is-active' : '') +
				'" data-dcountry="' + esc(key) + '">' + esc(pick(locations[key].label)) + '</button>';
		}).join('');

		// If the server ever sends no locations the picker would be empty and
		// the form unsubmittable, so say so instead of showing a blank gap.
		if (!countryBtns) {
			countryBtns = '<div class="hv-alert hv-alert-orange">' + esc(t('error_generic')) + '</div>';
		}

		var cityBlock = '';
		if (d.country && locations[d.country]) {
			var cities = locations[d.country].cities || {};
			cityBlock =
				'<div class="hv-step-q hv-mt">' + esc(t('q_city_select')) + '</div>' +
				'<div class="hv-choice-grid">' +
					Object.keys(cities).map(function (key) {
						return '<button type="button" class="hv-choice' + (d.city === key ? ' is-active' : '') +
							'" data-dcity="' + esc(key) + '">' + esc(pick(cities[key])) + '</button>';
					}).join('') +
				'</div>';
		}

		openModal(
			'<h3 class="hv-modal-title">' + esc(t('details_title')) + '</h3>' +
			'<p class="hv-muted" style="margin:0 0 12px">' + esc(t('details_hint')) + '</p>' +

			'<div class="hv-field"><label for="hv-d-name">' + esc(t('q_name')) + '</label>' +
				'<input type="text" class="hv-input" id="hv-d-name" maxlength="60" value="' + esc(d.name) + '"></div>' +

			'<div class="hv-field hv-mt"><label for="hv-d-age">' + esc(t('q_age')) + '</label>' +
				'<select class="hv-select" id="hv-d-age">' + ages + '</select></div>' +

			'<div class="hv-step-q hv-mt">' + esc(t('q_gender')) + '</div>' +
			'<div class="hv-choice-grid">' + genders + '</div>' +

			'<div class="hv-step-q hv-mt">' + esc(t('q_country')) + '</div>' +
			'<div class="hv-choice-grid">' + countryBtns + '</div>' +
			cityBlock +

			'<div class="hv-field hv-mt"><label for="hv-d-phone">' + esc(t('q_phone')) + '</label>' +
				'<div class="hv-phone-row">' +
					'<span class="hv-dial" id="hv-d-dial">' + esc(dialCode(d.country)) + '</span>' +
					'<input type="tel" inputmode="tel" autocomplete="tel" class="hv-input" id="hv-d-phone" ' +
						'value="' + esc(d.phone) + '" placeholder="' + esc(phonePlaceholder(d.country)) + '">' +
				'</div>' +
				'<p class="hv-muted" style="margin:6px 0 0">' + esc(t('phone_hint')) + '</p></div>' +

			'<button type="button" class="hv-btn hv-btn-primary hv-btn-block hv-mt" id="hv-d-save">' +
				esc(t('save')) + '</button>'
		);

		bindDetailsEvents();
	}

	function bindDetailsEvents() {
		var name = $('#hv-d-name');
		if (name) { name.oninput = function () { S.detailsData.name = name.value; }; }

		var age = $('#hv-d-age');
		if (age) { age.onchange = function () { S.detailsData.age = parseInt(age.value, 10); }; }

		var phone = $('#hv-d-phone');
		if (phone) { phone.oninput = function () { S.detailsData.phone = phone.value; }; }

		$$('[data-dgender]').forEach(function (btn) {
			btn.onclick = function () {
				S.detailsData.gender = btn.dataset.dgender;
				$$('[data-dgender]').forEach(function (o) { o.classList.toggle('is-active', o === btn); });
			};
		});

		$$('[data-dcountry]').forEach(function (btn) {
			btn.onclick = function () {
				if (S.detailsData.country === btn.dataset.dcountry) { return; }
				S.detailsData.country = btn.dataset.dcountry;
				S.detailsData.city = ''; // a city from the old country would be invalid
				// Re-rendering also refreshes the dialling prefix.
				renderDetails();
			};
		});

		$$('[data-dcity]').forEach(function (btn) {
			btn.onclick = function () {
				S.detailsData.city = btn.dataset.dcity;
				$$('[data-dcity]').forEach(function (o) { o.classList.toggle('is-active', o === btn); });
			};
		});

		$('#hv-d-save').onclick = function () {
			var d = S.detailsData;

			if (!d.name || d.name.trim().length < 2) { toast(t('err_name_short'), 'error'); return; }
			if (!d.gender) { toast(t('q_gender'), 'error'); return; }
			if (!d.country || !d.city) { toast(t('q_city_select'), 'error'); return; }
			// Server normalises and re-validates; this is only a fast local
			// check so the user is not bounced by a round-trip.
			if (String(d.phone).replace(/\D+/g, '').length < 6) { toast(t('err_phone'), 'error'); return; }

			saveWithProgress(api('profile/details', { method: 'POST', body: d }))
				.then(function (res) {
					closeModal();
					toast(t('details_saved'), 'ok');
					if (res && res.city) { S.city = res.city; }
					// The city drives where the map opens.
					if (res && res.map) { S.mapCenter = res.map; }
					// Picking Turkey switches the panel to Turkish straight away.
					if (res && res.lang && res.lang !== S.lang) { applyLang(res.lang); }
					if (res && res.user) { S.user = res.user; renderHeaderUser(); }
					viewProfile();
				})
				.catch(function () { /* reported by the progress bar */ });
		};
	}

	/* =====================================================================


	/* =====================================================================



	/* =====================================================================






	/* =====================================================================



	/* =====================================================================
	 * Boot
	 * ================================================================== */
	function cacheElements() {
		el.root = $('#havato-app');
		el.header = $('#hv-header');
		el.headerTitle = $('#hv-header-title');
		el.headerEyebrow = $('#hv-header-eyebrow');
		el.headerAvatar = $('#hv-header-avatar');
		el.avatarFallback = $('#hv-avatar-fallback');
		el.langLabel = $('#hv-lang-label');
		el.langBtn = $('#hv-lang-btn');
		el.langMenu = $('#hv-lang-menu');
		el.strip = $('#hv-status-strip');
		el.main = $('#main-tab-content');
		el.bottomNav = $('#hv-bottom-nav');
		el.tabs = $('#hv-tabs');
		el.headerAction = $('#hv-header-action');
		el.modalHost = $('#hv-modal-host');
		el.modalBody = $('#hv-modal-body');
		el.toastHost = $('#hv-toast-host');
		el.redirect = $('#hv-redirect');
		el.redirectText = $('#hv-redirect-text');
	}

	function bindGlobalEvents() {
		el.tabs.addEventListener('click', function (event) {
			var btn = event.target.closest('.hv-tab');
			if (btn) { setTab(btn.dataset.tab); }
		});

		el.langBtn.onclick = function (event) {
			event.stopPropagation();
			toggleLangMenu();
		};

		// Tapping anywhere else closes it. Without this the list would stay
		// open behind whatever the guest went on to do.
		document.addEventListener('click', function (event) {
			if (el.langMenu && !el.langMenu.hidden && !event.target.closest('.hv-lang-wrap')) {
				closeLangMenu();
			}
		});
		document.addEventListener('keydown', function (event) {
			if ('Escape' === event.key) { closeLangMenu(); }
		});
		$('#hv-avatar-btn').onclick = function () {
			if (!S.loggedIn) { return; }
			setTab('profile');
		};

		el.modalHost.addEventListener('click', function (event) {
			if (event.target.dataset && event.target.dataset.close) { closeModal(); }
		});

		document.addEventListener('keydown', function (event) {
			if (event.key === 'Escape' && !el.modalHost.hidden) { closeModal(); }
		});

		// Keep the layout stable when the mobile keyboard opens/closes.
		window.addEventListener('resize', function () {
			if (S.map) { S.map.invalidateSize(); }
			if (S.ownerMap) { S.ownerMap.invalidateSize(); }
		});
	}

	/**
	 * Delete the account, asking twice.
	 *
	 * Step 1 explains what is lost. Step 2 requires the word to be typed, so
	 * it cannot be completed by tapping through. The server independently
	 * requires confirm=DELETE.
	 */
	function confirmDeleteAccount() {
		openModal(
			'<h3 class="hv-modal-title">' + esc(t('delete_account')) + '</h3>' +
			'<div class="hv-alert hv-alert-orange">' + esc(t('delete_confirm_1')) + '</div>' +
			'<button type="button" class="hv-btn hv-btn-danger hv-btn-block hv-mt" id="hv-del-step1">' +
				esc(t('delete_continue')) + '</button>' +
			'<button type="button" class="hv-btn hv-btn-ghost hv-btn-block hv-mt" data-close="1">' +
				esc(t('cancel')) + '</button>'
		);

		$('#hv-del-step1').onclick = function () {
			var word = t('delete_keyword');

			openModal(
				'<h3 class="hv-modal-title">' + esc(t('delete_account')) + '</h3>' +
				'<p class="hv-muted">' + esc(t('delete_confirm_2')) + '</p>' +
				'<p style="font-weight:800;font-size:1.1rem;margin:8px 0">' + esc(word) + '</p>' +
				'<input type="text" class="hv-input" id="hv-del-word" autocomplete="off">' +
				'<button type="button" class="hv-btn hv-btn-danger hv-btn-block hv-mt" id="hv-del-final">' +
					esc(t('delete_final')) + '</button>' +
				'<button type="button" class="hv-btn hv-btn-ghost hv-btn-block hv-mt" data-close="1">' +
					esc(t('cancel')) + '</button>'
			);

			$('#hv-del-final').onclick = function () {
				var typed = ($('#hv-del-word').value || '').trim();
				if (typed !== word) { toast(t('delete_mismatch'), 'error'); return; }

				var btn = $('#hv-del-final');
				btn.disabled = true;

				api('profile/delete', { method: 'POST', body: { confirm: 'DELETE' } })
					.then(function () {
						closeModal();
						toast(t('delete_done'), 'ok');
						disableGoogleAutoSelect();
						clearAppCaches().then(hardReload, hardReload);
					})
					.catch(function (err) {
						btn.disabled = false;
						toast(err.message, 'error');
					});
			};
		};
	}

	/* =====================================================================
	 * LOGOUT
	 * ================================================================== */

	/**
	 * Sign out for real.
	 *
	 * Re-rendering the SPA is NOT enough: the WordPress session lives in a
	 * cookie that the rest of the site (theme header, admin bar, other open
	 * tabs) still sees, and the service worker may hold a cached copy of the
	 * signed-in HTML/bootstrap. So we
	 *   1. stop Google from silently signing the user back in,
	 *   2. drop the server session,
	 *   3. wipe every cache the worker owns,
	 *   4. do a real top-level navigation so nothing stale survives.
	 */
	function doLogout() {
		disableGoogleAutoSelect();

		var finish = function () {
			clearAppCaches().then(hardReload, hardReload);
		};

		api('auth/logout', { method: 'POST' }).then(finish, function () {
			// REST unreachable or the nonce expired: fall back to the native
			// WordPress logout URL so the session always ends.
			clearAppCaches().then(function () {
				window.location.replace(BOOT.logoutUrl || BOOT.homeUrl || '/');
			}, function () {
				window.location.replace(BOOT.logoutUrl || BOOT.homeUrl || '/');
			});
		});
	}

	function disableGoogleAutoSelect() {
		try {
			if (window.google && window.google.accounts && window.google.accounts.id) {
				window.google.accounts.id.disableAutoSelect();
			}
		} catch (e) { /* SDK blocked — nothing to disable */ }
	}

	/**
	 * Empty the CacheStorage and tell the active worker to do the same.
	 * Always resolves: a failure here must never block the sign-out.
	 */
	function clearAppCaches() {
		var jobs = [];

		try {
			if (window.caches && caches.keys) {
				jobs.push(caches.keys().then(function (keys) {
					return Promise.all(keys.map(function (k) { return caches.delete(k); }));
				}));
			}
			if (navigator.serviceWorker && navigator.serviceWorker.controller) {
				navigator.serviceWorker.controller.postMessage({ type: 'havato-logout' });
			}
		} catch (e) { /* private mode / unsupported */ }

		return Promise.all(jobs).catch(function () { return null; });
	}

	/**
	 * Full page load (not a history navigation), cache-busted so no
	 * intermediate proxy can hand back the signed-in document.
	 */
	function hardReload() {
		var base = BOOT.homeUrl || window.location.pathname;
		try {
			var u = new URL(window.location.href);
			u.hash = '';
			u.searchParams.set('hv', String(Date.now()));
			window.location.replace(u.toString());
			return;
		} catch (e) { /* very old browser */ }
		window.location.replace(base);
	}

	function registerServiceWorker() {
		if (!('serviceWorker' in navigator) || !BOOT.swUrl) { return; }
		if (window.location.protocol !== 'https:' && window.location.hostname !== 'localhost') { return; }
		navigator.serviceWorker.register(BOOT.swUrl).catch(function () { /* optional */ });
	}

	function boot() {
		cacheElements();
		if (!el.root) { return; }

		applyLangSilent(BOOT.lang);
		bindGlobalEvents();
		buildTabs();
		initHistory();

		api('bootstrap').then(function (res) {
			S.loggedIn = !!res.logged_in;
			S.role = res.role || 'guest';
			S.user = res.user || null;
			S.venue = res.venue || null;
			S.city = res.city || '';
			if (res.map) { S.mapCenter = res.map; }

			if (res.lang && res.lang !== S.lang) { applyLangSilent(res.lang); }

			buildTabs();
			render();
			S.booted = true;
		}).catch(function (err) {
			// Never leave the user staring at a spinner: if the REST API is
			// unreachable (permalinks off, wp-json blocked by a security
			// plugin, offline…) show the reason plus a retry button.
			bootFailed(err);
		});

		registerServiceWorker();
	}

	function bootFailed(err) {
		el.bottomNav.style.display = 'none';
		el.header.style.display = '';
		setHeader(t('app_name'), '');

		var detail = (err && err.message) ? err.message : t('error_generic');

		el.main.innerHTML =
			'<div class="hv-card" style="margin-top:8dvh;text-align:center">' +
				'<div class="hv-empty">' + icon('cup') +
					'<p><strong>' + esc(t('boot_failed')) + '</strong></p>' +
					'<p class="hv-muted" style="direction:ltr;word-break:break-word">' + esc(detail) + '</p>' +
				'</div>' +
				'<button type="button" class="hv-btn hv-btn-primary hv-btn-block" id="hv-boot-retry">' +
					esc(t('retry')) + '</button>' +
			'</div>';

		var retry = $('#hv-boot-retry');
		if (retry) {
			retry.onclick = function () {
				retry.disabled = true;
				loading();
				api('bootstrap').then(function (res) {
					S.loggedIn = !!res.logged_in;
					S.role = res.role || 'guest';
					S.user = res.user || null;
					S.venue = res.venue || null;
					if (res.map) { S.mapCenter = res.map; }
					buildTabs();
					render();
					S.booted = true;
				}).catch(bootFailed);
			};
		}
	}

	function applyLangSilent(lang) {
		setLangAttrs(lang);
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', boot);
	} else {
		boot();
	}
})();
