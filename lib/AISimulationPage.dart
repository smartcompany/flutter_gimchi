import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const int days = 200;
const String upbitUsdtUrl =
    "https://rate-history.vercel.app/api/usdt-history?days=$days";
const String strategyUrl =
    "https://rate-history.vercel.app/api/analyze-strategy";

class AISimulationPage extends StatefulWidget {
  const AISimulationPage({super.key});

  static List<SimulationResult> simulateResults(
    List strategyList,
    Map usdtMap,
  ) {
    return _AISimulationPageState.simulateResults(strategyList, usdtMap);
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
      final strategyRes = await http.get(Uri.parse(strategyUrl));
      final strategyList = json.decode(utf8.decode(strategyRes.bodyBytes));
      if (strategyList is! List) throw Exception('전략 데이터가 배열이 아닙니다.');

      final usdtRes = await http.get(Uri.parse(upbitUsdtUrl));
      final usdtMap = json.decode(utf8.decode(usdtRes.bodyBytes));
      if (usdtMap is! Map) throw Exception('USDT 데이터가 맵이 아닙니다.');

      final simResults = simulateResults(strategyList, usdtMap);

      setState(() {
        strategies = List<Map<String, dynamic>>.from(strategyList);
        results = simResults;
        loading = false;
      });
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

      if (buyStrategyPrice == null || sellStrategyPrice == null) {
        continue;
      }

      if (buyDate == null && sellDate == null) {
        final low = _toDouble(usdtMap[date]?['low']);
        if (low != null && low <= buyStrategyPrice) {
          buyDate = date;
          buyPrice = buyStrategyPrice;
        }
        if (buyDate == null) continue;
      }

      final high = _toDouble(usdtMap[date]?['high']) ?? 0;
      final open = _toDouble(usdtMap[date]?['open']) ?? 0;
      final close = _toDouble(usdtMap[date]?['close']) ?? 0;
      final canSell = (buyDate == date) ? (open < close) : true;

      if (canSell && high >= sellStrategyPrice) {
        sellDate = date;
        final sellPrice = sellStrategyPrice;

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
                  const Text('해당 날짜에 대한 전략이 없습니다.'),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      textStyle: const TextStyle(fontSize: 14),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FA),
      appBar: AppBar(
        title: const Text(
          'AI 매매 전략 시뮬레이션',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
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
                            const Text(
                              'AI 시뮬레이션 (100 만원 기준)',
                              style: TextStyle(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimulationResult {
  final String analysisDate;
  final String buyDate;
  final double buyPrice;
  final String? sellDate; // 매도하지 못한 경우 null
  final double? sellPrice; // 매도하지 못한 경우 null
  final double profit;
  final double profitRate;
  final double finalKRW;
  final double? finalUSDT; // USDT 보유량 추가

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
