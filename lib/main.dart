import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'AISimulationPage.dart';

void main() => runApp(const MyApp());

const int days = 200;
const String upbitUsdtUrl =
    "https://rate-history.vercel.app/api/usdt-history?days=$days";
const String rateHistoryUrl =
    "https://rate-history.vercel.app/api/rate-history?days=$days";
const String gimchHistoryUrl =
    "https://rate-history.vercel.app/api/gimch-history?days=$days";
const String strategyUrl =
    "https://rate-history.vercel.app/api/analyze-strategy";

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class ChartData {
  final DateTime time;
  final double value;
  ChartData(this.time, this.value);
}

class USDTChartData {
  final DateTime time;
  final double open;
  final double close;
  final double high;
  final double low;
  USDTChartData(this.time, this.open, this.close, this.high, this.low);
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey chartKey = GlobalKey();
  List<ChartData> kimchiPremium = [];
  List<ChartData> usdtPrices = [];
  List<ChartData> exchangeRates = [];
  double plotOffsetEnd = 0;
  bool showKimchiPremium = true; // 김치 프리미엄 표시 여부
  String? strategyText;
  Map<String, dynamic>? parsedStrategy;
  List<USDTChartData> usdtChartData = [];

  @override
  void initState() {
    super.initState();
    fetchExchangeRateData();
    fetchUSDTData();
    fetchKimchiPremiumData();
    fetchStrategy(); // 매매 전략도 불러오기
  }

  Future<void> fetchUSDTData() async {
    try {
      final response = await http.get(Uri.parse(upbitUsdtUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<USDTChartData> rate = [];
        data.forEach((key, value) {
          final close = value['price']?.toDouble() ?? 0;
          final high = value['high']?.toDouble() ?? 0;
          final low = value['low']?.toDouble() ?? 0;
          final open = close; // open 값이 없으므로 close로 대체
          rate.add(USDTChartData(DateTime.parse(key), open, close, high, low));
        });
        setState(() {
          usdtChartData = rate;
        });
        print("USDT prices Data: $usdtChartData");
      } else {
        print("Failed to fetch data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  Future<void> fetchExchangeRateData() async {
    try {
      final response = await http.get(Uri.parse(rateHistoryUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<ChartData> rate = [];

        data.forEach((key, value) {
          rate.add(ChartData(DateTime.parse(key), value.toDouble()));
        });

        setState(() {
          exchangeRates = rate;
        });

        print("Exchange Rates Data: $exchangeRates");
      } else {
        print("Failed to fetch data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  Future<void> fetchKimchiPremiumData() async {
    try {
      final response = await http.get(Uri.parse(gimchHistoryUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<ChartData> premium = [];
        data.forEach((key, value) {
          premium.add(ChartData(DateTime.parse(key), value.toDouble()));
        });
        setState(() {
          kimchiPremium = premium;
        });
        print("Kimchi Premium Data: $kimchiPremium");
      } else {
        print("Failed to fetch kimchi premium: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching kimchi premium: $e");
    }
  }

  Future<void> fetchStrategy() async {
    try {
      final response = await http.get(Uri.parse(strategyUrl));
      if (response.statusCode == 200) {
        strategyText = utf8.decode(response.bodyBytes);
        print("Strategy Data: $strategyText");

        Map<String, dynamic>? strategyData;
        if (strategyText != null) {
          try {
            final parsed = json.decode(strategyText!);
            print('parsed: $parsed');
            // 배열이 아니면 파싱 에러 처리
            if (parsed is List &&
                parsed.isNotEmpty &&
                parsed[0] is Map<String, dynamic>) {
              strategyData = parsed[0];
            } else {
              throw Exception('전략 응답이 배열이 아님');
            }
          } catch (e) {
            print('파싱 에러: $e');
            strategyData = null;
          }
        }

        setState(() {
          parsedStrategy = strategyData;
        });
      } else {
        print("Failed to fetch strategy: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching strategy: $e");
    }
  }

  void _onActualRangeChanged(ActualRangeChangedArgs args) {
    if (args.axisName == 'primaryXAxis' && kimchiPremium.isNotEmpty) {
      // X축 min/max는 chart의 primaryXAxis에서 가져와야 함
      final dynamic minXValue = args.visibleMin;
      final dynamic maxXValue = args.visibleMax;
      if (minXValue == null || maxXValue == null) return;

      final DateTime minX =
          minXValue is DateTime
              ? minXValue
              : DateTime.fromMillisecondsSinceEpoch(minXValue.toInt());
      final DateTime maxX =
          maxXValue is DateTime
              ? maxXValue
              : DateTime.fromMillisecondsSinceEpoch(maxXValue.toInt());

      final visibleData = kimchiPremium.where(
        (d) => !d.time.isBefore(minX) && !d.time.isAfter(maxX),
      );
      if (visibleData.isNotEmpty) {
        final minY = visibleData
            .map((d) => d.value)
            .reduce((a, b) => a < b ? a : b);
        final maxY = visibleData
            .map((d) => d.value)
            .reduce((a, b) => a > b ? a : b);
        final padding = (maxY - minY) * 0.1;
        args.visibleMin = minY - padding;
        args.visibleMax = maxY + padding;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double chartHeight = MediaQuery.of(context).size.height * 0.5;

    return Scaffold(
      appBar: AppBar(title: const Text("USDT, 환율, 김치 프리미엄")),
      body: SafeArea(
        // ← 추가
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: chartHeight,
                width: double.infinity,
                child: SfCartesianChart(
                  // onActualRangeChanged: _onActualRangeChanged,
                  legend: const Legend(
                    isVisible: true,
                    position: LegendPosition.bottom, // 아래쪽에 범례 표시
                  ),
                  margin: const EdgeInsets.all(10),
                  primaryXAxis: DateTimeAxis(
                    edgeLabelPlacement: EdgeLabelPlacement.shift,
                    intervalType: DateTimeIntervalType.days,
                    dateFormat: DateFormat.yMd(),
                    rangePadding: ChartRangePadding.additionalEnd,
                    initialZoomFactor: 0.9,
                    initialZoomPosition: 0.8,
                  ),
                  primaryYAxis: NumericAxis(
                    rangePadding: ChartRangePadding.auto,
                    labelFormat: '{value}',
                    numberFormat: NumberFormat("###,##0.0"),
                  ),
                  axes: <ChartAxis>[
                    NumericAxis(
                      name: 'kimchiAxis',
                      opposedPosition: true,
                      labelFormat: '{value}%',
                      numberFormat: NumberFormat("##0.0"),
                      axisLine: const AxisLine(width: 2, color: Colors.red),
                      majorTickLines: const MajorTickLines(
                        size: 2,
                        color: Colors.red,
                      ),
                      rangePadding: ChartRangePadding.round,
                    ),
                  ],
                  zoomPanBehavior: ZoomPanBehavior(
                    enablePinching: true,
                    enablePanning: true,
                    enableDoubleTapZooming: true,
                    zoomMode: ZoomMode.xy,
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries>[
                    LineSeries<USDTChartData, DateTime>(
                      name: 'USDT',
                      dataSource: usdtChartData,
                      xValueMapper: (USDTChartData data, _) => data.time,
                      yValueMapper: (USDTChartData data, _) => data.close,
                      color: Colors.blue,
                    ),
                    LineSeries<ChartData, DateTime>(
                      name: '환율',
                      dataSource:
                          exchangeRates.isNotEmpty
                              ? exchangeRates
                              : [ChartData(DateTime.now(), 0)],
                      xValueMapper: (ChartData data, _) => data.time,
                      yValueMapper: (ChartData data, _) => data.value,
                    ),
                    if (showKimchiPremium)
                      LineSeries<ChartData, DateTime>(
                        name: '김치 프리미엄(%)',
                        dataSource:
                            kimchiPremium.isNotEmpty
                                ? kimchiPremium
                                : [ChartData(DateTime.now(), 0)],
                        xValueMapper: (ChartData data, _) => data.time,
                        yValueMapper: (ChartData data, _) => data.value,
                        color: Colors.red,
                        yAxisName: 'kimchiAxis',
                        width: 2,
                        markerSettings: const MarkerSettings(
                          isVisible: true,
                          width: 3,
                          height: 3,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: showKimchiPremium,
                    onChanged: (val) {
                      setState(() {
                        showKimchiPremium = val ?? true;
                      });
                    },
                  ),
                  const Text('gimch premium'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text(
                      '매매 전략',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed:
                          parsedStrategy == null
                              ? null
                              : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AISimulationPage(),
                                  ),
                                );
                              },
                      child: const Text('AI 수익 시뮬레이션'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '매매 전략',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(),
                      children: [
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                '추천 매수 가격',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                '${parsedStrategy?['buy_price'] ?? '-'}',
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                '추천 매도 가격',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                '${parsedStrategy?['sell_price'] ?? '-'}',
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                '예상 기대 수익',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                '${parsedStrategy?['expected_return'] ?? '-'}',
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'AI 요약',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                '${parsedStrategy?['summary'] ?? '-'}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
