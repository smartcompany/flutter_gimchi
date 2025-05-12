import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // 숫자 포맷팅을 위한 패키지

void main() => runApp(const MyApp());

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

class _MyHomePageState extends State<MyHomePage> {
  List<FlSpot> kimchiPremiumSpots = [];
  List<FlSpot> usdtPriceSpots = [];
  List<FlSpot> exchangeRateSpots = [];

  @override
  void initState() {
    super.initState();
    fetchExchangeRateData();
  }

  Future<void> fetchExchangeRateData() async {
    try {
      // 환율 데이터 가져오기
      final response = await http.get(
        Uri.parse(
          "https://rate-history.vercel.app/api/rate-history?days=200",
        ), // 200일 치 데이터 요청
      );

      // 업비트 USDT-KRW 캔들 데이터 가져오기
      final upbitResponse = await http.get(
        Uri.parse(
          "https://api.upbit.com/v1/candles/days?market=KRW-USDT&count=200",
        ),
      );

      if (response.statusCode == 200 && upbitResponse.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final upbitData = jsonDecode(upbitResponse.body) as List<dynamic>;

        if (data.isNotEmpty && upbitData.isNotEmpty) {
          List<String> dates = data.keys.toList(); // 날짜 키를 리스트로 저장
          dates.sort(); // 날짜를 오름차순으로 정렬

          // 날짜별 데이터를 정확히 매핑
          for (int index = 0; index < dates.length; index++) {
            final date = dates[index];
            final exchangeRate = data[date] as num;

            // 업비트 데이터에서 해당 날짜의 종가(close) 값을 가져옴
            final usdtCandle = upbitData.firstWhere(
              (candle) => candle['candle_date_time_utc'].startsWith(date),
              orElse: () => null,
            );

            if (usdtCandle != null) {
              final usdtPrice = usdtCandle['trade_price'] as num;

              // 데이터를 추가
              exchangeRateSpots.add(
                FlSpot(index.toDouble(), exchangeRate.toDouble()),
              );
              usdtPriceSpots.add(
                FlSpot(index.toDouble(), usdtPrice.toDouble()),
              );
            }
          }

          setState(() {});
        } else {
          print("API returned empty data.");
        }
      } else {
        print(
          "Failed to load data: ${response.statusCode}, ${upbitResponse.statusCode}",
        );
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('김치 프리미엄 분석 --')),
      body:
          exchangeRateSpots.isEmpty
              ? const Center(child: CircularProgressIndicator()) // 로딩 상태 표시
              : Column(
                mainAxisAlignment: MainAxisAlignment.start, // 위쪽 정렬
                crossAxisAlignment: CrossAxisAlignment.stretch, // 가로로 꽉 채움
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      height: 300, // 차트의 높이를 지정
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            show: true,
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 10, // Y축 간격 설정
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toStringAsFixed(1), // 소수점 1자리까지 표시
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 200, // 오른쪽 Y축 간격 설정
                                reservedSize: 50, // 오른쪽 Y축 레이블 공간 확보
                                getTitlesWidget: (value, meta) {
                                  // 숫자를 쉼표로 구분된 형식으로 변환
                                  final formattedValue =
                                      NumberFormat.decimalPattern().format(
                                        value,
                                      );
                                  return Text(
                                    formattedValue, // 쉼표로 구분된 숫자 표시
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 20, // X축 간격 설정
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  if (index < 0 ||
                                      index >= exchangeRateSpots.length) {
                                    return const Text('');
                                  }
                                  // 날짜를 계산하여 표시
                                  final date = DateTime.now().subtract(
                                    Duration(
                                      days:
                                          exchangeRateSpots.length - 1 - index,
                                    ),
                                  );
                                  return Text(
                                    '${date.month}/${date.day}', // MM/DD 형식으로 표시
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: kimchiPremiumSpots,
                              isCurved: true,
                              color: Colors.red,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                            ),
                            LineChartBarData(
                              spots: usdtPriceSpots, // USDT-KRW 차트
                              isCurved: true,
                              color: Colors.blue, // 파란색으로 설정
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                            ),
                            LineChartBarData(
                              spots: exchangeRateSpots,
                              isCurved: true,
                              color: Colors.green,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
