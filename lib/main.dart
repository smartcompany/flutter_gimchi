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

  @override
  void initState() {
    super.initState();
    fetchExchangeRateData();
    fetchUSDTData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("시세 차트")),
      body: SizedBox(
        height: 300, // 원하는 높이(px)로 고정
        width: double.infinity, // 가로로 꽉 차게
        child: SfCartesianChart(
          margin: const EdgeInsets.all(10),
          primaryXAxis: DateTimeAxis(
            edgeLabelPlacement: EdgeLabelPlacement.shift,
            intervalType: DateTimeIntervalType.days,
            dateFormat: DateFormat.yMd(),
            plotOffsetEnd: 30,
            initialZoomFactor: 0.5,
            initialZoomPosition: 1.0,
          ),
          primaryYAxis: NumericAxis(
            labelFormat: '{value}',
            numberFormat: NumberFormat("###,##0.0"), // 소수점 첫째자리까지
          ),
          zoomPanBehavior: ZoomPanBehavior(
            enablePinching: true,
            enablePanning: true,
            enableDoubleTapZooming: true,
            zoomMode: ZoomMode.xy, // x축만 확대 (원하면 ZoomMode.xy 도 가능)
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
          ],
        ),
      ),
    );
  }
}
