/**
 * Café owner sign-in / sign-up page.
 *
 * Talks to owner/login and owner/register. Both are IP-throttled server-side
 * and owner/login refuses any account that is not a `cafe_owner`, so this page
 * can never be used to reach an administrator account.
 */
(function () {
	'use strict';

	if (typeof window.HAVATO_AUTH === 'undefined') { return; }

	var CFG = window.HAVATO_AUTH;

	function $(sel, root) { return (root || document).querySelector(sel); }
	function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
	function t(key) { return (CFG.i18n && CFG.i18n[key] !== undefined) ? CFG.i18n[key] : key; }

	function esc(str) {
		return String(str === undefined || str === null ? '' : str)
			.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
			.replace(/"/g, '&quot;').replace(/'/g, '&#39;');
	}

	function api(path, body) {
		return fetch(CFG.rest + '/' + path, {
			method: 'POST',
			credentials: 'same-origin',
			headers: {
				'Content-Type': 'application/json',
				'X-WP-Nonce': CFG.nonce
			},
			body: JSON.stringify(body)
		}).then(function (res) {
			return res.json().catch(function () { return {}; }).then(function (json) {
				if (!res.ok) {
					var err = new Error(json.message || t('error_generic'));
					err.status = res.status;
					throw err;
				}
				return json;
			});
		});
	}

	function message(text, kind) {
		var box = $('#hv-auth-msg');
		box.className = 'hv-alert hv-alert-' + (kind || 'blue');
		box.textContent = text;
		box.hidden = false;
	}

	function busy(form, on) {
		var btn = form.querySelector('button[type="submit"]');
		if (btn) {
			btn.disabled = on;
			btn.style.opacity = on ? '0.6' : '';
		}
	}

	/* ---------------------------------------------------------------- tabs */
	function initTabs() {
		$$('[data-authtab]').forEach(function (btn) {
			btn.onclick = function () {
				var tab = btn.dataset.authtab;
				$$('[data-authtab]').forEach(function (o) {
					o.classList.toggle('is-active', o === btn);
				});
				$('#hv-auth-login').hidden = (tab !== 'login');
				$('#hv-auth-register').hidden = (tab !== 'register');
				$('#hv-auth-msg').hidden = true;
			};
		});
	}

	/* ------------------------------------------------------ country/city */
	function initLocations() {
		var country = $('#hv-r-country');
		var city = $('#hv-r-city');
		if (!country || !city) { return; }

		var locations = CFG.locations || {};

		country.innerHTML = Object.keys(locations).map(function (k) {
			var label = locations[k].label[CFG.lang] || locations[k].label.en;
			return '<option value="' + esc(k) + '">' + esc(label) + '</option>';
		}).join('');

		function fillCities() {
			var cities = (locations[country.value] || {}).cities || {};
			city.innerHTML = Object.keys(cities).map(function (k) {
				var label = cities[k][CFG.lang] || cities[k].en;
				return '<option value="' + esc(k) + '">' + esc(label) + '</option>';
			}).join('');
		}

		country.onchange = fillCities;
		fillCities();
	}

	/* --------------------------------------------------------------- login */
	function initLogin() {
		var form = $('#hv-auth-login');
		form.onsubmit = function (e) {
			e.preventDefault();
			busy(form, true);

			api('owner/login', {
				email: $('#hv-l-email').value.trim(),
				password: $('#hv-l-pass').value
			}).then(function () {
				message(t('saved'), 'green');
				window.location.href = CFG.panelUrl;
			}).catch(function (err) {
				busy(form, false);
				message(err.message, 'orange');
			});
		};
	}

	/* ------------------------------------------------------------ register */
	function initRegister() {
		var form = $('#hv-auth-register');
		form.onsubmit = function (e) {
			e.preventDefault();

			var payload = {
				venue_name: $('#hv-r-venue').value.trim(),
				manager_name: $('#hv-r-manager').value.trim(),
				country: $('#hv-r-country').value,
				city: $('#hv-r-city').value,
				address: $('#hv-r-address').value.trim(),
				email: $('#hv-r-email').value.trim(),
				password: $('#hv-r-pass').value
			};

			if (!payload.venue_name || !payload.manager_name || !payload.email || payload.password.length < 6) {
				message(t('error_generic'), 'orange');
				return;
			}

			busy(form, true);

			api('owner/register', payload).then(function () {
				// The account is created and signed in, but the café stays
				// unverified until an administrator approves it — the panel
				// asks for a storefront photo to speed that up.
				message(t('signup_pending_hint'), 'green');
				window.location.href = CFG.panelUrl;
			}).catch(function (err) {
				busy(form, false);
				message(err.message, 'orange');
			});
		};
	}

	function boot() {
		initTabs();
		initLocations();
		initLogin();
		initRegister();
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', boot);
	} else {
		boot();
	}
})();
