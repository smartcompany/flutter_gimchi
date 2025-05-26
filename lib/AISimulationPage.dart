import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  Map<String, double>? usdtHistory;
  List<SimulationResult> results = [];
  bool loading = true;
  String? error;

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

      // 2. USDT 가격 히스토리 가져오기
      final usdtRes = await http.get(Uri.parse(upbitUsdtUrl));
      final usdtMap = json.decode(utf8.decode(usdtRes.bodyBytes));
      if (usdtMap is! Map) throw Exception('USDT 데이터가 맵이 아닙니다.');

      // 날짜 오름차순 정렬
      final sortedDates = usdtMap.keys.toList()..sort();

      // 3. 전략별 시뮬레이션
      List<SimulationResult> simResults = [];
      double initialKRW = 10000000;
      double totalKRW = initialKRW;

      for (final strat in strategyList) {
        final String? date = strat['analysis_date'];
        final double? buyPrice = _toDouble(strat['buy_price']);
        final double? sellPrice = _toDouble(strat['sell_price']);
        if (date == null || buyPrice == null || sellPrice == null) continue;

        // 매수: 해당 날짜 이후 buyPrice 이하가 처음 등장하는 날짜
        String? buyDate;
        for (final d in sortedDates.where((d) => d.compareTo(date) >= 0)) {
          final price = _toDouble(usdtMap[d]);
          if (price != null && price <= buyPrice) {
            buyDate = d;
            break;
          }
        }
        if (buyDate == null) continue; // 매수 불가

        // 매도: 매수일 이후 sellPrice 이상이 처음 등장하는 날짜
        String? sellDate;
        for (final d in sortedDates.where((d) => d.compareTo(buyDate) > 0)) {
          final price = _toDouble(usdtMap[d]);
          if (price != null && price >= sellPrice) {
            sellDate = d;
            break;
          }
        }
        if (sellDate == null) continue; // 매도 불가

        final buyPriceActual = _toDouble(usdtMap[buyDate]);
        final sellPriceActual = _toDouble(usdtMap[sellDate]);
        if (buyPriceActual == null || sellPriceActual == null) continue;

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
        usdtHistory = Map<String, double>.fromEntries(
          usdtMap.entries.map((e) => MapEntry(e.key, _toDouble(e.value) ?? 0)),
        );
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
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(child: Text('에러: $error'))
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child:
                    results.isEmpty
                        ? const Text('시뮬레이션 결과가 없습니다.')
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI 전략 실전 수익 시뮬레이션',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (context, idx) {
                                  final r = results[idx];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        '${r.analysisDate} 매수→${r.buyDate} / 매도→${r.sellDate}',
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '매수: ${r.buyPrice.toStringAsFixed(2)}원, 매도: ${r.sellPrice.toStringAsFixed(2)}원',
                                          ),
                                          Text(
                                            '실현 수익: ${r.profitRate.toStringAsFixed(2)}% (${r.profit.toStringAsFixed(0)}원)',
                                          ),
                                          Text(
                                            '최종 원화: ${r.finalKRW.toStringAsFixed(0)}원',
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '누적 최종 원화: ${results.isNotEmpty ? results.last.finalKRW.toStringAsFixed(0) : '-'}원',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
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
