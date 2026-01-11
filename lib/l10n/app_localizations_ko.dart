// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get usdt => '테더';

  @override
  String get exchangeRate => '환율';

  @override
  String get gimchiPremiem => '김치 프리미엄';

  @override
  String get cancel => '취소';

  @override
  String get changeStrategy => '김프 전략 변경';

  @override
  String get close => '닫기';

  @override
  String get failedToSaveAlarm => '알림 설정을 저장하는데 실패했습니다.';

  @override
  String get failedToload => '데이터를 불러오는데 실패했습니다.\n다시 시도하시겠습니까?';

  @override
  String get loadingFail => '불러오기 실패';

  @override
  String get moveToSetting => '설정으로 이동';

  @override
  String get needPermission => '알림 권한 필요';

  @override
  String get permissionRequiredMessage =>
      '알림을 받으려면 기기 설정에서 알림 권한을 허용해야 합니다.\n설정으로 이동하시겠습니까?';

  @override
  String get no => '아니오';

  @override
  String get yes => '예';

  @override
  String get useTrendBasedStrategy => '추세 기반 전략 사용';

  @override
  String get error => '에러';

  @override
  String get dash => '-';

  @override
  String get kimchiStrategy => '김프 전략';

  @override
  String get viewAllStrategyHistory => '전체 전략 히스토리 보기';

  @override
  String get kimchiStrategyHistory => '김프 매매 전략 히스토리';

  @override
  String get aiStrategyHistory => 'AI 매매 전략 히스토리';

  @override
  String get strategy => '전략';

  @override
  String get noStrategyData => '전략 데이터가 없습니다';

  @override
  String get seeAdsAndStrategy => '광고 보고 매매 전략 보기';

  @override
  String get todayStrategyAfterAds => '광고 보고 매매 전략 보기';

  @override
  String get todayStrategyDirect => '바로 전략 보기';

  @override
  String get aiReturn => 'AI 매매 수익률';

  @override
  String get gimchiReturn => '김프 매매 수익률';

  @override
  String get throwTestException => 'throwTestException';

  @override
  String get throw_test_exception => '테스트 예외 발생';

  @override
  String get usdtSignal => '테더 시그널';

  @override
  String get usdt_signal => '테더 매매 알리미';

  @override
  String get buyWin => '현재 매수 구간입니다';

  @override
  String get sellWin => '현재 매도 구간입니다';

  @override
  String get justSee => '현재 관망 구간입니다';

  @override
  String get aiStrategy => 'AI 매매 전략';

  @override
  String get gimchiStrategy => '김프 매매 전략';

  @override
  String get buy => '매수';

  @override
  String get sell => '매도';

  @override
  String get gain => '수익률';

  @override
  String get runSimulation => '수익률 시뮬레이션';

  @override
  String get seeStrategy => '전략 보기';

  @override
  String get aiTradingSimulation => 'AI 매매 시뮬레이션 (100 만원 기준)';

  @override
  String get gimchTradingSimulation => '김프 매매 시뮬레이션 (100 만원 기준)';

  @override
  String get finalKRW => '최종원화';

  @override
  String get tradingPerioid => '매매기간';

  @override
  String get stackedFinalKRW => '누적 최종 원화';

  @override
  String get currencyWonSuffix => '원';

  @override
  String get totalGain => '총 수익률';

  @override
  String get extimatedYearGain => '추정 연 수익률';

  @override
  String get annualYieldDescription =>
      '추정 연 수익률은 현재 매매 내역의 수익률을 복리 기준으로 1년치로 환산한 값입니다.\n\n예를 들어, 6개월 동안 5%의 수익률을 얻었다면, 이를 1년 기준으로 환산하면 약 10.25%의 연 수익률이 됩니다.';

  @override
  String get chartTrendAnalysis => '차트 추세 분석';

  @override
  String get aiSell => 'AI 매도';

  @override
  String get kimchiPremiumSell => '김프 매도';

  @override
  String get aiBuy => 'AI 매수';

  @override
  String get kimchiPremiumBuy => '김프 매수';

  @override
  String changeFromPreviousDay(Object change) {
    return '전일 대비: $change%';
  }

  @override
  String get kimchiPremiumPercent => '김치 프리미엄(%)';

  @override
  String get resetChart => '차트 리셋';

  @override
  String get backToPreviousChart => '차트 이전';

  @override
  String get kimchiPremium => '김치 프리미엄';

  @override
  String get aiBuySell => 'AI 매수/매도';

  @override
  String get kimchiPremiumBuySell => '김프 매수/매도';

  @override
  String get kimchiPremiumBackground => '김치 프리미엄 배경';

  @override
  String get kimchiPremiumBackgroundDescriptionTooltip => '김치 프리미엄 배경 설명';

  @override
  String get whatIsKimchiPremiumBackground => '김치 프리미엄 배경이란?';

  @override
  String get kimchiPremiumBackgroundDescription =>
      '차트의 배경색은 김치 프리미엄 값에 따라 달라집니다. 프리미엄이 높을수록 빨간색, 낮을수록 파란색에 가깝게 표시되어 김치 프리미엄에 따른 매수 매도 시점을 시각적으로 파악할 수 있습니다. 이 기능은 김치 프리미엄의 변동성을 한눈에 파악하는 데 도움을 줍니다.';

  @override
  String get confirm => '확인';

  @override
  String get chatRoom => '토론방';

  @override
  String get gimchBaseTrade => '김프 기준 매매';

  @override
  String get aiBaseTrade => 'AI 전략 매매';

  @override
  String get seeWithChart => '차트로 보기';

  @override
  String get buyBase => '매수 기준(%)';

  @override
  String get sellBase => '매도 기준(%)';

  @override
  String get sameAsAI => 'AI와 동일 일정 적용';

  @override
  String get failedToSaveSettings => '설정 저장에 실패했습니다.';

  @override
  String get buyPrice => '매수 가격';

  @override
  String get sellPrice => '매도 가격';

  @override
  String get expectedGain => '기대 수익률';

  @override
  String get summary => '요약';

  @override
  String kimchiStrategyComment(double buyThreshold, double sellThreshold) {
    return '김치 프리미엄이 $buyThreshold% 이하일 때 매수, $sellThreshold% 이상일 때 매도 전략입니다.';
  }

  @override
  String get strategySummaryEmpty => '전략 요약 정보가 없습니다.';

  @override
  String get sellIfCurrentPrice => '현재가 매도시';

  @override
  String get onboardingTitle1 => '테더(USDT)는 단순한 달러가 아닙니다';

  @override
  String get onboardingBody1 =>
      '외국에서는 1 테더(USDT)가 1 달러 이지만, 한국 거래소 에서는 환율과 가격이 달라요. 특히 한국에서는 ‘김치 프리미엄’에 따라 환율과의 가격 차이가 발생 합니다.';

  @override
  String get onboardingImageDesc1 => '테더(USDT) ≒ 환율 + 김치 프리미엄';

  @override
  String get onboardingTitle2 => '높은 김치 프리미엄일 때 테더(USDT) 매도는 수익의 기회';

  @override
  String get onboardingBody2 =>
      '한국에서는 테더(USDT)가 해외보다 비싸게 거래되는 경우가 많습니다. (이걸 ‘김치 프리미엄’이라 부릅니다.) 우리 앱은 테더(USDT)의 과거 테이타를 분석해 최적의 매수/매도 시점을 찾아줍니다.';

  @override
  String get onboardingImageDesc2 => '테더(USDT) → 저가 매수 → 고가 매도 → 안정적인 수익 구조';

  @override
  String get onboardingTitle3 => '매수/매도 타이밍? 우리가 알려드려요';

  @override
  String get onboardingBody3 =>
      '김치 프리미엄의 매매 기준, AI 분석을 통해 매수와 매도 시점을 알림으로 알려 줍니다. 본인의 판단에 따라 맞는 방법을 참고 하시면 됩니다.';

  @override
  String get onboardingImageDesc3 => '실시간 테더(USDT) 가격을 확인 후 매수/매도 알림';

  @override
  String get onboardingTitle4 => '만약 100만원으로 시작했다면?';

  @override
  String get onboardingBody4 => '실제 과거 데이터를 기반으로, 우리 전략을 썼을 때 수익률 보여드릴게요.';

  @override
  String get onboardingImageDesc4 => '과거 데이타를 통한 수익률 시각화';

  @override
  String get previous => '이전';

  @override
  String get start => '시작하기';

  @override
  String get next => '다음';

  @override
  String get selectReceiveAlert => '받을 알림을 선택하세요';

  @override
  String get selectReceiveAlertSubtitle => '수신할 알림 유형을 선택하세요';

  @override
  String get aIalert => 'AI 분석 알림 받기';

  @override
  String get aIalertDescription => 'AI가 분석한 매매 전략을 알림으로 받습니다';

  @override
  String get gimpAlert => '김프 알림 받기';

  @override
  String get gimpAlertDescription => '김치 프리미엄 기반 매매 전략을 알림으로 받습니다';

  @override
  String get turnOffAlert => '알림 끄기';

  @override
  String get unFilled => '미체결';

  @override
  String get coinInfoSite => '코인 정보 사이트';

  @override
  String get adClickInstruction => 'X 클릭 후 매수/매도 시그널 확인';

  @override
  String get removeAdsCta => '광고 없이 매매 전략 보기';

  @override
  String get removeAdsTitle => '광고 없이 보기';

  @override
  String get removeAdsSubtitle => '더 깔끔하게 매매 전략을 확인하세요.';

  @override
  String get removeAdsDescription => '결제 후에는 광고 시청 없이 바로 매매 전략을 확인할 수 있습니다.';

  @override
  String get purchaseButton => '구매하기';

  @override
  String get restoreButton => '구매 복원';

  @override
  String get restoreSuccess => '성공';

  @override
  String get restoreNoPurchases => '복원할 구매 내역이 없습니다';

  @override
  String get adLoadingMessage => '광고를 불러오는 중입니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get privacyPolicy => '개인정보 처리 방침';

  @override
  String get termsOfService => '약관';

  @override
  String get nextBuyPoint => '다음 매수 시점';

  @override
  String get nextSellPoint => '다음 매도 시점';

  @override
  String get priceLabel => '가격';

  @override
  String get basePremium => '기준 프리미엄';

  @override
  String get kimchiPremiumShort => '김프';

  @override
  String get tradeTimeline => '매매 타임라인';

  @override
  String get performanceMetrics => '성과 지표';

  @override
  String get initialCapital => '초기 자본: ₩1,000,000';

  @override
  String get finalValue => '최종 가치';

  @override
  String get aiSimulatedTradeTitle => 'AI 모의 투자';

  @override
  String get kimchiSimulatedTradeTitle => '김프 모의 투자';

  @override
  String get profitRate => '수익률';

  @override
  String get evaluationAmount => '평가금액';

  @override
  String get fee => '수수료';

  @override
  String upbitFeeApplied(double buyFee, double sellFee) {
    return '업비트 수수료 적용 (매수 $buyFee%, 매도 $sellFee%)';
  }

  @override
  String feeWithAmount(String amount) {
    return '수수료: ₩$amount';
  }
}
