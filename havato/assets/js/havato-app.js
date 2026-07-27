/**
 * Havato web-app — single-page controller.
 *
 * Design goals:
 *   • Zero full page reloads (WebView friendly): every navigation is a fetch +
 *     re-render, tab state is mirrored into the History API so the hardware
 *     Back button moves between tabs instead of leaving the app.
 *   • Instant bilingual switch: all strings live in HAVATO_BOOT.i18n, dates and
 *     prices are pre-rendered by PHP in both calendars, so switching language
 *     only re-renders the current view.
 *   • Two completely separate portals: gatherer (client) and cafe_owner.
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
		authView: 'wall', // wall | owner-login | owner-register
		chatMode: 'groups',
		chatRoom: null, // {type:'group'|'private', id}
		viewingUser: 0, // >0 while looking at somebody else's public profile
		returnTab: null,
		pollTimer: null,
		lastMsgId: 0,
		map: null,
		mapMarkers: [],
		meMarker: null,   // "you are here" dot, recreated with each map
		ownerMap: null,
		testStep: 0,
		testData: { age: 27, gender: '', extroversion: 5, talkative: 5, vibe: 'fun', interests: [], neighborhood: '', country: '', city: '' },
		menuDraft: [],
		menuOpenRow: -1,
		menuHasPending: false,
		booted: false
	};

	var el = {};

	/* =====================================================================
	 * Tiny helpers
	 * ================================================================== */
	function $(sel, root) { return (root || document).querySelector(sel); }
	function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

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
	function applyLang(lang) {
		S.lang = lang === 'en' ? 'en' : 'fa';
		S.dir = S.lang === 'fa' ? 'rtl' : 'ltr';

		el.root.setAttribute('dir', S.dir);
		el.root.setAttribute('data-lang', S.lang);
		el.root.classList.toggle('hv-dir-rtl', S.dir === 'rtl');
		el.root.classList.toggle('hv-dir-ltr', S.dir === 'ltr');
		el.langLabel.textContent = S.lang === 'fa' ? 'EN' : 'فا';

		document.cookie = 'havato_lang=' + S.lang + ';path=/;max-age=31536000;samesite=lax';

		buildTabs();
		render();
	}

	function toggleLang() {
		var next = S.lang === 'fa' ? 'en' : 'fa';
		applyLang(next);
		api('lang', { method: 'POST', body: { value: next } }).catch(function () {});
	}

	/* =====================================================================
	 * Tabs & routing
	 * ================================================================== */
	function tabsFor(role) {
		// nav-* icons are the monochrome variants: they paint with
		// currentColor so the tab state (translucent vs solid white) actually
		// drives them on the dark indigo bar.
		if (role === 'cafe_owner') {
			return [
				{ id: 'dashboard', label: 'tab_dashboard', icon: 'nav-dashboard' },
				{ id: 'venue-events', label: 'tab_venue_events', icon: 'nav-calendar' },
				{ id: 'menu', label: 'tab_menu_builder', icon: 'nav-menu' },
				{ id: 'venue-settings', label: 'tab_venue_settings', icon: 'nav-settings' }
			];
		}
		return [
			{ id: 'explore', label: 'tab_explore', icon: 'nav-explore' },
			{ id: 'map', label: 'tab_map', icon: 'nav-map' },
			{ id: 'chats', label: 'tab_chats', icon: 'nav-chat' },
			{ id: 'profile', label: 'tab_profile', icon: 'nav-profile' }
		];
	}

	function buildTabs() {
		S.tabs = tabsFor(S.role);
		if (!S.tab || !S.tabs.some(function (tab) { return tab.id === S.tab; })) {
			S.tab = S.tabs[0].id;
		}

		el.tabs.innerHTML = S.tabs.map(function (tab) {
			return '<button type="button" class="hv-tab' + (tab.id === S.tab ? ' is-active' : '') +
				'" data-tab="' + tab.id + '" role="tab">' +
				icon(tab.icon) + '<span>' + esc(t(tab.label)) + '</span></button>';
		}).join('');
	}

	function setTab(id, push) {
		if (!S.tabs.some(function (tab) { return tab.id === id; })) { return; }
		S.tab = id;
		S.chatRoom = null;
		if ('profile' !== id) { S.viewingUser = 0; }
		stopPolling();

		$$('.hv-tab', el.tabs).forEach(function (btn) {
			btn.classList.toggle('is-active', btn.dataset.tab === id);
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
	 * Floating action button — bound to the primary action of each tab
	 * ================================================================== */
	function updateFab() {
		var conf = {
			explore: { icon: 'filter', action: showFilters },
			map: { icon: 'map', action: locateMe },
			chats: { icon: 'chat', action: function () { S.chatRoom = null; render(); } },
			profile: { icon: 'plus', action: pickGalleryPhoto },
			dashboard: { icon: 'filter', action: function () { loadTab(true); } },
			'venue-events': { icon: 'plus', action: openCreateEvent },
			menu: { icon: 'plus', action: addMenuRow },
			'venue-settings': { icon: 'check', action: saveVenueForm }
		}[S.tab] || { icon: 'filter', action: function () { loadTab(true); } };

		el.fab.querySelector('use').setAttribute('href', '#hv-i-' + conf.icon);
		el.fab.onclick = function () {
			if (!S.loggedIn) { return; }
			conf.action();
		};
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
		updateFab();
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
			explore: viewExplore,
			map: viewMap,
			chats: viewChats,
			profile: viewProfile,
			dashboard: viewOwnerDashboard,
			'venue-events': viewOwnerEvents,
			menu: viewMenuBuilder,
			'venue-settings': viewVenueSettings
		};

		var fn = loaders[tab] || viewExplore;
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
		if (S.authView === 'owner-login') {
			body = ownerLoginMarkup();
		} else if (S.authView === 'owner-register') {
			body = ownerRegisterMarkup();
		} else {
			body = authWallMarkup();
		}

		el.authwall.innerHTML =
			'<button type="button" class="hv-lang-btn hv-auth-lang" id="hv-auth-lang">' +
				(S.lang === 'fa' ? 'EN' : 'فا') +
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

		return '' +
			'<div class="hv-auth-card hv-glass">' +
				'<div class="hv-auth-logo">' + icon('cup') + '</div>' +
				'<h2 class="hv-auth-title">' + esc(t('auth_title')) + '</h2>' +
				'<p class="hv-auth-sub">' + esc(t('auth_sub')) + '</p>' +
				googleBlock +
				'<div class="hv-auth-foot">' +
					'<button type="button" data-auth="owner-login">' + esc(t('login_owner')) + '</button>' +
					'<button type="button" data-auth="owner-register">' + esc(t('register_partner')) + '</button>' +
				'</div>' +
			'</div>';
	}

	function ownerLoginMarkup() {
		return '' +
			'<div class="hv-auth-card hv-glass">' +
				'<div class="hv-auth-logo">' + icon('cup') + '</div>' +
				'<h2 class="hv-auth-title">' + esc(t('owner_login_title')) + '</h2>' +
				'<div class="hv-field"><label>' + esc(t('email')) + '</label>' +
					'<input type="email" class="hv-input" id="hv-owner-email" autocomplete="username"></div>' +
				'<div class="hv-field"><label>' + esc(t('password')) + '</label>' +
					'<input type="password" class="hv-input" id="hv-owner-pass" autocomplete="current-password"></div>' +
				'<button type="button" class="hv-btn hv-btn-blue hv-btn-block" id="hv-owner-login-btn">' + esc(t('owner_signin')) + '</button>' +
				'<div class="hv-auth-foot">' +
					'<button type="button" data-auth="owner-register">' + esc(t('register_partner')) + '</button>' +
					'<button type="button" data-auth="wall">' + esc(t('back')) + '</button>' +
				'</div>' +
			'</div>';
	}

	function ownerRegisterMarkup() {
		return '' +
			'<div class="hv-auth-card hv-glass">' +
				'<div class="hv-auth-logo">' + icon('cup') + '</div>' +
				'<h2 class="hv-auth-title">' + esc(t('owner_signup')) + '</h2>' +
				'<div class="hv-field"><label>' + esc(t('venue_name')) + '</label>' +
					'<input type="text" class="hv-input" id="hv-reg-name"></div>' +
				'<div class="hv-field"><label>' + esc(t('manager_name')) + '</label>' +
					'<input type="text" class="hv-input" id="hv-reg-manager"></div>' +
				locationSelects('hv-reg', '', '') +
				'<div class="hv-field"><label>' + esc(t('venue_address')) + '</label>' +
					'<textarea class="hv-textarea" id="hv-reg-addr"></textarea></div>' +
				'<div class="hv-field"><label>' + esc(t('email')) + '</label>' +
					'<input type="email" class="hv-input" id="hv-reg-email" autocomplete="email"></div>' +
				'<div class="hv-field"><label>' + esc(t('password')) + '</label>' +
					'<input type="password" class="hv-input" id="hv-reg-pass" autocomplete="new-password"></div>' +
				'<button type="button" class="hv-btn hv-btn-green hv-btn-block" id="hv-owner-reg-btn">' + esc(t('owner_signup')) + '</button>' +
				'<div class="hv-auth-foot">' +
					'<button type="button" data-auth="owner-login">' + esc(t('owner_signin')) + '</button>' +
					'<button type="button" data-auth="wall">' + esc(t('back')) + '</button>' +
				'</div>' +
			'</div>';
	}

	/**
	 * Country + city <select> pair for the owner forms. Changing the country
	 * repopulates the cities, so an invalid pair cannot be submitted.
	 */
	function locationSelects(idPrefix, country, city) {
		var locations = BOOT.locations || {};
		var countries = Object.keys(locations);
		if (!country || !locations[country]) { country = countries[0]; }
		var cities = Object.keys((locations[country] || {}).cities || {});
		if (cities.indexOf(city) === -1) { city = cities[0]; }

		return '<div class="hv-field"><label>' + esc(t('q_country')) + '</label>' +
				'<select class="hv-select" id="' + idPrefix + '-country">' +
					countries.map(function (k) {
						return '<option value="' + esc(k) + '"' + (k === country ? ' selected' : '') + '>' +
							esc(pick(locations[k].label)) + '</option>';
					}).join('') +
				'</select></div>' +
			'<div class="hv-field hv-mt"><label>' + esc(t('q_city_select')) + '</label>' +
				'<select class="hv-select" id="' + idPrefix + '-city">' +
					cities.map(function (k) {
						return '<option value="' + esc(k) + '"' + (k === city ? ' selected' : '') + '>' +
							esc(pick(locations[country].cities[k])) + '</option>';
					}).join('') +
				'</select></div>';
	}

	/** Keep the city list in sync with the chosen country. */
	function bindLocationSelects(idPrefix) {
		var cSel = $('#' + idPrefix + '-country');
		var sSel = $('#' + idPrefix + '-city');
		if (!cSel || !sSel) { return; }

		cSel.onchange = function () {
			var cities = ((BOOT.locations || {})[cSel.value] || {}).cities || {};
			sSel.innerHTML = Object.keys(cities).map(function (k) {
				return '<option value="' + esc(k) + '">' + esc(pick(cities[k])) + '</option>';
			}).join('');
		};
	}

	function bindAuthEvents() {
		$$('[data-auth]', el.authwall).forEach(function (btn) {
			btn.onclick = function () {
				S.authView = btn.dataset.auth;
				renderAuthWall();
			};
		});

		var loginBtn = $('#hv-owner-login-btn');
		if (loginBtn) {
			loginBtn.onclick = function () {
				var email = $('#hv-owner-email').value.trim();
				var pass = $('#hv-owner-pass').value;
				if (!email || !pass) { toast(t('error_generic'), 'error'); return; }
				loginBtn.disabled = true;
				api('owner/login', { method: 'POST', body: { email: email, password: pass } })
					.then(function (res) {
						S.loggedIn = true;
						S.role = res.role || 'cafe_owner';
						S.user = res.user;
						S.venue = res.venue;
						S.tab = null;
						buildTabs();
						render();
					})
					.catch(function (err) { toast(err.message, 'error'); loginBtn.disabled = false; });
			};
		}

		var regBtn = $('#hv-owner-reg-btn');
		if (regBtn) {
			regBtn.onclick = function () {
				var payload = {
					venue_name: $('#hv-reg-name').value.trim(),
					manager_name: $('#hv-reg-manager').value.trim(),
					country: $('#hv-reg-country').value,
					city: $('#hv-reg-city').value,
					address: $('#hv-reg-addr').value.trim(),
					email: $('#hv-reg-email').value.trim(),
					password: $('#hv-reg-pass').value
				};
				if (!payload.venue_name || !payload.manager_name || !payload.email || payload.password.length < 6) {
					toast(t('error_generic'), 'error');
					return;
				}
				regBtn.disabled = true;
				api('owner/register', { method: 'POST', body: payload })
					.then(function (res) {
						S.loggedIn = true;
						S.role = 'cafe_owner';
						S.user = res.user;
						S.venue = res.venue;
						S.tab = null;
						buildTabs();
						render();
						toast(t('owner_pending_notice'), 'info');
					})
					.catch(function (err) { toast(err.message, 'error'); regBtn.disabled = false; });
			};
		}

		bindLocationSelects('hv-reg');

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
	 * TAB: EXPLORE
	 * ================================================================== */
	function viewExplore() {
		setHeader(t('explore_title'), t('app_name'));
		setStatusStrip('');

		var params = {};
		if (S.data.exploreFilter) { params.budget = S.data.exploreFilter; }

		return api('events', { params: params }).then(function (res) {
			S.data.events = res.events || [];

			if (!S.data.events.length) {
				// Results are scoped to the user's city, so say so.
				el.main.innerHTML = emptyState(S.city ? t('city_empty') : t('explore_empty'), 'explore');
				return;
			}

			el.main.innerHTML =
				'<div class="hv-section">' +
					S.data.events.map(eventCard).join('') +
				'</div>';

			$$('[data-event-join]').forEach(function (btn) {
				btn.onclick = function () { joinEvent(btn.dataset.eventJoin, btn); };
			});
			$$('[data-venue-open]').forEach(function (node) {
				node.onclick = function () { openVenue(node.dataset.venueOpen); };
			});
		});
	}

	function eventCard(event) {
		var full = event.seats_left <= 0;
		var pct = event.capacity ? Math.round((event.taken / event.capacity) * 100) : 0;

		var action;
		if (event.joined) {
			action = '<span class="hv-badge hv-badge-green">' + esc(t('joined_event')) + '</span>';
		} else if (full || event.status !== 'open') {
			action = '<button class="hv-btn hv-btn-ghost hv-btn-sm" disabled>' + esc(t('event_full')) + '</button>';
		} else {
			action = '<button class="hv-btn hv-btn-primary hv-btn-sm" data-event-join="' + esc(event.id) + '">' +
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
						'<p class="hv-event-when">' + esc(pick(event.weekday)) + ' · ' + esc(pick(event.date)) + ' · ' + num(event.time) + '</p>' +
						'<div class="hv-row" style="margin-top:7px">' +
							statusBadge(event.status) +
							'<span class="hv-badge hv-badge-indigo">' + esc(budgetLabel(event.budget_tier)) + '</span>' +
						'</div>' +
					'</div>' +
				'</div>' +
				'<div class="hv-seatbar"><span style="width:' + pct + '%"></span></div>' +
				'<div class="hv-event-foot">' +
					'<div>' +
						'<div class="hv-event-price">' + esc(pick(event.price_label)) + '</div>' +
						'<div class="hv-muted">' + num(event.seats_left) + ' ' + esc(t('seats_left')) + '</div>' +
					'</div>' +
					action +
				'</div>' +
			'</article>';
	}

	function joinEvent(eventId, btn) {
		btn.disabled = true;
		api('events/join', { method: 'POST', body: { event_id: eventId } })
			.then(function (res) {
				if (res.checkout_url) {
					el.redirectText.textContent = t('redirect_payment');
					el.redirect.hidden = false;
					setTimeout(function () { window.location.href = res.checkout_url; }, 700);
					return;
				}
				toast(res.matched ? t('status_matched') : t('joined_event'), 'ok');
				viewExplore();
			})
			.catch(function (err) {
				btn.disabled = false;
				toast(err.message, 'error');
				if (err.data && err.data.code === 'havato_no_profile') {
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
					'<span class="hv-list-sub">' + esc(venue.address || '') + '</span>' +
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

		S.map = window.L.map(node, {
			zoomControl: false,
			attributionControl: false
		}).setView([BOOT.map.lat, BOOT.map.lng], BOOT.map.zoom);

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
				'<div class="hv-chat-form">' +
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

		fetchMessages(true);
		startPolling();

		return Promise.resolve();
	}

	function fetchMessages(initial) {
		var room = S.chatRoom;
		if (!room) { return; }

		var path = room.type === 'group' ? 'chat/group' : 'chat/private';
		var params = room.type === 'group'
			? { group_id: room.id, since: S.lastMsgId }
			: { user_id: room.id, since: S.lastMsgId };

		api(path, { params: params }).then(function (res) {
			var log = $('#hv-chat-log');
			if (!log) { return; }

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
				S.lastMsgId = Math.max(S.lastMsgId, msg.id);
				var node = document.createElement('div');
				node.className = 'hv-msg' + (msg.is_system ? ' is-system' : (msg.mine ? ' is-mine' : ''));
				node.innerHTML =
					(!msg.mine && !msg.is_system && msg.name ? '<span class="hv-msg-name">' + esc(msg.name) + '</span>' : '') +
					esc(msg.text) +
					'<span class="hv-msg-time">' + num(msg.time) + '</span>';
				log.appendChild(node);
			});

			if ((res.messages || []).length) {
				log.scrollTop = log.scrollHeight;
			}

			if (initial && room.type === 'group' && (res.members || []).length) {
				renderGroupMembers(res.members);
			}
		}).catch(function () { /* silent during polling */ });
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

	function sendMessage() {
		var input = $('#hv-chat-input');
		var room = S.chatRoom;
		if (!input || !room) { return; }

		var text = input.value.trim();
		if (!text) { return; }
		input.value = '';

		var path = room.type === 'group' ? 'chat/group/send' : 'chat/private/send';
		var body = room.type === 'group' ? { group_id: room.id, text: text } : { user_id: room.id, text: text };

		api(path, { method: 'POST', body: body })
			.then(function () { fetchMessages(false); })
			.catch(function (err) { toast(err.message, 'error'); });
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
		// button, gallery, no wallet / no feedback / no logout).
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
			if (profile.is_self) { S.user = profile.user; renderHeaderUser(); }

			var html = '';

			if (!profile.is_self) {
				html += '<button type="button" class="hv-btn hv-btn-ghost hv-btn-sm" id="hv-profile-back">' +
					esc(t('back')) + '</button><div class="hv-mt"></div>';
			}

			html += profileHeadMarkup(profile);

			if (profile.is_self) {
				html += walletMarkup(profile);
			}

			if (profile.is_self && !profile.completed) {
				html += '<div class="hv-card"><button type="button" class="hv-btn hv-btn-primary hv-btn-block" id="hv-start-test">' +
					icon('brain', 'hv-fab-icon') + esc(t('start_test')) + '</button></div>';
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

		return '' +
			'<div class="hv-profile-head">' +
				'<img class="hv-profile-avatar" src="' + esc(user.avatar) + '" alt=""' +
					(profile.is_self ? ' id="hv-avatar-upload" style="cursor:pointer" title="' + esc(t('upload_photo')) + '"' : '') + '>' +
				'<div style="flex:1 1 auto;min-width:0">' +
					'<h2 class="hv-profile-name">' + esc(user.name) + '</h2>' +
					'<p class="hv-profile-meta">★ ' + num(profile.rating) + ' · ' +
						num(profile.attended) + ' ' + esc(t('events_attended')) + '</p>' +
				'</div>' +
				addFriend +
			'</div>';
	}

	function walletMarkup(profile) {
		var wallet = profile.wallet || { spent_label: { fa: '', en: '' }, tickets: 0 };
		return '' +
			'<div class="hv-stat-grid">' +
				'<div class="hv-stat">' +
					'<div class="hv-stat-icon is-blue">' + icon('wallet') + '</div>' +
					'<div class="hv-stat-value">' + esc(pick(wallet.spent_label)) + '</div>' +
					'<div class="hv-stat-label">' + esc(t('wallet_spent')) + '</div>' +
				'</div>' +
				'<div class="hv-stat">' +
					'<div class="hv-stat-icon is-green">' + icon('star') + '</div>' +
					'<div class="hv-stat-value">' + num(profile.rating) + '</div>' +
					'<div class="hv-stat-label">' + esc(t('rating_score')) + '</div>' +
				'</div>' +
				'<div class="hv-stat">' +
					'<div class="hv-stat-icon is-orange">' + icon('users') + '</div>' +
					'<div class="hv-stat-value">' + num(wallet.tickets) + '</div>' +
					'<div class="hv-stat-label">' + esc(t('my_events')) + '</div>' +
				'</div>' +
			'</div>';
	}

	function behaviourMarkup(profile) {
		var tags = (profile.interests || []).map(function (item) {
			return '<span class="hv-behaviour-tag">' + esc(pick(item)) + '</span>';
		}).join('');

		var extro = profile.extroversion >= 7 ? t('extrovert') : (profile.extroversion <= 4 ? t('introvert') : 'Ambivert');
		var talk = profile.talkative >= 7 ? t('speaker') : (profile.talkative <= 4 ? t('listener') : '—');

		return '' +
			'<div class="hv-card">' +
				'<div class="hv-section-head">' +
					'<h3 class="hv-section-title">' + esc(t('behaviour_id')) + '</h3>' +
				'</div>' +
				'<div class="hv-behaviour-tags">' +
					'<span class="hv-behaviour-tag">' + esc(extro) + ' · ' + num(profile.extroversion) + '/' + num(10) + '</span>' +
					'<span class="hv-behaviour-tag">' + esc(talk) + '</span>' +
					'<span class="hv-behaviour-tag">' + esc(profile.vibe === 'deep' ? t('vibe_deep') : t('vibe_fun')) + '</span>' +
					(profile.age ? '<span class="hv-behaviour-tag">' + num(profile.age) + '</span>' : '') +
					(profile.neighborhood ? '<span class="hv-behaviour-tag">' + esc(profile.neighborhood) + '</span>' : '') +
					tags +
				'</div>' +
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
							'<span class="hv-list-sub">' + esc(pick(event.date)) + ' · ' + num(event.time) + '</span>' +
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

		var logout = $('#hv-logout');
		if (logout) {
			logout.onclick = function () {
				api('auth/logout', { method: 'POST' }).then(function () {
					S.loggedIn = false;
					S.role = 'guest';
					S.user = null;
					S.authView = 'wall';
					render();
				});
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
		if (S.role === 'cafe_owner') { return; }
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
	function renderTestStep() {
		var steps = 7;
		var dots = '';
		for (var i = 0; i < steps; i++) {
			dots += '<i class="' + (i <= S.testStep ? 'is-done' : '') + '"></i>';
		}

		var body = [
			stepLocation, stepAge, stepGender, stepExtroversion, stepTalkative, stepVibe, stepInterests
		][S.testStep]();

		openModal(
			'<h3 class="hv-modal-title">' + esc(t('start_test')) + '</h3>' +
			'<div class="hv-stepper-dots">' + dots + '</div>' +
			'<div id="hv-step-body">' + body + '</div>' +
			'<div class="hv-row hv-mt">' +
				(S.testStep > 0 ? '<button type="button" class="hv-btn hv-btn-ghost" id="hv-step-prev">' + esc(t('prev')) + '</button>' : '') +
				'<button type="button" class="hv-btn hv-btn-primary" style="flex:1 1 auto" id="hv-step-next">' +
					esc(S.testStep === steps - 1 ? t('finish') : t('next')) + '</button>' +
			'</div>'
		);

		bindStepEvents();
	}

	function stepAge() {
		var options = '';
		for (var age = 18; age <= 75; age++) {
			options += '<option value="' + age + '"' + (S.testData.age === age ? ' selected' : '') + '>' + num(age) + '</option>';
		}
		return '<div class="hv-step-q">' + esc(t('q_age')) + '</div>' +
			'<select class="hv-select" id="hv-step-age">' + options + '</select>';
	}

	/**
	 * Country + city. The city list is derived from the selected country, so
	 * an impossible pair (e.g. Iran + Istanbul) cannot be submitted.
	 */
	function stepLocation() {
		var locations = BOOT.locations || {};
		var country = S.testData.country;

		var countryBtns = Object.keys(locations).map(function (key) {
			var active = country === key ? ' is-active' : '';
			return '<button type="button" class="hv-choice' + active + '" data-country="' + esc(key) + '">' +
				esc(pick(locations[key].label)) + '</button>';
		}).join('');

		var cityBlock = '';
		if (country && locations[country]) {
			var cities = locations[country].cities || {};
			cityBlock =
				'<div class="hv-step-q hv-mt">' + esc(t('q_city_select')) + '</div>' +
				'<div class="hv-choice-grid">' +
					Object.keys(cities).map(function (key) {
						var active = S.testData.city === key ? ' is-active' : '';
						return '<button type="button" class="hv-choice' + active + '" data-city="' + esc(key) + '">' +
							esc(pick(cities[key])) + '</button>';
					}).join('') +
				'</div>';
		}

		return '<div class="hv-step-q">' + esc(t('q_country')) + '</div>' +
			'<div class="hv-choice-grid">' + countryBtns + '</div>' +
			cityBlock +
			'<div class="hv-field hv-mt"><label>' + esc(t('q_neighborhood')) + '</label>' +
				'<input type="text" class="hv-input" id="hv-step-hood" value="' + esc(S.testData.neighborhood) + '"></div>';
	}

	function stepGender() {
		var options = [
			{ key: 'male', label: t('gender_male') },
			{ key: 'female', label: t('gender_female') },
			{ key: 'other', label: t('gender_other') }
		];
		return '<div class="hv-step-q">' + esc(t('q_gender')) + '</div>' +
			'<div class="hv-choice-grid">' +
				options.map(function (opt) {
					return '<button type="button" class="hv-choice' + (S.testData.gender === opt.key ? ' is-active' : '') +
						'" data-gender="' + opt.key + '">' + esc(opt.label) + '</button>';
				}).join('') +
			'</div>';
	}

	function stepExtroversion() {
		return '<div class="hv-step-q">' + esc(t('q_extroversion')) + '</div>' +
			'<div class="hv-row-between"><span class="hv-muted">' + esc(t('introvert')) + '</span>' +
				'<span class="hv-range-value" id="hv-extro-value">' + num(S.testData.extroversion) + '</span>' +
				'<span class="hv-muted">' + esc(t('extrovert')) + '</span></div>' +
			'<input type="range" min="1" max="10" step="1" class="hv-range" id="hv-step-extro" value="' + S.testData.extroversion + '">';
	}

	function stepTalkative() {
		return '<div class="hv-step-q">' + esc(t('q_talkative')) + '</div>' +
			'<div class="hv-row-between"><span class="hv-muted">' + esc(t('listener')) + '</span>' +
				'<span class="hv-range-value" id="hv-talk-value">' + num(S.testData.talkative) + '</span>' +
				'<span class="hv-muted">' + esc(t('speaker')) + '</span></div>' +
			'<input type="range" min="1" max="10" step="1" class="hv-range" id="hv-step-talk" value="' + S.testData.talkative + '">';
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
		var age = $('#hv-step-age');
		if (age) {
			age.onchange = function () { S.testData.age = parseInt(age.value, 10); };
		}

		var hood = $('#hv-step-hood');
		if (hood) {
			hood.oninput = function () { S.testData.neighborhood = hood.value; };
		}

		$$('[data-country]').forEach(function (btn) {
			btn.onclick = function () {
				if (S.testData.country === btn.dataset.country) { return; }
				S.testData.country = btn.dataset.country;
				S.testData.city = ''; // a city from the old country would be invalid
				renderTestStep();
			};
		});

		$$('[data-city]').forEach(function (btn) {
			btn.onclick = function () {
				S.testData.city = btn.dataset.city;
				$$('[data-city]').forEach(function (o) { o.classList.toggle('is-active', o === btn); });
			};
		});

		$$('[data-gender]').forEach(function (btn) {
			btn.onclick = function () {
				S.testData.gender = btn.dataset.gender;
				$$('[data-gender]').forEach(function (o) { o.classList.toggle('is-active', o === btn); });
			};
		});

		var extro = $('#hv-step-extro');
		if (extro) {
			extro.oninput = function () {
				S.testData.extroversion = parseInt(extro.value, 10);
				$('#hv-extro-value').textContent = num(S.testData.extroversion);
			};
		}

		var talk = $('#hv-step-talk');
		if (talk) {
			talk.oninput = function () {
				S.testData.talkative = parseInt(talk.value, 10);
				$('#hv-talk-value').textContent = num(S.testData.talkative);
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
			if (S.testStep === 0 && (!S.testData.country || !S.testData.city)) {
				toast(t('q_city_select'), 'error');
				return;
			}
			if (S.testStep === 2 && !S.testData.gender) { toast(t('q_gender'), 'error'); return; }
			if (S.testStep < 6) { S.testStep++; renderTestStep(); return; }
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
	 * OWNER: dashboard
	 * ================================================================== */
	function viewOwnerDashboard() {
		setHeader(t('tab_dashboard'), t('owner_login_title'));

		return api('owner/dashboard').then(function (res) {
			S.venue = res.venue;
			var stats = res.stats;

			if (!res.venue.verified) {
				setStatusStrip(t('owner_pending_notice'), 'orange');
			} else {
				setStatusStrip(t('verified_venue'), 'green');
			}

			var payouts = (res.payouts || []).length
				? (res.payouts || []).map(function (row) {
					// The café only ever sees its OWN settlement amount.
					// Platform ticket revenue and the commission split are
					// admin-only figures and are deliberately not exposed here.
					return '<div class="hv-payout-row">' +
						'<div><strong>' + esc(pick(row.period_label)) + '</strong>' +
							'<div class="hv-muted">' + esc(t('payout_share')) + '</div></div>' +
						'<div style="text-align:end">' +
							'<div class="hv-menu-price">' + esc(pick(row.share_label)) + '</div>' +
							'<span class="hv-badge hv-badge-' + (row.status === 'paid' ? 'green' : 'orange') + '">' +
								esc(row.status === 'paid' ? t('payout_paid') : t('payout_due')) + '</span>' +
						'</div>' +
					'</div>';
				}).join('')
				: '<p class="hv-muted">' + esc(t('empty_state')) + '</p>';

			el.main.innerHTML =
				(!res.venue.verified ? '<div class="hv-alert hv-alert-orange">' + esc(t('owner_pending_notice')) + '</div>' : '') +
				'<div class="hv-kpi-grid">' +
					kpiCard('utilization', stats.utilization + '%', 'blue', 'dashboard', stats.utilization) +
					kpiCard('guests_routed', num(stats.guests_routed), 'green', 'users') +
					kpiCard('tab_venue_events', num(stats.upcoming), 'orange', 'calendar') +
					kpiCard('check_in', num(stats.checked_in), 'pink', 'check') +
				'</div>' +
				'<div class="hv-card hv-mt">' +
					'<h3 class="hv-section-title">' + esc(t('payout_status')) + '</h3>' +
					payouts +
				'</div>';
		});
	}

	function kpiCard(labelKey, value, color, iconId, progress) {
		return '' +
			'<div class="hv-kpi">' +
				'<div class="hv-kpi-top">' +
					'<span class="hv-stat-icon is-' + color + '">' + icon(iconId) + '</span>' +
					'<span class="hv-kpi-label">' + esc(t(labelKey)) + '</span>' +
				'</div>' +
				'<div class="hv-kpi-value">' + esc(value) + '</div>' +
				(progress !== undefined ? '<div class="hv-progress"><span style="width:' + Math.min(100, progress) + '%"></span></div>' : '') +
			'</div>';
	}

	/* =====================================================================
	 * OWNER: venue events + check-in
	 * ================================================================== */
	function viewOwnerEvents() {
		setHeader(t('tab_venue_events'), t('owner_login_title'));

		return api('owner/events').then(function (res) {
			var events = res.events || [];

			var createBtn = '<button type="button" class="hv-btn hv-btn-primary hv-btn-block" id="hv-create-event">' +
				esc(t('add_item')) + '</button>';

			if (!events.length) {
				el.main.innerHTML = emptyState(t('empty_state'), 'calendar') + createBtn;
				$('#hv-create-event').onclick = openCreateEvent;
				return;
			}

			el.main.innerHTML = createBtn + '<div class="hv-mt"></div>' + events.map(function (event) {
				return '<button type="button" class="hv-list-card" data-owner-event="' + esc(event.id) + '">' +
					'<span class="hv-list-thumb">' + icon('calendar') + '</span>' +
					'<span class="hv-list-body">' +
						'<span class="hv-list-title">' + esc(pick(event.date)) + ' · ' + num(event.time) + '</span>' +
						'<span class="hv-list-sub">' + num(event.taken) + '/' + num(event.capacity) + ' · ' +
							esc(budgetLabel(event.budget_tier)) + '</span>' +
					'</span>' +
					'<span class="hv-list-meta">' + statusBadge(event.status) + '</span>' +
				'</button>';
			}).join('');

			$('#hv-create-event').onclick = openCreateEvent;
			$$('[data-owner-event]').forEach(function (btn) {
				btn.onclick = function () { openOwnerEvent(btn.dataset.ownerEvent); };
			});
		});
	}

	function openCreateEvent() {
		if (S.role !== 'cafe_owner') { return; }

		var today = new Date();
		today.setDate(today.getDate() + 1);
		var iso = today.toISOString().slice(0, 10);

		openModal(
			'<h3 class="hv-modal-title">' + esc(t('tab_venue_events')) + '</h3>' +
			'<div class="hv-field"><label>' + esc(t('payout_period')) + '</label>' +
				'<input type="date" class="hv-input" id="hv-ev-date" value="' + iso + '"></div>' +
			'<div class="hv-field hv-mt"><label>' + esc(t('quiet_hours')) + '</label>' +
				'<input type="time" class="hv-input" id="hv-ev-time" value="19:00"></div>' +
			'<div class="hv-field hv-mt"><label>' + esc(t('seats_left')) + '</label>' +
				'<input type="number" class="hv-input" id="hv-ev-cap" value="6" min="2" max="12"></div>' +
			'<div class="hv-field hv-mt"><label>' + esc(t('menu_item_price')) + '</label>' +
				'<input type="number" class="hv-input" id="hv-ev-price" value="75000" min="0" step="5000"></div>' +
			'<div class="hv-field hv-mt"><label>' + esc(t('filter')) + '</label>' +
				'<select class="hv-select" id="hv-ev-tier">' +
					'<option value="low">' + esc(t('budget_low')) + '</option>' +
					'<option value="medium" selected>' + esc(t('budget_medium')) + '</option>' +
					'<option value="high">' + esc(t('budget_high')) + '</option>' +
				'</select></div>' +
			'<button type="button" class="hv-btn hv-btn-primary hv-btn-block hv-mt" id="hv-ev-save">' + esc(t('save')) + '</button>'
		);

		$('#hv-ev-save').onclick = function () {
			var btn = $('#hv-ev-save');
			btn.disabled = true;
			api('owner/event/create', {
				method: 'POST',
				body: {
					event_date: $('#hv-ev-date').value,
					event_time: $('#hv-ev-time').value,
					max_capacity: parseInt($('#hv-ev-cap').value, 10),
					price: parseInt($('#hv-ev-price').value, 10),
					budget_tier: $('#hv-ev-tier').value
				}
			}).then(function () {
				closeModal();
				toast(t('saved'), 'ok');
				viewOwnerEvents();
			}).catch(function (err) { btn.disabled = false; toast(err.message, 'error'); });
		};
	}

	function openOwnerEvent(eventId) {
		api('owner/event', { params: { event_id: eventId } }).then(function (res) {
			var members = res.members || [];

			openModal(
				'<h3 class="hv-modal-title">' + esc(pick(res.event.date)) + ' · ' + num(res.event.time) + '</h3>' +
				'<div class="hv-row" style="margin-bottom:12px">' +
					statusBadge(res.event.status) +
					'<span class="hv-badge hv-badge-indigo">' + num(res.event.taken) + '/' + num(res.event.capacity) + '</span>' +
				'</div>' +
				(members.length === 0 && res.event.status !== 'completed'
					? '<button type="button" class="hv-btn hv-btn-danger hv-btn-block" data-cancel-event="' + esc(eventId) + '">' +
						esc(t('delete')) + '</button><div class="hv-mt"></div>'
					: '') +
				'<h4 class="hv-section-title">' + esc(t('members_at_table')) + '</h4>' +
				(members.length ? members.map(function (member) {
					return '<div class="hv-list-card" style="cursor:default">' +
						'<span class="hv-list-thumb"><img src="' + esc(member.user.avatar) + '" alt=""></span>' +
						'<span class="hv-list-body">' +
							'<span class="hv-list-title">' + esc(member.user.name) + '</span>' +
							'<span class="hv-list-sub">★ ' + num(member.rating) + '</span>' +
						'</span>' +
						'<span class="hv-list-meta">' +
							'<button type="button" class="hv-btn hv-btn-sm ' +
								(member.checked_in ? 'hv-btn-green' : 'hv-btn-outline') + '" ' +
								'data-checkin="' + eventId + '|' + member.user.id + '|' + (member.checked_in ? '0' : '1') + '">' +
								esc(member.checked_in ? t('check_in') : t('not_checked_in')) +
							'</button>' +
						'</span>' +
					'</div>';
				}).join('') : emptyState(t('empty_state'), 'users'))
			);

			var cancelBtn = $('[data-cancel-event]');
			if (cancelBtn) {
				cancelBtn.onclick = function () {
					cancelBtn.disabled = true;
					api('owner/event/cancel', { method: 'POST', body: { event_id: eventId } })
						.then(function () { closeModal(); toast(t('saved'), 'ok'); viewOwnerEvents(); })
						.catch(function (err) { cancelBtn.disabled = false; toast(err.message, 'error'); });
				};
			}

			$$('[data-checkin]').forEach(function (btn) {
				btn.onclick = function () {
					var parts = btn.dataset.checkin.split('|');
					btn.disabled = true;
					api('owner/checkin', {
						method: 'POST',
						body: { event_id: parts[0], user_id: parseInt(parts[1], 10), checked_in: parts[2] === '1' }
					}).then(function () {
						closeModal();
						openOwnerEvent(eventId);
					}).catch(function (err) { btn.disabled = false; toast(err.message, 'error'); });
				};
			});
		}).catch(function (err) { toast(err.message, 'error'); });
	}

	/* =====================================================================
	 * OWNER: menu builder (display-only menu, no ordering)
	 * ================================================================== */
	function viewMenuBuilder() {
		setHeader(t('tab_menu_builder'), t('owner_login_title'));

		return api('owner/dashboard').then(function (res) {
			S.venue = res.venue;
			var pending = (res.venue.pending_menu || []);
			S.menuDraft = (pending.length ? pending : (res.venue.menu || [])).map(function (item) {
				return { name: item.name, price: item.price, desc: item.desc || '', image: item.image || '' };
			});

			renderMenuDraft(pending.length > 0);
		});
	}

	function renderMenuDraft(hasPending) {
		S.menuHasPending = !!hasPending;
		el.main.innerHTML =
			(hasPending ? '<div class="hv-alert hv-alert-orange">' + esc(t('menu_pending_badge')) + '</div>' : '') +
			'<div class="hv-alert hv-alert-blue">' + esc(t('menu_display_only')) + '</div>' +
			'<div id="hv-menu-list">' + S.menuDraft.map(menuRowMarkup).join('') + '</div>' +
			'<button type="button" class="hv-btn hv-btn-outline hv-btn-block hv-mt" id="hv-menu-add">' + esc(t('add_item')) + '</button>' +
			'<button type="button" class="hv-btn hv-btn-primary hv-btn-block hv-mt" id="hv-menu-save">' + esc(t('save')) + '</button>';

		$('#hv-menu-add').onclick = addMenuRow;
		$('#hv-menu-save').onclick = saveMenu;
		bindMenuRows();
	}

	function menuRowMarkup(item, index) {
		// Compact restaurant-style row: square photo | name + price | actions.
		// The description is collapsed behind a toggle so a long menu stays
		// scannable instead of turning into a wall of tall forms.
		var open = S.menuOpenRow === index;

		return '' +
			'<div class="hv-menu-edit" data-menu-row="' + index + '">' +
				'<div class="hv-menu-edit-main">' +
					'<button type="button" class="hv-menu-thumb" data-menu-img="' + index + '" title="' + esc(t('menu_item_image')) + '">' +
						(item.image ? '<img src="' + esc(item.image) + '" alt="">' : icon('cup')) +
					'</button>' +
					'<div class="hv-menu-edit-fields">' +
						'<input type="text" class="hv-input hv-input-flush" data-menu-name ' +
							'placeholder="' + esc(t('menu_item_name')) + '" value="' + esc(item.name) + '">' +
						'<div class="hv-menu-edit-price">' +
							'<input type="number" class="hv-input hv-input-flush" data-menu-price ' +
								'placeholder="' + esc(t('menu_item_price')) + '" value="' + (parseInt(item.price, 10) || 0) + '" min="0" step="1000">' +
							'<span class="hv-muted">' + esc(t('toman')) + '</span>' +
						'</div>' +
					'</div>' +
					'<div class="hv-menu-edit-actions">' +
						'<button type="button" class="hv-icon-btn" data-menu-toggle="' + index + '" ' +
							'title="' + esc(t('menu_item_desc')) + '" aria-expanded="' + (open ? 'true' : 'false') + '">' +
							(open ? '▲' : '▼') +
						'</button>' +
						'<button type="button" class="hv-icon-btn is-danger" data-menu-del="' + index + '" ' +
							'title="' + esc(t('delete')) + '">✕</button>' +
					'</div>' +
				'</div>' +
				(open
					? '<div class="hv-menu-edit-desc">' +
						'<label>' + esc(t('menu_item_desc')) + '</label>' +
						'<textarea class="hv-textarea" data-menu-desc rows="2">' + esc(item.desc) + '</textarea>' +
					'</div>'
					: (item.desc ? '<p class="hv-menu-edit-hint">' + esc(item.desc) + '</p>' : '')) +
			'</div>';
	}

	function bindMenuRows() {
		$$('[data-menu-row]').forEach(function (row) {
			var index = parseInt(row.dataset.menuRow, 10);

			$('[data-menu-name]', row).oninput = function (e) { S.menuDraft[index].name = e.target.value; };
			$('[data-menu-price]', row).oninput = function (e) { S.menuDraft[index].price = parseInt(e.target.value, 10) || 0; };

			$('[data-menu-img]', row).onclick = function () {
				pickFile(function (file) {
					uploadWithProgress('owner/upload', file, t('uploading_photo')).then(function (res) {
						S.menuDraft[index].image = res.url;
						progress.done(t('saved'));
						// Keep the pending banner state; passing false here used
						// to make the "awaiting approval" notice vanish.
						renderMenuDraft(S.menuHasPending);
					}).catch(function (err) { uploadFailed(err); });
				});
			};

			var descBox = $('[data-menu-desc]', row);
			if (descBox) {
				descBox.oninput = function (e) { S.menuDraft[index].desc = e.target.value; };
			}

			var toggle = $('[data-menu-toggle]', row);
			if (toggle) {
				toggle.onclick = function () {
					S.menuOpenRow = (S.menuOpenRow === index) ? -1 : index;
					renderMenuDraft(S.menuHasPending);
				};
			}

			$('[data-menu-del]', row).onclick = function () {
				S.menuDraft.splice(index, 1);
				if (S.menuOpenRow === index) { S.menuOpenRow = -1; }
				renderMenuDraft(S.menuHasPending);
			};
		});
	}

	function addMenuRow() {
		if (S.role !== 'cafe_owner') { return; }
		S.menuDraft.push({ name: '', price: 0, desc: '', image: '' });
		S.menuOpenRow = S.menuDraft.length - 1;
		renderMenuDraft(S.menuHasPending);
		el.main.scrollTop = el.main.scrollHeight;
	}

	function saveMenu() {
		var items = S.menuDraft.filter(function (item) { return item.name.trim() !== ''; });
		saveWithProgress(
			api('owner/menu', { method: 'POST', body: { items: items } }),
			t('saving')
		).then(function (res) {
			if (res && res.message) { toast(res.message, 'ok'); }
			viewMenuBuilder();
		}).catch(function () { /* progress bar already reported it */ });
	}

	/* =====================================================================
	 * OWNER: venue settings (auto-saving map pin)
	 * ================================================================== */
	function viewVenueSettings() {
		setHeader(t('tab_venue_settings'), t('owner_login_title'));

		return api('owner/dashboard').then(function (res) {
			var venue = res.venue;
			S.venue = venue;

			el.main.innerHTML =
				'<div class="hv-card">' +
					'<div class="hv-field"><label>' + esc(t('venue_name')) + '</label>' +
						'<input type="text" class="hv-input" id="hv-v-name" value="' + esc(venue.name || '') + '"></div>' +
					'<div class="hv-field hv-mt"><label>' + esc(t('manager_name')) + '</label>' +
						'<input type="text" class="hv-input" id="hv-v-manager" value="' + esc(venue.manager_name || '') + '"></div>' +
					'<div class="hv-mt">' + locationSelects('hv-v', venue.country, venue.city) + '</div>' +
					'<div class="hv-field hv-mt"><label>' + esc(t('venue_address')) + '</label>' +
						'<textarea class="hv-textarea" id="hv-v-addr">' + esc(venue.address || '') + '</textarea></div>' +
					'<div class="hv-field hv-mt"><label>' + esc(t('quiet_hours')) + '</label>' +
						'<input type="text" class="hv-input" id="hv-v-quiet" value="' + esc(venue.quiet_hours || '') + '" placeholder="10:00 - 16:00"></div>' +
					'<div class="hv-field hv-mt"><label>' + esc(t('cover_image')) + '</label>' +
						'<button type="button" class="hv-btn hv-btn-outline hv-btn-block" id="hv-v-cover">' +
							(venue.image ? esc(t('edit')) : esc(t('upload_photo'))) + '</button></div>' +
					(venue.image ? '<img class="hv-modal-hero hv-mt" src="' + esc(venue.image) + '" alt="">' : '') +
					'<button type="button" class="hv-btn hv-btn-primary hv-btn-block hv-mt" id="hv-v-save">' + esc(t('save')) + '</button>' +
				'</div>' +
				'<div class="hv-card">' +
					'<h3 class="hv-section-title">' + esc(t('col_location')) + '</h3>' +
					'<p class="hv-muted">' + esc(t('drag_pin')) + '</p>' +
					'<div class="hv-owner-map hv-mt" id="hv-owner-map"></div>' +
				'</div>';

			bindLocationSelects('hv-v');
			$('#hv-v-save').onclick = saveVenueForm;
			$('#hv-v-cover').onclick = function () {
				pickFile(function (file) {
					uploadWithProgress('owner/upload', file, t('uploading_cover')).then(function (up) {
						// Bytes are in; now persist the URL on the venue.
						progress.set(null);
						return api('owner/venue', { method: 'POST', body: { image: up.url } });
					}).then(function () {
						progress.done(t('saved'));
						viewVenueSettings();
					}).catch(function (err) { uploadFailed(err); });
				});
			};

			initOwnerMap(venue);
		});
	}

	function initOwnerMap(venue) {
		if (typeof window.L === 'undefined') { return; }
		var node = $('#hv-owner-map');
		if (!node) { return; }

		var lat = venue.lat || BOOT.map.lat;
		var lng = venue.lng || BOOT.map.lng;

		S.ownerMap = window.L.map(node, { zoomControl: false, attributionControl: false }).setView([lat, lng], 15);
		window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19 }).addTo(S.ownerMap);

		var marker = window.L.marker([lat, lng], {
			draggable: true,
			icon: window.L.divIcon({ className: '', html: '<div class="hv-pin"></div>', iconSize: [34, 34], iconAnchor: [17, 32] })
		}).addTo(S.ownerMap);

		// Auto-save on drag end, exactly as specified.
		marker.on('dragend', function () {
			var pos = marker.getLatLng();
			saveWithProgress(
				api('owner/venue', { method: 'POST', body: { lat: pos.lat, lng: pos.lng } })
			).catch(function () { /* reported by the progress bar */ });
		});

		setTimeout(function () { if (S.ownerMap) { S.ownerMap.invalidateSize(); } }, 220);
	}

	function saveVenueForm() {
		if (S.role !== 'cafe_owner') { return; }
		var nameField = $('#hv-v-name');
		if (!nameField) { return; }

		saveWithProgress(api('owner/venue', {
			method: 'POST',
			body: {
				name: nameField.value,
				manager_name: $('#hv-v-manager').value,
				country: $('#hv-v-country').value,
				city: $('#hv-v-city').value,
				address: $('#hv-v-addr').value,
				quiet_hours: $('#hv-v-quiet').value
			}
		})).catch(function () { /* reported by the progress bar */ });
	}

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
		el.strip = $('#hv-status-strip');
		el.main = $('#main-tab-content');
		el.bottomNav = $('#hv-bottom-nav');
		el.tabs = $('#hv-tabs');
		el.fab = $('#hv-fab');
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

		$('#hv-lang-btn').onclick = toggleLang;
		$('#hv-avatar-btn').onclick = function () {
			if (!S.loggedIn) { return; }
			setTab(S.role === 'cafe_owner' ? 'venue-settings' : 'profile');
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
					buildTabs();
					render();
					S.booted = true;
				}).catch(bootFailed);
			};
		}
	}

	function applyLangSilent(lang) {
		S.lang = lang === 'en' ? 'en' : 'fa';
		S.dir = S.lang === 'fa' ? 'rtl' : 'ltr';
		el.root.setAttribute('dir', S.dir);
		el.root.setAttribute('data-lang', S.lang);
		el.root.classList.toggle('hv-dir-rtl', S.dir === 'rtl');
		el.root.classList.toggle('hv-dir-ltr', S.dir === 'ltr');
		el.langLabel.textContent = S.lang === 'fa' ? 'EN' : 'فا';
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', boot);
	} else {
		boot();
	}
})();
