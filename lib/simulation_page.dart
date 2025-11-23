import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:usdt_signal/ChartOnlyPage.dart'; // ChartOnlyPageModel import 추가
import 'package:usdt_signal/api_service.dart';
import 'package:usdt_signal/l10n/app_localizations.dart';
import 'package:usdt_signal/simulation_model.dart';
import 'package:usdt_signal/strategy_history_page.dart';
import 'utils.dart';

enum SimulationType { ai, kimchi }

class SimulationPage extends StatefulWidget {
  final SimulationType simulationType;
  final Map<DateTime, USDTChartData> usdtMap;
  final List<StrategyMap> strategyList;
  final List<ChartData> usdExchangeRates;
  final Map<DateTime, Map<String, double>>? premiumTrends; // 김치 프리미엄 트렌드 데이터

  // ChartOnlyPageModel을 직접 받는 생성자 추가
  final ChartOnlyPageModel? chartOnlyPageModel;

  const SimulationPage({
    super.key,
    required this.simulationType,
    required this.usdtMap,
    required this.strategyList,
    required this.usdExchangeRates,
    this.premiumTrends,
    this.chartOnlyPageModel,
  });

  static Future<bool> showKimchiStrategyUpdatePopup(
    BuildContext context, {
    bool showSameDatesAsAI = false,
    bool showUseTrend = false,
  }) async {
    final result = await showDialog<Map<String, Object>>(
      context: context,
      builder: (context) {
        double buy = SimulationCondition.instance.kimchiBuyThreshold;
        double sell = SimulationCondition.instance.kimchiSellThreshold;
        bool sameAsAI = SimulationCondition.instance.matchSameDatesAsAI;
        bool useTrend = SimulationCondition.instance.useTrend;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
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
                  if (showSameDatesAsAI)
                    Row(
                      children: [
                        Checkbox(
                          value: sameAsAI,
                          onChanged: (val) {
                            setState(() {
                              sameAsAI = val ?? false;
                            });
                          },
                        ),
                        Text(l10n(context).sameAsAI),
                      ],
                    ),
                  if (showUseTrend)
                    Row(
                      children: [
                        Checkbox(
                          value: useTrend,
                          onChanged: (val) {
                            setState(() {
                              useTrend = val ?? false;
                            });
                          },
                        ),
                        Text(l10n(context).useTrendBasedStrategy),
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
                      'sameAsAI': sameAsAI,
                      'useTrend': useTrend,
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
      final sameAsAI = result['sameAsAI'] as bool;
      final useTrend = result['useTrend'] as bool;

      final isSuccess = await ApiService.saveAndSyncUserData({
        UserDataKey.gimchiBuyPercent: buy,
        UserDataKey.gimchiSellPercent: sell,
      });

      if (isSuccess) {
        await SimulationCondition.instance.saveKimchiBuyThreshold(buy);
        await SimulationCondition.instance.saveKimchiSellThreshold(sell);
        await SimulationCondition.instance.saveMatchSameDatesAsAI(sameAsAI);
        await SimulationCondition.instance.saveUseTrend(useTrend);
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

  late AnimationController _bottomBarController;
  late Animation<Offset> _bottomBarOffset;

  @override
  void initState() {
    super.initState();
    runSimulation();

    // 애니메이션 컨트롤러 및 애니메이션 초기화
    _bottomBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bottomBarOffset = Tween<Offset>(
      begin: const Offset(0, 1.0), // 아래에서 시작
      end: Offset.zero, // 제자리
    ).animate(
      CurvedAnimation(
        parent: _bottomBarController,
        curve: Curves.easeOutBack, // 중력 느낌의 곡선
      ),
    );

    // 페이지가 열릴 때 애니메이션 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomBarController.forward();
    });
  }

  @override
  void dispose() {
    _bottomBarController.dispose();
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

      if (widget.simulationType == SimulationType.ai) {
        final simResults = SimulationModel.simulateResults(
          usdExchangeRates,
          strategyList,
          usdtMap,
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
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${displayDate.toCustomString()} ${l10n(context).strategy}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.deepPurple),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strategy['summary'] ?? '',
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
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
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FA),
      appBar: AppBar(
        title: Text(
          widget.simulationType == SimulationType.kimchi
              ? l10n(context).gimchBaseTrade
              : l10n(context).aiBaseTrade,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
        actions:
            widget.simulationType == SimulationType.kimchi
                ? [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.deepPurple),
                    tooltip: l10n(context).changeStrategy,
                    onPressed: () async {
                      final success =
                          await SimulationPage.showKimchiStrategyUpdatePopup(
                            context,
                            showSameDatesAsAI: true,
                            showUseTrend: true,
                          );
                      if (success) {
                        runSimulation();
                      }
                    },
                  ),
                ]
                : null,
      ),
      body: SafeArea(
        child:
            loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(child: Text('${l10n(context).error}: $error'))
                : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18.0,
                          horizontal: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.deepPurple.withOpacity(0.05),
                                    Colors.deepPurple.withOpacity(0.02),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.deepPurple.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    SimulationType.ai == widget.simulationType
                                        ? Icons.psychology
                                        : Icons.trending_up,
                                    color: Colors.deepPurple,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      SimulationType.ai == widget.simulationType
                                          ? AppLocalizations.of(
                                            context,
                                          )!.aiTradingSimulation
                                          : AppLocalizations.of(
                                            context,
                                          )!.gimchTradingSimulation,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...results.map(
                              (r) => Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.white, Colors.grey[100]!],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(
                                        0.05,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.deepPurple.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.withOpacity(
                                            0.03,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.deepPurple
                                                .withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${l10n(context).buy}→${r.buyDate?.toCustomString()}\n${l10n(context).sell}→${r.sellDate?.toCustomString() ?? l10n(context).unFilled}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2), // ← 간격 줄이기
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.green
                                                      .withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.trending_up,
                                                    color: Colors.green,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      '${l10n(context).buy}: ${krwFormat.format(r.buyPrice)}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          setupStretegyButton(
                                            context,
                                            r.buyDate,
                                          ),
                                        ],
                                      ),
                                      if (r.sellDate != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(
                                                    0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.red
                                                        .withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.trending_down,
                                                      color: Colors.red,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '${l10n(context).sell}: ${krwFormat.format(r.sellPrice!)}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            setupStretegyButton(
                                              context,
                                              r.sellDate!,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.deepPurple.withOpacity(
                                                  0.1,
                                                ),
                                                Colors.deepPurple.withOpacity(
                                                  0.05,
                                                ),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.deepPurple
                                                  .withOpacity(0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '${l10n(context).gain}:',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${krwFormat.format(r.profit.round())} (${r.profitRate.toStringAsFixed(2)})%',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.deepPurple,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '${l10n(context).finalKRW}:',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${krwFormat.format(r.finalKRW.round())}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.deepPurple,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else if (r.finalUSDT != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.orange.withOpacity(0.05),
                                                Colors.orange.withOpacity(0.02),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange.withOpacity(
                                                0.3,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.schedule,
                                                    color: Colors.orange,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '미체결 상태',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.orange,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .account_balance_wallet,
                                                        color: Colors.blue,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '${l10n(context).usdt}:',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    '${r.finalUSDT?.toStringAsFixed(4)} USDT',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.trending_up,
                                                        color: Colors.green,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '${l10n(context).sellIfCurrentPrice}:',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    '${krwFormat.format(r.finalKRW.round())}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80), // 하단 고정 영역과 겹치지 않게 여유 공간
                  ],
                ),
      ),
      bottomNavigationBar: bottomNavigationBar(context),
    );
  }

  SafeArea bottomNavigationBar(BuildContext context) {
    return SafeArea(
      child: SlideTransition(
        position: _bottomBarOffset,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.deepPurple.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              top: 0,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === 늘이기/줄이기 버튼 ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        isCardExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        color: Colors.deepPurple,
                        size: 36,
                      ),
                      onPressed: () {
                        setState(() {
                          isCardExpanded = !isCardExpanded;
                        });
                      },
                      tooltip: isCardExpanded ? '줄이기' : '늘리기',
                    ),
                  ],
                ),
                // === 매매기간 ===
                Row(
                  children: [
                    Text(
                      l10n(context).tradingPerioid,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.show_chart,
                        color: Colors.deepPurple,
                        size: 18,
                      ),
                      label: Text(
                        l10n(context).seeWithChart,
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.deepPurple),
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
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    if (results.isEmpty) return Text(l10n(context).dash);
                    final startDate = results.first.buyDate?.toCustomString();
                    final endDate = results.last.analysisDate.toCustomString();
                    final text = '${startDate} ~ ${endDate}';

                    return Text(
                      text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    );
                  },
                ),
                if (isCardExpanded) ...[
                  const SizedBox(height: 12),

                  // === 누적 최종 원화 ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n(context).stackedFinalKRW,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${krwFormat.format(results.isNotEmpty ? results.last.finalKRW.round() : 1000000)}${l10n(context).currencyWonSuffix}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // === 구분선 ===
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.deepPurple.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // === 총 수익률/연 수익률 강조 ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n(context).totalGain,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.deepPurple.withOpacity(0.05),
                                  Colors.deepPurple.withOpacity(0.02),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.deepPurple.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${(results.isNotEmpty ? (results.last.finalKRW / 1000000 * 100 - 100) : 0).toStringAsFixed(2)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            l10n(context).extimatedYearGain,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Builder(
                            builder: (context) {
                              if (results.isEmpty) {
                                return Text(
                                  l10n(context).dash,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                );
                              }
                              final firstDate = results.first.buyDate;
                              final lastDate = results.last.analysisDate;
                              if (firstDate == null) {
                                return Text(
                                  l10n(context).dash,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                );
                              }
                              final days =
                                  lastDate.difference(firstDate).inDays;
                              if (days < 1) {
                                return Text(
                                  l10n(context).dash,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                );
                              }
                              final years = days / 365.0;
                              final totalReturn =
                                  results.last.finalKRW / 1000000;
                              final annualYield =
                                  (years > 0)
                                      ? (pow(totalReturn, 1 / years) - 1) * 100
                                      : 0.0;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.deepPurple.withOpacity(0.05),
                                      Colors.deepPurple.withOpacity(0.02),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.deepPurple.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${annualYield.isNaN || annualYield.isInfinite ? 0 : annualYield.toStringAsFixed(2)}%',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // === 전체 전략 히스토리 보기 버튼 ===
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
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
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                        ),
                                      ),
                                      child: StrategyHistoryPage(
                                        simulationType: widget.simulationType,
                                        usdExchangeRates:
                                            widget.usdExchangeRates,
                                        usdtMap: widget.usdtMap,
                                        strategies: widget.strategyList,
                                        premiumTrends: widget.premiumTrends,
                                      ),
                                    ),
                              ),
                        );
                      },
                      icon: const Icon(Icons.history, color: Colors.white),
                      label: Text(
                        l10n(context).viewAllStrategyHistory,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  OutlinedButton setupStretegyButton(BuildContext context, DateTime? date) {
    // 버튼 스타일에서 padding, minimumSize 조정
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.deepPurple,
      side: const BorderSide(color: Colors.deepPurple),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // ← 더 얇게
      textStyle: const TextStyle(fontSize: 14),
    );

    return OutlinedButton(
      onPressed: () {
        _showStrategyDialog(context, date!);
      },
      style: buttonStyle,
      child: Text(l10n(context).seeStrategy),
    );
  }

  /// 김치 프리미엄 시뮬레이션 함수
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
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
