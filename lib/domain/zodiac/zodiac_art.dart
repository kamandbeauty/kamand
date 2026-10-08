import 'domain/zodiac/zodiac_sign.dart';

/// ASTRAL COSMOS artwork mapping (central, phase-7 of the design brief).
///
/// Every sign's hero art lives at one predictable path; the My-Sign
/// header, share sheets and any future surface resolve through here so
/// the mapping is never duplicated across screens.
String zodiacArtAsset(String signId) =>
    'assets/zodiac_art/$signId.webp';

/// Convenience for a resolved [ZodiacSign].
String zodiacArtFor(ZodiacSign sign) => zodiacArtAsset(sign.id);
