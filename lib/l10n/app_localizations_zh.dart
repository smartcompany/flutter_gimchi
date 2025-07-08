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

  @override
  String get chatRoom => '聊天室';

  @override
  String get gimchBaseTrade => '韩元溢价基准交易';

  @override
  String get aiBaseTrade => 'AI 基准交易';

  @override
  String get seeWithChart => '使用图表查看';

  @override
  String get buyBase => '买入基准（%）';

  @override
  String get sellBase => '卖出基准（%）';

  @override
  String get sameAsAI => '与AI使用相同的时间设置';

  @override
  String get failedToSaveSettings => '保存设置失败。';

  @override
  String get strategy => '策略';

  @override
  String get buyPrice => '买入价格';

  @override
  String get sellPrice => '卖出价格';

  @override
  String get expectedGain => '预期收益率';

  @override
  String get summary => '摘要';

  @override
  String kimchiStrategyComment(double buyThreshold, double sellThreshold) {
    return '当泡菜溢价低于 $buyThreshold% 时买入，高于 $sellThreshold% 时卖出。';
  }

  @override
  String get sellIfCurrentPrice => '当前价格卖出';

  @override
  String get onboardingTitle1 => 'USDT 不仅仅是美元';

  @override
  String get onboardingBody1 =>
      '1 USDT ≈ 1 USD，但实际价格会因交易所、市价和汇率而异。特别是在韩国，由于“泡菜溢价”和“汇率差异”，经常会产生价差。';

  @override
  String get onboardingImageDesc1 => 'USDT vs 泡菜溢价对比图';

  @override
  String get onboardingTitle2 => '泡菜溢价 + 汇率差异 = 盈利机会';

  @override
  String get onboardingBody2 =>
      '在韩国，USDT的交易价格通常高于海外（这被称为“泡菜溢价”）。如果再考虑到汇率，价差可能会更大。我们的应用程序通过AI分析泡菜溢价和汇率，为您找到最佳的买入/卖出时机。';

  @override
  String get onboardingImageDesc2 => 'USDT → 低价买入 → 高价卖出 → 稳定的盈利结构';

  @override
  String get onboardingTitle3 => '买/卖时机？我们来告诉您';

  @override
  String get onboardingBody3 => '我们的AI实时分析泡菜溢价、汇率和海外市价，并以“立即购买/立即出售”的信号通知您。';

  @override
  String get onboardingImageDesc3 => '实际应用屏幕截图示例（买入信号通知）';

  @override
  String get onboardingTitle4 => '如果从100万韩元开始会怎样？';

  @override
  String get onboardingBody4 => '根据过去的实际数据，我们将向您展示使用我们的策略可以达到的收益率。';

  @override
  String get onboardingImageDesc4 => '按日期显示资产变化';

  @override
  String get previous => '上一步';

  @override
  String get start => '开始使用';

  @override
  String get next => '下一步';

  @override
  String get selectReceiveAlert => '选择要接收的通知';

  @override
  String get aIalert => 'AI 通知';

  @override
  String get gimpAlert => '泡菜溢价通知';

  @override
  String get turnOffAlert => '关闭通知';

  @override
  String get unFilled => '未成交';
}
