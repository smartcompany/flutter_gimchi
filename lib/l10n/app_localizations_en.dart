// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get usdt => 'USDT';

  @override
  String get exchangeRate => 'Exchange Rate';

  @override
  String get gimchiPremiem => 'KR Premiem';

  @override
  String get cancel => 'Cancel';

  @override
  String get changeStrategy => 'Change strategy';

  @override
  String get close => 'Close';

  @override
  String get failedToSaveAlarm => 'Failed to save alarm setting';

  @override
  String get failedToload => 'Failed to load';

  @override
  String get loadingFail => 'Loading failed';

  @override
  String get moveToSetting => 'Go to settings';

  @override
  String get needPermission => 'Permission required';

  @override
  String get no => 'No';

  @override
  String get seeAdsAndStrategy => 'Watch ad to view strategy';

  @override
  String get throwTestException => 'Throw Test Exception';

  @override
  String get throw_test_exception => 'Throw Test Exception';

  @override
  String get usdtSignal => 'USDT Signal';

  @override
  String get usdt_signal => 'USDT Signal';

  @override
  String get buyWin => 'It is currently a favorable time to buy';

  @override
  String get sellWin => 'It is currently a favorable time to sell';

  @override
  String get justSee => 'It is currently a wait-and-see period';

  @override
  String get aiStrategy => 'AI Strategy';

  @override
  String get gimchiStrategy => 'KR Premiem Strategy';

  @override
  String get buy => 'Buy';

  @override
  String get sell => 'Sell';

  @override
  String get gain => 'Gain';

  @override
  String get runSimulation => 'Run simulation';

  @override
  String get seeStrategy => 'View strategy';

  @override
  String get aiTradingSimulation =>
      'AI Trading Simulation (based on 1 million KRW)';

  @override
  String get gimchTradingSimulation =>
      'KR Premium Trading Simulation (based on 1 million KRW)';

  @override
  String get finalKRW => 'Final KRW';

  @override
  String get tradingPerioid => 'Trading Period';

  @override
  String get stackedFinalKRW => 'Accumulated Final KRW';

  @override
  String get totalGain => 'Total Rate of Return';

  @override
  String get extimatedYearGain => 'Estimated Annual Return';

  @override
  String get chartTrendAnalysis => 'Chart Trend Analysis';

  @override
  String get aiSell => 'AI Sell';

  @override
  String get kimchiPremiumSell => 'Kimchi Premium Sell';

  @override
  String get aiBuy => 'AI Buy';

  @override
  String get kimchiPremiumBuy => 'Kimchi Premium Buy';

  @override
  String changeFromPreviousDay(Object change) {
    return 'Change from previous day: $change%';
  }

  @override
  String get kimchiPremiumPercent => 'Kimchi Premium (%)';

  @override
  String get resetChart => 'Reset Chart';

  @override
  String get backToPreviousChart => 'Previous Chart';

  @override
  String get kimchiPremium => 'Kimchi Premium';

  @override
  String get aiBuySell => 'AI Buy/Sell';

  @override
  String get kimchiPremiumBuySell => 'Kimchi Premium Buy/Sell';

  @override
  String get kimchiPremiumBackground => 'Kimchi Premium Background';

  @override
  String get kimchiPremiumBackgroundDescriptionTooltip =>
      'Explanation of Kimchi Premium Background';

  @override
  String get whatIsKimchiPremiumBackground =>
      'What is the Kimchi Premium Background?';

  @override
  String get kimchiPremiumBackgroundDescription =>
      'The background color of the chart changes depending on the Kimchi Premium value. The higher the premium, the redder it becomes; the lower the premium, the bluer it becomes. This allows you to visually assess buy/sell timing based on the Kimchi Premium. It helps you grasp the volatility at a glance.';

  @override
  String get confirm => 'Confirm';

  @override
  String get chatRoom => 'Chat Room';

  @override
  String get gimchBaseTrade => 'KR Premiem Base Trade';

  @override
  String get aiBaseTrade => 'AI Base Trade';

  @override
  String get seeWithChart => 'View with Chart';

  @override
  String get buyBase => 'Buy Threshold (%)';

  @override
  String get sellBase => 'Sell Threshold (%)';

  @override
  String get sameAsAI => 'Apply same schedule as AI';

  @override
  String get failedToSaveSettings => 'Failed to save settings.';

  @override
  String get strategy => 'Strategy';

  @override
  String get buyPrice => 'Buy Price';

  @override
  String get sellPrice => 'Sell Price';

  @override
  String get expectedGain => 'Expected Return';

  @override
  String get summary => 'Summary';

  @override
  String kimchiStrategyComment(double buyThreshold, double sellThreshold) {
    return 'Buy when the Kimchi Premium is below $buyThreshold%, and sell when it is above $sellThreshold%.';
  }

  @override
  String get sellIfCurrentPrice => 'Sell if current price';
}
