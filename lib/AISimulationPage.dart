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

      final Map<String, Map<String, dynamic>> strategyMap = {
        for (var strat in strategyList)
          if (strat['analysis_date'] != null) strat['analysis_date']: strat,
      };

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
      SimulationResult? unselledResult = null;

      String? sellDate = null;
      String? buyDate = null;

      String strategyDate = strategyList.first['analysis_date']; // 조회를 시작할 날짜
      final filteredEntries = getEntriesFromDate(
        usdtMap.cast<String, dynamic>(),
        strategyDate,
      );

      // 필터링된 데이터 출력
      Map<String, dynamic>? strategy = strategyMap[strategyDate];

      for (final entry in filteredEntries) {
        final String date = entry.key;
        final newStrategy = strategyMap[date];
        if (newStrategy != null) {
          strategy = newStrategy; // 새로운 전략으로 업데이트
          strategyDate = date; // 전략 날짜 업데이트
        }

        final double? buyPrice = _toDouble(strategy?['buy_price']);
        final double? sellPrice = _toDouble(strategy?['sell_price']);

        if (buyPrice == null || sellPrice == null) {
          print('Skipping strategy due to missing buy/sell price for $date');
          continue; // 매수/매도 가격이 없으면 건너뜀
        }

        print(
          'Running strategy for $strategyDate: buyPrice=$buyPrice, sellPrice=$sellPrice',
        );

        // 사지도 팔지도 못했을때 전략을 참조해서 매수 시도
        if (buyDate == null && sellDate == null) {
          final low = _toDouble(usdtMap[date]?['low']);
          print(
            'Checking buy condition for $date: low=$low, buyPrice=$buyPrice',
          );

          // 최저가 보다 크면 매수가 됨
          if (low != null && low <= buyPrice) {
            buyDate = date;
            print('Buy condition met: buyDate=$buyDate');
          }

          if (buyDate == null) {
            print('Skipping strategy due to missing buyDate for $date');
            continue;
          }
        }

        // 매도 시도
        final high = _toDouble(usdtMap[date]?['high']);
        print(
          'Checking sell condition anaysisDate=$date high=$high, sellPrice=$sellPrice',
        );

        if (high != null && high >= sellPrice) {
          sellDate = date;
          totalKRW = addResultCard(
            sellDate,
            date,
            buyPrice,
            sellPrice,
            totalKRW,
            simResults,
            buyDate,
          );

          buyDate = null; // 다음 거래를 위해 초기화
          sellDate = null; // 다음 거래를 위해 초기화
          unselledResult = null; // 매도하지 못한 경우 초기화
        } else {
          print(
            'No sellDate found for buyDate=$buyDate anaysisDate=$date Holding USDT.',
          );

          final usdtPrice = _toDouble(usdtMap[date]?['price']);
          final usdtCount = totalKRW / buyPrice; // 현재 보유 USDT 수량
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
            finalUSDT: usdtCount, // USDT 보유량 추가
          );
        }
      }

      // 마지막 단계에서 매도하지 못한 경우 처리
      if (unselledResult != null) {
        simResults.add(unselledResult);
      }

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

  double addResultCard(
    String sellDate,
    String date,
    double buyPrice,
    double sellPrice,
    double totalKRW,
    List<SimulationResult> simResults,
    String? buyDate,
  ) {
    print('Sell condition met: sellDate=$sellDate anaysisDate=$date');

    final buyPriceActual = buyPrice;
    final sellPriceActual = sellPrice;

    double usdtAmount = totalKRW / buyPriceActual;
    double? finalKRW;
    double? profit;
    double? profitRate;

    finalKRW = usdtAmount * sellPriceActual;
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
        buyPrice: buyPriceActual,
        sellDate: sellDate,
        sellPrice: sellPriceActual,
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

  // 특정 날짜부터 usdtMap 데이터를 조회하는 함수
  List<MapEntry<String, dynamic>> getEntriesFromDate(
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

  void _showStrategyDialog(BuildContext context, String date) {
    final strategy = strategies?.firstWhere(
      (s) => s['analysis_date'] == date,
      orElse: () => {},
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$date 전략'),
          content:
              strategy != null && strategy.isNotEmpty
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('매수 가격: ${strategy['buy_price']}'),
                      Text('매도 가격: ${strategy['sell_price']}'),
                      Text('기대 수익율: ${strategy['expected_return']}'),
                      const SizedBox(height: 8),
                      const Text(
                        '요약:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        strategy['summary'] ?? '',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  )
                  : const Text('해당 날짜에 대한 전략이 없습니다.'),
          actions: [
            TextButton(
              child: const Text('닫기'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
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
                            '매수→${r.buyDate} / 매도→${r.sellDate ?? "미체결"}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('매수: ${krwFormat.format(r.buyPrice)}원'),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      _showStrategyDialog(context, r.buyDate);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
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
                                    ElevatedButton(
                                      onPressed: () {
                                        _showStrategyDialog(
                                          context,
                                          r.sellDate!,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                      child: const Text('전략 보기'),
                                    ),
                                  ],
                                ),
                                Text(
                                  '최종 원화: ${krwFormat.format(r.finalKRW.round())}원',
                                ),
                              ] else if (r.finalUSDT != null) ...[
                                Text(
                                  '최종 USDT: ${r.finalUSDT?.toStringAsFixed(4)} USDT',
                                ),
                                Text(
                                  '현재가 매도시: ${krwFormat.format(r.finalKRW.round())}원',
                                ),
                              ],
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
