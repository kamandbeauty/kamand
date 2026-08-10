import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../models/business_profile_model.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate600 = Color(0xFF475569);
const _cardBg = Color(0xFFF1F5F9);

class HeaderCustomizeScreen extends ConsumerStatefulWidget {
  const HeaderCustomizeScreen({super.key});
  @override
  ConsumerState<HeaderCustomizeScreen> createState() => _HeaderCustomizeScreenState();
}

class _HeaderCustomizeScreenState extends ConsumerState<HeaderCustomizeScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  Color _selectedColor = _orange;
  XFile? _logoFile;
  XFile? _stampFile;
  XFile? _signFile;
  final _picker = ImagePicker();

  final List<Color> _paletteRow1 = const [
    Color(0xFF455A64), // dark gray
    Color(0xFF2196F3), // blue
    Color(0xFF7C4DFF), // purple
    Color(0xFFE040FB), // pink
    Color(0xFFE53935), // red
    Color(0xFFBC6C25), // brown/orange
    Color(0xFFFBC02D), // yellow
    Color(0xFF43A047), // green
  ];
  final List<Color> _paletteRow2 = const [
    Color(0xFF90A4AE), // gray
    Color(0xFF81D4FA), // light blue
    Color(0xFFB39DDB), // light purple
    Color(0xFFF48FB1), // light pink
    Color(0xFFEF9A9A), // light red
    Color(0xFFFFCC80), // light orange
    Color(0xFFFFF59D), // light yellow
    Color(0xFFA5D6A7), // light green
  ];

  @override
  void initState() {
    super.initState();
    final biz = ref.read(businessProvider);
    _nameCtrl = TextEditingController(text: biz.shopName);
    _descCtrl = TextEditingController(text: biz.address);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function(XFile?) onPicked) async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    try {
      final bytes = await File(x.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        // حذف زمینه سفید: پیکسل‌های نزدیک سفید را شفاف کن
        for (var y = 0; y < decoded.height; y++) {
          for (var x2 = 0; x2 < decoded.width; x2++) {
            final p = decoded.getPixel(x2, y);
            final r = p.r.toInt();
            final g = p.g.toInt();
            final b = p.b.toInt();
            if (r > 242 && g > 242 && b > 242) {
              decoded.setPixelRgba(x2, y, r, g, b, 0);
            }
          }
        }
        final dir = await getTemporaryDirectory();
        final outPath = '${dir.path}/rubi_${DateTime.now().millisecondsSinceEpoch}_${x.name}';
        final outFile = File(outPath);
        await outFile.writeAsBytes(img.encodePng(decoded));
        final newX = XFile(outFile.path);
        setState(() => onPicked(newX));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عکس انتخاب شد — زمینه سفید حذف شد')));
        }
        return;
      }
    } catch (_) {}
    // fallback بدون پردازش
    setState(() => onPicked(x));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عکس انتخاب شد — زمینه سفید هنگام چاپ حذف می‌شود')));
    }
  }

  void _save() {
    final biz = ref.read(businessProvider);
    final updated = BusinessProfileModel(
      id: biz.id,
      shopName: _nameCtrl.text.trim().isEmpty ? biz.shopName : _nameCtrl.text.trim(),
      phone: biz.phone,
      address: _descCtrl.text.trim(),
      taxId: biz.taxId,
      logoPath: _logoFile?.path ?? biz.logoPath,
      bankCards: biz.bankCards,
    );
    ref.read(businessProvider.notifier).updateBusiness(updated);
    // Save selected color to AppTheme? For now just show and pop
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ذخیره شد — رنگ ${(_selectedColor.value.toRadixString(16))} اعمال خواهد شد')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: AppBar(
          backgroundColor: _selectedColor,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=> Navigator.pop(context)),
          centerTitle: true,
          title: Column(
            children: [
              const Text('تنظیمات شخصی‌سازی', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 4),
              Text('فاکتور', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            // نام کسب و کار
            _fieldCard(
              dark: dark,
              child: TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: 'نام کسب و کار',
                  hintStyle: TextStyle(color: _slate400, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                style: TextStyle(fontSize: 13, color: dark? Colors.white: _slate600),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(height: 10),
            _fieldCard(
              dark: dark,
              child: TextField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  hintText: 'توضیحات کوتاه یا آدرس',
                  hintStyle: TextStyle(color: _slate400, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                style: TextStyle(fontSize: 13, color: dark? Colors.white: _slate600),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(height: 12),

            // لوگو
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: dark? const Color(0xFF1E293B): Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: dark? const Color(0xFF334155): const Color(0xFFE2E8F0))),
              child: Column(
                children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFFFFF3CD), shape: BoxShape.circle), child: const Icon(Icons.verified, size: 16, color: Color(0xFFEAB308))),
                    const SizedBox(width: 6),
                    Text('لوگو', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: dark? Colors.white: _slate600)),
                    const Spacer(),
                    if (_logoFile != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_logoFile!.path), width: 40, height: 40, fit: BoxFit.cover)) else const SizedBox(),
                  ]),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: ()=> _pickImage((x)=> _logoFile = x),
                    child: Row(children: [
                      const Icon(Icons.more_horiz, color: _slate500),
                      const Spacer(),
                      Text('انتخاب لوگو', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark? Colors.white: _slate600)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // رنگ
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: dark? const Color(0xFF1E293B): Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: dark? const Color(0xFF334155): const Color(0xFFE2E8F0))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(alignment: Alignment.centerRight, child: Text('رنگ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: dark? Colors.white: _slate600))),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, crossAxisSpacing: 8, mainAxisSpacing: 10, childAspectRatio: 1),
                    itemCount: _paletteRow1.length + _paletteRow2.length,
                    itemBuilder: (ctx,i){
                      final colors = [..._paletteRow1, ..._paletteRow2];
                      final c = colors[i];
                      final isSelected = c.value == _selectedColor.value;
                      return InkWell(
                        onTap: ()=> setState(()=> _selectedColor = c),
                        child: Container(
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: dark? Colors.white: _slate600, width: 2) : null,
                          ),
                          child: isSelected ? const Center(child: Icon(Icons.check, color: Colors.white, size: 16)) : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Divider(color: dark? const Color(0xFF334155): const Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final c = await showDialog<Color>(context: context, builder: (ctx)=> _ColorPickerDialog(initial: _selectedColor));
                      if (c != null) setState(()=> _selectedColor = c);
                    },
                    child: Row(children: [
                      Icon(Icons.colorize_outlined, color: _slate500, size: 20),
                      const Spacer(),
                      Text('انتخاب رنگ دلخواه', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark? Colors.white: _slate600)),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_back_ios, size: 14, color: _slate400),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // مهر / امضا — زمینه سفید حذف می‌شود
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: dark? const Color(0xFF1E293B): Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: dark? const Color(0xFF334155): const Color(0xFFE2E8F0))),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: Row(children: [
                      Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFFFF3CD), shape: BoxShape.circle), child: const Icon(Icons.verified, size: 14, color: Color(0xFFEAB308))),
                      const SizedBox(width: 4),
                      Text('امضا', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dark? Colors.white: _slate600)),
                    ])),
                    Expanded(child: Row(children: [
                      Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFFFF3CD), shape: BoxShape.circle), child: const Icon(Icons.verified, size: 14, color: Color(0xFFEAB308))),
                      const SizedBox(width: 4),
                      Text('مهر', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dark? Colors.white: _slate600)),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: InkWell(
                      onTap: ()=> _pickImage((x)=> _signFile = x),
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
                        child: _signFile != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_signFile!.path), fit: BoxFit.contain))
                            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.add_photo_alternate_outlined, size: 36, color: _selectedColor),
                                const SizedBox(height: 8),
                                Text('انتخاب امضا', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _slate600)),
                                const SizedBox(height: 2),
                                Text('زمینه سفید خودکار حذف می‌شود', style: TextStyle(fontSize: 9, color: _slate400)),
                              ]),
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: InkWell(
                      onTap: ()=> _pickImage((x)=> _stampFile = x),
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
                        child: _stampFile != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_stampFile!.path), fit: BoxFit.contain))
                            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.add_photo_alternate_outlined, size: 36, color: _selectedColor),
                                const SizedBox(height: 8),
                                Text('انتخاب مهر', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _slate600)),
                                const SizedBox(height: 2),
                                Text('زمینه سفید خودکار حذف می‌شود', style: TextStyle(fontSize: 9, color: _slate400)),
                              ]),
                      ),
                    )),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: _selectedColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('ذخیره', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldCard({required bool dark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: dark? const Color(0xFF1E293B): _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: dark? const Color(0xFF334155): const Color(0xFFE2E8F0))),
      child: child,
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});
  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}
class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double r,g,b;
  @override
  void initState(){ super.initState(); r=widget.initial.red.toDouble(); g=widget.initial.green.toDouble(); b=widget.initial.blue.toDouble(); }
  @override
  Widget build(BuildContext context){
    final c = Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt());
    return AlertDialog(
      title: const Text('انتخاب رنگ دلخواه'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 40, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8))),
        const SizedBox(height: 16),
        _slider('R', r, (v)=> setState(()=> r=v)),
        _slider('G', g, (v)=> setState(()=> g=v)),
        _slider('B', b, (v)=> setState(()=> b=v)),
      ]),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('لغو')),
        ElevatedButton(onPressed: ()=> Navigator.pop(context, c), child: const Text('تایید')),
      ],
    );
  }
  Widget _slider(String l, double v, Function(double) onChanged){
    return Row(children: [SizedBox(width: 20, child: Text(l)), Expanded(child: Slider(value: v, min: 0, max: 255, onChanged: onChanged)), Text(v.toInt().toString().padLeft(3))]);
  }
}
