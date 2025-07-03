import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kr'),
    Locale('zh')
  ];

  /// No description provided for @usdt.
  ///
  /// In en, this message translates to:
  /// **'USDT'**
  String get usdt;

  /// No description provided for @exchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Exchange Rate'**
  String get exchangeRate;

  /// No description provided for @gimchiPremiem.
  ///
  /// In en, this message translates to:
  /// **'KR Premiem'**
  String get gimchiPremiem;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @changeStrategy.
  ///
  /// In en, this message translates to:
  /// **'Change strategy'**
  String get changeStrategy;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @failedToSaveAlarm.
  ///
  /// In en, this message translates to:
  /// **'Failed to save alarm setting'**
  String get failedToSaveAlarm;

  /// No description provided for @failedToload.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get failedToload;

  /// No description provided for @loadingFail.
  ///
  /// In en, this message translates to:
  /// **'Loading failed'**
  String get loadingFail;

  /// No description provided for @moveToSetting.
  ///
  /// In en, this message translates to:
  /// **'Go to settings'**
  String get moveToSetting;

  /// No description provided for @needPermission.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get needPermission;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @seeAdsAndStrategy.
  ///
  /// In en, this message translates to:
  /// **'Watch ad to view strategy'**
  String get seeAdsAndStrategy;

  /// No description provided for @throwTestException.
  ///
  /// In en, this message translates to:
  /// **'Throw Test Exception'**
  String get throwTestException;

  /// No description provided for @throw_test_exception.
  ///
  /// In en, this message translates to:
  /// **'Throw Test Exception'**
  String get throw_test_exception;

  /// No description provided for @usdtSignal.
  ///
  /// In en, this message translates to:
  /// **'USDT Signal'**
  String get usdtSignal;

  /// No description provided for @usdt_signal.
  ///
  /// In en, this message translates to:
  /// **'USDT Signal'**
  String get usdt_signal;

  /// No description provided for @buyWin.
  ///
  /// In en, this message translates to:
  /// **'It is currently a favorable time to buy'**
  String get buyWin;

  /// No description provided for @sellWin.
  ///
  /// In en, this message translates to:
  /// **'It is currently a favorable time to sell'**
  String get sellWin;

  /// No description provided for @justSee.
  ///
  /// In en, this message translates to:
  /// **'It is currently a wait-and-see period'**
  String get justSee;

  /// No description provided for @aiStrategy.
  ///
  /// In en, this message translates to:
  /// **'AI Strategy'**
  String get aiStrategy;

  /// No description provided for @gimchiStrategy.
  ///
  /// In en, this message translates to:
  /// **'KR Premiem Strategy'**
  String get gimchiStrategy;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// No description provided for @gain.
  ///
  /// In en, this message translates to:
  /// **'Gain'**
  String get gain;

  /// No description provided for @runSimulation.
  ///
  /// In en, this message translates to:
  /// **'Run simulation'**
  String get runSimulation;

  /// No description provided for @seeStrategy.
  ///
  /// In en, this message translates to:
  /// **'View strategy'**
  String get seeStrategy;

  /// No description provided for @aiTradingSimulation.
  ///
  /// In en, this message translates to:
  /// **'AI Trading Simulation (based on 1 million KRW)'**
  String get aiTradingSimulation;

  /// No description provided for @gimchTradingSimulation.
  ///
  /// In en, this message translates to:
  /// **'KR Premium Trading Simulation (based on 1 million KRW)'**
  String get gimchTradingSimulation;

  /// No description provided for @finalKRW.
  ///
  /// In en, this message translates to:
  /// **'Final KRW'**
  String get finalKRW;

  /// No description provided for @tradingPerioid.
  ///
  /// In en, this message translates to:
  /// **'Trading Period'**
  String get tradingPerioid;

  /// No description provided for @stackedFinalKRW.
  ///
  /// In en, this message translates to:
  /// **'Accumulated Final KRW'**
  String get stackedFinalKRW;

  /// No description provided for @totalGain.
  ///
  /// In en, this message translates to:
  /// **'Total Rate of Return'**
  String get totalGain;

  /// No description provided for @extimatedYearGain.
  ///
  /// In en, this message translates to:
  /// **'Estimated Annual Return'**
  String get extimatedYearGain;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'kr', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'kr': return AppLocalizationsKr();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
