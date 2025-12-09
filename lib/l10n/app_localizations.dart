import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';
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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ko'),
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @usdt.
  ///
  /// In ko, this message translates to:
  /// **'테더'**
  String get usdt;

  /// No description provided for @exchangeRate.
  ///
  /// In ko, this message translates to:
  /// **'환율'**
  String get exchangeRate;

  /// No description provided for @gimchiPremiem.
  ///
  /// In ko, this message translates to:
  /// **'김치 프리미엄'**
  String get gimchiPremiem;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @changeStrategy.
  ///
  /// In ko, this message translates to:
  /// **'김프 전략 변경'**
  String get changeStrategy;

  /// No description provided for @close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get close;

  /// No description provided for @failedToSaveAlarm.
  ///
  /// In ko, this message translates to:
  /// **'알림 설정을 저장하는데 실패했습니다.'**
  String get failedToSaveAlarm;

  /// No description provided for @failedToload.
  ///
  /// In ko, this message translates to:
  /// **'데이터를 불러오는데 실패했습니다.\n다시 시도하시겠습니까?'**
  String get failedToload;

  /// No description provided for @loadingFail.
  ///
  /// In ko, this message translates to:
  /// **'불러오기 실패'**
  String get loadingFail;

  /// No description provided for @moveToSetting.
  ///
  /// In ko, this message translates to:
  /// **'설정으로 이동'**
  String get moveToSetting;

  /// No description provided for @needPermission.
  ///
  /// In ko, this message translates to:
  /// **'알림 권한 필요'**
  String get needPermission;

  /// No description provided for @permissionRequiredMessage.
  ///
  /// In ko, this message translates to:
  /// **'알림을 받으려면 기기 설정에서 알림 권한을 허용해야 합니다.\n설정으로 이동하시겠습니까?'**
  String get permissionRequiredMessage;

  /// No description provided for @no.
  ///
  /// In ko, this message translates to:
  /// **'아니오'**
  String get no;

  /// No description provided for @yes.
  ///
  /// In ko, this message translates to:
  /// **'예'**
  String get yes;

  /// No description provided for @useTrendBasedStrategy.
  ///
  /// In ko, this message translates to:
  /// **'추세 기반 전략 사용'**
  String get useTrendBasedStrategy;

  /// No description provided for @error.
  ///
  /// In ko, this message translates to:
  /// **'에러'**
  String get error;

  /// No description provided for @dash.
  ///
  /// In ko, this message translates to:
  /// **'-'**
  String get dash;

  /// No description provided for @kimchiStrategy.
  ///
  /// In ko, this message translates to:
  /// **'김프 전략'**
  String get kimchiStrategy;

  /// No description provided for @viewAllStrategyHistory.
  ///
  /// In ko, this message translates to:
  /// **'전체 전략 히스토리 보기'**
  String get viewAllStrategyHistory;

  /// No description provided for @kimchiStrategyHistory.
  ///
  /// In ko, this message translates to:
  /// **'김프 매매 전략 히스토리'**
  String get kimchiStrategyHistory;

  /// No description provided for @aiStrategyHistory.
  ///
  /// In ko, this message translates to:
  /// **'AI 매매 전략 히스토리'**
  String get aiStrategyHistory;

  /// No description provided for @strategy.
  ///
  /// In ko, this message translates to:
  /// **'전략'**
  String get strategy;

  /// No description provided for @noStrategyData.
  ///
  /// In ko, this message translates to:
  /// **'전략 데이터가 없습니다'**
  String get noStrategyData;

  /// No description provided for @seeAdsAndStrategy.
  ///
  /// In ko, this message translates to:
  /// **'광고 보고 매매 전략 보기'**
  String get seeAdsAndStrategy;

  /// No description provided for @todayStrategyAfterAds.
  ///
  /// In ko, this message translates to:
  /// **'광고 보고 매매 전략 보기'**
  String get todayStrategyAfterAds;

  /// No description provided for @todayStrategyDirect.
  ///
  /// In ko, this message translates to:
  /// **'바로 전략 보기'**
  String get todayStrategyDirect;

  /// No description provided for @aiReturn.
  ///
  /// In ko, this message translates to:
  /// **'AI 매매 수익률'**
  String get aiReturn;

  /// No description provided for @gimchiReturn.
  ///
  /// In ko, this message translates to:
  /// **'김프 매매 수익률'**
  String get gimchiReturn;

  /// No description provided for @throwTestException.
  ///
  /// In ko, this message translates to:
  /// **'throwTestException'**
  String get throwTestException;

  /// No description provided for @throw_test_exception.
  ///
  /// In ko, this message translates to:
  /// **'테스트 예외 발생'**
  String get throw_test_exception;

  /// No description provided for @usdtSignal.
  ///
  /// In ko, this message translates to:
  /// **'테더 시그널'**
  String get usdtSignal;

  /// No description provided for @usdt_signal.
  ///
  /// In ko, this message translates to:
  /// **'테더 매매 알리미'**
  String get usdt_signal;

  /// No description provided for @buyWin.
  ///
  /// In ko, this message translates to:
  /// **'현재 매수 구간입니다'**
  String get buyWin;

  /// No description provided for @sellWin.
  ///
  /// In ko, this message translates to:
  /// **'현재 매도 구간입니다'**
  String get sellWin;

  /// No description provided for @justSee.
  ///
  /// In ko, this message translates to:
  /// **'현재 관망 구간입니다'**
  String get justSee;

  /// No description provided for @aiStrategy.
  ///
  /// In ko, this message translates to:
  /// **'AI 매매 전략'**
  String get aiStrategy;

  /// No description provided for @gimchiStrategy.
  ///
  /// In ko, this message translates to:
  /// **'김프 매매 전략'**
  String get gimchiStrategy;

  /// No description provided for @buy.
  ///
  /// In ko, this message translates to:
  /// **'매수'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In ko, this message translates to:
  /// **'매도'**
  String get sell;

  /// No description provided for @gain.
  ///
  /// In ko, this message translates to:
  /// **'수익률'**
  String get gain;

  /// No description provided for @runSimulation.
  ///
  /// In ko, this message translates to:
  /// **'수익률 시뮬레이션'**
  String get runSimulation;

  /// No description provided for @seeStrategy.
  ///
  /// In ko, this message translates to:
  /// **'전략 보기'**
  String get seeStrategy;

  /// No description provided for @aiTradingSimulation.
  ///
  /// In ko, this message translates to:
  /// **'AI 매매 시뮬레이션 (100 만원 기준)'**
  String get aiTradingSimulation;

  /// No description provided for @gimchTradingSimulation.
  ///
  /// In ko, this message translates to:
  /// **'김프 매매 시뮬레이션 (100 만원 기준)'**
  String get gimchTradingSimulation;

  /// No description provided for @finalKRW.
  ///
  /// In ko, this message translates to:
  /// **'최종원화'**
  String get finalKRW;

  /// No description provided for @tradingPerioid.
  ///
  /// In ko, this message translates to:
  /// **'매매기간'**
  String get tradingPerioid;

  /// No description provided for @stackedFinalKRW.
  ///
  /// In ko, this message translates to:
  /// **'누적 최종 원화'**
  String get stackedFinalKRW;

  /// No description provided for @currencyWonSuffix.
  ///
  /// In ko, this message translates to:
  /// **'원'**
  String get currencyWonSuffix;

  /// No description provided for @totalGain.
  ///
  /// In ko, this message translates to:
  /// **'총 수익률'**
  String get totalGain;

  /// No description provided for @extimatedYearGain.
  ///
  /// In ko, this message translates to:
  /// **'추정 연 수익률'**
  String get extimatedYearGain;

  /// No description provided for @annualYieldDescription.
  ///
  /// In ko, this message translates to:
  /// **'추정 연 수익률은 현재 매매 내역의 수익률을 복리 기준으로 1년치로 환산한 값입니다.\n\n예를 들어, 6개월 동안 5%의 수익률을 얻었다면, 이를 1년 기준으로 환산하면 약 10.25%의 연 수익률이 됩니다.'**
  String get annualYieldDescription;

  /// No description provided for @chartTrendAnalysis.
  ///
  /// In ko, this message translates to:
  /// **'차트 추세 분석'**
  String get chartTrendAnalysis;

  /// No description provided for @aiSell.
  ///
  /// In ko, this message translates to:
  /// **'AI 매도'**
  String get aiSell;

  /// No description provided for @kimchiPremiumSell.
  ///
  /// In ko, this message translates to:
  /// **'김프 매도'**
  String get kimchiPremiumSell;

  /// No description provided for @aiBuy.
  ///
  /// In ko, this message translates to:
  /// **'AI 매수'**
  String get aiBuy;

  /// No description provided for @kimchiPremiumBuy.
  ///
  /// In ko, this message translates to:
  /// **'김프 매수'**
  String get kimchiPremiumBuy;

  /// No description provided for @changeFromPreviousDay.
  ///
  /// In ko, this message translates to:
  /// **'전일 대비: {change}%'**
  String changeFromPreviousDay(Object change);

  /// No description provided for @kimchiPremiumPercent.
  ///
  /// In ko, this message translates to:
  /// **'김치 프리미엄(%)'**
  String get kimchiPremiumPercent;

  /// No description provided for @resetChart.
  ///
  /// In ko, this message translates to:
  /// **'차트 리셋'**
  String get resetChart;

  /// No description provided for @backToPreviousChart.
  ///
  /// In ko, this message translates to:
  /// **'차트 이전'**
  String get backToPreviousChart;

  /// No description provided for @kimchiPremium.
  ///
  /// In ko, this message translates to:
  /// **'김치 프리미엄'**
  String get kimchiPremium;

  /// No description provided for @aiBuySell.
  ///
  /// In ko, this message translates to:
  /// **'AI 매수/매도'**
  String get aiBuySell;

  /// No description provided for @kimchiPremiumBuySell.
  ///
  /// In ko, this message translates to:
  /// **'김프 매수/매도'**
  String get kimchiPremiumBuySell;

  /// No description provided for @kimchiPremiumBackground.
  ///
  /// In ko, this message translates to:
  /// **'김치 프리미엄 배경'**
  String get kimchiPremiumBackground;

  /// No description provided for @kimchiPremiumBackgroundDescriptionTooltip.
  ///
  /// In ko, this message translates to:
  /// **'김치 프리미엄 배경 설명'**
  String get kimchiPremiumBackgroundDescriptionTooltip;

  /// No description provided for @whatIsKimchiPremiumBackground.
  ///
  /// In ko, this message translates to:
  /// **'김치 프리미엄 배경이란?'**
  String get whatIsKimchiPremiumBackground;

  /// No description provided for @kimchiPremiumBackgroundDescription.
  ///
  /// In ko, this message translates to:
  /// **'차트의 배경색은 김치 프리미엄 값에 따라 달라집니다. 프리미엄이 높을수록 빨간색, 낮을수록 파란색에 가깝게 표시되어 김치 프리미엄에 따른 매수 매도 시점을 시각적으로 파악할 수 있습니다. 이 기능은 김치 프리미엄의 변동성을 한눈에 파악하는 데 도움을 줍니다.'**
  String get kimchiPremiumBackgroundDescription;

  /// No description provided for @confirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get confirm;

  /// No description provided for @chatRoom.
  ///
  /// In ko, this message translates to:
  /// **'토론방'**
  String get chatRoom;

  /// No description provided for @gimchBaseTrade.
  ///
  /// In ko, this message translates to:
  /// **'김프 기준 매매'**
  String get gimchBaseTrade;

  /// No description provided for @aiBaseTrade.
  ///
  /// In ko, this message translates to:
  /// **'AI 전략 매매'**
  String get aiBaseTrade;

  /// No description provided for @seeWithChart.
  ///
  /// In ko, this message translates to:
  /// **'차트로 보기'**
  String get seeWithChart;

  /// No description provided for @buyBase.
  ///
  /// In ko, this message translates to:
  /// **'매수 기준(%)'**
  String get buyBase;

  /// No description provided for @sellBase.
  ///
  /// In ko, this message translates to:
  /// **'매도 기준(%)'**
  String get sellBase;

  /// No description provided for @sameAsAI.
  ///
  /// In ko, this message translates to:
  /// **'AI와 동일 일정 적용'**
  String get sameAsAI;

  /// No description provided for @failedToSaveSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정 저장에 실패했습니다.'**
  String get failedToSaveSettings;

  /// No description provided for @buyPrice.
  ///
  /// In ko, this message translates to:
  /// **'매수 가격'**
  String get buyPrice;

  /// No description provided for @sellPrice.
  ///
  /// In ko, this message translates to:
  /// **'매도 가격'**
  String get sellPrice;

  /// No description provided for @expectedGain.
  ///
  /// In ko, this message translates to:
  /// **'기대 수익률'**
  String get expectedGain;

  /// No description provided for @summary.
  ///
  /// In ko, this message translates to:
  /// **'요약'**
  String get summary;

  /// 김치 프리미엄 매수/매도 전략 설명
  ///
  /// In ko, this message translates to:
  /// **'김치 프리미엄이 {buyThreshold}% 이하일 때 매수, {sellThreshold}% 이상일 때 매도 전략입니다.'**
  String kimchiStrategyComment(double buyThreshold, double sellThreshold);

  /// No description provided for @strategySummaryEmpty.
  ///
  /// In ko, this message translates to:
  /// **'전략 요약 정보가 없습니다.'**
  String get strategySummaryEmpty;

  /// No description provided for @sellIfCurrentPrice.
  ///
  /// In ko, this message translates to:
  /// **'현재가 매도시'**
  String get sellIfCurrentPrice;

  /// No description provided for @onboardingTitle1.
  ///
  /// In ko, this message translates to:
  /// **'테더(USDT)는 단순한 달러가 아닙니다'**
  String get onboardingTitle1;

  /// No description provided for @onboardingBody1.
  ///
  /// In ko, this message translates to:
  /// **'외국에서는 1 테더(USDT)가 1 달러 이지만, 한국 거래소 에서는 환율과 가격이 달라요. 특히 한국에서는 ‘김치 프리미엄’에 따라 환율과의 가격 차이가 발생 합니다.'**
  String get onboardingBody1;

  /// No description provided for @onboardingImageDesc1.
  ///
  /// In ko, this message translates to:
  /// **'테더(USDT) ≒ 환율 + 김치 프리미엄'**
  String get onboardingImageDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In ko, this message translates to:
  /// **'높은 김치 프리미엄일 때 테더(USDT) 매도는 수익의 기회'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In ko, this message translates to:
  /// **'한국에서는 테더(USDT)가 해외보다 비싸게 거래되는 경우가 많습니다. (이걸 ‘김치 프리미엄’이라 부릅니다.) 우리 앱은 테더(USDT)의 과거 테이타를 분석해 최적의 매수/매도 시점을 찾아줍니다.'**
  String get onboardingBody2;

  /// No description provided for @onboardingImageDesc2.
  ///
  /// In ko, this message translates to:
  /// **'테더(USDT) → 저가 매수 → 고가 매도 → 안정적인 수익 구조'**
  String get onboardingImageDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In ko, this message translates to:
  /// **'매수/매도 타이밍? 우리가 알려드려요'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In ko, this message translates to:
  /// **'김치 프리미엄의 매매 기준, AI 분석을 통해 매수와 매도 시점을 알림으로 알려 줍니다. 본인의 판단에 따라 맞는 방법을 참고 하시면 됩니다.'**
  String get onboardingBody3;

  /// No description provided for @onboardingImageDesc3.
  ///
  /// In ko, this message translates to:
  /// **'실시간 테더(USDT) 가격을 확인 후 매수/매도 알림'**
  String get onboardingImageDesc3;

  /// No description provided for @onboardingTitle4.
  ///
  /// In ko, this message translates to:
  /// **'만약 100만원으로 시작했다면?'**
  String get onboardingTitle4;

  /// No description provided for @onboardingBody4.
  ///
  /// In ko, this message translates to:
  /// **'실제 과거 데이터를 기반으로, 우리 전략을 썼을 때 수익률 보여드릴게요.'**
  String get onboardingBody4;

  /// No description provided for @onboardingImageDesc4.
  ///
  /// In ko, this message translates to:
  /// **'과거 데이타를 통한 수익률 시각화'**
  String get onboardingImageDesc4;

  /// No description provided for @previous.
  ///
  /// In ko, this message translates to:
  /// **'이전'**
  String get previous;

  /// No description provided for @start.
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get start;

  /// No description provided for @next.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get next;

  /// No description provided for @selectReceiveAlert.
  ///
  /// In ko, this message translates to:
  /// **'받을 알림을 선택하세요'**
  String get selectReceiveAlert;

  /// No description provided for @aIalert.
  ///
  /// In ko, this message translates to:
  /// **'AI 분석 알림 받기'**
  String get aIalert;

  /// No description provided for @gimpAlert.
  ///
  /// In ko, this message translates to:
  /// **'김프 알림 받기'**
  String get gimpAlert;

  /// No description provided for @turnOffAlert.
  ///
  /// In ko, this message translates to:
  /// **'알림 끄기'**
  String get turnOffAlert;

  /// No description provided for @unFilled.
  ///
  /// In ko, this message translates to:
  /// **'미체결'**
  String get unFilled;

  /// No description provided for @coinInfoSite.
  ///
  /// In ko, this message translates to:
  /// **'코인 정보 사이트'**
  String get coinInfoSite;

  /// No description provided for @adClickInstruction.
  ///
  /// In ko, this message translates to:
  /// **'X 클릭 후 매수/매도 시그널 확인'**
  String get adClickInstruction;

  /// No description provided for @removeAdsCta.
  ///
  /// In ko, this message translates to:
  /// **'광고 없이 매매 전략 보기'**
  String get removeAdsCta;

  /// No description provided for @removeAdsTitle.
  ///
  /// In ko, this message translates to:
  /// **'광고 없이 보기'**
  String get removeAdsTitle;

  /// No description provided for @removeAdsSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'더 깔끔하게 매매 전략을 확인하세요.'**
  String get removeAdsSubtitle;

  /// No description provided for @removeAdsDescription.
  ///
  /// In ko, this message translates to:
  /// **'결제 후에는 광고 시청 없이 바로 매매 전략을 확인할 수 있습니다.'**
  String get removeAdsDescription;

  /// No description provided for @purchaseButton.
  ///
  /// In ko, this message translates to:
  /// **'구매하기'**
  String get purchaseButton;

  /// No description provided for @restoreButton.
  ///
  /// In ko, this message translates to:
  /// **'구매 복원'**
  String get restoreButton;

  /// No description provided for @restoreSuccess.
  ///
  /// In ko, this message translates to:
  /// **'성공'**
  String get restoreSuccess;

  /// No description provided for @restoreNoPurchases.
  ///
  /// In ko, this message translates to:
  /// **'복원할 구매 내역이 없습니다'**
  String get restoreNoPurchases;

  /// No description provided for @adLoadingMessage.
  ///
  /// In ko, this message translates to:
  /// **'광고를 불러오는 중입니다. 잠시 후 다시 시도해 주세요.'**
  String get adLoadingMessage;

  /// No description provided for @privacyPolicy.
  ///
  /// In ko, this message translates to:
  /// **'개인정보 처리 방침'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In ko, this message translates to:
  /// **'약관'**
  String get termsOfService;

  /// No description provided for @nextBuyPoint.
  ///
  /// In ko, this message translates to:
  /// **'다음 매수 시점'**
  String get nextBuyPoint;

  /// No description provided for @nextSellPoint.
  ///
  /// In ko, this message translates to:
  /// **'다음 매도 시점'**
  String get nextSellPoint;

  /// No description provided for @priceLabel.
  ///
  /// In ko, this message translates to:
  /// **'가격'**
  String get priceLabel;

  /// No description provided for @basePremium.
  ///
  /// In ko, this message translates to:
  /// **'기준 프리미엄'**
  String get basePremium;

  /// No description provided for @kimchiPremiumShort.
  ///
  /// In ko, this message translates to:
  /// **'김프'**
  String get kimchiPremiumShort;

  /// No description provided for @tradeTimeline.
  ///
  /// In ko, this message translates to:
  /// **'매매 타임라인'**
  String get tradeTimeline;

  /// No description provided for @performanceMetrics.
  ///
  /// In ko, this message translates to:
  /// **'성과 지표'**
  String get performanceMetrics;

  /// No description provided for @initialCapital.
  ///
  /// In ko, this message translates to:
  /// **'초기 자본: ₩1,000,000'**
  String get initialCapital;

  /// No description provided for @finalValue.
  ///
  /// In ko, this message translates to:
  /// **'최종 가치'**
  String get finalValue;

  /// No description provided for @aiSimulatedTradeTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 모의 투자'**
  String get aiSimulatedTradeTitle;

  /// No description provided for @kimchiSimulatedTradeTitle.
  ///
  /// In ko, this message translates to:
  /// **'김프 모의 투자'**
  String get kimchiSimulatedTradeTitle;

  /// No description provided for @profitRate.
  ///
  /// In ko, this message translates to:
  /// **'수익률'**
  String get profitRate;

  /// No description provided for @evaluationAmount.
  ///
  /// In ko, this message translates to:
  /// **'평가금액'**
  String get evaluationAmount;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
