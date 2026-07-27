/**
 * Café owner panel — desktop behaviour inside wp-admin.
 *
 * Three interactive pieces:
 *   • Menu builder  — rows edited client-side, submitted as one JSON payload.
 *   • Cover image   — the native WordPress media library.
 *   • Location pin  — draggable Leaflet marker writing into hidden inputs.
 *
 * Everything else on these screens is plain server-rendered HTML with normal
 * form posts, which keeps the panel fast and works without JavaScript.
 */
(function () {
	'use strict';

	if (typeof window.HAVATO_OWNER === 'undefined') { return; }

	var CFG = window.HAVATO_OWNER;

	function $(sel, root) { return (root || document).querySelector(sel); }
	function t(key) { return (CFG.i18n && CFG.i18n[key] !== undefined) ? CFG.i18n[key] : key; }

	function esc(str) {
		return String(str === undefined || str === null ? '' : str)
			.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
			.replace(/"/g, '&quot;').replace(/'/g, '&#39;');
	}

	/* =====================================================================
	 * Menu builder
	 * ================================================================== */
	function initMenu() {
		var host = $('#hv-owner-menu');
		if (!host) { return; }

		var items = [];
		try { items = JSON.parse(host.dataset.items || '[]') || []; } catch (e) { items = []; }

		function render() {
			var rows = items.map(function (item, i) {
				return '' +
					'<tr data-row="' + i + '">' +
						'<td class="hv-adm-menu-cell">' +
							'<button type="button" class="hv-adm-menu-thumb' + (item.image ? '' : ' is-empty') + '" data-pick="' + i + '">' +
								(item.image
									? '<img src="' + esc(item.image) + '" alt="">'
									: '<span class="dashicons dashicons-food"></span>') +
							'</button>' +
						'</td>' +
						'<td><input type="text" class="hv-adm-input" data-name="' + i + '" value="' + esc(item.name) + '" placeholder="' + esc(t('menu_item_name')) + '"></td>' +
						'<td><input type="number" class="hv-adm-input" data-price="' + i + '" value="' + (parseInt(item.price, 10) || 0) + '" min="0" step="1000"></td>' +
						'<td><input type="text" class="hv-adm-input" data-desc="' + i + '" value="' + esc(item.desc || '') + '" placeholder="' + esc(t('menu_item_desc')) + '"></td>' +
						'<td class="hv-adm-actions">' +
							'<button type="button" class="hv-adm-btn hv-adm-btn-danger" data-del="' + i + '">✕</button>' +
						'</td>' +
					'</tr>';
			}).join('');

			host.innerHTML =
				'<table class="hv-adm-table hv-adm-menu-table"><thead><tr>' +
					'<th>' + esc(t('menu_item_image')) + '</th>' +
					'<th>' + esc(t('menu_item_name')) + '</th>' +
					'<th>' + esc(t('menu_item_price')) + '</th>' +
					'<th>' + esc(t('menu_item_desc')) + '</th>' +
					'<th></th>' +
				'</tr></thead><tbody>' +
					(rows || '<tr><td colspan="5" class="hv-adm-muted">' + esc(t('empty_state')) + '</td></tr>') +
				'</tbody></table>' +
				'<p class="hv-adm-menu-actions">' +
					'<button type="button" class="hv-adm-btn hv-adm-btn-ghost" id="hv-menu-add">＋ ' + esc(t('add_item')) + '</button> ' +
					'<button type="button" class="hv-adm-btn hv-adm-btn-blue" id="hv-menu-save">' + esc(t('save')) + '</button>' +
				'</p>';

			bind();
		}

		function bind() {
			Array.prototype.forEach.call(host.querySelectorAll('[data-name]'), function (el) {
				el.oninput = function () { items[+el.dataset.name].name = el.value; };
			});
			Array.prototype.forEach.call(host.querySelectorAll('[data-price]'), function (el) {
				el.oninput = function () { items[+el.dataset.price].price = parseInt(el.value, 10) || 0; };
			});
			Array.prototype.forEach.call(host.querySelectorAll('[data-desc]'), function (el) {
				el.oninput = function () { items[+el.dataset.desc].desc = el.value; };
			});
			Array.prototype.forEach.call(host.querySelectorAll('[data-del]'), function (el) {
				el.onclick = function () { items.splice(+el.dataset.del, 1); render(); };
			});
			Array.prototype.forEach.call(host.querySelectorAll('[data-pick]'), function (el) {
				el.onclick = function () {
					pickMedia(function (url) {
						items[+el.dataset.pick].image = url;
						render();
					});
				};
			});

			$('#hv-menu-add').onclick = function () {
				items.push({ name: '', price: 0, desc: '', image: '' });
				render();
			};

			$('#hv-menu-save').onclick = function () {
				// Submit as one JSON payload through the normal admin-post flow,
				// so the same sanitiser and approval rules apply as before.
				var clean = items.filter(function (i) { return String(i.name).trim() !== ''; });
				postJson(host, 'save_menu', 'menu_json', clean);
			};
		}

		render();
	}

	/* =====================================================================
	 * WordPress media library
	 * ================================================================== */
	function pickMedia(onPick) {
		if (!window.wp || !window.wp.media) { return; }
		var frame = window.wp.media({
			title: t('menu_item_image'),
			library: { type: 'image' },
			button: { text: t('confirm') },
			multiple: false
		});
		frame.on('select', function () {
			var att = frame.state().get('selection').first().toJSON();
			onPick(att.url);
		});
		frame.open();
	}

	function initCover() {
		var btn = $('#hv-owner-pick-image');
		if (!btn) { return; }
		btn.onclick = function () {
			pickMedia(function (url) {
				$('#hv-owner-image').value = url;
				var img = $('#hv-owner-image-preview');
				img.src = url;
				img.hidden = false;
			});
		};
	}

	/* =====================================================================
	 * Draggable location pin
	 * ================================================================== */
	function initStorefront() {
		var btn = $('#hv-storefront-pick');
		if (!btn) { return; }
		btn.onclick = function () {
			pickMedia(function (url) {
				$('#hv-storefront-url').value = url;
				var save = $('#hv-storefront-save');
				if (save) { save.disabled = false; }
				// Submit immediately: one tap, one job done.
				save.click();
			});
		};
	}

	function initMap() {
		var node = $('#hv-owner-map');
		if (!node || typeof window.L === 'undefined') { return; }

		var lat = parseFloat(node.dataset.lat) || CFG.map.lat;
		var lng = parseFloat(node.dataset.lng) || CFG.map.lng;

		var map = window.L.map(node, { scrollWheelZoom: false }).setView([lat, lng], 15);
		window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19 }).addTo(map);

		var marker = window.L.marker([lat, lng], { draggable: true }).addTo(map);

		// The pin writes into hidden inputs; the surrounding form saves it, so
		// the position cannot drift out of sync with the rest of the settings.
		marker.on('dragend', function () {
			var pos = marker.getLatLng();
			$('#hv-owner-lat').value = pos.lat;
			$('#hv-owner-lng').value = pos.lng;
		});

		map.on('click', function (e) {
			marker.setLatLng(e.latlng);
			$('#hv-owner-lat').value = e.latlng.lat;
			$('#hv-owner-lng').value = e.latlng.lng;
		});

		setTimeout(function () { map.invalidateSize(); }, 200);
	}

	/* =====================================================================
	 * Country -> city dependency
	 * ================================================================== */
	function initLocationSelects() {
		var country = $('#hv-owner-country');
		var city = $('#hv-owner-city');
		if (!country || !city) { return; }

		country.onchange = function () {
			var cities = ((CFG.locations || {})[country.value] || {}).cities || {};
			city.innerHTML = Object.keys(cities).map(function (k) {
				var label = cities[k][CFG.lang] || cities[k].en;
				return '<option value="' + esc(k) + '">' + esc(label) + '</option>';
			}).join('');
		};
	}


	/* =====================================================================
	 * Venue tables ("3 tables of 4, 2 tables of 6")
	 * ================================================================== */
	function initTables() {
		var host = $('#hv-owner-tables');
		if (!host) { return; }

		var rows = [];
		try { rows = JSON.parse(host.dataset.tables || '[]') || []; } catch (e) { rows = []; }

		function totalSeats() {
			return rows.reduce(function (n, r) {
				return n + (parseInt(r.seats, 10) || 0) * (parseInt(r.quantity, 10) || 0);
			}, 0);
		}

		function render() {
			var body = rows.map(function (r, i) {
				return '' +
					'<tr>' +
						'<td><input type="text" class="hv-adm-input" data-label="' + i + '" value="' + esc(r.label || '') +
							'" placeholder="' + esc(t('table_label_hint')) + '"></td>' +
						'<td><input type="number" class="hv-adm-input" data-seats="' + i + '" value="' +
							(parseInt(r.seats, 10) || 4) + '" min="2" max="20"></td>' +
						'<td><input type="number" class="hv-adm-input" data-qty="' + i + '" value="' +
							(parseInt(r.quantity, 10) || 1) + '" min="1" max="50"></td>' +
						'<td class="hv-adm-muted">' +
							((parseInt(r.seats, 10) || 0) * (parseInt(r.quantity, 10) || 0)) +
						'</td>' +
						'<td class="hv-adm-actions">' +
							'<button type="button" class="hv-adm-btn hv-adm-btn-danger" data-del="' + i + '">✕</button>' +
						'</td>' +
					'</tr>';
			}).join('');

			host.innerHTML =
				'<table class="hv-adm-table"><thead><tr>' +
					'<th>' + esc(t('table_label')) + '</th>' +
					'<th>' + esc(t('table_seats')) + '</th>' +
					'<th>' + esc(t('table_quantity')) + '</th>' +
					'<th>' + esc(t('seats_left')) + '</th>' +
					'<th></th>' +
				'</tr></thead><tbody>' +
					(body || '<tr><td colspan="5" class="hv-adm-muted">' + esc(t('empty_state')) + '</td></tr>') +
				'</tbody></table>' +
				'<p class="hv-adm-menu-actions">' +
					'<button type="button" class="hv-adm-btn hv-adm-btn-ghost" id="hv-tables-add">＋ ' + esc(t('add_item')) + '</button> ' +
					'<button type="button" class="hv-adm-btn hv-adm-btn-blue" id="hv-tables-save">' + esc(t('save')) + '</button> ' +
					'<span class="hv-adm-muted">' + esc(t('seats_left')) + ': <strong>' + totalSeats() + '</strong></span>' +
				'</p>';

			bind();
		}

		function bind() {
			[['label', 'label'], ['seats', 'seats'], ['qty', 'quantity']].forEach(function (pair) {
				Array.prototype.forEach.call(host.querySelectorAll('[data-' + pair[0] + ']'), function (el) {
					el.oninput = function () {
						var i = +el.dataset[pair[0] === 'qty' ? 'qty' : pair[0]];
						rows[i][pair[1]] = (pair[0] === 'label') ? el.value : (parseInt(el.value, 10) || 0);
						// Re-render only for numbers, so the seat total stays live
						// without stealing focus from the text field.
						if (pair[0] !== 'label') { render(); }
					};
				});
			});

			Array.prototype.forEach.call(host.querySelectorAll('[data-del]'), function (el) {
				el.onclick = function () { rows.splice(+el.dataset.del, 1); render(); };
			});

			$('#hv-tables-add').onclick = function () {
				rows.push({ id: 0, label: '', seats: 4, quantity: 1 });
				render();
			};

			$('#hv-tables-save').onclick = function () {
				var clean = rows.filter(function (r) {
					return (parseInt(r.seats, 10) || 0) >= 2 && (parseInt(r.quantity, 10) || 0) >= 1;
				});
				postJson(host, 'save_tables', 'tables_json', clean);
			};
		}

		render();
	}

	/**
	 * Submit a JSON payload through the normal admin-post flow, so the server
	 * keeps doing the validation.
	 */
	function postJson(host, action, field, payload) {
		var form = document.createElement('form');
		form.method = 'post';
		form.action = host.dataset.action;
		form.innerHTML =
			'<input type="hidden" name="action" value="havato_owner_action">' +
			'<input type="hidden" name="havato_action" value="' + esc(action) + '">' +
			'<input type="hidden" name="havato_owner_nonce" value="' + esc(host.dataset.nonce) + '">';
		var input = document.createElement('input');
		input.type = 'hidden';
		input.name = field;
		input.value = JSON.stringify(payload);
		form.appendChild(input);
		document.body.appendChild(form);
		form.submit();
	}

	/* =====================================================================
	 * Event form: live capacity + optional photo
	 * ================================================================== */
	function initEventForm() {
		var pick = $('#hv-event-image-pick');
		if (pick) {
			pick.onclick = function () {
				pickMedia(function (url) {
					$('#hv-event-image').value = url;
					var img = $('#hv-event-image-preview');
					img.src = url;
					img.hidden = false;
				});
			};
		}

		var out = $('#hv-event-capacity');
		if (!out) { return; }

		function recalc() {
			var total = 0;
			Array.prototype.forEach.call(document.querySelectorAll('.hv-adm-tablepick-item'), function (item) {
				var box = item.querySelector('input[type="checkbox"]');
				var qty = item.querySelector('.hv-adm-tablepick-qty');
				item.classList.toggle('is-on', box.checked);
				if (box.checked) {
					total += (parseInt(box.dataset.seats, 10) || 0) * (parseInt(qty.value, 10) || 0);
				}
			});
			out.textContent = t('event_capacity_preview').replace('%d', total);
		}

		Array.prototype.forEach.call(document.querySelectorAll('.hv-adm-tablepick-item input'), function (el) {
			el.addEventListener('change', recalc);
			el.addEventListener('input', recalc);
		});
		recalc();
	}

	function boot() {
		initMenu();
		initTables();
		initEventForm();
		initCover();
		initStorefront();
		initMap();
		initLocationSelects();
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', boot);
	} else {
		boot();
	}
})();
