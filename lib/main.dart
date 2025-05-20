import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

void main() => runApp(const MyApp());

const int days = 200;
const String upbitUsdtUrl =
    "https://api.upbit.com/v1/candles/days?market=KRW-USDT&count=$days";
const String rateHistoryUrl =
    "https://rate-history.vercel.app/api/rate-history?days=$days";
const String gimchHistoryUrl =
    "https://rate-history.vercel.app/api/gimch-history?days=$days";

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

class _MyHomePageState extends State<MyHomePage> {
  List<ChartData> kimchiPremium = [];
  List<ChartData> usdtPrices = [];
  List<ChartData> exchangeRates = [];
  double plotOffsetEnd = 0;
  bool showKimchiPremium = true; // 김치 프리미엄 표시 여부

  @override
  void initState() {
    super.initState();
    fetchExchangeRateData();
    fetchUSDTData();
    fetchKimchiPremiumData(); // 김치 프리미엄 데이터도 불러오기
  }

  Future<void> fetchUSDTData() async {
    try {
      final response = await http.get(Uri.parse(upbitUsdtUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final List<ChartData> rate = [];

        for (final item in data) {
          // 날짜와 가격을 올바르게 추출
          final dateStr = item['candle_date_time_utc'] as String;
          final price = item['trade_price'] as num;
          rate.add(ChartData(DateTime.parse(dateStr), price.toDouble()));
        }

        // 최신 날짜가 앞으로 오므로, 그래프를 위해 뒤집기
        final reversedRate = rate.reversed.toList();

        setState(() {
          usdtPrices = reversedRate;
        });

        print("USDT prices Data: $usdtPrices");
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

  void _onActualRangeChanged(ActualRangeChangedArgs args) {
    if (exchangeRates.isEmpty) return;
    final DateTime? maxX = args.visibleMax is DateTime ? args.visibleMax : null;
    final DateTime lastDate = exchangeRates.last.time;

    // 마지막 데이터가 화면에 보일 때만 plotOffsetEnd 적용
    setState(() {
      plotOffsetEnd =
          (maxX != null && maxX.isAtSameMomentAs(lastDate)) ? 30 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("시세 차트")),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            width: double.infinity,
            child: SfCartesianChart(
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
                  title: AxisTitle(text: '김치 프리미엄(%)'),
                  labelFormat: '{value}%',
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
                LineSeries<ChartData, DateTime>(
                  name: '환율',
                  dataSource:
                      exchangeRates.isNotEmpty
                          ? exchangeRates
                          : [ChartData(DateTime.now(), 0)],
                  xValueMapper: (ChartData data, _) => data.time,
                  yValueMapper: (ChartData data, _) => data.value,
                ),
                LineSeries<ChartData, DateTime>(
                  name: 'USDT',
                  dataSource:
                      usdtPrices.isNotEmpty
                          ? usdtPrices
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
                      width: 3, // 동그라미(마커) 크기 줄이기
                      height: 3, // 동그라미(마커) 크기 줄이기
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
        ],
      ),
    );
  }
}
