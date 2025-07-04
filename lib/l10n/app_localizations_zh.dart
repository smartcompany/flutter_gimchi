// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get usdt => 'USDT';

  @override
  String get exchangeRate => '汇率';

  @override
  String get gimchiPremiem => '韩元溢价';

  @override
  String get cancel => '取消';

  @override
  String get changeStrategy => '更改泡菜溢价策略';

  @override
  String get close => '关闭';

  @override
  String get failedToSaveAlarm => '无法保存通知设置。';

  @override
  String get failedToload => '数据加载失败。\n是否要重试？';

  @override
  String get loadingFail => '加载失败';

  @override
  String get moveToSetting => '前往设置';

  @override
  String get needPermission => '需要通知权限';

  @override
  String get no => '否';

  @override
  String get seeAdsAndStrategy => '观看广告后查看策略';

  @override
  String get throwTestException => '抛出测试异常';

  @override
  String get throw_test_exception => '抛出测试异常';

  @override
  String get usdtSignal => 'USDT 信号';

  @override
  String get usdt_signal => 'USDT 信号';

  @override
  String get buyWin => '当前是买入有利的区间';

  @override
  String get sellWin => '当前是卖出有利的区间';

  @override
  String get justSee => '当前是观望区间';

  @override
  String get aiStrategy => 'AI 策略';

  @override
  String get gimchiStrategy => '韩元溢价策略';

  @override
  String get buy => '买入';

  @override
  String get sell => '卖出';

  @override
  String get gain => '收益率';

  @override
  String get runSimulation => '运行模拟';

  @override
  String get seeStrategy => '查看策略';

  @override
  String get aiTradingSimulation => 'AI交易模拟（以100万韩元为基准）';

  @override
  String get gimchTradingSimulation => '泡菜溢价交易模拟（以100万韩元为基准）';

  @override
  String get finalKRW => '最终韩元';

  @override
  String get tradingPerioid => '交易期间';

  @override
  String get stackedFinalKRW => '累计最终韩元';

  @override
  String get totalGain => '总收益率';

  @override
  String get extimatedYearGain => '预估年收益率';

  @override
  String get chartTrendAnalysis => '图表趋势分析';

  @override
  String get aiSell => 'AI 卖出';

  @override
  String get kimchiPremiumSell => '泡菜溢价卖出';

  @override
  String get aiBuy => 'AI 买入';

  @override
  String get kimchiPremiumBuy => '泡菜溢价买入';

  @override
  String changeFromPreviousDay(Object change) {
    return '较前一日变化：$change%';
  }

  @override
  String get kimchiPremiumPercent => '泡菜溢价 (%)';

  @override
  String get resetChart => '重置图表';

  @override
  String get backToPreviousChart => '上一张图表';

  @override
  String get kimchiPremium => '泡菜溢价';

  @override
  String get aiBuySell => 'AI 买入/卖出';

  @override
  String get kimchiPremiumBuySell => '泡菜溢价买入/卖出';

  @override
  String get kimchiPremiumBackground => '泡菜溢价背景';

  @override
  String get kimchiPremiumBackgroundDescriptionTooltip => '泡菜溢价背景说明';

  @override
  String get whatIsKimchiPremiumBackground => '什么是泡菜溢价背景？';

  @override
  String get kimchiPremiumBackgroundDescription =>
      '图表背景颜色根据泡菜溢价数值而变化。溢价越高背景越红，越低则偏蓝。此功能可帮助你根据泡菜溢价的高低来直观判断买卖时机，一目了然地把握其波动性。';

  @override
  String get confirm => '确认';
}
