import 'package:factor_ruby/providers/app_providers.dart';
import 'package:factor_ruby/screens/customize/header_customize_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saving customization closes safely before root providers rebuild',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: _CustomizationHarness()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('باز کردن تنظیمات'));
    await tester.pumpAndSettle();
    expect(find.byType(HeaderCustomizeScreen), findsOneWidget);

    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(find.byType(HeaderCustomizeScreen), findsNothing);
    expect(find.text('ذخیره شد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CustomizationHarness extends ConsumerStatefulWidget {
  const _CustomizationHarness();

  @override
  ConsumerState<_CustomizationHarness> createState() =>
      _CustomizationHarnessState();
}

class _CustomizationHarnessState extends ConsumerState<_CustomizationHarness> {
  bool _saved = false;

  Future<void> _open() async {
    final result = await Navigator.of(context).push<HeaderCustomizeResult>(
      MaterialPageRoute(builder: (_) => const HeaderCustomizeScreen()),
    );
    if (result == null || !mounted) return;
    await ref.read(businessProvider.notifier).updateBusiness(result.business);
    await ref.read(settingsProvider.notifier).updateSettings(result.settings);
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(businessProvider);
    ref.watch(settingsProvider);
    return Scaffold(
      body: Center(
        child: _saved
            ? const Text('ذخیره شد')
            : ElevatedButton(
                onPressed: _open,
                child: const Text('باز کردن تنظیمات'),
              ),
      ),
    );
  }
}
