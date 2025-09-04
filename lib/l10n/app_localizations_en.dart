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
  String get exchangeRate => 'FX';

  @override
  String get gimchiPremiem => 'K-Premium';

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
  String get todayStrategyAfterAds =>
      'Check Today\'s Trading Strategy (After Watching Ad)';

  @override
  String get throwTestException => 'Throw Test Exception';

  @override
  String get throw_test_exception => 'Throw Test Exception';

  @override
  String get usdtSignal => 'USDT Signal';

  @override
  String get usdt_signal => 'USDT Signal';

  @override
  String get buyWin => 'Favorable time to buy';

  @override
  String get sellWin => 'Favorable time to sell';

  @override
  String get justSee => 'A wait-and-see period';

  @override
  String get aiStrategy => 'AI Strategy';

  @override
  String get gimchiStrategy => 'K-Premium Strategy';

  @override
  String get buy => 'Buy';

  @override
  String get sell => 'Sell';

  @override
  String get gain => 'Gain';

  @override
  String get runSimulation => 'Run simulation';

  @override
  String get seeStrategy => 'Strategy';

  @override
  String get aiTradingSimulation => 'AI Simulated Trade (₩1M)';

  @override
  String get gimchTradingSimulation => 'K-Premium AI Simulated Trade (₩1M)';

  @override
  String get finalKRW => 'Final KRW';

  @override
  String get tradingPerioid => 'Period';

  @override
  String get stackedFinalKRW => 'Final ₩';

  @override
  String get totalGain => 'Total Gain';

  @override
  String get extimatedYearGain => 'Est. %/yr';

  @override
  String get chartTrendAnalysis => 'Chart Trend Analysis';

  @override
  String get aiSell => 'AI Sell';

  @override
  String get kimchiPremiumSell => 'K-Premium Sell';

  @override
  String get aiBuy => 'AI Buy';

  @override
  String get kimchiPremiumBuy => 'K-Premium Buy';

  @override
  String changeFromPreviousDay(Object change) {
    return 'D-1: $change%';
  }

  @override
  String get kimchiPremiumPercent => 'K-Premium (%)';

  @override
  String get resetChart => 'Reset Chart';

  @override
  String get backToPreviousChart => 'Previous Chart';

  @override
  String get kimchiPremium => 'K-Premium';

  @override
  String get aiBuySell => 'AI Buy/Sell';

  @override
  String get kimchiPremiumBuySell => 'K-Premium Buy/Sell';

  @override
  String get kimchiPremiumBackground => 'K-Premium Background';

  @override
  String get kimchiPremiumBackgroundDescriptionTooltip => 'K-Premium Explained';

  @override
  String get whatIsKimchiPremiumBackground =>
      'What is the K-Premium Background?';

  @override
  String get kimchiPremiumBackgroundDescription =>
      'The background color of the chart changes depending on the K-Premium value. The higher the premium, the redder it becomes; the lower the premium, the bluer it becomes. This allows you to visually assess buy/sell timing based on the K-Premium. It helps you grasp the volatility at a glance.';

  @override
  String get confirm => 'Confirm';

  @override
  String get chatRoom => 'Chat Room';

  @override
  String get gimchBaseTrade => 'K-Premium Base Trade';

  @override
  String get aiBaseTrade => 'AI Base Trade';

  @override
  String get seeWithChart => 'Show Chart';

  @override
  String get buyBase => 'Buy Threshold (%)';

  @override
  String get sellBase => 'Sell Threshold (%)';

  @override
  String get sameAsAI => 'Use AI Schedule';

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
    return 'Buy when the K-Premium is below $buyThreshold%, and sell when it is above $sellThreshold%.';
  }

  @override
  String get sellIfCurrentPrice => 'Sell if current price';

  @override
  String get onboardingTitle1 => 'USDT is not just a dollar';

  @override
  String get onboardingBody1 =>
      '1 USDT ≈ 1 USD, but the actual price varies depending on the exchange, market price, and exchange rate. Especially in Korea, price differences often occur due to the \'Kimchi Premium\' and \'exchange rate differences\'.';

  @override
  String get onboardingImageDesc1 => 'USDT vs. Kimchi Premium comparison graph';

  @override
  String get onboardingTitle2 =>
      'Kimchi Premium + Exchange Rate Difference = Opportunity for Profit';

  @override
  String get onboardingBody2 =>
      'In Korea, USDT is often traded at a higher price than abroad (this is called the \'Kimchi Premium\'). When you also consider the exchange rate, the price difference can be even greater. Our app\'s AI analyzes the Kimchi Premium and exchange rate to find the optimal buying/selling points.';

  @override
  String get onboardingImageDesc2 =>
      'USDT → Buy Low → Sell High → Stable Profit Structure';

  @override
  String get onboardingTitle3 => 'Buy/Sell Timing? We\'ll let you know';

  @override
  String get onboardingBody3 =>
      'Our AI analyzes the Kimchi Premium, exchange rate, and overseas market prices in real-time to give you signals like \'Buy Now / Sell Now\'.';

  @override
  String get onboardingImageDesc3 =>
      'Example of actual app screen capture (Buy signal notification)';

  @override
  String get onboardingTitle4 => 'What if you started with ₩1,000,000?';

  @override
  String get onboardingBody4 =>
      'Based on actual past data, we\'ll show you the rate of return you would have achieved using our strategy.';

  @override
  String get onboardingImageDesc4 => 'Asset change visualization by date';

  @override
  String get previous => 'Previous';

  @override
  String get start => 'Get Started';

  @override
  String get next => 'Next';

  @override
  String get selectReceiveAlert => 'Select alert to receive';

  @override
  String get aIalert => 'AI Alert';

  @override
  String get gimpAlert => 'K-Premium Alert';

  @override
  String get turnOffAlert => 'Turn off alert';

  @override
  String get unFilled => 'Unfilled';

  @override
  String get coinInfoSite => 'Coin Info Site';
}
