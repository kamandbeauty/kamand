import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'persian_number_formatter.dart';
import 'thousand_separator_formatter.dart';

/// فیلد عددی: فوکوس = انتخاب کل متن + جداکننده هزارگان هنگام تایپ
class ReplaceOnTypeNumberField extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final TextStyle? style;
  final String emptyDisplay;
  final bool allowDecimal;
  final bool useThousandSeparator;
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
    this.useThousandSeparator = true,
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
    if (v == 0 && widget.emptyDisplay == '\u0000') return '';
    if (!widget.useThousandSeparator) {
      if (v == v.roundToDouble()) {
        return PersianNumberFormatter.toPersian(v.toInt().toString());
      }
      var s = v.toString();
      if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
      return PersianNumberFormatter.toPersian(s);
    }
    if (v == 0) {
      return widget.emptyDisplay == '\u0000' ? '' : PersianNumberFormatter.toPersian('0');
    }
    final raw = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return ThousandSeparatorInputFormatter.formatDisplay(
      raw,
      allowDecimal: widget.allowDecimal,
      persianDigits: true,
    );
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _format(widget.value));
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
    } else {
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
        if (widget.useThousandSeparator)
          ThousandSeparatorInputFormatter(allowDecimal: widget.allowDecimal)
        else
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
      onTap: () {
        _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
      },
      onChanged: (v) {
        if (_syncing) return;
        if (v.trim().isEmpty) {
          widget.onChanged(0);
          return;
        }
        final parsed = ThousandSeparatorInputFormatter.parseToDouble(v);
        if (parsed != null) widget.onChanged(parsed);
      },
    );
  }
}
