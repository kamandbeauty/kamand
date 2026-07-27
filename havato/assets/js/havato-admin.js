/**
 * Havato admin helpers: live slider read-outs, matcher trigger, console tail.
 */
(function () {
	'use strict';

	if (typeof window.HAVATO_ADMIN === 'undefined') { return; }

	var CFG = window.HAVATO_ADMIN;

	function $(sel, root) { return (root || document).querySelector(sel); }
	function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

	function api(path, options) {
		options = options || {};
		var init = {
			method: options.method || 'GET',
			credentials: 'same-origin',
			headers: { 'X-WP-Nonce': CFG.nonce }
		};
		if (options.body) {
			init.headers['Content-Type'] = 'application/json';
			init.body = JSON.stringify(options.body);
		}
		return fetch(CFG.rest + '/' + path, init).then(function (res) {
			return res.json().catch(function () { return {}; }).then(function (json) {
				if (!res.ok) { throw new Error(json.message || 'Request failed'); }
				return json;
			});
		});
	}

	/* Live slider values */
	function bindSliders() {
		$$('.hv-adm-range').forEach(function (range) {
			var out = document.querySelector('[data-out="' + range.name + '"]');
			if (!out) { return; }
			var unit = range.dataset.unit || '';
			range.addEventListener('input', function () {
				out.textContent = range.value + unit;
			});
		});
	}

	/* Manual matcher trigger */
	function bindMatcher() {
		$$('[data-run-matcher]').forEach(function (btn) {
			btn.addEventListener('click', function () {
				var id = btn.dataset.runMatcher;
				var body = id === 'all' ? {} : { event_id: id };
				btn.disabled = true;
				var original = btn.textContent;
				btn.textContent = '…';

				api('admin/run-matcher', { method: 'POST', body: body })
					.then(function (res) {
						btn.textContent = res.ok === false ? '×' : '✓';
						refreshConsole();
						setTimeout(function () { window.location.reload(); }, 900);
					})
					.catch(function () {
						btn.disabled = false;
						btn.textContent = original;
					});
			});
		});
	}

	/* Console auto-tail (every 5s while the tab is visible) */
	function refreshConsole() {
		var body = $('#hv-console-body');
		if (!body) { return; }

		api('admin/log?limit=24').then(function (res) {
			var lines = res.lines || [];
			if (!lines.length) { return; }
			body.innerHTML = lines.map(function (line) {
				return '<p class="hv-line is-' + line.level + '">[' + line.time + '] ' +
					String(line.msg).replace(/</g, '&lt;') + '</p>';
			}).join('');
			body.scrollTop = body.scrollHeight;
		}).catch(function () { /* silent */ });
	}

	function boot() {
		bindSliders();
		bindMatcher();

		var body = $('#hv-console-body');
		if (body) {
			body.scrollTop = body.scrollHeight;
			setInterval(function () {
				if (!document.hidden) { refreshConsole(); }
			}, 5000);
		}
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', boot);
	} else {
		boot();
	}
})();
