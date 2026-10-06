import 'package:fale_hafez/config.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/util/persian_text.dart';
import 'package:flutter/material.dart';

/// صفحهٔ معرفی حافظ و اپلیکیشن
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const Color _gold = Color(0xFFE1B968);
  static const Color _cream = Color(0xFFFFF5DF);
  static const Color _mutedCream = Color(0xFFEAD9B8);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width < 370 ? 12.0 : 18.0;
    final iconSize = (size.width * 0.29).clamp(104.0, 136.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF1B100D),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background/homebg.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99150B08),
                    Color(0xCC24120D),
                    Color(0xF21A0D0A),
                  ],
                  stops: [0, 0.38, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scrollbar(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    22,
                    horizontalPadding,
                    28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: _gold.withOpacity(0.72),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: _gold.withOpacity(0.14),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(27),
                              child: Image.asset(
                                'assets/appicon.png',
                                width: iconSize,
                                height: iconSize,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'معرفی حافظ و اپلیکیشن',
                            textAlign: TextAlign.center,
                            style: vazirText(
                              color: _gold,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: size.width < 370 ? 16 : 24,
                              vertical: 26,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xD9361E17),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: _gold.withOpacity(0.42),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.34),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _OpeningQuote(),
                                SizedBox(height: 22),
                                _WelcomeTitle(),
                                SizedBox(height: 16),
                                _BodyParagraph(
                                  text:
                                      'خواجه شمس‌الدین محمد حافظ شیرازی، بزرگ‌ترین غزل‌سرای ادب پارسی و راوی اسرار دلدادگی و معرفت است. کلام حافظ همواره آیینه‌ای برای بازتاب احوال درون انسان‌ها بوده؛ از همین روست که قرن‌هاست دلدادگان در لحظه‌های تردید، امید و عاشقی، به دیوان او تفأل می‌زنند.',
                                ),
                                SizedBox(height: 12),
                                _BodyParagraph(
                                  text:
                                      'این اپلیکیشن با هدف ارائه یک مرجع کامل، دقیق و زیبا از آثار این شاعر بزرگ طراحی شده است تا همراهِ همیشگی خلوت‌ها و تفأل‌های شما باشد.',
                                ),
                                SizedBox(height: 24),
                                _SectionTitle(
                                  icon: Icons.auto_stories_rounded,
                                  text: 'محتوای این اپلیکیشن شامل:',
                                ),
                                SizedBox(height: 15),
                                _FeatureItem(
                                  icon: Icons.menu_book_rounded,
                                  title: 'متن کامل غزلیات',
                                  detail: 'به همراه تعبیر و فال‌نامه',
                                ),
                                _FeatureItem(
                                  icon: Icons.history_edu_rounded,
                                  title: 'رباعیات و دوبیتی‌ها',
                                ),
                                _FeatureItem(
                                  icon: Icons.draw_rounded,
                                  title: 'قطعات و قصاید',
                                ),
                                _FeatureItem(
                                  icon: Icons.music_note_rounded,
                                  title: 'مثنویات',
                                  detail: 'ساقی‌نامه و مغنی‌نامه',
                                ),
                                _FeatureItem(
                                  icon: Icons.manage_search_rounded,
                                  title: 'اشعار منتسب به حافظ',
                                  showDivider: false,
                                ),
                                SizedBox(height: 20),
                                _ClosingWish(),
                                SizedBox(height: 27),
                                _OrnamentalDivider(),
                                SizedBox(height: 25),
                                _BiographyTitle(),
                                SizedBox(height: 16),
                                _BodyParagraph(
                                  text:
                                      'حافظ، «ترجمان‌الاسرار»، بزرگ‌ترین غزل‌سرای زبان فارسی و از برجسته‌ترین شاعران تمام اعصار در تاریخ ادبیات جهان است.',
                                ),
                                SizedBox(height: 12),
                                _BodyParagraph(
                                  text:
                                      'حافظ در قرن هشتم هجری در شیراز می‌زیست؛ دورانی پرآشوب که با قدرت کلام و بینش عمیق او به یکی از درخشان‌ترین دوران‌های شعر و حکمت فارسی تبدیل شد. شهرت حافظ به دلیل نبوغ بی‌نظیرش در سرایش غزل است؛ جایی که او توانست عشق زمینی، عرفان عمیق، فلسفه زیستن و نقد تند اجتماعی را در فرمی موزون، خیال‌انگیز و چندلایه تلفیق کند.',
                                ),
                                SizedBox(height: 12),
                                _EmphasizedBiographyParagraph(),
                                SizedBox(height: 12),
                                _BodyParagraph(
                                  text:
                                      'دیوان حافظ چنان در فرهنگ ایرانیان ریشه دوانده که کمتر خانه‌ای بدون آن یافت می‌شود و سنت «فال حافظ» در مناسبت‌هایی چون شب یلدا و نوروز، پیوند قلبی مردم با کلام او را نشان می‌دهد. آوازه او مرزهای ایران را نیز درنوردیده؛ تا جایی که بزرگانی چون «گوته»، شاعر نامدار آلمانی، با الهام از حافظ دیوان شرقی-غربی خود را نگاشت.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          const _StudioSignature(),
                          const SizedBox(height: 18),
                          Text(
                            'نسخه برنامه ${toPersianDigits(AppInfo.version)}',
                            textAlign: TextAlign.center,
                            style: vazirText(
                              color: _mutedCream,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpeningQuote extends StatelessWidget {
  const _OpeningQuote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AboutScreen._gold.withOpacity(0.13),
            AboutScreen._gold.withOpacity(0.035),
            AboutScreen._gold.withOpacity(0.13),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: AboutScreen._gold.withOpacity(0.48),
          ),
        ),
      ),
      child: Text(
        '«فاش می‌گویم و از گفتهٔ خود دلشادم\nبندهٔ عشقم و از هر دو جهان آزادم»',
        textAlign: TextAlign.center,
        style: vazirText(
          fontFamily: 'Tahriri',
          color: AboutScreen._cream,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          height: 1.9,
        ).copyWith(
          shadows: const [
            Shadow(
              color: Color(0xAA000000),
              blurRadius: 7,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeTitle extends StatelessWidget {
  const _WelcomeTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'به حریم کلام لسان‌الغیب، حافظ شیرازی خوش آمدید.',
      textAlign: TextAlign.center,
      style: vazirText(
        color: AboutScreen._gold,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        height: 1.8,
      ),
    );
  }
}

class _BodyParagraph extends StatelessWidget {
  const _BodyParagraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: vazirText(
        color: AboutScreen._cream,
        fontSize: 15.5,
        height: 2,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AboutScreen._gold, size: 25),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: vazirText(
              color: AboutScreen._gold,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    this.detail,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AboutScreen._gold.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AboutScreen._gold.withOpacity(0.35),
                  ),
                ),
                child: Icon(icon, color: AboutScreen._gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: vazirText(
                      color: AboutScreen._cream,
                      fontSize: 15,
                      height: 1.7,
                    ),
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (detail != null)
                        TextSpan(
                          text: '  ($detail)',
                          style: const TextStyle(
                            color: AboutScreen._mutedCream,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: AboutScreen._gold.withOpacity(0.16),
            indent: 50,
          ),
      ],
    );
  }
}

class _ClosingWish extends StatelessWidget {
  const _ClosingWish();

  @override
  Widget build(BuildContext context) {
    return Text(
      'امید است نوای جان‌بخش کلام حافظ، روشنایی‌بخش دل و جانتان باشد.',
      textAlign: TextAlign.center,
      style: vazirText(
        fontFamily: 'Tahriri',
        color: AboutScreen._cream,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.9,
      ),
    );
  }
}

class _OrnamentalDivider extends StatelessWidget {
  const _OrnamentalDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: AboutScreen._gold.withOpacity(0.46)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            Icons.local_florist_rounded,
            color: AboutScreen._gold,
            size: 24,
          ),
        ),
        Expanded(
          child: Divider(color: AboutScreen._gold.withOpacity(0.46)),
        ),
      ],
    );
  }
}

class _BiographyTitle extends StatelessWidget {
  const _BiographyTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'حافظ؛ ترجمان‌الاسرار',
      textAlign: TextAlign.center,
      style: vazirText(
        fontFamily: 'Tahriri',
        color: AboutScreen._gold,
        fontSize: 23,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmphasizedBiographyParagraph extends StatelessWidget {
  const _EmphasizedBiographyParagraph();

  @override
  Widget build(BuildContext context) {
    final baseStyle = vazirText(
      color: AboutScreen._cream,
      fontSize: 15.5,
      height: 2,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: const [
          TextSpan(text: 'از مهم‌ترین ویژگی‌های شعر حافظ، '),
          TextSpan(
            text: 'مبارزه با زهد ریایی و سالوس‌بازی',
            style: TextStyle(
              color: AboutScreen._gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text:
                '، دعوت به مدارا و انسانیت، و گرامیداشت لحظه حال («دم را غنیمت شمردن») است. شخصیت نمادین «رِند» در دیوان حافظ، تصویر انسانی است آزاده که از قید تظاهر رها شده و به گوهر ناب راستی و عشق دست یافته است.',
          ),
        ],
      ),
      textAlign: TextAlign.justify,
    );
  }
}

class _StudioSignature extends StatelessWidget {
  const _StudioSignature();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'طراحی شده در استودیو جاوید',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xB33A2118), Color(0xD91E100C)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x99E1B968)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 20,
              offset: Offset(0, 9),
            ),
            BoxShadow(
              color: Color(0x2EE1B968),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: AboutScreen._gold.withOpacity(0.36),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 9),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AboutScreen._gold,
                    size: 18,
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: AboutScreen._gold.withOpacity(0.36),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'طراحی شده در',
              textAlign: TextAlign.center,
              style: vazirText(
                fontFamily: 'Shabnam',
                color: AboutScreen._mutedCream,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 5),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFFFFF2C6),
                  Color(0xFFE1B968),
                  Color(0xFFF4D99A),
                ],
              ).createShader(bounds),
              child: Text(
                'استودیو جاوید',
                textAlign: TextAlign.center,
                style: vazirText(
                  fontFamily: 'Sahel',
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w700,
                ).copyWith(
                  shadows: const [
                    Shadow(
                      color: Color(0xCC000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                    Shadow(
                      color: Color(0x88E1B968),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
