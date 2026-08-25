// Minimal in-app localization for Anime Road Runner.
//
// Deliberately does NOT depend on `flutter_localizations` / `intl`: the UI
// here is a couple dozen short strings, not a document-heavy app, so a plain
// string table plus a `Directionality` override is enough to get real
// Arabic support (including RTL layout) without adding a dependency the
// project doesn't otherwise need.
import 'package:flutter/material.dart';

enum AppLanguage { en, ar }

/// Global language state. A single `ValueNotifier` so any widget in the tree
/// (menus, HUD, settings) can listen and rebuild on change, and so the choice
/// can be persisted the same way volume/quality already are (see
/// `_loadLanguage`/`_saveLanguage` in `game_state.dart`).
class AppStrings {
  AppStrings._();

  static final ValueNotifier<AppLanguage> language =
      ValueNotifier<AppLanguage>(_systemDefault());

  static AppLanguage _systemDefault() {
    // Best-effort first-run guess from the device locale; overridden the
    // moment a stored preference is loaded (see _loadLanguage).
    final String code =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == 'ar' ? AppLanguage.ar : AppLanguage.en;
  }

  static TextDirection get direction => language.value == AppLanguage.ar
      ? TextDirection.rtl
      : TextDirection.ltr;

  static Locale get locale =>
      Locale(language.value == AppLanguage.ar ? 'ar' : 'en');

  static String t(String key) {
    final Map<String, String> table =
        language.value == AppLanguage.ar ? _ar : _en;
    return table[key] ?? _en[key] ?? key;
  }

  static const Map<String, String> _en = <String, String>{
    'app_name': 'Anime Road Runner',
    'tagline': '3D endless runner · built on Flutter GPU',
    'play': 'PLAY',
    'tap_to_play': 'tap  or  Space  to play',
    'best_scores': 'BEST SCORES',
    'no_scores': 'no scores yet — be the first!',
    'crashed': 'CRASHED',
    'new_best': '★  NEW BEST',
    'new_best_bang': '★  NEW BEST!',
    'best_label': 'BEST',
    'score_best_line': 'Score  %s      Best  %s',
    'enter_name': 'new best score — enter your name',
    'name_hint': 'YOU',
    'save': 'SAVE',
    'play_again': 'PLAY AGAIN',
    'menu': 'MENU',
    'share_score': 'SHARE SCORE',
    'hint_keys': 'Space  play again    ·    M  menu',
    'hint_controls': 'swipe or arrows to move  ·  swipe up / Space to jump',
    'got_place': 'You got %s place!',
    'settings': 'Settings',
    'language': 'Language',
    'sound_effects': 'Sound Effects',
    'render_quality': 'Render Quality',
    'off': 'Off',
    'low': 'Low',
    'high': 'High',
    'close': 'Close',
    'quality_high': 'HIGH',
    'quality_balanced': 'BALANCED',
    'quality_fast': 'FAST',
    'world_load_warning': 'Some assets failed to load — try restarting',
    'boot_initializing': 'Initializing 3D engine',
    'boot_still_working': 'Still working — first launch can take a bit longer',
    'boot_taking_long':
        'Taking longer than usual. If this device struggles to continue, an option to retry will appear shortly.',
  };

  static const Map<String, String> _ar = <String, String>{
    'app_name': 'انيمي رود رانر',
    'tagline': 'لعبة جري لا نهائية ثلاثية الأبعاد · مبنية على Flutter GPU',
    'play': 'ابدأ اللعب',
    'tap_to_play': 'اضغط أو مسافة للعب',
    'best_scores': 'أفضل النتائج',
    'no_scores': 'لا توجد نتائج بعد — كن أول من يسجل!',
    'crashed': 'اصطدمت',
    'new_best': '★  رقم قياسي جديد',
    'new_best_bang': '★  رقم قياسي جديد!',
    'best_label': 'الأفضل',
    'score_best_line': 'النتيجة  %s      الأفضل  %s',
    'enter_name': 'رقم قياسي جديد — أدخل اسمك',
    'name_hint': 'أنت',
    'save': 'حفظ',
    'play_again': 'العب مجددًا',
    'menu': 'القائمة',
    'share_score': 'مشاركة النتيجة',
    'hint_keys': 'مسافة للعب مجددًا    ·    M للقائمة',
    'hint_controls': 'اسحب أو استخدم الأسهم للتحرك  ·  اسحب لأعلى / مسافة للقفز',
    'got_place': 'حصلت على المركز %s!',
    'settings': 'الإعدادات',
    'language': 'اللغة',
    'sound_effects': 'المؤثرات الصوتية',
    'render_quality': 'جودة العرض',
    'off': 'صامت',
    'low': 'منخفض',
    'high': 'عالي',
    'close': 'إغلاق',
    'quality_high': 'عالية',
    'quality_balanced': 'متوازنة',
    'quality_fast': 'سريعة',
    'world_load_warning': 'فشل تحميل بعض الموارد — حاول إعادة التشغيل',
    'boot_initializing': 'جارٍ تهيئة محرك الرسوميات ثلاثي الأبعاد',
    'boot_still_working': 'لا يزال العمل جاريًا — أول تشغيل قد يستغرق وقتًا أطول قليلًا',
    'boot_taking_long':
        'الأمر يستغرق وقتًا أطول من المعتاد. إن استمر التحميل، سيظهر خيار إعادة المحاولة قريبًا.',
  };
}
