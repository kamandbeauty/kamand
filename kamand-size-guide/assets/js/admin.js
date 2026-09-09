/**
 * کمند | راهنمای سایز — ویرایشگر جدول در پیشخوان
 */
(function () {
	'use strict';

	var i18n = (window.ksgAdmin && window.ksgAdmin.i18n) || {};
	var MAX_ROWS = (window.ksgAdmin && window.ksgAdmin.maxRows) || 80;
	var MAX_COLS = (window.ksgAdmin && window.ksgAdmin.maxCols) || 12;
	var MAX_TIPS = (window.ksgAdmin && window.ksgAdmin.maxTips) || 12;

	function t(key, fallback) {
		return i18n[key] || fallback;
	}

	function el(tag, className, text) {
		var node = document.createElement(tag);

		if (className) {
			node.className = className;
		}

		if (typeof text !== 'undefined') {
			node.textContent = text;
		}

		return node;
	}

	function uid(prefix) {
		return prefix + Math.random().toString(36).slice(2, 8);
	}

	function emptyTable() {
		return { unit: 'cm', columns: [], rows: [], tips: [], note: '', image: 0 };
	}

	/**
	 * ویرایشگر یک جدول (راهنما یا جدول اختصاصی محصول).
	 */
	function TableEditor(root, options) {
		this.root = root;
		this.shell = root.querySelector('.ksg-admin-shell');
		this.hidden = root.querySelector('.ksg-admin-json');
		this.context = options.context || 'guide';
		this.state = options.table || emptyTable();

		if (!this.state.columns) {
			this.state.columns = [];
		}

		if (!this.state.rows) {
			this.state.rows = [];
		}

		if (!this.state.tips) {
			this.state.tips = [];
		}

		this.render();
		this.sync();
	}

	TableEditor.prototype.addColumn = function () {
		if (this.state.columns.length >= MAX_COLS) {
			return;
		}

		var isFirst = this.state.columns.length === 0;

		this.state.columns.push({
			id: uid('c_'),
			label: '',
			kind: isFirst ? 'size' : 'measure'
		});

		this.state.rows.forEach(function (row) {
			row.values = row.values || {};
		});

		this.render();
		this.sync();
	};

	TableEditor.prototype.removeColumn = function (id) {
		this.state.columns = this.state.columns.filter(function (column) {
			return column.id !== id;
		});

		this.state.rows.forEach(function (row) {
			if (row.values) {
				delete row.values[id];
			}
		});

		this.render();
		this.sync();
	};

	TableEditor.prototype.moveColumn = function (id, delta) {
		var index = this.indexOfColumn(id);
		var target = index + delta;

		if (index === -1 || target < 0 || target >= this.state.columns.length) {
			return;
		}

		var column = this.state.columns.splice(index, 1)[0];
		this.state.columns.splice(target, 0, column);

		this.render();
		this.sync();
	};

	TableEditor.prototype.indexOfColumn = function (id) {
		for (var i = 0; i < this.state.columns.length; i++) {
			if (this.state.columns[i].id === id) {
				return i;
			}
		}

		return -1;
	};

	TableEditor.prototype.addRow = function (copyFrom) {
		if (this.state.rows.length >= MAX_ROWS || !this.state.columns.length) {
			return;
		}

		var values = {};
		var columns = this.state.columns;

		columns.forEach(function (column) {
			values[column.id] = copyFrom && copyFrom.values && copyFrom.values[column.id] ? copyFrom.values[column.id] : '';
		});

		this.state.rows.push({ id: uid('r_'), values: values });

		this.render();
		this.sync();
	};

	TableEditor.prototype.removeRow = function (id) {
		this.state.rows = this.state.rows.filter(function (row) {
			return row.id !== id;
		});

		this.render();
		this.sync();
	};

	TableEditor.prototype.duplicateRow = function (id) {
		var source = null;

		this.state.rows.forEach(function (row) {
			if (row.id === id) {
				source = row;
			}
		});

		if (!source) {
			return;
		}

		var index = this.state.rows.indexOf(source);
		var values = {};
		var columns = this.state.columns;

		columns.forEach(function (column) {
			values[column.id] = source.values && source.values[column.id] ? source.values[column.id] : '';
		});

		this.state.rows.splice(index + 1, 0, { id: uid('r_'), values: values });

		this.render();
		this.sync();
	};

	TableEditor.prototype.importText = function (text) {
		var lines = String(text || '').replace(/\r/g, '').split('\n').filter(function (line) {
			return line.trim() !== '';
		});

		if (!lines.length) {
			return;
		}

		var delimiter = lines[0].indexOf('\t') !== -1 ? '\t' : ',';
		var matrix = lines.map(function (line) {
			return line.split(delimiter).map(function (cell) {
				return cell.replace(/^"|"$/g, '').trim();
			});
		});

		var width = matrix.reduce(function (max, row) {
			return Math.max(max, row.length);
		}, 0);

		var columns = [];

		for (var i = 0; i < width; i++) {
			columns.push({
				id: uid('c_'),
				label: matrix[0][i] || '',
				kind: i === 0 ? 'size' : 'measure'
			});
		}

		var rows = [];

		matrix.slice(1).forEach(function (cells, rowIndex) {
			var values = {};
			var hasValue = false;

			columns.forEach(function (column, columnIndex) {
				var value = cells[columnIndex] || '';

				if (value !== '') {
					hasValue = true;
				}

				values[column.id] = value;
			});

			if (hasValue && rows.length < MAX_ROWS) {
				rows.push({ id: 'r_import_' + rowIndex, values: values });
			}
		});

		if (!rows.length) {
			return;
		}

		this.state.columns = columns.slice(0, MAX_COLS);
		this.state.rows = rows;

		this.render();
		this.sync();
	};

	TableEditor.prototype.sync = function () {
		if (!this.hidden) {
			return;
		}

		this.hidden.value = JSON.stringify({
			unit: this.state.unit,
			columns: this.state.columns,
			rows: this.state.rows,
			tips: this.context === 'guide' ? this.state.tips : [],
			note: this.context === 'guide' ? (this.state.note || '') : '',
			image: this.context === 'guide' ? (this.state.image || 0) : 0
		});
	};

	TableEditor.prototype.hasSizeColumn = function () {
		return this.state.columns.some(function (column) {
			return column.kind === 'size';
		});
	};

	TableEditor.prototype.render = function () {
		var self = this;
		this.shell.innerHTML = '';

		/* نوار ابزار */
		var toolbar = el('div', 'ksg-toolbar');

		var unitWrap = el('label', 'ksg-inline');
		unitWrap.appendChild(el('span', 'ksg-inline-label', 'واحد اندازه‌گیری'));

		var unitSelect = el('select', 'ksg-select');
		[['cm', 'سانتی‌متر'], ['inch', 'اینچ']].forEach(function (pair) {
			var option = el('option', null, pair[1]);
			option.value = pair[0];
			option.selected = self.state.unit === pair[0];
			unitSelect.appendChild(option);
		});
		unitSelect.addEventListener('change', function () {
			self.state.unit = unitSelect.value;
			self.sync();
		});
		unitWrap.appendChild(unitSelect);
		toolbar.appendChild(unitWrap);

		var addColumn = el('button', 'button button-small', '+ ' + t('addColumn', 'افزودن ستون'));
		addColumn.type = 'button';
		addColumn.addEventListener('click', function () {
			self.addColumn();
		});
		toolbar.appendChild(addColumn);

		var addRow = el('button', 'button button-small button-primary', '+ ' + t('addRow', 'افزودن ردیف'));
		addRow.type = 'button';
		addRow.addEventListener('click', function () {
			self.addRow();
		});
		toolbar.appendChild(addRow);

		var importToggle = el('button', 'button button-small button-link', t('pasteImport', 'ساخت جدول از متن'));
		importToggle.type = 'button';
		toolbar.appendChild(importToggle);

		this.shell.appendChild(toolbar);

		/* جعبهٔ واردکردن از متن */
		var importBox = el('div', 'ksg-import');
		importBox.hidden = true;

		var importHint = el('p', 'description', t('pasteHint', 'دادهٔ جدول را از اکسل یا گوگل‌شیت کپی و اینجا جای‌گذاری کنید.'));
		importBox.appendChild(importHint);

		var importArea = el('textarea', 'ksg-textarea');
		importArea.rows = 4;
		importArea.placeholder = 'سایز\tدور سینه\tدور کمر\nM\t92\t74';
		importBox.appendChild(importArea);

		var importButton = el('button', 'button button-small', t('pasteImport', 'ساخت جدول از متن'));
		importButton.type = 'button';
		importButton.addEventListener('click', function () {
			self.importText(importArea.value);
			importBox.hidden = true;
			importArea.value = '';
		});
		importBox.appendChild(importButton);

		importToggle.addEventListener('click', function () {
			importBox.hidden = !importBox.hidden;
		});

		this.shell.appendChild(importBox);

		if (!this.hasSizeColumn() && this.state.columns.length) {
			this.shell.appendChild(el('p', 'ksg-warning', t('needSizeCol', 'دست‌کم یک ستون از نوع «سایز» لازم است.')));
		}

		if (!this.state.columns.length) {
			this.shell.appendChild(el('p', 'description ksg-empty', t('emptyTable', 'جدول خالی است؛ با «افزودن ردیف» شروع کنید.')));
			this.renderExtras();
			return;
		}

		/* ویرایش ستون‌ها */
		var columnsWrap = el('div', 'ksg-columns');

		this.state.columns.forEach(function (column, index) {
			var card = el('div', 'ksg-column');

			var labelInput = el('input', 'ksg-input');
			labelInput.type = 'text';
			labelInput.value = column.label;
			labelInput.placeholder = t('columnLabel', 'عنوان ستون');
			labelInput.addEventListener('input', function () {
				column.label = labelInput.value;
				self.sync();
			});
			card.appendChild(labelInput);

			var kindSelect = el('select', 'ksg-select');
			[['size', t('kindSize', 'سایز')], ['measure', t('kindMeasure', 'عدد اندازه‌گیری')], ['note', t('kindNote', 'توضیح')]].forEach(function (pair) {
				var option = el('option', null, pair[1]);
				option.value = pair[0];
				option.selected = column.kind === pair[0];
				kindSelect.appendChild(option);
			});
			kindSelect.addEventListener('change', function () {
				column.kind = kindSelect.value;
				self.render();
				self.sync();
			});
			card.appendChild(kindSelect);

			var actions = el('div', 'ksg-actions');

			var moveLeft = el('button', 'button button-small', '→');
			moveLeft.type = 'button';
			moveLeft.title = t('moveLeft', 'انتقال');
			moveLeft.disabled = index === self.state.columns.length - 1;
			moveLeft.addEventListener('click', function () {
				self.moveColumn(column.id, 1);
			});
			actions.appendChild(moveLeft);

			var moveRight = el('button', 'button button-small', '←');
			moveRight.type = 'button';
			moveRight.title = t('moveRight', 'انتقال');
			moveRight.disabled = index === 0;
			moveRight.addEventListener('click', function () {
				self.moveColumn(column.id, -1);
			});
			actions.appendChild(moveRight);

			var remove = el('button', 'button button-small button-link-delete', t('remove', 'حذف'));
			remove.type = 'button';
			remove.addEventListener('click', function () {
				self.removeColumn(column.id);
			});
			actions.appendChild(remove);

			card.appendChild(actions);
			columnsWrap.appendChild(card);
		});

		this.shell.appendChild(columnsWrap);
		this.shell.appendChild(el('p', 'description', t('sizeColumnTip', 'ستون «سایز» برای هایلایت خودکار سایز انتخاب‌شده استفاده می‌شود.')));

		/* ردیف‌ها */
		var table = el('table', 'ksg-grid widefat striped');
		var thead = el('thead');
		var headRow = el('tr');

		this.state.columns.forEach(function (column) {
			var th = el('th', null, column.label || '—');
			headRow.appendChild(th);
		});

		var actionHead = el('th', 'ksg-grid-actions', t('row', 'ردیف'));
		headRow.appendChild(actionHead);
		thead.appendChild(headRow);
		table.appendChild(thead);

		var tbody = el('tbody');

		this.state.rows.forEach(function (row) {
			var tr = el('tr');

			self.state.columns.forEach(function (column) {
				var td = el('td');
				var input = el('input', 'ksg-input ksg-cell-input');
				input.type = 'text';
				input.value = (row.values && row.values[column.id]) || '';
				input.addEventListener('input', function () {
					row.values = row.values || {};
					row.values[column.id] = input.value;
					self.sync();
				});
				td.appendChild(input);
				tr.appendChild(td);
			});

			var actionsCell = el('td', 'ksg-grid-actions');

			var duplicate = el('button', 'button button-small', t('duplicate', 'تکثیر'));
			duplicate.type = 'button';
			duplicate.addEventListener('click', function () {
				self.duplicateRow(row.id);
			});
			actionsCell.appendChild(duplicate);

			var removeRow = el('button', 'button button-small button-link-delete', t('remove', 'حذف'));
			removeRow.type = 'button';
			removeRow.addEventListener('click', function () {
				self.removeRow(row.id);
			});
			actionsCell.appendChild(removeRow);

			tr.appendChild(actionsCell);
			tbody.appendChild(tr);
		});

		table.appendChild(tbody);
		this.shell.appendChild(table);

		this.renderExtras();
	};

	TableEditor.prototype.renderExtras = function () {
		if (this.context !== 'guide') {
			return;
		}

		var self = this;
		var extras = el('div', 'ksg-extras');

		/* نکته‌ها */
		var tipsWrap = el('div', 'ksg-tips');
		tipsWrap.appendChild(el('strong', null, 'نکته‌های اندازه‌گیری'));

		this.state.tips.forEach(function (tip, index) {
			var line = el('div', 'ksg-tip-line');
			var input = el('input', 'ksg-input');
			input.type = 'text';
			input.value = tip;
			input.addEventListener('input', function () {
				self.state.tips[index] = input.value;
				self.sync();
			});
			line.appendChild(input);

			var remove = el('button', 'button button-small button-link-delete', t('remove', 'حذف'));
			remove.type = 'button';
			remove.addEventListener('click', function () {
				self.state.tips.splice(index, 1);
				self.render();
				self.sync();
			});
			line.appendChild(remove);

			tipsWrap.appendChild(line);
		});

		if (this.state.tips.length < MAX_TIPS) {
			var addTip = el('button', 'button button-small', '+ افزودن نکته');
			addTip.type = 'button';
			addTip.addEventListener('click', function () {
				self.state.tips.push('');
				self.render();
				self.sync();
			});
			tipsWrap.appendChild(addTip);
		}

		extras.appendChild(tipsWrap);

		/* توضیح */
		var noteWrap = el('div', 'ksg-note-field');
		noteWrap.appendChild(el('strong', null, 'توضیح زیر جدول'));

		var noteArea = el('textarea', 'ksg-textarea');
		noteArea.rows = 2;
		noteArea.value = this.state.note || '';
		noteArea.addEventListener('input', function () {
			self.state.note = noteArea.value;
			self.sync();
		});
		noteWrap.appendChild(noteArea);
		extras.appendChild(noteWrap);

		/* تصویر */
		var imageWrap = el('div', 'ksg-image-field');
		imageWrap.appendChild(el('strong', null, 'تصویر راهنما (اختیاری)'));

		var preview = el('div', 'ksg-image-preview');

		if (this.state.image) {
			var img = el('img');
			img.src = (window.ksgAdmin && window.ksgAdmin.imageUrl) || '';
			img.alt = '';
			if (!img.src) {
				preview.appendChild(el('span', 'description', 'شناسهٔ تصویر: ' + this.state.image));
			} else {
				preview.appendChild(img);
			}
		} else {
			preview.appendChild(el('span', 'description', 'تصویری انتخاب نشده است.'));
		}

		imageWrap.appendChild(preview);

		var choose = el('button', 'button button-small', t('chooseImage', 'انتخاب تصویر'));
		choose.type = 'button';
		choose.addEventListener('click', function () {
			self.pickImage();
		});
		imageWrap.appendChild(choose);

		if (this.state.image) {
			var removeImage = el('button', 'button button-small button-link-delete', t('removeImage', 'حذف تصویر'));
			removeImage.type = 'button';
			removeImage.addEventListener('click', function () {
				self.state.image = 0;
				self.render();
				self.sync();
			});
			imageWrap.appendChild(removeImage);
		}

		extras.appendChild(imageWrap);
		this.shell.appendChild(extras);
	};

	TableEditor.prototype.pickImage = function () {
		var self = this;

		if (!window.wp || !window.wp.media) {
			return;
		}

		var frame = window.wp.media({
			title: t('chooseImage', 'انتخاب تصویر'),
			multiple: false,
			library: { type: 'image' }
		});

		frame.on('select', function () {
			var attachment = frame.state().get('selection').first().toJSON();
			self.state.image = attachment.id;
			self.render();
			self.sync();
		});

		frame.open();
	};

	function readData(root) {
		var script = root.querySelector('.ksg-admin-data');

		if (!script) {
			return {};
		}

		try {
			return JSON.parse(script.textContent || '{}');
		} catch (error) {
			return {};
		}
	}

	function initEditors() {
		Array.prototype.forEach.call(document.querySelectorAll('.ksg-admin[data-ksg-editor]'), function (root) {
			if (root.dataset.ksgInitialised === '1') {
				return;
			}

			root.dataset.ksgInitialised = '1';

			var data = readData(root);
			var table = data.table || emptyTable();

			if (data.context === 'product') {
				table.tips = [];
				table.note = '';
				table.image = 0;
			}

			new TableEditor(root, { table: table, context: data.context || 'guide' }); // eslint-disable-line no-new
		});
	}

	function initModePanels() {
		Array.prototype.forEach.call(document.querySelectorAll('.ksg-admin[data-ksg-product]'), function (root) {
			var radios = root.querySelectorAll('input[name="ksg_mode"]');
			var panels = root.querySelectorAll('.ksg-mode-panel');

			function apply() {
				var current = 'inherit';

				Array.prototype.forEach.call(radios, function (radio) {
					if (radio.checked) {
						current = radio.value;
					}
				});

				Array.prototype.forEach.call(panels, function (panel) {
					panel.hidden = panel.getAttribute('data-ksg-mode') !== current;
				});
			}

			Array.prototype.forEach.call(radios, function (radio) {
				radio.addEventListener('change', apply);
			});

			apply();
		});
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', function () {
			initEditors();
			initModePanels();
		});
	} else {
		initEditors();
		initModePanels();
	}
})();
