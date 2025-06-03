import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'AISimulationPage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb을 사용하기 위해 import
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  final ZoomPanBehavior _zoomPanBehavior = ZoomPanBehavior(
    enablePinching: true,
    enablePanning: true,
    enableDoubleTapZooming: true,
    zoomMode: ZoomMode.xy,
  );
  List<ChartData> kimchiPremium = [];
  List<ChartData> usdtPrices = [];
  List<ChartData> exchangeRates = [];
  double plotOffsetEnd = 0;
  bool showKimchiPremium = true; // 김치 프리미엄 표시 여부
  bool showAITrading = false; // AI trading 표시 여부 추가
  String? strategyText;
  Map<String, dynamic>? parsedStrategy;
  List<USDTChartData> usdtChartData = [];
  Map<String, dynamic> usdtMap = {};
  List<SimulationResult> aiTradeResults = [];
  List strategyList = [];
  bool _strategyUnlocked = false; // 광고 시청 여부
  RewardedAd? _rewardedAd;

  @override
  void initState() {
    super.initState();

    // 테스트 기기 ID 로깅
    MobileAds.instance.getRequestConfiguration().then((config) {
      print('AdMob Test Device IDs: ${config.testDeviceIds}');
    });

    if (!kIsWeb) {
      MobileAds.instance.initialize().then((InitializationStatus status) {
        print('AdMob initialized: ${status.adapterStatuses}');
        _loadRewardedAd();
      });
    }
    fetchExchangeRateData();
    fetchUSDTData();
    fetchKimchiPremiumData();
    fetchStrategy(); // 매매 전략도 불러오기
  }

  void _loadRewardedAd() {
    try {
      final adUnitId =
          Platform.isAndroid
              ? 'ca-app-pub-5520596727761259/2854023304'
              : 'ca-app-pub-3940256099942544/1712485313';

      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            setState(() {
              _rewardedAd = ad;
            });
            print('Rewarded Ad Loaded Successfully');
          },
          onAdFailedToLoad: (error) {
            setState(() {
              _rewardedAd = null;
            });
            print('Failed to load rewarded ad: ${error.message}');
          },
        ),
      );
    } catch (e, s) {
      print('Ad load exception: $e\n$s');
    }
  }

  void _showRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          setState(() {
            _strategyUnlocked = true;
          });
          _rewardedAd?.dispose();
          _loadRewardedAd(); // 다음 광고 미리 로드
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고를 불러오는 중입니다. 잠시 후 다시 시도해 주세요.')),
      );
      _loadRewardedAd();
    }
  }

  Future<void> fetchUSDTData() async {
    try {
      final response = await http.get(Uri.parse(upbitUsdtUrl));
      if (response.statusCode == 200) {
        usdtMap = json.decode(response.body) as Map<String, dynamic>;
        final List<USDTChartData> rate = [];
        usdtMap.forEach((key, value) {
          final close = value['close']?.toDouble() ?? 0;
          final high = value['high']?.toDouble() ?? 0;
          final low = value['low']?.toDouble() ?? 0;
          final open = value['open']?.toDouble() ?? 0;
          rate.add(USDTChartData(DateTime.parse(key), open, close, high, low));
        });

        rate.sort((a, b) => a.time.compareTo(b.time));

        setState(() {
          usdtChartData = rate;
        });
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

        rate.sort((a, b) => a.time.compareTo(b.time));

        setState(() {
          exchangeRates = rate;
        });
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

        premium.sort((a, b) => a.time.compareTo(b.time));

        setState(() {
          kimchiPremium = premium;
        });
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

        Map<String, dynamic>? strategyData;
        if (strategyText != null) {
          try {
            strategyList = json.decode(strategyText!);
            // 배열이 아니면 파싱 에러 처리
            if (strategyList.isNotEmpty &&
                strategyList[0] is Map<String, dynamic>) {
              strategyData = strategyList[0];
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

  @override
  Widget build(BuildContext context) {
    // 마지막 날짜 로그 추가
    if (kimchiPremium.isNotEmpty) {
      print('김치프리미엄 마지막 날짜: ${kimchiPremium.last.time}');
    }
    if (exchangeRates.isNotEmpty) {
      print('환율 마지막 날짜: ${exchangeRates.last.time}');
    }
    if (usdtChartData.isNotEmpty) {
      print('USDT 마지막 날짜: ${usdtChartData.last.time}');
    }

    final double chartHeight = MediaQuery.of(context).size.height * 0.5;
    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      minimumSize: const Size(0, 0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 18),
      visualDensity: VisualDensity.compact,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("USDT Signal")),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 2. 리셋 버튼 추가 (차트 위나 아래 원하는 위치에)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      _zoomPanBehavior.reset();
                    },
                    child: const Text('차트 리셋'),
                  ),
                ),
              ),
              SizedBox(
                height: chartHeight,
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
                    // 아래 두 줄을 추가!
                    minimum:
                        usdtChartData.isNotEmpty
                            ? usdtChartData
                                    .map((e) => e.low)
                                    .reduce((a, b) => a < b ? a : b) *
                                0.98
                            : null,
                    maximum:
                        usdtChartData.isNotEmpty
                            ? usdtChartData
                                    .map((e) => e.high)
                                    .reduce((a, b) => a > b ? a : b) *
                                1.02
                            : null,
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
                  zoomPanBehavior: _zoomPanBehavior, // 3. 적용
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries>[
                    CandleSeries<USDTChartData, DateTime>(
                      name: 'USDT',
                      dataSource: usdtChartData,
                      xValueMapper: (USDTChartData data, _) => data.time,
                      lowValueMapper: (USDTChartData data, _) => data.low,
                      highValueMapper: (USDTChartData data, _) => data.high,
                      openValueMapper: (USDTChartData data, _) => data.open,
                      closeValueMapper: (USDTChartData data, _) => data.close,
                      bearColor: Colors.blue,
                      bullColor: Colors.red,
                    ),
                    LineSeries<ChartData, DateTime>(
                      name: '환율',
                      dataSource:
                          exchangeRates.isNotEmpty
                              ? exchangeRates
                              : [ChartData(DateTime.now(), 0)],
                      xValueMapper: (ChartData data, _) => data.time,
                      yValueMapper: (ChartData data, _) => data.value,
                      color: Colors.green,
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
                        color: Colors.yellow,
                        yAxisName: 'kimchiAxis',
                        width: 2,
                        markerSettings: const MarkerSettings(
                          isVisible: true,
                          width: 3,
                          height: 3,
                        ),
                      ),
                    if (showAITrading && aiTradeResults.isNotEmpty) ...[
                      ScatterSeries<dynamic, DateTime>(
                        name: 'AI 매수',
                        dataSource:
                            aiTradeResults
                                .where((r) => r.buyDate != null)
                                .toList(),
                        xValueMapper: (r, _) => DateTime.parse(r.buyDate),
                        yValueMapper: (r, _) => r.buyPrice,
                        markerSettings: const MarkerSettings(
                          isVisible: true,
                          shape: DataMarkerType.triangle,
                          color: Colors.red,
                          width: 12,
                          height: 12,
                        ),
                      ),
                      ScatterSeries<dynamic, DateTime>(
                        name: 'AI 매도',
                        dataSource:
                            aiTradeResults
                                .where((r) => r.sellDate != null)
                                .toList(),
                        xValueMapper: (r, _) => DateTime.parse(r.sellDate!),
                        yValueMapper: (r, _) => r.sellPrice!,
                        markerSettings: const MarkerSettings(
                          isVisible: true,
                          shape: DataMarkerType.invertedTriangle,
                          color: Colors.blue,
                          width: 12,
                          height: 12,
                        ),
                      ),
                    ],
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
                  const Text('김치 프리미엄 표시'),
                  const SizedBox(width: 16),
                  Checkbox(
                    value: showAITrading,
                    onChanged: (val) {
                      setState(() {
                        showAITrading = val ?? false;
                        if (showAITrading) {
                          aiTradeResults = AISimulationPage.simulateResults(
                            strategyList, // 전략 리스트 필요시 교체
                            usdtMap,
                          );
                        } else {
                          aiTradeResults = [];
                        }
                      });
                    },
                  ),
                  const Text('AI 매수 매도 표시'),
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
                    const SizedBox(width: 8),
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
                      style: buttonStyle,
                      child: const Text('AI 매매 전략 시뮬레이션'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 광고를 보기 전에는 버튼만, 본 후에는 테이블 표시
                    if (!kIsWeb) // 웹이 아닐때만 광고 로직 실행
                      if (!_strategyUnlocked)
                        Center(
                          child: ElevatedButton(
                            onPressed:
                                _rewardedAd == null
                                    ? null
                                    : () {
                                      _showRewardedAd();
                                    },
                            child: const Text('광고 보고 전략 보기'),
                          ),
                        )
                      else
                        Column(
                          children: [
                            Table(
                              border: TableBorder.all(),
                              children: [
                                TableRow(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        '추천 매수 가격',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
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
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () async {
                                // 전략 전체 히스토리 불러오기
                                final response = await http.get(
                                  Uri.parse(strategyUrl),
                                );
                                if (response.statusCode == 200) {
                                  final List<dynamic> history = json.decode(
                                    utf8.decode(response.bodyBytes),
                                  );
                                  if (context.mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('매매 전략 히스토리'),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: history.length,
                                              itemBuilder: (context, idx) {
                                                final strat = history[idx];
                                                return ListTile(
                                                  title: Text(
                                                    '날짜: ${strat['analysis_date'] ?? '-'}',
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '매수: ${strat['buy_price'] ?? '-'}',
                                                      ),
                                                      Text(
                                                        '매도: ${strat['sell_price'] ?? '-'}',
                                                      ),
                                                      Text(
                                                        '예상 수익: ${strat['expected_return'] ?? '-'}',
                                                      ),
                                                      Text(
                                                        '요약: ${strat['summary'] ?? '-'}',
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.of(
                                                        context,
                                                      ).pop(),
                                              child: const Text('닫기'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    showDialog(
                                      context: context,
                                      builder:
                                          (_) => const AlertDialog(
                                            content: Text('전략 히스토리 불러오기 실패'),
                                          ),
                                    );
                                  }
                                }
                              },
                              style: buttonStyle,
                              child: const Text('히스토리'),
                            ),
                            const SizedBox(height: 8),
                          ],
                        )
                    else // 웹에서는 바로 테이블 표시
                      Column(
                        children: [
                          Table(
                            border: TableBorder.all(),
                            children: [
                              TableRow(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      '추천 매수 가격',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () async {
                              // 전략 전체 히스토리 불러오기
                              final response = await http.get(
                                Uri.parse(strategyUrl),
                              );
                              if (response.statusCode == 200) {
                                final List<dynamic> history = json.decode(
                                  utf8.decode(response.bodyBytes),
                                );
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('매매 전략 히스토리'),
                                        content: SizedBox(
                                          width: double.maxFinite,
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: history.length,
                                            itemBuilder: (context, idx) {
                                              final strat = history[idx];
                                              return ListTile(
                                                title: Text(
                                                  '날짜: ${strat['analysis_date'] ?? '-'}',
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '매수: ${strat['buy_price'] ?? '-'}',
                                                    ),
                                                    Text(
                                                      '매도: ${strat['sell_price'] ?? '-'}',
                                                    ),
                                                    Text(
                                                      '예상 수익: ${strat['expected_return'] ?? '-'}',
                                                    ),
                                                    Text(
                                                      '요약: ${strat['summary'] ?? '-'}',
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () =>
                                                    Navigator.of(context).pop(),
                                            child: const Text('닫기'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (_) => const AlertDialog(
                                          content: Text('전략 히스토리 불러오기 실패'),
                                        ),
                                  );
                                }
                              }
                            },
                            style: buttonStyle,
                            child: const Text('히스토리'),
                          ),
                          const SizedBox(height: 8),
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
