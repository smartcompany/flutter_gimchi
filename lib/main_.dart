import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// API URL 상수 정의
const String bybitKlineUrl =
    'https://api.bybit.com/v5/market/kline?category=spot&symbol=BTCUSDT&interval=D&limit=365';
const String upbitCandleUrl = 'https://api.upbit.com/v1/candles/days';
const String exchangeRateApiUrl =
    'https://rate-history.vercel.app/api/rate-history?days=100';

void main() {
  runApp(
    MaterialApp(home: KimchiPremiumPage(), debugShowCheckedModeBanner: false),
  );
}

class KimchiPremiumPage extends StatefulWidget {
  @override
  _KimchiPremiumPageState createState() => _KimchiPremiumPageState();
}

class _KimchiPremiumPageState extends State<KimchiPremiumPage> {
  List<DateTime> dates = [];
  List<double> kimchiPremiums = [];
  List<double> usdtPrices = [];

  bool loading = true;
  Map<String, double>? exchangeRates;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      exchangeRates = await fetchExchangeRateData();
      print('Exchange Rates: $exchangeRates');

      final results = await Future.wait([
        fetchBybitData(),
        fetchUpbitData('KRW-BTC'),
        fetchUpbitData('KRW-USDT'),
      ]);

      final btcUsdtData = results[0] as Map<String, double>;
      final btcKrwData = results[1] as Map<String, double>;
      final usdtKrwData = results[2] as Map<String, double>;

      print('BTC-USDT Data: $btcUsdtData');
      print('BTC-KRW Data: $btcKrwData');
      print('USDT-KRW Data: $usdtKrwData');

      Set<String> allDates =
          btcUsdtData.keys.toSet()..retainAll(btcKrwData.keys);

      List<DateTime> tempDates = [];
      List<double> tempKimchi = [];
      List<double> tempUsdtPrices = [];

      for (var dateStr in allDates) {
        final btcUsdt = btcUsdtData[dateStr]!;
        final btcKrw = btcKrwData[dateStr]!;
        final exchange = exchangeRates?[dateStr] ?? 1300.0;
        final usdtKrw = usdtKrwData[dateStr] ?? exchange;

        double premium = ((btcKrw / (btcUsdt * exchange)) - 1) * 100;

        tempDates.add(DateTime.parse(dateStr));
        tempKimchi.add(double.parse(premium.toStringAsFixed(2)));
        tempUsdtPrices.add(usdtKrw);
      }

      tempDates.sort();

      setState(() {
        dates = tempDates;
        kimchiPremiums = tempKimchi;
        usdtPrices = tempUsdtPrices;
        loading = false;
      });

      print('Dates: $dates');
      print('Kimchi Premiums: $kimchiPremiums');
      print('USDT Prices: $usdtPrices');
    } catch (e) {
      print('Error: $e');
      setState(() {
        loading = false;
      });
    }
  }

  Future<Map<String, double>> fetchExchangeRateData() async {
    final uri = Uri.parse(exchangeRateApiUrl);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
    } else {
      throw Exception('Failed to fetch exchange rate data');
    }
  }

  Future<Map<String, double>> fetchBybitData() async {
    final uri = Uri.parse(bybitKlineUrl);
    final response = await http.get(uri);
    final data = jsonDecode(response.body);

    Map<String, double> result = {};
    for (var item in data['result']['list']) {
      String date = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.fromMillisecondsSinceEpoch(int.parse(item[0])));
      result[date] = double.parse(item[4]);
    }
    return result;
  }

  Future<Map<String, double>> fetchUpbitData(String market) async {
    final uri = Uri.parse('$upbitCandleUrl?market=$market&count=365');
    final response = await http.get(uri);
    final data = jsonDecode(response.body);

    Map<String, double> result = {};
    for (var item in data) {
      String date = item['candle_date_time_kst'].substring(0, 10);
      result[date] =
          (market == 'KRW-USDT')
              ? item['high_price'].toDouble()
              : item['trade_price'].toDouble();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('김치 프리미엄 분석')),
      body:
          loading
              ? Center(child: CircularProgressIndicator())
              : Column(
                mainAxisAlignment: MainAxisAlignment.start, // 상단에 배치
                crossAxisAlignment: CrossAxisAlignment.stretch, // 가로로 꽉 채움
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      height:
                          MediaQuery.of(context).size.height /
                          2, // 차트 높이를 화면의 절반으로 설정
                      child: LineChart(
                        LineChartData(
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 30, // X축 간격 설정
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  if (index >= 0 && index < dates.length) {
                                    return Text(
                                      DateFormat('MM/dd').format(dates[index]),
                                    );
                                  }
                                  return Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 5, // Y축 간격 설정 (김치 프리미엄 %)
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toStringAsFixed(0)}%', // % 표시
                                    style: TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(show: true), // 그리드 활성화
                          borderData: FlBorderData(show: true), // 테두리 활성화
                          lineBarsData: [
                            // 김치 프리미엄 차트 (빨간색)
                            LineChartBarData(
                              spots: List.generate(
                                kimchiPremiums.length,
                                (index) => FlSpot(
                                  index.toDouble(),
                                  kimchiPremiums[index],
                                ),
                              ),
                              isCurved: true,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                              color: Colors.red,
                            ),
                            // USDT-KRW 차트 (파란색)
                            LineChartBarData(
                              spots: List.generate(
                                usdtPrices.length,
                                (index) => FlSpot(
                                  index.toDouble(),
                                  usdtPrices[index] / 100,
                                ),
                              ),
                              isCurved: true,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1, // 하단 여백을 차지하지 않음
                    child: SizedBox(), // 빈 공간
                  ),
                ],
              ),
    );
  }
}
