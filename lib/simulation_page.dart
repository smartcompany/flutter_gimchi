import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:usdt_signal/ChartOnlyPage.dart'; // ChartOnlyPageModel import 추가
import 'package:usdt_signal/api_service.dart';
import 'package:usdt_signal/simulation_model.dart';
import 'package:usdt_signal/strategy_history_page.dart';
import 'utils.dart';
import 'dialogs/liquid_glass_dialog.dart';

// ============================================================================
// 시뮬레이션 화면 테마 (다크/라이트 공통 ColorScheme)
// ============================================================================

class _SimUi {
  static const accentGradient = [
    Color(0xFF667EEA),
    Color(0xFF764BA2),
  ];

  static List<Color> pageBackground(ColorScheme cs) => [
    cs.surface,
    cs.surfaceContainerLow,
    cs.surfaceContainerHigh,
  ];

  static List<Color> glassCardFill(ColorScheme cs) => [
    cs.surfaceContainerHigh.withValues(alpha: 0.96),
    cs.surfaceContainerHigh.withValues(alpha: 0.85),
  ];

  static Color glassBorder(ColorScheme cs) =>
      cs.outline.withValues(alpha: 0.42);

  static List<Color> glassCardFillLight(ColorScheme cs) => [
    cs.surfaceContainerHighest.withValues(alpha: 0.92),
    cs.surfaceContainerHighest.withValues(alpha: 0.78),
  ];
}

class _TitleStyles {
  static TextStyle appBarTitle(BuildContext context) => TextStyle(
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle sectionTitle(BuildContext context) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle headerCardTitle(BuildContext context) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle dialogTitle(BuildContext context) => TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

class _BodyStyles {
  static TextStyle bodyText(BuildContext context) => TextStyle(
    fontSize: 18,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle labelText(BuildContext context) => TextStyle(
    fontSize: 16,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  static TextStyle greyLabelText(BuildContext context) => TextStyle(
    fontSize: 16,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

class _ButtonStyles {
  static const smallButton = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  static TextStyle largeButton(BuildContext context) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onPrimary,
  );
}

class _CardStyles {
  static TextStyle cardTitle(BuildContext context) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle cardDate(BuildContext context) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  static TextStyle cardPrice(BuildContext context) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle metricLabel(BuildContext context) => TextStyle(
    fontSize: 14,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontWeight: FontWeight.w600,
  );

  static TextStyle metricValue(BuildContext context) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle headerCardValue(BuildContext context) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

class _DialogStyles {
  static TextStyle sectionTitle(BuildContext context) => TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 15,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle bodyText(BuildContext context) => TextStyle(
    fontSize: 14,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
  );
}

enum SimulationType { ai, kimchi }

class SimulationPage extends StatefulWidget {
  final SimulationType simulationType;
  final Map<DateTime, USDTChartData> usdtMap;
  final List<StrategyMap> strategyList;
  final List<ChartData> usdExchangeRates;
  final Map<DateTime, Map<String, double>>? premiumTrends; // 김치 프리미엄 트렌드 데이터

  // ChartOnlyPageModel을 직접 받는 생성자 추가
  final ChartOnlyPageModel? chartOnlyPageModel;

  // Settings 데이터
  final Map<String, dynamic>? settings;

  const SimulationPage({
    super.key,
    required this.simulationType,
    required this.usdtMap,
    required this.strategyList,
    required this.usdExchangeRates,
    this.premiumTrends,
    this.chartOnlyPageModel,
    this.settings,
  });

  static Future<bool> showKimchiStrategyUpdatePopup(
    BuildContext context, {
    DateTime? defaultStartDate,
    DateTime? defaultEndDate,
    List<DateTime>? availableDates,
  }) async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) {
        double buy = SimulationCondition.instance.kimchiBuyThreshold;
        double sell = SimulationCondition.instance.kimchiSellThreshold;
        final sortedDates = (availableDates ?? <DateTime>[]).toList()..sort();
        bool useExchangeRateSellWeight =
            SimulationCondition.instance.useExchangeRateSellWeight;
        DateTime? startDate =
            SimulationCondition.instance.kimchiStartDate ?? defaultStartDate;
        DateTime? endDate =
            SimulationCondition.instance.kimchiEndDate ?? defaultEndDate;
        double rangeStart = 0;
        double rangeEnd =
            sortedDates.isNotEmpty ? (sortedDates.length - 1).toDouble() : 0;
        if (sortedDates.isNotEmpty) {
          final startIndex =
              startDate != null
                  ? sortedDates.indexWhere((d) => d.isSameDate(startDate!))
                  : -1;
          final endIndex =
              endDate != null
                  ? sortedDates.indexWhere((d) => d.isSameDate(endDate!))
                  : -1;
          rangeStart = (startIndex >= 0 ? startIndex : 0).toDouble();
          rangeEnd =
              (endIndex >= 0 ? endIndex : sortedDates.length - 1).toDouble();
        }

        return StatefulBuilder(
          builder: (context, setState) {
            return LiquidGlassDialog(
              title: Text(l10n(context).changeStrategy),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(l10n(context).buyBase),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: buy.toString(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final n = double.tryParse(v);
                            if (n != null && n >= -10 && n <= 10) {
                              setState(() {
                                buy = n;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(l10n(context).sellBase),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: sell.toString(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final n = double.tryParse(v);
                            if (n != null && n >= -10 && n <= 10) {
                              setState(() {
                                sell = n;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (sortedDates.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n(context).kimchiStartDate),
                        Text(startDate?.toCustomString() ?? l10n(context).dash),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n(context).kimchiEndDate),
                        Text(endDate?.toCustomString() ?? l10n(context).dash),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RangeSlider(
                      values: RangeValues(rangeStart, rangeEnd),
                      min: 0,
                      max: (sortedDates.length - 1).toDouble(),
                      divisions: sortedDates.length - 1,
                      labels: RangeLabels(
                        startDate?.toCustomString() ?? l10n(context).dash,
                        endDate?.toCustomString() ?? l10n(context).dash,
                      ),
                      onChanged: (values) {
                        setState(() {
                          rangeStart = values.start.roundToDouble();
                          rangeEnd = values.end.roundToDouble();
                          final startIndex = rangeStart.toInt();
                          final endIndex = rangeEnd.toInt();
                          startDate = sortedDates[startIndex];
                          endDate = sortedDates[endIndex];
                        });
                      },
                    ),
                  ] else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n(context).kimchiStartDate),
                        Text(l10n(context).dash),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                          (defaultStartDate == null && defaultEndDate == null)
                              ? null
                              : () {
                                setState(() {
                                  startDate = defaultStartDate;
                                  endDate = defaultEndDate;
                                  if (sortedDates.isNotEmpty) {
                                    rangeStart = 0;
                                    rangeEnd =
                                        (sortedDates.length - 1).toDouble();
                                  }
                                });
                              },
                      child: Text(l10n(context).kimchiResetDateRange),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: useExchangeRateSellWeight,
                        onChanged: (value) {
                          setState(() {
                            useExchangeRateSellWeight = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          l10n(context).useExchangeRateSellWeight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n(context).cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'buy': buy,
                      'sell': sell,
                      'startDate': startDate,
                      'endDate': endDate,
                      'useExchangeRateSellWeight': useExchangeRateSellWeight,
                    });
                  },
                  child: Text(l10n(context).confirm),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      final buy = result['buy'] as double;
      final sell = result['sell'] as double;
      final startDate = result['startDate'] as DateTime?;
      final endDate = result['endDate'] as DateTime?;
      final useExchangeRateSellWeight =
          result['useExchangeRateSellWeight'] as bool? ?? false;

      final isSuccess = await ApiService.shared.saveAndSyncUserData({
        UserDataKey.gimchiBuyPercent: buy,
        UserDataKey.gimchiSellPercent: sell,
        UserDataKey.gimchiSellFollowExchangeRate: useExchangeRateSellWeight,
      });

      if (isSuccess) {
        await SimulationCondition.instance.saveKimchiBuyThreshold(buy);
        await SimulationCondition.instance.saveKimchiSellThreshold(sell);
        await SimulationCondition.instance.saveKimchiDateRange(
          startDate: startDate,
          endDate: endDate,
        );
        await SimulationCondition.instance
            .saveUseExchangeRateSellWeight(useExchangeRateSellWeight);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n(context).failedToSaveSettings)),
        );
      }

      return isSuccess;
    }
    return false;
  }

  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage>
    with SingleTickerProviderStateMixin {
  List<StrategyMap>? strategies;
  List<SimulationResult> results = [];
  bool loading = true;
  String? error;
  bool isCardExpanded = true; // 카드 확장/축소 상태

  // 소수점 4자리까지 표시하는 포맷
  final NumberFormat krwFormat = NumberFormat("#,##0.#", "ko_KR");
  double totalProfitRate = 0; // 총 수익률 변수 추가

  @override
  void initState() {
    super.initState();
    runSimulation();

    // 애니메이션 컨트롤러 및 애니메이션 초기화
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> runSimulation() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // apiService 대신 생성자에서 받은 데이터 사용
      final usdtMap = widget.usdtMap;
      final usdExchangeRates = widget.usdExchangeRates;
      final strategyList = widget.strategyList;

      // Settings에서 수수료 정보 추출
      double? buyFee;
      double? sellFee;
      if (widget.settings != null) {
        final upbitFees =
            widget.settings!['upbit_fees'] as Map<String, dynamic>?;
        if (upbitFees != null) {
          buyFee = (upbitFees['buy_fee'] as num?)?.toDouble();
          sellFee = (upbitFees['sell_fee'] as num?)?.toDouble();
          print('시뮬레이션 수수료 설정: buyFee=$buyFee%, sellFee=$sellFee%');
        } else {
          print('시뮬레이션 수수료 설정: upbit_fees가 null입니다.');
        }
      } else {
        print('시뮬레이션 수수료 설정: settings가 null입니다.');
      }

      if (widget.simulationType == SimulationType.ai) {
        final simResults = SimulationModel.simulateResults(
          usdExchangeRates,
          strategyList,
          usdtMap,
          buyFee: buyFee,
          sellFee: sellFee,
        );

        setState(() {
          strategies = List<StrategyMap>.from(strategyList);
          results = simResults;
          loading = false;
        });
      } else if (widget.simulationType == SimulationType.kimchi) {
        final simResults = SimulationModel.gimchiSimulateResults(
          usdExchangeRates,
          strategyList,
          usdtMap,
          widget.premiumTrends,
          buyFee: buyFee,
          sellFee: sellFee,
        );

        setState(() {
          strategies = List<StrategyMap>.from(strategyList);
          results = simResults;
          loading = false;
        });
      }
    } catch (e) {
      print('Error during simulation: $e');
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  // 이전 AI 전략을 찾는 헬퍼 함수
  StrategyMap? _findPreviousAIStrategy(DateTime targetDate) {
    if (strategies == null || strategies!.isEmpty) return null;

    // 날짜를 내림차순으로 정렬 (최신순)
    final sortedStrategies = List<StrategyMap>.from(strategies!)..sort((a, b) {
      final dateA = DateTime.parse(a['analysis_date']);
      final dateB = DateTime.parse(b['analysis_date']);
      return dateB.compareTo(dateA);
    });

    // targetDate보다 이전 날짜 중에서 가장 가까운 전략을 찾기
    for (final strategy in sortedStrategies) {
      final strategyDate = DateTime.parse(strategy['analysis_date']);
      if (strategyDate.isBefore(targetDate)) {
        return strategy;
      }
    }

    return null; // 이전 전략이 없으면 null 반환
  }

  void _showStrategyDialog(BuildContext context, DateTime date) {
    var strategy = strategies?.firstWhere(
      (s) => DateTime.parse(s['analysis_date']).isSameDate(date),
      orElse: () => {},
    );

    // AI 전략에서 해당 날짜에 전략이 없으면 이전 전략을 찾아서 사용
    DateTime displayDate = date; // 표시할 날짜 (기본값은 요청한 날짜)
    if (widget.simulationType == SimulationType.ai &&
        (strategy == null || strategy.isEmpty)) {
      strategy = _findPreviousAIStrategy(date);
      // 이전 전략을 찾았으면 그 전략의 날짜를 표시 날짜로 사용
      if (strategy != null && strategy.isNotEmpty) {
        displayDate = DateTime.parse(strategy['analysis_date']);
      }
    }

    var (buyThreshold, sellThreshold) = (
      SimulationCondition.instance.kimchiBuyThreshold,
      SimulationCondition.instance.kimchiSellThreshold,
    );

    if (widget.simulationType == SimulationType.kimchi) {
      // 서버에서 받은 김치 프리미엄 트렌드 데이터 사용
      (buyThreshold, sellThreshold) = SimulationModel.getKimchiThresholds(
        trendData: widget.premiumTrends?[date],
        exchangeRates: widget.usdExchangeRates,
        targetDate: date,
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final cs = Theme.of(context).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _SimUi.glassCardFill(cs),
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _SimUi.glassBorder(cs),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${displayDate.toCustomString()} ${l10n(context).strategy}',
                            style: _TitleStyles.dialogTitle(context).copyWith(
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: cs.primary,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (widget.simulationType == SimulationType.ai &&
                          strategy != null &&
                          strategy.isNotEmpty) ...[
                        _StrategyDialogRow(
                          label: l10n(context).buyPrice,
                          value: '${strategy['buy_price']}',
                        ),
                        _StrategyDialogRow(
                          label: l10n(context).sellPrice,
                          value: '${strategy['sell_price']}',
                        ),
                        _StrategyDialogRow(
                          label: l10n(context).expectedGain,
                          value: '${strategy['expected_return']}',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n(context).summary,
                          style: _DialogStyles.sectionTitle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strategy['summary'] ?? '',
                          style: _DialogStyles.bodyText(context),
                        ),
                      ] else ...[
                        Text(
                          widget.simulationType == SimulationType.kimchi
                              ? l10n(context).kimchiStrategyComment(
                                double.parse(buyThreshold.toStringAsFixed(1)),
                                double.parse(sellThreshold.toStringAsFixed(1)),
                              )
                              : (strategy != null && strategy.isNotEmpty)
                              ? '${strategy['summary'] ?? '전략 정보'}'
                              : '해당 날짜에 대한 전략이 없습니다.',
                          style: _DialogStyles.bodyText(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text(
          widget.simulationType == SimulationType.kimchi
              ? l10n(context).gimchBaseTrade
              : l10n(context).aiBaseTrade,
          style: _TitleStyles.appBarTitle(context).copyWith(fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: cs.onSurface,
          size: 22,
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.surface.withValues(alpha: 0.92),
                    cs.surface.withValues(alpha: 0.78),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: _SimUi.glassBorder(cs),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        actions:
            widget.simulationType == SimulationType.kimchi
                ? [
                  IconButton(
                    icon: Icon(Icons.settings, color: cs.primary),
                    onPressed: () async {
                      final sortedDates = widget.usdtMap.keys.toList()..sort();
                      final defaultStartDate =
                          sortedDates.isNotEmpty ? sortedDates.first : null;
                      final defaultEndDate =
                          sortedDates.isNotEmpty ? sortedDates.last : null;
                      final success =
                          await SimulationPage.showKimchiStrategyUpdatePopup(
                            context,
                            defaultStartDate: defaultStartDate,
                            defaultEndDate: defaultEndDate,
                            availableDates: sortedDates,
                          );
                      if (success) {
                        runSimulation();
                      }
                    },
                  ),
                ]
                : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _SimUi.pageBackground(cs),
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 메인 콘텐츠
              loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: cs.primary,
                      ),
                    )
                  : error != null
                  ? Center(
                      child: Text(
                        '${l10n(context).error}: $error',
                        style: TextStyle(color: cs.error),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(context),
                        const SizedBox(height: 24),
                        Text(
                          l10n(context).tradeTimeline,
                          style: _TitleStyles.sectionTitle(context),
                        ),
                        const SizedBox(height: 12),
                        if (results.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                l10n(context).noStrategyData,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          ...results.expand((r) {
                            List<Widget> widgets = [_buildBuyCard(context, r)];
                            if (r.sellDate != null) {
                              widgets.add(const SizedBox(height: 12));
                              widgets.add(_buildSellCard(context, r));
                            }
                            // 매도가 있든 없든 평가금액 표시
                            widgets.add(const SizedBox(height: 12));
                            widgets.add(_buildResultCard(context, r));
                            widgets.add(const SizedBox(height: 12));
                            return widgets;
                          }),
                        // 버텀 시트 공간 확보 (화면 높이의 40% + 여유 공간)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.35,
                        ),
                      ],
                    ),
                  ),
              // 버텀 시트 (오버레이)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildBottomSheet(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    if (loading || results.isEmpty) {
      return const SizedBox.shrink();
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.4, // 초기 크기 (모든 컨텐츠가 보이도록)
      minChildSize: 0.12, // 최소 크기
      maxChildSize: 0.4, // 최대 크기 (초기 크기와 동일)
      builder: (context, scrollController) {
        final cs = Theme.of(context).colorScheme;
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _SimUi.glassCardFill(cs),
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: _SimUi.glassBorder(cs), width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // 스크롤이 끝에 도달했을 때 시트가 확장되지 않도록 함
                  if (notification is ScrollEndNotification) {
                    if (scrollController.position.pixels == 0) {
                      // 스크롤이 맨 위에 있을 때만 드래그 가능
                    }
                  }
                  return false;
                },
                child: ListView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  children: [
                    // 드래그 핸들
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: cs.outlineVariant.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // 성과 지표 & 차트로 보기 버튼
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n(context).performanceMetrics,
                          style: _TitleStyles.sectionTitle(context),
                        ),
                        OutlinedButton.icon(
                          icon: Icon(
                            Icons.show_chart,
                            color: cs.primary,
                            size: 16,
                          ),
                          label: Text(
                            l10n(context).seeWithChart,
                            style: _ButtonStyles.smallButton.copyWith(
                              color: cs.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: cs.primary.withValues(alpha: 0.85),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => ChartOnlyPage.fromModel(
                                      widget.chartOnlyPageModel!,
                                      initialShowAITrading:
                                          widget.simulationType ==
                                          SimulationType.ai,
                                      initialShowGimchiTrading:
                                          widget.simulationType ==
                                          SimulationType.kimchi,
                                    ),
                                fullscreenDialog: true,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPerformanceMetrics(context),
                    const SizedBox(height: 24),
                    _buildViewHistoryButton(context),
                    // 하단 SafeArea 고려
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _SimUi.glassCardFillLight(cs),
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _SimUi.glassBorder(cs), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _SimUi.accentGradient,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _SimUi.accentGradient[0].withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.simulationType == SimulationType.ai
                            ? Icons.psychology
                            : Icons.trending_up,
                        color: cs.onPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.simulationType == SimulationType.ai
                                ? l10n(context).aiSimulatedTradeTitle
                                : l10n(context).kimchiSimulatedTradeTitle,
                            style: _TitleStyles.headerCardTitle(context),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n(context).initialCapital,
                            style: _BodyStyles.labelText(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 차트 라인 (플레이스홀더)
                Container(
                  height: 3,
                  width: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: _SimUi.accentGradient,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Period
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n(context).tradingPerioid,
                      style: _BodyStyles.greyLabelText(context),
                    ),
                    Builder(
                      builder: (context) {
                        if (results.isEmpty) return const Text("-");
                        final startDate =
                            results.first.buyDate?.toCustomString() ?? "";
                        final endDate =
                            results.last.analysisDate.toCustomString();
                        return Text(
                          "$startDate - $endDate",
                          style: _CardStyles.headerCardValue(context),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Total Gain
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n(context).totalGain,
                      style: _BodyStyles.greyLabelText(context),
                    ),
                    Builder(
                      builder: (context) {
                        final double totalGain =
                            results.isNotEmpty
                                ? (results.last.finalKRW - 1000000)
                                : 0;
                        final double totalGainPercent =
                            results.isNotEmpty
                                ? (results.last.finalKRW / 1000000 * 100 - 100)
                                : 0;
                        return RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    "${totalGain >= 0 ? '+' : ''}${krwFormat.format(totalGain.round())} ",
                                style: _CardStyles.cardPrice(context).copyWith(
                                  color:
                                      totalGain >= 0
                                          ? const Color(0xFF4ADE80)
                                          : const Color(0xFFF87171),
                                ),
                              ),
                              TextSpan(
                                text:
                                    "(${totalGainPercent.toStringAsFixed(2)}%)",
                                style: _CardStyles.headerCardValue(context)
                                    .copyWith(
                                  color:
                                      totalGain >= 0
                                          ? const Color(0xFF4ADE80)
                                          : const Color(0xFFF87171),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stacked Final KRW (누적 최종 원화)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n(context).stackedFinalKRW,
                      style: _BodyStyles.greyLabelText(context),
                    ),
                    Builder(
                      builder: (context) {
                        if (results.isEmpty) return const Text("-");
                        final finalKRW = results.last.finalKRW;
                        return Text(
                          "₩${krwFormat.format(finalKRW.round())}",
                          style: _CardStyles.headerCardValue(context),
                        );
                      },
                    ),
                  ],
                ),
                // 수수료 적용 여부 표시
                Builder(
                  builder: (context) {
                    if (widget.settings == null) return const SizedBox.shrink();
                    final upbitFees =
                        widget.settings!['upbit_fees'] as Map<String, dynamic>?;
                    if (upbitFees == null) return const SizedBox.shrink();
                    final buyFee = (upbitFees['buy_fee'] as num?)?.toDouble();
                    final sellFee = (upbitFees['sell_fee'] as num?)?.toDouble();
                    if (buyFee == null || sellFee == null)
                      return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n(context).upbitFeeApplied(buyFee, sellFee),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyButton(
    BuildContext context,
    DateTime? date,
    Color color,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.12),
            ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
          ),
          child: OutlinedButton(
            onPressed: () {
              if (date != null) {
                _showStrategyDialog(context, date);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n(context).seeStrategy,
              style: _ButtonStyles.smallButton.copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuyCard(BuildContext context, SimulationResult r) {
    final gradient = [
      const Color(0xFF7F1D1D).withValues(alpha: 0.92),
      const Color(0xFFB91C1C).withValues(alpha: 0.78),
    ];

    return GestureDetector(
      onTap: () {
        if (r.buyDate != null) {
          _showStrategyDialog(context, r.buyDate!);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradient[0], gradient[1]],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withValues(alpha: 0.35),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.north_east,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n(context).buy,
                      style: _CardStyles.cardTitle(context).copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.buyDate?.toCustomString() ?? "-",
                      style: _CardStyles.cardDate(context).copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    "₩${krwFormat.format(r.buyPrice)}",
                    style: _CardStyles.cardPrice(context).copyWith(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
                const SizedBox(width: 4),
                _buildStrategyButton(context, r.buyDate, Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSellCard(BuildContext context, SimulationResult r) {
    final gradient = [
      const Color(0xFF134E4A).withValues(alpha: 0.92),
      const Color(0xFF0D9488).withValues(alpha: 0.78),
    ];

    return GestureDetector(
      onTap: () {
        if (r.sellDate != null) {
          _showStrategyDialog(context, r.sellDate!);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradient[0], gradient[1]],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withValues(alpha: 0.35),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.south_east,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n(context).sell,
                      style: _CardStyles.cardTitle(context).copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.sellDate?.toCustomString() ?? "-",
                      style: _CardStyles.cardDate(context).copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    r.sellPrice != null
                        ? "₩${krwFormat.format(r.sellPrice!)}"
                        : "-",
                    style: _CardStyles.cardPrice(context).copyWith(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
                const SizedBox(width: 4),
                _buildStrategyButton(context, r.sellDate, Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, SimulationResult r) {
    // 매도가 없는 경우 수익과 수익률을 다시 계산
    double currentValue = r.finalKRW;
    double profit = r.profit;
    double profitRate = r.profitRate;
    double? currentUsdtPrice; // 매도가 없는 경우 USDT 가격 저장

    if (r.sellDate == null) {
      // 매도가 안된 경우: 현재 USDT 가격 기준으로 평가금액 계산
      final analysisDate = r.analysisDate;
      final usdtData = widget.usdtMap[analysisDate];
      currentUsdtPrice = usdtData?.close ?? 0.0;
      final usdtAmount = r.finalUSDT ?? 0.0;
      currentValue = currentUsdtPrice * usdtAmount;

      // 이전 거래의 finalKRW 또는 초기 자본을 매수 금액으로 사용
      final buyAmount = _getBuyAmountForResult(r);
      profit = currentValue - buyAmount;
      if (buyAmount > 0) {
        profitRate = (profit / buyAmount) * 100;
      }
    }

    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽 아이콘
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          // 오른쪽 텍스트 영역
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 첫 번째 줄: 수익 금액과 수익률
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "${l10n(context).gain}: ",
                        style: _CardStyles.cardDate(context).copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text:
                            "${profit >= 0 ? '+' : ''}₩${krwFormat.format(profit.round())} ",
                        style: _CardStyles.cardDate(context).copyWith(
                          color:
                              profit >= 0
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFF87171),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (profitRate != 0)
                        TextSpan(
                          text:
                              "(${profitRate >= 0 ? '+' : ''}${profitRate.toStringAsFixed(2)}%)",
                          style: _CardStyles.cardDate(context).copyWith(
                            color:
                                profitRate >= 0
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFFF87171),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                // 수수료 표시 (매도가 있는 경우만)
                Builder(
                  builder: (context) {
                    if (r.sellDate == null) return const SizedBox.shrink();
                    if (widget.settings == null) return const SizedBox.shrink();
                    final upbitFees =
                        widget.settings!['upbit_fees'] as Map<String, dynamic>?;
                    if (upbitFees == null) return const SizedBox.shrink();
                    final buyFee = (upbitFees['buy_fee'] as num?)?.toDouble();
                    final sellFee = (upbitFees['sell_fee'] as num?)?.toDouble();
                    if (buyFee == null ||
                        sellFee == null ||
                        (buyFee == 0 && sellFee == 0))
                      return const SizedBox.shrink();

                    // 매수 수수료 계산
                    // buyPrice는 USDT 단가이고, 실제 매수 금액은 totalKRW입니다
                    // 매수 시: 실제 매수 금액 기준으로 수수료 계산
                    // 이전 거래의 finalKRW 또는 초기 자본을 매수 금액으로 사용
                    final buyAmount = _getBuyAmountForResult(r);
                    final buyFeeAmount = buyAmount * (buyFee / 100);

                    // 매도 수수료 계산
                    // sellPrice는 USDT 단가이고, 실제 매도 금액은 usdtAmount * sellPrice입니다
                    // 매도 시: 실제 매도 금액 기준으로 수수료 계산
                    // usdtAmount = buyAmount / buyPrice (buyPrice는 수수료 포함 가격)
                    final usdtAmount = buyAmount / r.buyPrice;
                    // 실제 매도 금액 = usdtAmount * sellPrice (sellPrice는 수수료 미적용 가격)
                    final sellAmount = usdtAmount * (r.sellPrice ?? 0);
                    final sellFeeAmount = sellAmount * (sellFee / 100);

                    print(
                      '수수료 계산: buyAmount=$buyAmount, buyFeeAmount=$buyFeeAmount, sellAmount=$sellAmount, sellFeeAmount=$sellFeeAmount, totalFee=${buyFeeAmount + sellFeeAmount}',
                    );

                    // 총 수수료
                    final totalFee = buyFeeAmount + sellFeeAmount;

                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n(
                          context,
                        ).feeWithAmount(krwFormat.format(totalFee.round())),
                        style: _CardStyles.cardDate(context).copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // 두 번째 줄: 최종원화 또는 평가금액
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text:
                            r.sellDate == null
                                ? "${l10n(context).evaluationAmount} "
                                : "${l10n(context).finalKRW} ",
                        style: _CardStyles.cardDate(context).copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: "₩${krwFormat.format(currentValue.round())}",
                        style: _CardStyles.cardDate(context).copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      if (r.sellDate == null && currentUsdtPrice != null)
                        TextSpan(
                          text:
                              " (${l10n(context).usdt}: ${currentUsdtPrice.toStringAsFixed(1)})",
                          style: _CardStyles.cardDate(context).copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 결과 카드에서 사용할 매수 금액 계산
  double _getBuyAmountForResult(SimulationResult r) {
    // 현재 결과의 인덱스 찾기
    final index = results.indexOf(r);
    if (index > 0) {
      // 이전 거래의 finalKRW 사용
      return results[index - 1].finalKRW;
    } else {
      // 첫 거래인 경우 초기 자본 사용
      return 1000000.0;
    }
  }

  Widget _buildPerformanceMetrics(BuildContext context) {
    final double totalGain =
        results.isNotEmpty ? (results.last.finalKRW / 1000000 * 100 - 100) : 0;

    String annualYieldText = "0.00%";
    if (results.isNotEmpty) {
      final annualYield = SimulationModel.calculateAnnualYield(results);
      if (!annualYield.isNaN && !annualYield.isInfinite && annualYield != 0.0) {
        annualYieldText = "${annualYield.toStringAsFixed(2)}%";
      }
    }

    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            context,
            l10n(context).totalGain,
            "${totalGain.toStringAsFixed(2)}%",
            const Color(0xFF4ADE80),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            context,
            l10n(context).extimatedYearGain,
            annualYieldText,
            cs.primary,
            showInfoIcon: true,
            onInfoTap: () => _showAnnualYieldInfoDialog(context),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    Color valueColor, {
    bool showInfoIcon = false,
    VoidCallback? onInfoTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _SimUi.glassCardFillLight(cs),
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _SimUi.glassBorder(cs), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: _CardStyles.metricLabel(context)),
                  if (showInfoIcon) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onInfoTap,
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: _CardStyles.metricValue(context).copyWith(
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnnualYieldInfoDialog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    LiquidGlassDialog.show(
      context: context,
      title: Row(
        children: [
          Icon(Icons.info_outline, color: cs.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n(context).extimatedYearGain,
              style: _TitleStyles.dialogTitle(context),
            ),
          ),
        ],
      ),
      content: Text(
        l10n(context).annualYieldDescription,
        style: _DialogStyles.bodyText(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n(context).confirm,
            style: TextStyle(color: cs.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildViewHistoryButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder:
                (context) => DraggableScrollableSheet(
                  initialChildSize: 0.9,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder:
                      (context, scrollController) => Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: StrategyHistoryPage(
                          simulationType: widget.simulationType,
                          usdExchangeRates: widget.usdExchangeRates,
                          usdtMap: widget.usdtMap,
                          strategies: widget.strategyList,
                          premiumTrends: widget.premiumTrends,
                        ),
                      ),
                ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          l10n(context).viewAllStrategyHistory,
          style: _ButtonStyles.largeButton(context),
        ),
      ),
    );
  }
}

class SimulationYieldData {
  final double totalReturn; // 총 수익률 (%)
  final int tradingDays; // 거래 기간 (일)
  final double annualYield; // 연수익률 (%)

  SimulationYieldData({
    required this.totalReturn,
    required this.tradingDays,
    required this.annualYield,
  });
}

class SimulationResult {
  final DateTime analysisDate;
  final DateTime? buyDate;
  final double buyPrice;
  final DateTime? sellDate;
  final double? sellPrice;
  final double profit;
  final double profitRate;
  final double finalKRW;
  final double? finalUSDT;
  final double? usdExchangeRateAtBuy; // ← 추가
  final double? usdExchangeRateAtSell; // ← 추가

  SimulationResult({
    required this.analysisDate,
    required this.buyDate,
    required this.buyPrice,
    this.sellDate,
    this.sellPrice,
    required this.profit,
    required this.profitRate,
    required this.finalKRW,
    this.finalUSDT,
    this.usdExchangeRateAtBuy, // ← 추가
    this.usdExchangeRateAtSell, // ← 추가
  });

  // 매도시 김치 프리미엄 계산 함수
  double gimchiPremiumAtSell() {
    if (usdExchangeRateAtSell == null || sellPrice == null) {
      return 0.0; // 매도 가격이 없으면 프리미엄 계산 불가
    }

    return ((sellPrice! - usdExchangeRateAtSell!) /
        usdExchangeRateAtSell! *
        100);
  }

  // 매수시 김치 프리미엄 계산 함수
  double gimchiPremiumAtBuy() {
    if (usdExchangeRateAtBuy == null) {
      return 0.0; // 매수 가격이 없으면 프리미엄 계산 불가
    }

    return ((buyPrice - usdExchangeRateAtBuy!) / usdExchangeRateAtBuy! * 100);
  }
}

class _StrategyDialogRow extends StatelessWidget {
  final String label;
  final String value;
  const _StrategyDialogRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: _BodyStyles.labelText(context).copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: _BodyStyles.bodyText(context)),
        ],
      ),
    );
  }
}
