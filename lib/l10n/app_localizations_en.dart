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
  String get xrpFundingRateTitle => 'XRP Funding (Y)';

  @override
  String fundingRateInterval(Object hours) {
    return '(${hours}h)';
  }

  @override
  String get fundingRateSourceBinance => 'Binance';

  @override
  String get fundingRateSourceBybit => 'Bybit';

  @override
  String get fundingRateLoading => 'Loading funding rate...';

  @override
  String get fundingRateFailed => 'Failed to load funding rate';

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
  String get permissionRequiredMessage =>
      'To receive notifications, you need to allow notification permissions in device settings.\nWould you like to go to settings?';

  @override
  String get no => 'No';

  @override
  String get yes => 'Yes';

  @override
  String get useTrendBasedStrategy => 'Use trend-based strategy';

  @override
  String get error => 'Error';

  @override
  String get dash => '-';

  @override
  String get kimchiStrategy => 'K-Premium Strategy';

  @override
  String get viewAllStrategyHistory => 'View History';

  @override
  String get kimchiStrategyHistory => 'K-Premium History';

  @override
  String get aiStrategyHistory => 'AI History';

  @override
  String get strategy => 'Strategy';

  @override
  String get noStrategyData => 'No strategy data available';

  @override
  String get seeAdsAndStrategy => 'Watch ad to view strategy';

  @override
  String get todayStrategyAfterAds => 'Watch Ad & View Strategy';

  @override
  String get todayStrategyDirect => 'View Strategy Now';

  @override
  String get aiReturn => 'AI ROI';

  @override
  String get gimchiReturn => 'K-Premium ROI';

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
  String get currencyWonSuffix => ' KRW';

  @override
  String get totalGain => 'Total Gain';

  @override
  String get extimatedYearGain => 'Est. %/yr';

  @override
  String get annualYieldDescription =>
      'Estimated annual yield is the current trading performance converted to an annualized rate using compound interest.\n\nFor example, if you earned 5% over 6 months, this would be approximately 10.25% when annualized.';

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
  String get kimchiStartDate => 'Start date';

  @override
  String get kimchiEndDate => 'End date';

  @override
  String get kimchiResetDateRange => 'Full period';

  @override
  String get failedToSaveSettings => 'Failed to save settings.';

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
  String get strategySummaryEmpty => 'No strategy summary available.';

  @override
  String get sellIfCurrentPrice => 'Sell if current price';

  @override
  String get onboardingTitle1 => 'The Hidden Price Difference of USDT';

  @override
  String get onboardingBody1 =>
      'While 1 USDT = 1 USD overseas, Korean exchanges show different prices due to exchange rates and \'K-Premium\'. Understanding this difference can help you profit.';

  @override
  String get onboardingImageDesc1 =>
      'Korean USDT Price = Exchange Rate + K-Premium';

  @override
  String get onboardingTitle2 => 'Profiting from K-Premium';

  @override
  String get onboardingBody2 =>
      'When USDT trades higher in Korea than abroad (K-Premium), selling can be profitable. Our app analyzes K-Premium and exchange rates in real-time to find the best buy/sell timing.';

  @override
  String get onboardingImageDesc2 =>
      'Buy Low → Sell When Premium is High → Profit';

  @override
  String get onboardingTitle3 => 'Two Strategies: AI and K-Premium';

  @override
  String get onboardingBody3 =>
      'Choose between AI-analyzed trading strategies or K-Premium-based strategies for notifications. View real-time charts at a glance and compare each strategy\'s historical returns.';

  @override
  String get onboardingImageDesc3 =>
      'AI Strategy Alerts + K-Premium Strategy Alerts';

  @override
  String get onboardingTitle4 => 'Verified Returns with Past Data';

  @override
  String get onboardingBody4 =>
      'What if you started with ₩1,000,000? Simulate returns for each strategy using actual past data and compare which method works better.';

  @override
  String get onboardingImageDesc4 =>
      'AI Returns vs K-Premium Returns Comparison';

  @override
  String get previous => 'Previous';

  @override
  String get start => 'Get Started';

  @override
  String get next => 'Next';

  @override
  String get selectReceiveAlert => 'Select alert to receive';

  @override
  String get selectReceiveAlertSubtitle =>
      'Choose the type of notification to receive';

  @override
  String get aIalert => 'AI Alert';

  @override
  String get aIalertDescription =>
      'Receive notifications for AI-analyzed trading strategies';

  @override
  String get gimpAlert => 'K-Premium Alert';

  @override
  String get gimpAlertDescription =>
      'Receive notifications for K-Premium based trading strategies';

  @override
  String get turnOffAlert => 'Turn off alert';

  @override
  String get unFilled => 'Unfilled';

  @override
  String get coinInfoSite => 'Coin Info Site';

  @override
  String get adClickInstruction => 'Click X to check buy/sell signals';

  @override
  String get removeAdsCta => 'Ad-Free View';

  @override
  String get removeAdsTitle => 'View Without Ads';

  @override
  String get removeAdsSubtitle =>
      'See the trading strategy with zero distractions.';

  @override
  String get removeAdsDescription =>
      'After payment, you can view trading strategies immediately without watching ads.';

  @override
  String get purchaseButton => 'Purchase';

  @override
  String get restoreButton => 'Restore Purchases';

  @override
  String get restoreSuccess => 'Success';

  @override
  String get restoreNoPurchases => 'No purchases to restore';

  @override
  String get adLoadingMessage => 'Loading ad. Please try again later.';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms';

  @override
  String get nextBuyPoint => 'Next Buy Point';

  @override
  String get nextSellPoint => 'Next Sell Point';

  @override
  String get priceLabel => 'Price';

  @override
  String get basePremium => 'Base Premium';

  @override
  String get kimchiPremiumShort => 'K-Prem';

  @override
  String get tradeTimeline => 'Trade Timeline';

  @override
  String get performanceMetrics => 'Performance Metrics';

  @override
  String get initialCapital => 'Initial: ₩1,000,000';

  @override
  String get finalValue => 'Final Value';

  @override
  String get aiSimulatedTradeTitle => 'AI Simulated Trade';

  @override
  String get kimchiSimulatedTradeTitle => 'K-Premium Simulated Trade';

  @override
  String get profitRate => 'Profit Rate';

  @override
  String get evaluationAmount => 'Evaluation Amount';

  @override
  String get fee => 'Fee';

  @override
  String upbitFeeApplied(double buyFee, double sellFee) {
    return 'Upbit fee applied (Buy $buyFee%, Sell $sellFee%)';
  }

  @override
  String feeWithAmount(String amount) {
    return 'Fee: ₩$amount';
  }
}
