/**
 * راهنمای سایز ووکامرس — رفتار بخش فروشگاه (از استودیو جاوید)
 * بدون وابستگی به jQuery؛ روی همهٔ بلوک‌های .ksg اجرا می‌شود.
 */
(function () {
	'use strict';

	var STORAGE_KEY = 'ksgUnit';
	var CM_PER_INCH = 2.54;
	var PERSIAN_DIGITS = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
	var localised = (window.ksgFrontend || {});
	var initialised = false;

	function ready(fn) {
		if (document.readyState === 'loading') {
			document.addEventListener('DOMContentLoaded', fn, { once: true });
		} else {
			fn();
		}
	}

	function toArray(list) {
		return Array.prototype.slice.call(list || []);
	}

	function readConfig(block) {
		var raw = block.getAttribute('data-ksg') || '{}';

		try {
			return JSON.parse(raw);
		} catch (error) {
			return {};
		}
	}

	function toLatinDigits(value) {
		return String(value).replace(/[۰-۹٠-٩]/g, function (digit) {
			var code = digit.charCodeAt(0);
			var index = code >= 0x06f0 ? code - 0x06f0 : code - 0x0660;
			return String(index);
		});
	}

	function toPersianDigits(value) {
		return String(value).replace(/\d/g, function (digit) {
			return PERSIAN_DIGITS[parseInt(digit, 10)];
		});
	}

	function formatNumber(number) {
		var rounded = Math.round(number * 10) / 10;

		if (Math.abs(rounded - Math.round(rounded)) < 0.05) {
			return String(Math.round(rounded));
		}

		return rounded.toFixed(1);
	}

	/**
	 * تبدیل همهٔ اعداد یک متن از واحد مبدأ به واحد مقصد.
	 */
	function convertText(text, fromUnit, toUnit, persian) {
		var latin = toLatinDigits(text);

		var converted = latin.replace(/\d+(?:\.\d+)?/g, function (match) {
			var number = parseFloat(match);

			if (isNaN(number)) {
				return match;
			}

			if (fromUnit === 'cm' && toUnit === 'inch') {
				number = number / CM_PER_INCH;
			} else if (fromUnit === 'inch' && toUnit === 'cm') {
				number = number * CM_PER_INCH;
			}

			return formatNumber(number);
		});

		return persian ? toPersianDigits(converted) : converted;
	}

	function normalise(value) {
		return toLatinDigits(String(value || ''))
			.replace(/[\u200c\u200f\s]+/g, ' ')
			.replace(/ي/g, 'ی')
			.replace(/ك/g, 'ک')
			.toLowerCase()
			.trim();
	}

	function unitLabel(unit) {
		if (unit === 'inch') {
			return localised.inchLabel || 'in';
		}

		return localised.cmLabel || 'cm';
	}

	function initBlock(block) {
		if (block.dataset.ksgReady === '1') {
			return;
		}

		block.dataset.ksgReady = '1';

		var config = readConfig(block);
		var persian = config.persianDigits !== false && localised.persianDigits !== false;
		var panels = toArray(block.querySelectorAll('.ksg__panel'));
		var switchButtons = toArray(block.querySelectorAll('[data-ksg-unit]'));
		var expandButton = block.querySelector('[data-ksg-expand]');
		var printButton = block.querySelector('[data-ksg-print]');
		var hint = block.querySelector('[data-ksg-hint]');
		var pinned = null;

		function tableUnit(panel) {
			return (panel.getAttribute('data-ksg-unit') || config.defaultUnit || 'cm');
		}

		function activePanel() {
			var found = panels.filter(function (panel) {
				return !panel.hidden;
			});

			return found.length ? found[0] : panels[0];
		}

		function applyUnit(unit, persist) {
			var panel = activePanel();

			if (!panel) {
				return;
			}

			var from = tableUnit(panel);

			toArray(panel.querySelectorAll('[data-ksg-raw]')).forEach(function (cell) {
				cell.textContent = convertText(cell.getAttribute('data-ksg-raw') || cell.textContent, from, unit, persian);
			});

			toArray(panel.querySelectorAll('[data-ksg-unit-chip]')).forEach(function (chip) {
				chip.textContent = from === unit ? '' : unitLabel(unit);
			});

			switchButtons.forEach(function (button) {
				var isOn = button.getAttribute('data-ksg-unit') === unit;
				button.classList.toggle('is-on', isOn);
				button.setAttribute('aria-pressed', isOn ? 'true' : 'false');
			});

			block.setAttribute('data-ksg-active-unit', unit);

			if (persist) {
				try {
					window.localStorage.setItem(STORAGE_KEY, unit);
				} catch (error) {
					/* ذخیره‌سازی در دسترس نیست؛ حالت فقط برای همین صفحه می‌ماند. */
				}
			}
		}

		function currentUnit() {
			return block.getAttribute('data-ksg-active-unit') || tableUnit(activePanel() || block);
		}

		switchButtons.forEach(function (button) {
			button.addEventListener('click', function () {
				applyUnit(button.getAttribute('data-ksg-unit'), true);
			});
		});

		/* ---------- تب‌ها ---------- */

		var tabs = toArray(block.querySelectorAll('[data-ksg-tab]'));

		tabs.forEach(function (tab) {
			tab.addEventListener('click', function () {
				var index = parseInt(tab.getAttribute('data-ksg-tab'), 10);

				tabs.forEach(function (other) {
					var isOn = other === tab;
					other.classList.toggle('is-on', isOn);
					other.setAttribute('aria-selected', isOn ? 'true' : 'false');
					other.setAttribute('tabindex', isOn ? '0' : '-1');
				});

				panels.forEach(function (panel, position) {
					panel.hidden = position !== index;
					panel.classList.toggle('is-on', position === index);
				});

				applyUnit(currentUnit(), false);
			});

			tab.addEventListener('keydown', function (event) {
				if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') {
					return;
				}

				event.preventDefault();

				var position = tabs.indexOf(tab);
				var delta = event.key === 'ArrowLeft' ? 1 : -1;
				var next = tabs[(position + delta + tabs.length) % tabs.length];

				next.focus();
				next.click();
			});
		});

		/* ---------- برجسته‌کردن سایز انتخاب‌شده ---------- */

		function rowSizeValues(panel) {
			return toArray(panel.querySelectorAll('.ksg__row[data-ksg-size]')).map(function (row) {
				return row.getAttribute('data-ksg-size');
			});
		}

		function clearActive(panel) {
			toArray(panel.querySelectorAll('.ksg__row.is-active')).forEach(function (row) {
				row.classList.remove('is-active');
			});

			if (hint) {
				hint.hidden = true;
			}
		}

		function markRow(row) {
			row.classList.add('is-active');

			if (hint) {
				hint.hidden = false;
			}
		}

		function selectedTokens() {
			var tokens = [];

			var form = block.closest('form.cart') || document.querySelector('.variations_form') || document.querySelector('form.cart');

			if (!form) {
				return tokens;
			}

			toArray(form.querySelectorAll('select')).forEach(function (select) {
				var option = select.options[select.selectedIndex];

				if (option) {
					tokens.push(option.value, option.textContent);
				}
			});

			toArray(form.querySelectorAll('input[type="radio"]:checked, input[type="checkbox"]:checked')).forEach(function (input) {
				tokens.push(input.value);

				var label = input.closest('label');

				if (label) {
					tokens.push(label.textContent);
				}
			});

			return tokens.filter(Boolean).map(normalise).filter(Boolean);
		}

		function syncVariation() {
			var panel = activePanel();

			if (!panel) {
				return;
			}

			clearActive(panel);

			if (pinned) {
				return;
			}

			var tokens = selectedTokens();

			if (!tokens.length) {
				return;
			}

			toArray(panel.querySelectorAll('.ksg__row[data-ksg-size]')).forEach(function (row) {
				if (tokens.indexOf(row.getAttribute('data-ksg-size')) !== -1) {
					markRow(row);
				}
			});
		}

		if (config.matchVariation) {
			var variationsForm = document.querySelector('.variations_form');

			if (variationsForm) {
				['change', 'found_variation', 'show_variation', 'woocommerce_variation_has_changed', 'reset_data'].forEach(function (eventName) {
					variationsForm.addEventListener(eventName, function () {
						window.setTimeout(syncVariation, 0);
					});
				});
			}
		}

		toArray(block.querySelectorAll('.ksg__row[data-ksg-size]')).forEach(function (row) {
			row.addEventListener('click', function () {
				var wasActive = row.classList.contains('is-active') && pinned === row;

				toArray(block.querySelectorAll('.ksg__row.is-active')).forEach(function (other) {
					other.classList.remove('is-active');
				});

				pinned = wasActive ? null : row;

				if (pinned) {
					markRow(row);
				} else if (hint) {
					hint.hidden = true;
				}
			});
		});

		/* ---------- پنجرهٔ بزرگ‌نمایی ---------- */

		var overlay = null;
		var anchor = null;
		var lastFocused = null;

		function closeModal() {
			if (!overlay) {
				return;
			}

			if (anchor && anchor.parentNode) {
				anchor.parentNode.insertBefore(block, anchor);
				anchor.parentNode.removeChild(anchor);
			}

			document.removeEventListener('keydown', onOverlayKeydown);

			if (overlay.parentNode) {
				overlay.parentNode.removeChild(overlay);
			}

			overlay = null;
			anchor = null;
			document.documentElement.classList.remove('ksg-lock');

			if (lastFocused && typeof lastFocused.focus === 'function') {
				lastFocused.focus();
			}
		}

		function openModal() {
			if (overlay) {
				return;
			}

			lastFocused = document.activeElement;
			anchor = document.createComment('ksg-anchor');

			if (block.parentNode) {
				block.parentNode.insertBefore(anchor, block);
			}

			overlay = document.createElement('div');
			overlay.className = 'ksg-overlay';
			overlay.setAttribute('role', 'dialog');
			overlay.setAttribute('aria-modal', 'true');
			overlay.setAttribute('aria-label', localised.expandLabel || 'راهنمای سایز');

			var closeButton = document.createElement('button');
			closeButton.type = 'button';
			closeButton.className = 'ksg__close';
			closeButton.textContent = localised.closeLabel || 'بستن';
			closeButton.addEventListener('click', closeModal);

			overlay.appendChild(closeButton);
			overlay.appendChild(block);

			overlay.addEventListener('click', function (event) {
				if (event.target === overlay) {
					closeModal();
				}
			});

			document.body.appendChild(overlay);
			document.documentElement.classList.add('ksg-lock');
			document.addEventListener('keydown', onOverlayKeydown);

			closeButton.focus();
		}

		function onOverlayKeydown(event) {
			if (event.key === 'Escape') {
				event.preventDefault();
				closeModal();
				return;
			}

			if (event.key !== 'Tab' || !overlay) {
				return;
			}

			var focusables = toArray(overlay.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')).filter(function (element) {
				return element.offsetParent !== null;
			});

			if (!focusables.length) {
				return;
			}

			var first = focusables[0];
			var last = focusables[focusables.length - 1];

			if (event.shiftKey && document.activeElement === first) {
				event.preventDefault();
				last.focus();
			} else if (!event.shiftKey && document.activeElement === last) {
				event.preventDefault();
				first.focus();
			}
		}

		if (expandButton) {
			expandButton.addEventListener('click', openModal);
		}

		if (printButton) {
			printButton.addEventListener('click', function () {
				window.print();
			});
		}

		/* ---------- حالت اولیه ---------- */

		var storedUnit = null;

		try {
			storedUnit = window.localStorage.getItem(STORAGE_KEY);
		} catch (error) {
			storedUnit = null;
		}

		var initialUnit = storedUnit === 'cm' || storedUnit === 'inch' ? storedUnit : (config.defaultUnit || tableUnit(panels[0] || block));

		applyUnit(initialUnit, false);

		if (config.matchVariation) {
			syncVariation();
		}
	}

	function initAll() {
		toArray(document.querySelectorAll('.ksg')).forEach(initBlock);
	}

	ready(function () {
		if (initialised) {
			return;
		}

		initialised = true;

		initAll();

		// پشتیبانی از محتوای تازه (مثلاً کوئری‌لوپ‌های Ajax یا سبد خرید زنده).
		if (window.MutationObserver) {
			var observer = new MutationObserver(function (records) {
				records.forEach(function (record) {
					toArray(record.addedNodes).forEach(function (node) {
						if (node.nodeType !== 1) {
							return;
						}

						if (node.classList && node.classList.contains('ksg')) {
							initBlock(node);
						} else if (node.querySelectorAll) {
							toArray(node.querySelectorAll('.ksg')).forEach(initBlock);
						}
					});
				});
			});

			observer.observe(document.body, { childList: true, subtree: true });
		}

		document.addEventListener('ksg:refresh', initAll);
	});
})();
