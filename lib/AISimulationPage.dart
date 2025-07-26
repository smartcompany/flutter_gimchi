import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usdt_signal/ChartOnlyPage.dart'; // ChartOnlyPageModel import 추가
import 'package:usdt_signal/api_service.dart';
import 'package:usdt_signal/l10n/app_localizations.dart';
import 'utils.dart';

enum SimulationType { ai, kimchi }

class AISimulationPage extends StatefulWidget {
  final SimulationType simulationType;
  final Map<DateTime, USDTChartData> usdtMap;
  final List<StrategyMap> strategyList;
  final List<ChartData> usdExchangeRates;

  // ChartOnlyPageModel을 직접 받는 생성자 추가
  final ChartOnlyPageModel? chartOnlyPageModel;

  const AISimulationPage({
    super.key,
    required this.simulationType,
    required this.usdtMap,
    required this.strategyList,
    required this.usdExchangeRates,
    this.chartOnlyPageModel,
  });

  static List<SimulationResult> simulateResults(
    List<ChartData> usdExchangeRates,
    List<StrategyMap> strategyList,
    Map<DateTime, USDTChartData> usdtMap,
  ) {
    return _AISimulationPageState.simulateResults(
      usdExchangeRates,
      strategyList,
      usdtMap,
    );
  }

  static List<SimulationResult> gimchiSimulateResults(
    List<ChartData> usdExchangeRates,
    List<StrategyMap> strategyList,
    Map<DateTime, USDTChartData> usdtMap,
  ) {
    return _AISimulationPageState.gimchiSimulateResults(
      usdExchangeRates,
      strategyList,
      usdtMap,
    );
  }

  static Future<bool> showKimchiStrategyUpdatePopup(
    BuildContext context, {
    bool showSameDatesAsAI = false,
  }) async {
    final result = await showDialog<Map<String, Object>>(
      context: context,
      builder: (context) {
        double buy = SimulationCondition.instance.kimchiBuyThreshold;
        double sell = SimulationCondition.instance.kimchiSellThreshold;
        bool sameAsAI = SimulationCondition.instance.matchSameDatesAsAI;

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
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n(context).cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop({'buy': buy, 'sell': sell, 'sameAsAI': sameAsAI});
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

      final isSuccess = await ApiService.saveAndSyncUserData({
        UserDataKey.gimchiBuyPercent: buy,
        UserDataKey.gimchiSellPercent: sell,
      });

      if (isSuccess) {
        await SimulationCondition.instance.saveKimchiBuyThreshold(buy);
        await SimulationCondition.instance.saveKimchiSellThreshold(sell);
        await SimulationCondition.instance.saveMatchSameDatesAsAI(sameAsAI);
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
  State<AISimulationPage> createState() => _AISimulationPageState();
}

class _AISimulationPageState extends State<AISimulationPage>
    with SingleTickerProviderStateMixin {
  List<StrategyMap>? strategies;
  List<SimulationResult> results = [];
  bool loading = true;
  String? error;

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
        final simResults = simulateResults(
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
        final simResults = gimchiSimulateResults(
          usdExchangeRates,
          strategyList,
          usdtMap,
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

  // 특정 날짜부터 usdtMap 데이터를 조회하는 함수
  static List<MapEntry<DateTime, dynamic>> getEntriesFromDate(
    Map<DateTime, dynamic> usdtMap,
    DateTime? startDate,
  ) {
    if (startDate == null) {
      // startDate가 null인 경우 전체 데이터를 반환
      return usdtMap.entries.toList();
    }

    // 날짜 오름차순 정렬
    final sortedEntries =
        usdtMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    // 특정 날짜 이후의 데이터 필터링
    return sortedEntries
        .where((entry) => entry.key.compareTo(startDate) >= 0)
        .toList();
  }

  // simResults 생성 로직을 별도 함수로 분리
  static List<SimulationResult> simulateResults(
    List<ChartData> usdExchangeRates, // ← 추가
    List<StrategyMap> strategyList,
    Map<DateTime, USDTChartData> usdtMap,
  ) {
    // 날짜 오름차순 정렬
    strategyList.sort((a, b) {
      final dateA = a['analysis_date'];
      final dateB = b['analysis_date'];
      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });

    final Map<DateTime, StrategyMap> strategyMap = {
      for (var strat in strategyList)
        if (strat['analysis_date'] != null)
          DateTime.parse(strat['analysis_date']): strat,
    };

    // 2. usdExchangeRateMap 생성
    final usdExchangeRateMap = {
      for (var rate in usdExchangeRates) rate.time: rate.value,
    };

    List<SimulationResult> simResults = [];
    double initialKRW = 1000000;
    double totalKRW = initialKRW;
    SimulationResult? unselledResult;

    DateTime? sellDate;
    DateTime? buyDate;
    DateTime? strategyDate = DateTime.parse(
      strategyList.first['analysis_date'],
    );

    final filteredEntries = getEntriesFromDate(usdtMap, strategyDate);

    Map<String, dynamic>? strategy = strategyMap[strategyDate];
    double buyPrice = 0;

    for (final entry in filteredEntries) {
      final date = entry.key;
      final newStrategy = strategyMap[date];
      if (newStrategy != null) {
        strategy = newStrategy;
        strategyDate = date;
      }

      final double? buyStrategyPrice = _toDouble(strategy?['buy_price']);
      final double? sellStrategyPrice = _toDouble(strategy?['sell_price']);
      final lowPrice = usdtMap[date]?.low ?? 0;
      final highPrice = usdtMap[date]?.high ?? 0;

      if (buyStrategyPrice == null || sellStrategyPrice == null) {
        continue;
      }

      if (buyDate == null && sellDate == null) {
        if (lowPrice <= buyStrategyPrice) {
          buyDate = date;
          // 매수 예상가가 고가 보다 낮은 경우는 고가로 매수가 현실적
          buyPrice = min(buyStrategyPrice, highPrice);
        }
        if (buyDate == null) continue;
      }

      final high = usdtMap[date]?.high ?? 0;
      final canSell = isSellCondition(usdtMap, date, buyDate!);

      if (canSell && high >= sellStrategyPrice) {
        sellDate = date;

        // 매도 예상가가 저가 보다 높은 경우는 저가로 매도가 현실적
        final sellPrice = max(sellStrategyPrice, lowPrice);

        totalKRW = addResultCard(
          sellDate,
          date,
          buyPrice,
          sellPrice,
          totalKRW,
          simResults,
          buyDate,
          usdExchangeRateMap, // ← 추가
        );

        buyDate = null;
        sellDate = null;
        unselledResult = null;
      } else {
        final usdtPrice = usdtMap[date]?.close;
        final usdtCount = totalKRW / buyPrice;
        final finalKRW = usdtCount * (usdtPrice ?? 0);

        unselledResult = SimulationResult(
          analysisDate: date,
          buyDate: buyDate!,
          buyPrice: buyPrice,
          sellDate: null,
          sellPrice: null,
          profit: 0,
          profitRate: 0,
          finalKRW: finalKRW,
          finalUSDT: usdtCount,
          usdExchangeRateAtBuy: usdExchangeRateMap[buyDate], // ← 추가
          usdExchangeRateAtSell: null, // 매도 시점은 아직 없음
        );
      }
    }

    if (unselledResult != null) {
      simResults.add(unselledResult);
    }

    return simResults;
  }

  static double addResultCard(
    DateTime sellDate,
    DateTime date,
    double buyPrice,
    double? sellPrice,
    double totalKRW,
    List<SimulationResult> simResults,
    DateTime? buyDate,
    Map<DateTime, double> usdExchangeRateMap, // ← 추가
  ) {
    print('Sell condition met: sellDate=$sellDate anaysisDate=$date');

    double usdtAmount = totalKRW / buyPrice;
    double? finalKRW;
    double? profit;
    double? profitRate;

    finalKRW = usdtAmount * (sellPrice ?? 0); // 매도 시 최종 원화 계산
    profit = finalKRW - totalKRW;
    profitRate = profit / totalKRW * 100;
    totalKRW = finalKRW; // 누적 투자금 갱신(복리)
    print(
      'Transaction complete: finalKRW=$finalKRW, profit=$profit, profitRate=$profitRate',
    );

    simResults.add(
      SimulationResult(
        analysisDate: date,
        buyDate: buyDate!,
        buyPrice: buyPrice,
        sellDate: sellDate,
        sellPrice: sellPrice,
        profit: profit,
        profitRate: profitRate,
        finalKRW: finalKRW,
        finalUSDT: null,
        usdExchangeRateAtBuy: usdExchangeRateMap[buyDate], // ← 추가
        usdExchangeRateAtSell: usdExchangeRateMap[sellDate], // ← 추가
      ),
    );
    return totalKRW;
  }

  static List<SimulationResult> gimchiSimulateResults(
    List<ChartData> usdExchangeRates,
    List<StrategyMap> strategyList,
    Map<DateTime, USDTChartData> usdtMap,
  ) {
    List<SimulationResult> simResults = [];
    double initialKRW = 1000000;
    double totalKRW = initialKRW;
    SimulationResult? unselledResult;

    DateTime? sellDate;
    DateTime? buyDate;
    double? buyPrice;
    double? sellPrice;

    // 날짜 오름차순 정렬
    final sortedDates = usdtMap.keys.toList()..sort();

    // 날짜 오름차순 정렬
    strategyList.sort((a, b) {
      final dateA = a['analysis_date'];
      final dateB = b['analysis_date'];
      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });

    if (SimulationCondition.instance.matchSameDatesAsAI) {
      final strategyFirstDate = DateTime.parse(
        strategyList.first['analysis_date'],
      );
      sortedDates.removeWhere((date) => date.compareTo(strategyFirstDate) < 0);
    }

    final usdExchangeRatesMap = {
      for (var rate in usdExchangeRates) rate.time: rate.value,
    };

    for (final date in sortedDates) {
      final usdtDay = usdtMap[date];
      final usdExchangeRate = usdExchangeRatesMap[date] ?? 0.0;
      final usdtLow = usdtDay?.low ?? 0.0;
      final usdtHigh = usdtDay?.high ?? 0.0;
      final buyTargetPrice =
          usdExchangeRate *
          (1 + SimulationCondition.instance.kimchiBuyThreshold / 100);
      final sellTargetPrice =
          usdExchangeRate *
          (1 + SimulationCondition.instance.kimchiSellThreshold / 100);

      // 매수 조건: 프리미엄 buyThreshold% 미만, 아직 매수 안한 상태
      if (buyPrice == null) {
        // 매도 대기 상태가 아니어야 매수
        if (sellPrice == null) {
          if (buyTargetPrice >= usdtLow) {
            // 100원에 매수 하려고 했는데 고가가 90원이라면 그냥 90원에 매수 하겠지
            buyPrice = min(buyTargetPrice, usdtHigh);
            buyDate = date;

            print(
              'Buy condition met: buyDate=$buyDate, buyPrice=$buyPrice, buyTargetPrice=$buyTargetPrice, usdtLow=$usdtLow',
            );
          }
        }
      }

      if (buyPrice == null) continue;

      bool canSell = isSellCondition(usdtMap, date, buyDate);

      // 매도 조건: 프리미엄 sellThreshold% 초과, 이미 매수한 상태
      if (canSell && sellTargetPrice <= usdtHigh) {
        sellDate = date;
        // 매도 가격이 100원인데 저가가 110원 이면 그냥 110원에 매도 그래서 둘중 높은값
        sellPrice = max(sellTargetPrice, usdtLow);
        print(
          'Sell condition met: sellDate=$sellDate, buyDate=$buyDate, buyPrice=$buyPrice, sellPrice=$sellPrice',
        );

        // 수익 계산
        final usdtAmount = totalKRW / buyPrice;
        final finalKRW = usdtAmount * sellPrice;
        final profit = finalKRW - totalKRW;
        final profitRate = profit / totalKRW * 100;

        simResults.add(
          SimulationResult(
            analysisDate: date,
            buyDate: buyDate,
            buyPrice: buyPrice,
            sellDate: sellDate,
            sellPrice: sellPrice,
            profit: profit,
            profitRate: profitRate,
            finalKRW: finalKRW,
            finalUSDT: null,
            usdExchangeRateAtBuy: usdExchangeRatesMap[buyDate], // ← 추가
            usdExchangeRateAtSell: usdExchangeRatesMap[sellDate], // ← 추가
          ),
        );

        // 다음 거래를 위해 초기화 (복리)
        totalKRW = finalKRW;
        buyDate = null;
        buyPrice = null;
        sellPrice = null;
        unselledResult = null;
      } else {
        final usdtPrice = usdtMap[date]?.close;
        final usdtCount = totalKRW / buyPrice;
        final finalKRW = usdtCount * (usdtPrice ?? 0);

        unselledResult = SimulationResult(
          analysisDate: date,
          buyDate: buyDate!,
          buyPrice: buyPrice,
          sellDate: null,
          sellPrice: null,
          profit: 0,
          profitRate: 0,
          finalKRW: finalKRW,
          finalUSDT: usdtCount,
          usdExchangeRateAtBuy: usdExchangeRatesMap[buyDate], // ← 추가
          usdExchangeRateAtSell: null, // ← 추가
        );
      }
    }

    if (unselledResult != null) {
      simResults.add(unselledResult);
    }

    return simResults;
  }

  static bool isSellCondition(
    Map<dynamic, dynamic> usdtMap,
    DateTime date,
    DateTime? buyDate,
  ) {
    final open = usdtMap[date]?.open ?? 0;
    final close = usdtMap[date]?.close ?? 0;
    final canSell = (buyDate == date) ? (open < close) : true;

    return canSell;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  void _showStrategyDialog(BuildContext context, DateTime date) {
    final strategy = strategies?.firstWhere(
      (s) => DateTime.parse(s['analysis_date']).isSameDate(date),
      orElse: () => {},
    );

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
                      '${date.toCustomString()} ${l10n(context).strategy}',
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
                          SimulationCondition.instance.kimchiBuyThreshold,
                          SimulationCondition.instance.kimchiSellThreshold,
                        )
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
                          await AISimulationPage.showKimchiStrategyUpdatePopup(
                            context,
                            showSameDatesAsAI: true,
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
                ? Center(child: Text('에러: $error'))
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
                            Text(
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
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...results.map(
                              (r) => Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                color: Colors.grey[50],
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${l10n(context).buy}→${r.buyDate?.toCustomString()}\n${l10n(context).sell}→${r.sellDate?.toCustomString() ?? l10n(context).unFilled}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2), // ← 간격 줄이기
                                      Row(
                                        children: [
                                          Text(
                                            '${l10n(context).buy}: ${krwFormat.format(r.buyPrice)}',
                                          ),
                                          const SizedBox(width: 8),
                                          setupStretegyButton(
                                            context,
                                            r.buyDate,
                                          ),
                                        ],
                                      ),
                                      if (r.sellDate != null) ...[
                                        Row(
                                          children: [
                                            Text(
                                              '${l10n(context).sell}: ${krwFormat.format(r.sellPrice!)}',
                                            ),
                                            const SizedBox(width: 8),
                                            setupStretegyButton(
                                              context,
                                              r.sellDate!,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2), // ← 간격 줄이기
                                        Text(
                                          '${l10n(context).gain}: ${krwFormat.format(r.profit.round())} (${r.profitRate.toStringAsFixed(2)})%',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${l10n(context).finalKRW}: ${krwFormat.format(r.finalKRW.round())}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ] else if (r.finalUSDT != null) ...[
                                        Text(
                                          '${l10n(context).usdt}: ${r.finalUSDT?.toStringAsFixed(4)} USDT',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${l10n(context).sellIfCurrentPrice}: ${krwFormat.format(r.finalKRW.round())}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
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
      bottomNavigationBar: SafeArea(
        child: SlideTransition(
          position: _bottomBarOffset,
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      if (results.isEmpty) return const Text('-');
                      final startDate = results.first.buyDate?.toCustomString();
                      final endDate =
                          results.last.analysisDate.toCustomString();
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
                        '${krwFormat.format(results.isNotEmpty ? results.last.finalKRW.round() : 1000000)}원',
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
                  const Divider(height: 1, thickness: 1, color: Colors.grey),
                  const SizedBox(height: 16),

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
                          Text(
                            '${(results.isNotEmpty ? (results.last.finalKRW / 1000000 * 100 - 100) : 0).toStringAsFixed(2)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: Colors.deepPurple,
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
                                return const Text(
                                  '-',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                );
                              }
                              final firstDate = results.first.buyDate;
                              final lastDate = results.last.analysisDate;
                              if (firstDate == null || lastDate == null) {
                                return const Text(
                                  '-',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                );
                              }
                              final days =
                                  lastDate.difference(firstDate).inDays;
                              if (days < 1) {
                                return const Text(
                                  '-',
                                  style: TextStyle(
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
                              return Text(
                                '${annualYield.isNaN || annualYield.isInfinite ? 0 : annualYield.toStringAsFixed(2)}%',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
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
