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
}
