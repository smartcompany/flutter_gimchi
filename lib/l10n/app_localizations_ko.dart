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
  String get no => '아니오';

  @override
  String get seeAdsAndStrategy => '광고 보고 전략 보기';

  @override
  String get throwTestException => 'throwTestException';

  @override
  String get throw_test_exception => '테스트 예외 발생';

  @override
  String get usdtSignal => '테더 시그널';

  @override
  String get usdt_signal => 'USDT 시그널';

  @override
  String get buyWin => '현재 매수 유리 구간입니다';

  @override
  String get sellWin => '현재 매수 유리 구간입니다';

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
  String get gain => '수익율';

  @override
  String get runSimulation => '시뮬레이션 해보기';

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
  String get totalGain => '총 수익률';

  @override
  String get extimatedYearGain => '추정 연 수익률';

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
  String get strategy => '전략';

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
  String get sellIfCurrentPrice => '현재가 매도시';
}
