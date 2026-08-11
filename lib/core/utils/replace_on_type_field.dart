import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'persian_number_formatter.dart';

/// فیلد عددی: با فوکوس/کلیک کل متن انتخاب می‌شود تا اولین تایپ جایگزین شود
class ReplaceOnTypeNumberField extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final TextStyle? style;
  final String emptyDisplay;
  final bool allowDecimal;
  final TextAlign textAlign;
  final EdgeInsetsGeometry contentPadding;
  final Color? fillColor;
  final bool filled;
  final InputBorder? border;

  const ReplaceOnTypeNumberField({
    super.key,
    required this.value,
    required this.onChanged,
    this.style,
    this.emptyDisplay = '',
    this.allowDecimal = true,
    this.textAlign = TextAlign.center,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
    this.fillColor,
    this.filled = false,
    this.border,
  });

  @override
  State<ReplaceOnTypeNumberField> createState() => _ReplaceOnTypeNumberFieldState();
}

class _ReplaceOnTypeNumberFieldState extends State<ReplaceOnTypeNumberField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _syncing = false;

  String _format(double v) {
    // اگر emptyDisplay صراحتاً '' برای صفر قیمت باشد و value==0 → خالی نشان بده
    // برای مقدار (quantity) emptyDisplay پیش‌فرض '' نیست با معنا؛ همیشه عدد نشان می‌دهیم
    // قرارداد: emptyDisplay == '\u0000' یعنی صفر را خالی نشان بده
    if (v == 0 && widget.emptyDisplay == '\u0000') return '';
    if (v == v.roundToDouble()) {
      return PersianNumberFormatter.toPersian(v.toInt().toString());
    }
    // حذف صفرهای انتهایی اعشار بی‌مورد
    var s = v.toString();
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return PersianNumberFormatter.toPersian(s);
  }

  String _faToEn(String s) {
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    var r = s;
    for (int i = 0; i < 10; i++) {
      r = r.replaceAll(fa[i], en[i]);
    }
    return r.replaceAll(RegExp(r'[^0-9.]'), '');
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _format(widget.value));
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      // کل متن را انتخاب کن تا تایپ بعدی جایگزین شود
      _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
    } else {
      // نرمال‌سازی نمایش بعد از blur
      _syncFromValue(widget.value);
    }
  }

  @override
  void didUpdateWidget(covariant ReplaceOnTypeNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.value != widget.value) {
      _syncFromValue(widget.value);
    }
  }

  void _syncFromValue(double v) {
    final t = _format(v);
    if (_ctrl.text != t) {
      _syncing = true;
      _ctrl.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _selectAll() {
    _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.allowDecimal),
      textAlign: widget.textAlign,
      textDirection: TextDirection.ltr,
      style: widget.style,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹.]')),
      ],
      decoration: InputDecoration(
        border: widget.border ?? InputBorder.none,
        contentPadding: widget.contentPadding,
        isDense: true,
        filled: widget.filled,
        fillColor: widget.fillColor,
        counterText: '',
      ),
      onTap: _selectAll,
      onChanged: (v) {
        if (_syncing) return;
        final en = _faToEn(v);
        if (en.isEmpty) {
          widget.onChanged(0);
          return;
        }
        final parsed = double.tryParse(en);
        if (parsed != null) {
          widget.onChanged(parsed);
        }
      },
    );
  }
}
