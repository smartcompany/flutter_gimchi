import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:usdt_signal/api_service.dart';

enum SimulationType { ai, kimchi }

class AISimulationPage extends StatefulWidget {
  final SimulationType simulationType;
  const AISimulationPage({super.key, required this.simulationType});

  // 외부에서 참조 가능한 static 변수로 변경
  static int kimchiBuyThreshold = 1;
  static int kimchiSellThreshold = 3;

  static List<SimulationResult> simulateResults(
    List strategyList,
    Map usdtMap,
  ) {
    return _AISimulationPageState.simulateResults(strategyList, usdtMap);
  }

  static Future<List<SimulationResult>> gimchiSimulateResults(
    List<ChartData> usdExchangeRates,
    Map usdtMap,
  ) {
    return _AISimulationPageState.gimchiSimulateResults(
      usdExchangeRates,
      usdtMap,
    );
  }

  @override
  State<AISimulationPage> createState() => _AISimulationPageState();
}

class _AISimulationPageState extends State<AISimulationPage> {
  List<Map<String, dynamic>>? strategies;
  List<SimulationResult> results = [];
  bool loading = true;
  String? error;

  // 소수점 4자리까지 표시하는 포맷
  final NumberFormat krwFormat = NumberFormat("#,##0.#", "ko_KR");
  double totalProfitRate = 0; // 총 수익률 변수 추가

  ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    runSimulation();
  }

  Future<void> runSimulation() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final usdtMap = await apiService.fetchUSDTData();

      if (widget.simulationType == SimulationType.ai) {
        final strategyList = await apiService.fetchStrategy();
        final simResults = simulateResults(strategyList ?? [], usdtMap);

        setState(() {
          strategies = List<Map<String, dynamic>>.from(strategyList ?? []);
          results = simResults;
          loading = false;
        });
      } else if (widget.simulationType == SimulationType.kimchi) {
        final usdExchangeRates = await apiService.fetchExchangeRateData();
        final simResults = await gimchiSimulateResults(
          usdExchangeRates,
          usdtMap,
          buyThreshold: AISimulationPage.kimchiBuyThreshold,
          sellThreshold: AISimulationPage.kimchiSellThreshold,
        );

        setState(() {
          strategies = null;
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
  static List<MapEntry<String, dynamic>> getEntriesFromDate(
    Map<String, dynamic> usdtMap,
    String startDate,
  ) {
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
    List strategyList,
    Map usdtMap,
  ) {
    // 날짜 오름차순 정렬
    strategyList.sort((a, b) {
      final dateA = a['analysis_date'];
      final dateB = b['analysis_date'];
      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });

    final Map<String, Map<String, dynamic>> strategyMap = {
      for (var strat in strategyList)
        if (strat['analysis_date'] != null) strat['analysis_date']: strat,
    };

    List<SimulationResult> simResults = [];
    double initialKRW = 1000000;
    double totalKRW = initialKRW;
    SimulationResult? unselledResult;

    String? sellDate;
    String? buyDate;

    String strategyDate = strategyList.first['analysis_date'];
    final filteredEntries = getEntriesFromDate(
      usdtMap.cast<String, dynamic>(),
      strategyDate,
    );

    Map<String, dynamic>? strategy = strategyMap[strategyDate];
    double buyPrice = 0;

    for (final entry in filteredEntries) {
      final String date = entry.key;
      final newStrategy = strategyMap[date];
      if (newStrategy != null) {
        strategy = newStrategy;
        strategyDate = date;
      }

      final double? buyStrategyPrice = _toDouble(strategy?['buy_price']);
      final double? sellStrategyPrice = _toDouble(strategy?['sell_price']);
      final lowPrice = _toDouble(usdtMap[date]?['low']) ?? 0;
      final highPrice = _toDouble(usdtMap[date]?['high']) ?? 0;

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

      final high = _toDouble(usdtMap[date]?['high']) ?? 0;
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
        );

        buyDate = null;
        sellDate = null;
        unselledResult = null;
      } else {
        final usdtPrice = _toDouble(usdtMap[date]?['close']);
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
        );
      }
    }

    if (unselledResult != null) {
      simResults.add(unselledResult);
    }

    return simResults;
  }

  static double addResultCard(
    String sellDate,
    String date,
    double buyPrice,
    double? sellPrice,
    double totalKRW,
    List<SimulationResult> simResults,
    String? buyDate,
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
        profit: profit ?? 0,
        profitRate: profitRate ?? 0,
        finalKRW: finalKRW ?? 0,
        finalUSDT: null,
      ),
    );
    return totalKRW;
  }

  static Future<List<SimulationResult>> gimchiSimulateResults(
    List<ChartData> usdExchangeRates,
    Map usdtMap, {
    int buyThreshold = 1,
    int sellThreshold = 3,
  }) async {
    List<SimulationResult> simResults = [];
    double initialKRW = 1000000;
    double totalKRW = initialKRW;
    SimulationResult? unselledResult;

    String sellDate = "";
    String buyDate = "";
    double? buyPrice;
    double? sellPrice;
    // 날짜 오름차순 정렬
    final sortedDates = usdtMap.keys.toList()..sort();
    final usdExchangeRatesMap = {
      for (var rate in usdExchangeRates)
        DateFormat('yyyy-MM-dd').format(rate.time): rate.value,
    };

    for (final date in sortedDates) {
      final usdtDay = usdtMap[date];
      final usdExchangeRate = usdExchangeRatesMap[date] ?? 0.0;
      final usdtLow = _toDouble(usdtDay['low']) ?? 0.0;
      final usdtHigh = _toDouble(usdtDay['high']) ?? 0.0;
      final buyTargetPrice = usdExchangeRate * (1 + buyThreshold / 100);
      final sellTargetPrice = usdExchangeRate * (1 + sellThreshold / 100);

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
        final kimchiValue =
            (sellPrice - usdExchangeRate) / usdExchangeRate * 100; // 김프 계산

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
            kimchiPremium: kimchiValue, // ← 해당 날짜의 김프 값
          ),
        );

        // 다음 거래를 위해 초기화 (복리)
        totalKRW = finalKRW;
        buyDate = "";
        buyPrice = null;
        sellPrice = null;
        unselledResult = null;
      } else {
        final usdtPrice = _toDouble(usdtMap[date]?['close']);
        final usdtCount = totalKRW / buyPrice;
        final finalKRW = usdtCount * (usdtPrice ?? 0);
        final kimchiValue =
            (buyPrice - usdExchangeRate) / usdExchangeRate * 100;

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
          kimchiPremium: kimchiValue,
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
    date,
    String buyDate,
  ) {
    final open = _toDouble(usdtMap[date]?['open']) ?? 0;
    final close = _toDouble(usdtMap[date]?['close']) ?? 0;
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

  void _showStrategyDialog(BuildContext context, String date) {
    final strategy = strategies?.firstWhere(
      (s) => s['analysis_date'] == date,
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
                      '$date 전략',
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
                if (strategy != null && strategy.isNotEmpty) ...[
                  _StrategyDialogRow(
                    label: '매수 가격',
                    value: '${strategy['buy_price']}',
                  ),
                  _StrategyDialogRow(
                    label: '매도 가격',
                    value: '${strategy['sell_price']}',
                  ),
                  _StrategyDialogRow(
                    label: '기대 수익률',
                    value: '${strategy['expected_return']}',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '요약',
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
                        ? '김치 프리미엄이 1% 이하일 때 매수, 3% 이상일 때 매도 전략입니다.'
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
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.deepPurple,
      side: const BorderSide(color: Colors.deepPurple),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      minimumSize: const Size(0, 16),
      textStyle: const TextStyle(fontSize: 14),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FA),
      appBar: AppBar(
        title: Text(
          widget.simulationType == SimulationType.kimchi
              ? '김프 매매 시뮬레이션'
              : 'AI 매매 시뮬레이션',
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
                    tooltip: '전략 변경',
                    onPressed: () async {
                      final result = await showDialog<Map<String, int>>(
                        context: context,
                        builder: (context) {
                          int buy = AISimulationPage.kimchiBuyThreshold;
                          int sell = AISimulationPage.kimchiSellThreshold;
                          return AlertDialog(
                            title: const Text('김프 전략 변경'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const Text('매수 기준(%)'),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: buy.toString(),
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        onChanged: (v) {
                                          final n = int.tryParse(v);
                                          if (n != null && n >= -10 && n <= 10)
                                            buy = n;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Text('매도 기준(%)'),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: sell.toString(),
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        onChanged: (v) {
                                          final n = int.tryParse(v);
                                          if (n != null && n >= -10 && n <= 10)
                                            sell = n;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('취소'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                  ).pop({'buy': buy, 'sell': sell});
                                },
                                child: const Text('확인'),
                              ),
                            ],
                          );
                        },
                      );
                      if (result != null) {
                        setState(() {
                          AISimulationPage.kimchiBuyThreshold = result['buy']!;
                          AISimulationPage.kimchiSellThreshold =
                              result['sell']!;
                          runSimulation(); // 기준 변경 후 시뮬레이션 재실행
                        });
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
                                  ? 'AI 매매 시뮬레이션 (100 만원 기준)'
                                  : '김프 매매 시뮬레이션 (100 만원 기준)',
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
                                        '매수→${r.buyDate} / 매도→${r.sellDate ?? "미체결"}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            '매수: ${krwFormat.format(r.buyPrice)}원',
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            onPressed: () {
                                              _showStrategyDialog(
                                                context,
                                                r.buyDate,
                                              );
                                            },
                                            style: buttonStyle,
                                            child: const Text('전략 보기'),
                                          ),
                                        ],
                                      ),
                                      if (r.sellDate != null) ...[
                                        Row(
                                          children: [
                                            Text(
                                              '매도: ${krwFormat.format(r.sellPrice!)}원',
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton(
                                              onPressed: () {
                                                _showStrategyDialog(
                                                  context,
                                                  r.sellDate!,
                                                );
                                              },
                                              style: buttonStyle,
                                              child: const Text('전략 보기'),
                                            ),
                                          ],
                                        ),
                                        // 수익률 계산
                                        const SizedBox(height: 6),
                                        Text(
                                          '수익: ${krwFormat.format(r.profit.round())}원 (${r.profitRate.toStringAsFixed(2)})%',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '최종 원화: ${krwFormat.format(r.finalKRW.round())}원',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ] else if (r.finalUSDT != null) ...[
                                        Text(
                                          '최종 USDT: ${r.finalUSDT?.toStringAsFixed(4)} USDT',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '현재가 매도시: ${krwFormat.format(r.finalKRW.round())}원',
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
        child: Card(
          elevation: 2,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '매매 기간',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // 시작일과 종료일 표시
                Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final text =
                            results.isEmpty
                                ? '-'
                                : '${results.first.analysisDate} ~ ${results.last.analysisDate}';

                        return Text(
                          text,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                          softWrap: true,
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '누적 최종 원화',
                      style: TextStyle(
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
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '총 수익률',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(results.isNotEmpty ? (results.last.finalKRW / 1000000 * 100 - 100) : 0).toStringAsFixed(2)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                // === 추정 연 수익률 ===
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '추정 연 수익률',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        if (results.isEmpty) return const Text('-');
                        final firstDate = results.first.buyDate;
                        final lastDate = results.last.analysisDate;
                        final start = DateTime.tryParse(firstDate);
                        final end = DateTime.tryParse(lastDate);
                        if (start == null || end == null)
                          return const Text('-');
                        final days = end.difference(start).inDays;
                        if (days < 1) return const Text('-');
                        final years = days / 365.0;
                        final totalReturn = results.last.finalKRW / 1000000;
                        // 연복리 수익률 공식: (최종/초기)^(1/years) - 1
                        final annualYield =
                            (years > 0)
                                ? (pow(totalReturn, 1 / years) - 1) * 100
                                : 0.0;
                        return Text(
                          '${annualYield.isNaN || annualYield.isInfinite ? 0 : annualYield.toStringAsFixed(2)}%',
                          style: const TextStyle(
                            fontSize: 16,
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
          ),
        ),
      ),
    );
  }

  /// 김치 프리미엄 시뮬레이션 함수
}

class SimulationResult {
  final String analysisDate;
  final String buyDate;
  final double buyPrice;
  final String? sellDate;
  final double? sellPrice;
  final double profit;
  final double profitRate;
  final double finalKRW;
  final double? finalUSDT;
  final double? kimchiPremium; // ← 김프 값 추가

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
    this.kimchiPremium, // ← 생성자에 추가
  });
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
