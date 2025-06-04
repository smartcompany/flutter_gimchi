import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'AISimulationPage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb을 사용하기 위해 import
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'OnboardingPage.dart'; // 온보딩 페이지 import

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
    return MaterialApp(home: OnboardingLauncher());
  }
}

// 온보딩 → 메인페이지 전환을 담당하는 위젯
class OnboardingLauncher extends StatefulWidget {
  const OnboardingLauncher({super.key});

  @override
  State<OnboardingLauncher> createState() => _OnboardingLauncherState();
}

class _OnboardingLauncherState extends State<OnboardingLauncher> {
  bool _onboardingDone = false;

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone) {
      return const MyHomePage();
    }
    return OnboardingPage(
      // 온보딩이 끝나면 콜백으로 상태 변경
      onFinish: () {
        setState(() {
          _onboardingDone = true;
        });
      },
    );
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
  bool showExchangeRate = true; // 환율 표시 여부 추가
  String? strategyText;
  Map<String, dynamic>? parsedStrategy;
  List<USDTChartData> usdtChartData = [];
  Map<String, dynamic> usdtMap = {};
  List<SimulationResult> aiTradeResults = [];
  List strategyList = [];
  bool _strategyUnlocked = false; // 광고 시청 여부
  RewardedAd? _rewardedAd;

  double? kimchiMin;
  double? kimchiMax;

  DateTimeAxis primaryXAxis = DateTimeAxis(
    edgeLabelPlacement: EdgeLabelPlacement.shift,
    intervalType: DateTimeIntervalType.days,
    dateFormat: DateFormat.yMd(),
    rangePadding: ChartRangePadding.additionalEnd,
    initialZoomFactor: 0.9,
    initialZoomPosition: 0.8,
  );

  @override
  void initState() {
    super.initState();

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
          kDebugMode
              ? (Platform.isAndroid
                  ? 'ca-app-pub-3940256099942544/5224354917' // Android 테스트 보상형 광고
                  : 'ca-app-pub-3940256099942544/1712485313') // iOS 테스트 보상형 광고
              : (Platform.isAndroid
                  ? 'ca-app-pub-5520596727761259/2854023304' // 실제 광고 ID
                  : 'ca-app-pub-3940256099942544/1712485313'); // 실제 광고 ID

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
              _strategyUnlocked = true; // 광고 실패 시 전략 바로 공개
            });
            print('Failed to load rewarded ad: ${error.message}');
          },
        ),
      );
    } catch (e, s) {
      print('Ad load exception: $e\n$s');
      setState(() {
        _strategyUnlocked = true; // 예외 발생 시도 전략 바로 공개
      });
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

        // 김치 프리미엄 Y축 min/max 계산 및 고정
        if (premium.isNotEmpty) {
          final min = premium
              .map((e) => e.value)
              .reduce((a, b) => a < b ? a : b);
          final max = premium
              .map((e) => e.value)
              .reduce((a, b) => a > b ? a : b);
          kimchiMin = (min * 0.98).floorToDouble();
          kimchiMax = (max * 1.02).ceilToDouble();
        }

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

  // USDT 최소값 계산 함수
  double? getUsdtMin(List<USDTChartData> data) {
    if (data.isEmpty) return null;
    final min = data.map((e) => e.low).reduce((a, b) => a < b ? a : b) * 0.98;
    return min < 1300 ? 1300 : min;
  }

  // USDT 최대값 계산 함수
  double? getUsdtMax(List<USDTChartData> data) {
    if (data.isEmpty) return null;
    final max = data.map((e) => e.high).reduce((a, b) => a > b ? a : b);
    return max * 1.02;
  }

  void _autoZoomToAITrades() {
    if (showAITrading &&
        aiTradeResults.isNotEmpty &&
        usdtChartData.isNotEmpty) {
      // AI 매수/매도 날짜 리스트
      final allDates = [
        ...aiTradeResults
            .where((r) => r.buyDate != null)
            .map((r) => DateTime.parse(r.buyDate)),
        ...aiTradeResults
            .where((r) => r.sellDate != null)
            .map((r) => DateTime.parse(r.sellDate!)),
      ];
      if (allDates.isNotEmpty) {
        allDates.sort();
        DateTime aiStart = allDates.first;
        DateTime aiEnd = allDates.last;

        // 여유를 위해 좌우로 2~3일 추가
        aiStart = aiStart.subtract(const Duration(days: 2));
        aiEnd = aiEnd.add(const Duration(days: 2));

        // 전체 차트 날짜 범위
        final chartStart = usdtChartData.first.time;
        final chartEnd = usdtChartData.last.time;
        final totalSpan =
            chartEnd.difference(chartStart).inMilliseconds.toDouble();
        final aiSpan = aiEnd.difference(aiStart).inMilliseconds.toDouble();

        // AI 매매 구간이 전체의 150%만 보이도록 줌 (여유 있게)
        final zoomFactor = (aiSpan / totalSpan) * 2; // 더 크게 줌인
        final zoomPosition = (aiStart
                    .difference(chartStart)
                    .inMilliseconds
                    .toDouble() /
                totalSpan)
            .clamp(0.0, 1.0);

        print('zoomFactor: $zoomFactor');
        print('zoomPosition: $zoomPosition');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _zoomPanBehavior.zoomToSingleAxis(
            primaryXAxis,
            zoomPosition,
            zoomFactor.clamp(0.01, 1.0), // 최소 5%까지 줌인 허용
          );
        });
      }
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

    // 오늘 날짜 데이터 추출
    DateTime today = DateTime.now();
    String todayStr = DateFormat('yyyy-MM-dd').format(today);

    // USDT 오늘 데이터
    USDTChartData? todayUsdt = usdtChartData.isNotEmpty
        ? usdtChartData.last
        : null;
    // 환율 오늘 데이터
    ChartData? todayRate = exchangeRates.isNotEmpty
        ? exchangeRates.last
        : null;
    // 김치 프리미엄 오늘 데이터
    ChartData? todayKimchi = kimchiPremium.isNotEmpty
        ? kimchiPremium.last
        : null;

    final double chartHeight = MediaQuery.of(context).size.height * 0.6;
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
              // 오늘 데이터 표시 영역 추가
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text('USDT', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(todayUsdt != null ? todayUsdt.close.toStringAsFixed(2) : '-'),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('환율', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(todayRate != null ? todayRate.value.toStringAsFixed(2) : '-'),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('김치 프리미엄', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(todayKimchi != null ? '${todayKimchi.value.toStringAsFixed(2)}%' : '-'),
                      ],
                    ),
                  ],
                ),
              ),
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
                  primaryXAxis: primaryXAxis,
                  primaryYAxis: NumericAxis(
                    rangePadding: ChartRangePadding.auto,
                    labelFormat: '{value}',
                    numberFormat: NumberFormat("###,##0.0"),
                    minimum: getUsdtMin(usdtChartData),
                    maximum: getUsdtMax(usdtChartData),
                  ),
                  axes: <ChartAxis>[
                    NumericAxis(
                      name: 'kimchiAxis',
                      opposedPosition: true,
                      labelFormat: '{value}%',
                      numberFormat: NumberFormat("##0.0"),
                      majorTickLines: const MajorTickLines(
                        size: 2,
                        color: Colors.red,
                      ),
                      rangePadding: ChartRangePadding.round,
                      minimum: kimchiMin, // 고정된 min
                      maximum: kimchiMax, // 고정된 max
                    ),
                  ],
                  zoomPanBehavior: _zoomPanBehavior, // 3. 적용
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries>[
                    if (!showAITrading)
                      // 일반 라인 차트 (USDT)
                      LineSeries<USDTChartData, DateTime>(
                        name: 'USDT',
                        dataSource: usdtChartData,
                        xValueMapper: (USDTChartData data, _) => data.time,
                        yValueMapper: (USDTChartData data, _) => data.close,
                        color: Colors.blue,
                        animationDuration: 0,
                      )
                    else
                      // 기존 캔들 차트
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
                        animationDuration: 0,
                      ),
                    // 환율 그래프를 showExchangeRate가 true일 때만 표시
                    if (showExchangeRate)
                      LineSeries<ChartData, DateTime>(
                        name: '환율',
                        dataSource: exchangeRates,
                        xValueMapper: (ChartData data, _) => data.time,
                        yValueMapper: (ChartData data, _) => data.value,
                        color: Colors.green,
                        animationDuration: 0,
                      ),
                    if (showKimchiPremium)
                      LineSeries<ChartData, DateTime>(
                        name: '김치 프리미엄(%)',
                        dataSource: kimchiPremium,
                        xValueMapper: (ChartData data, _) => data.time,
                        yValueMapper: (ChartData data, _) => data.value,
                        color: Colors.yellow,
                        yAxisName: 'kimchiAxis',
                        animationDuration: 0,
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

              // 체크박스 Row를 차트 바로 밑에 위치
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly, // 간격을 자동으로 맞춤
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: showExchangeRate,
                          onChanged: (val) {
                            setState(() {
                              showExchangeRate = val ?? true;
                            });
                          },
                        ),
                        const Text('환율', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: showKimchiPremium,
                          onChanged: (val) {
                            setState(() {
                              showKimchiPremium = val ?? true;
                            });
                          },
                        ),
                        const Text('김치 프리미엄', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: showAITrading,
                          onChanged: (val) {
                            setState(() {
                              showAITrading = val ?? false;
                              if (showAITrading) {
                                aiTradeResults =
                                    AISimulationPage.simulateResults(
                                      strategyList,
                                      usdtMap,
                                    );
                                _autoZoomToAITrades();
                              } else {
                                aiTradeResults = [];
                              }
                            });
                          },
                        ),
                        const Text(
                          'AI 매수/매도 마크',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
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
