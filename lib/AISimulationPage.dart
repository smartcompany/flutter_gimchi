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

  @override
  State<AISimulationPage> createState() => _AISimulationPageState();
}

class _AISimulationPageState extends State<AISimulationPage> {
  List<Map<String, dynamic>>? strategies;
  List<SimulationResult> results = [];
  bool loading = true;
  String? error;

  final NumberFormat krwFormat = NumberFormat("#,##0", "ko_KR");
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
      // 1. 전략 데이터 가져오기
      final strategyRes = await http.get(Uri.parse(strategyUrl));
      final strategyList = json.decode(utf8.decode(strategyRes.bodyBytes));
      if (strategyList is! List) throw Exception('전략 데이터가 배열이 아닙니다.');

      // 날짜 오름차순 정렬
      strategyList.sort((a, b) {
        final dateA = a['analysis_date'];
        final dateB = b['analysis_date'];
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

      // 2. USDT 가격 히스토리 가져오기
      final usdtRes = await http.get(Uri.parse(upbitUsdtUrl));
      final usdtMap = json.decode(utf8.decode(usdtRes.bodyBytes));
      if (usdtMap is! Map) throw Exception('USDT 데이터가 맵이 아닙니다.');

      // 날짜 오름차순 정렬
      final sortedDates = usdtMap.keys.toList()..sort();
      // 3. 전략별 시뮬레이션
      List<SimulationResult> simResults = [];
      double initialKRW = 1000000; // 100만원으로 변경
      double totalKRW = initialKRW;

      for (final strat in strategyList) {
        final String? date = strat['analysis_date'];
        final double? buyPrice = _toDouble(strat['buy_price']);
        final double? sellPrice = _toDouble(strat['sell_price']);
        if (date == null || buyPrice == null || sellPrice == null) continue;
        print(
          'Running strategy for $date: buyPrice=$buyPrice, sellPrice=$sellPrice',
        );

        // 매수: 해당 날짜 이후 buyPrice 이하가 처음 등장하는 날짜 (저가 기준)
        String? buyDate;
        for (final d in sortedDates.where((d) => d.compareTo(date) >= 0)) {
          final dayData = usdtMap[d];
          final low = _toDouble(dayData?['low']);
          print(
            'Checking buy condition for $date: low=$low, buyPrice=$buyPrice',
          );

          if (low != null && low <= buyPrice) {
            buyDate = d;
            break;
          }
        }
        if (buyDate == null) {
          print('Skipping strategy due to missing buyDate for $date');
          continue;
        }

        // 매도: 매수일 이후 sellPrice 이상이 처음 등장하는 날짜 (고가 기준)
        String? sellDate;
        for (final d in sortedDates.where((d) => d.compareTo(buyDate) > 0)) {
          final dayData = usdtMap[d];
          final high = _toDouble(dayData?['high']);
          print(
            'Checking sell condition for $buyDate: high=$high, sellPrice=$sellPrice',
          );
          if (high != null && high >= sellPrice) {
            sellDate = d;
            print('Sell condition met: sellDate=$sellDate');
            break;
          }
        }
        if (sellDate == null) {
          print('Skipping strategy due to missing sellDate for $buyDate');
          continue;
        }

        final buyPriceActual = _toDouble(usdtMap[buyDate]?['low']);
        final sellPriceActual = _toDouble(usdtMap[sellDate]?['high']);
        if (buyPriceActual == null || sellPriceActual == null) {
          print(
            'Skipping strategy due to null prices: buyPriceActual=$buyPriceActual, sellPriceActual=$sellPriceActual',
          );
          continue;
        }

        final usdtAmount = totalKRW / buyPriceActual;
        final finalKRW = usdtAmount * sellPriceActual;
        final profit = finalKRW - totalKRW;
        final profitRate = profit / totalKRW * 100;

        simResults.add(
          SimulationResult(
            analysisDate: date,
            buyDate: buyDate,
            buyPrice: buyPriceActual,
            sellDate: sellDate,
            sellPrice: sellPriceActual,
            profit: profit,
            profitRate: profitRate,
            finalKRW: finalKRW,
          ),
        );

        totalKRW = finalKRW; // 누적 투자금 갱신(복리)
      }

      setState(() {
        strategies = List<Map<String, dynamic>>.from(strategyList);
        results = simResults;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 수익 시뮬레이션')),
      body: SafeArea(
        child:
            loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(child: Text('에러: $error'))
                : ListView(
                  // SafeArea 내부에서 ListView를 직접 사용
                  padding: const EdgeInsets.all(16.0), // ListView에 Padding 추가
                  children: [
                    const Text(
                      'AI 전략 실전 수익 시뮬레이션',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...results.map(
                      (r) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                            '${r.analysisDate} 매수→${r.buyDate} / 매도→${r.sellDate}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '매수: ${krwFormat.format(r.buyPrice)}원, 매도: ${krwFormat.format(r.sellPrice)}원',
                              ),
                              Text(
                                '실현 수익: ${r.profitRate.toStringAsFixed(2)}% (${krwFormat.format(r.profit.round())}원)',
                              ),
                              Text(
                                '최종 원화: ${krwFormat.format(r.finalKRW.round())}원',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '누적 최종 원화:',
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
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '총 수익률:',
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class SimulationResult {
  final String analysisDate;
  final String buyDate;
  final double buyPrice;
  final String sellDate;
  final double sellPrice;
  final double profit;
  final double profitRate;
  final double finalKRW;

  SimulationResult({
    required this.analysisDate,
    required this.buyDate,
    required this.buyPrice,
    required this.sellDate,
    required this.sellPrice,
    required this.profit,
    required this.profitRate,
    required this.finalKRW,
  });
}
