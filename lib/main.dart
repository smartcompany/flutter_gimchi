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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:advertising_id/advertising_id.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await Firebase.initializeApp();

    // Crashlytics 에러 자동 수집 활성화
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }

  await printIDFA();
  runApp(const MyApp());
}

const int days = 200;
const String upbitUsdtUrl =
    "https://rate-history.vercel.app/api/usdt-history?days=$days";
const String rateHistoryUrl =
    "https://rate-history.vercel.app/api/rate-history?days=$days";
const String gimchHistoryUrl =
    "https://rate-history.vercel.app/api/gimch-history?days=$days";
const String strategyUrl =
    "https://rate-history.vercel.app/api/analyze-strategy";
const String fcmTokenUrl = "https://rate-history.vercel.app/api/fcm-token";

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: OnboardingLauncher(),
      debugShowCheckedModeBanner: false, // 이 줄을 추가!
    );
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    setState(() {
      _onboardingDone = done;
      _loading = false;
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    setState(() {
      _onboardingDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_onboardingDone) {
      return const MyHomePage();
    }
    return OnboardingPage(onFinish: _finishOnboarding);
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

  bool _loading = true;
  String? _loadError;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      MobileAds.instance.initialize().then((InitializationStatus status) {
        _loadRewardedAd();
      });

      _initFCM();
    }
    _loadAllApis();
  }

  void _initFCM() async {
    if (kIsWeb) {
      print('FCM은 웹에서 지원되지 않습니다.');
      return;
    }

    if (Platform.isIOS) {
      final simulator = await isIOSSimulator();
      if (simulator) {
        print('iOS 시뮬레이터에서는 FCM 토큰을 요청하지 않습니다.');
        return;
      }
    }

    // 권한 요청 (iOS)
    await FirebaseMessaging.instance.requestPermission();

    // FCM 토큰 얻기
    String? token = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $token');
    // 서버에 토큰을 저장(POST)해야 푸시를 받을 수 있습니다.
    if (token != null) {
      final userId = await getOrCreateUserId();
      await _saveFcmTokenToServer(token, userId);
    }

    // 포그라운드 메시지 수신
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('푸시 수신 포그라운드: ${message.notification?.title}');
      showPushAlert(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('푸시 수신 백그라운드: ${message.notification?.title}');
      // 푸시 알림을 다이얼로그로 표시
      showPushAlert(message);
    });
  }

  void showPushAlert(RemoteMessage message) {
    // 푸시 알림을 다이얼로그로 표시
    if (message.notification != null && context.mounted) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(
                message.notification!.title ?? '알림',
                style: const TextStyle(fontSize: 16), // 폰트 사이즈만 추가
              ),
              content: Text(message.notification!.body ?? ''),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
    }
  }

  // FCM 토큰을 서버에 저장하는 함수
  Future<void> _saveFcmTokenToServer(String token, String userId) async {
    try {
      final response = await http.post(
        Uri.parse(fcmTokenUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'userId': userId,
        }),
      );
      if (response.statusCode == 200) {
        print('FCM 토큰 서버 저장 성공');
      } else {
        print('FCM 토큰 서버 저장 실패: ${response.body}');
      }
    } catch (e) {
      print('FCM 토큰 서버 저장 에러: $e');
    }
  }

  Future<void> _loadAllApis() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      await Future.wait([
        fetchExchangeRateData(),
        fetchUSDTData(),
        fetchKimchiPremiumData(),
        fetchStrategy(),
      ]);
      setState(() {
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = '데이터를 불러오는데 실패했습니다.';
      });
      if (context.mounted) {
        _showRetryDialog();
      }
    }
  }

  void _loadRewardedAd() {
    try {
      var adUnitId = "";
      if (kDebugMode) {
        if (Platform.isIOS) {
          adUnitId = 'ca-app-pub-5520596727761259/5241271661';
          // adUnitId = 'ca-app-pub-3940256099942544/1712485313';
        } else if (Platform.isAndroid) {
          adUnitId = 'ca-app-pub-3940256099942544/5224354917';
        }
      } else {
        if (Platform.isIOS) {
          adUnitId = 'ca-app-pub-5520596727761259/5241271661'; // 실제 광고 ID
        } else if (Platform.isAndroid) {
          adUnitId = 'ca-app-pub-5520596727761259/2854023304'; // 실제 광고 ID
        }
      }

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

  void _showRewardedAd({required ScrollController scrollController}) {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) async {
          setState(() {
            _strategyUnlocked = true;
          });
          _rewardedAd?.dispose();
          _loadRewardedAd();

          // 프레임이 완전히 그려진 뒤 스크롤 이동
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scrollController.hasClients) {
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
              );
            }
          });
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
        throw Exception("Failed to fetch USDT data: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error fetching USDT data: $e");
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

  // 조건 체크 함수
  bool shouldShowAdUnlockButton() {
    return !kIsWeb && !_strategyUnlocked;
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('불러오기 실패'),
            content: const Text('데이터를 불러오는데 실패했습니다.\n다시 시도하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('종료'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _loadAllApis();
                },
                child: const Text('YES'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F5FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
    USDTChartData? todayUsdt =
        usdtChartData.isNotEmpty ? usdtChartData.last : null;
    // 환율 오늘 데이터
    ChartData? todayRate = exchangeRates.isNotEmpty ? exchangeRates.last : null;
    // 김치 프리미엄 오늘 데이터
    ChartData? todayKimchi =
        kimchiPremium.isNotEmpty ? kimchiPremium.last : null;

    final double chartHeight = MediaQuery.of(context).size.height * 0.6;
    final singleChildScrollView = SingleChildScrollView(
      controller: _scrollController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
        child: Column(
          children: [
            _buildTodayInfoCard(todayUsdt, todayRate, todayKimchi),
            const SizedBox(height: 8),
            _buildChartResetButton(),
            const SizedBox(height: 4),
            _buildChartCard(chartHeight),
            const SizedBox(height: 8),
            _buildCheckboxCard(),
            const SizedBox(height: 12),
            _buildStrategySection(),
            if (kDebugMode) // 디버그 모드일 때만 표시
              TextButton(
                onPressed: () => throw Exception(),
                child: const Text("Throw Test Exception"),
              ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FA),
      appBar: AppBar(
        title: const Text(
          "USDT Signal",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(child: singleChildScrollView),
    );
  }

  // 1. 오늘 데이터 카드
  Widget _buildTodayInfoCard(
    USDTChartData? todayUsdt,
    ChartData? todayRate,
    ChartData? todayKimchi,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _InfoItem(
              label: 'USDT',
              value:
                  todayUsdt != null ? todayUsdt.close.toStringAsFixed(1) : '-',
              color: Colors.blue,
            ),
            _InfoItem(
              label: '환율',
              value:
                  todayRate != null ? todayRate.value.toStringAsFixed(1) : '-',
              color: Colors.green,
            ),
            _InfoItem(
              label: '김치 프리미엄',
              value:
                  todayKimchi != null
                      ? '${todayKimchi.value.toStringAsFixed(2)}%'
                      : '-',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  // 2. 차트 리셋 버튼 (차트 카드 안에 넣으려면 _buildChartCard에서 Stack으로 처리)
  Widget _buildChartResetButton() {
    return Row(
      children: [
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () => _zoomPanBehavior.reset(),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('차트 리셋', style: TextStyle(fontSize: 15)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            side: const BorderSide(color: Colors.deepPurple),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
      ],
    );
  }

  // 3. 차트 카드
  Widget _buildChartCard(double chartHeight) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: chartHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SfCartesianChart(
          legend: const Legend(
            isVisible: true,
            position: LegendPosition.bottom,
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
              majorTickLines: const MajorTickLines(size: 2, color: Colors.red),
              rangePadding: ChartRangePadding.round,
              minimum: kimchiMin,
              maximum: kimchiMax,
            ),
          ],
          zoomPanBehavior: _zoomPanBehavior,
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
                color: Colors.orange,
                yAxisName: 'kimchiAxis',
                animationDuration: 0,
              ),
            if (showAITrading && aiTradeResults.isNotEmpty) ...[
              ScatterSeries<dynamic, DateTime>(
                name: 'AI 매수',
                dataSource:
                    aiTradeResults.where((r) => r.buyDate != null).toList(),
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
                    aiTradeResults.where((r) => r.sellDate != null).toList(),
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
    );
  }

  // 4. 체크박스 카드
  Widget _buildCheckboxCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 8,
          runSpacing: 2,
          children: [
            _CheckBoxItem(
              value: showExchangeRate,
              label: '환율',
              color: Colors.green,
              onChanged:
                  (val) => setState(() => showExchangeRate = val ?? true),
            ),
            _CheckBoxItem(
              value: showKimchiPremium,
              label: '김치 프리미엄',
              color: Colors.orange,
              onChanged:
                  (val) => setState(() => showKimchiPremium = val ?? true),
            ),
            _CheckBoxItem(
              value: showAITrading,
              label: 'AI 매수/매도', // 라벨을 더 짧게!
              color: Colors.deepPurple,
              onChanged: (val) {
                setState(() {
                  showAITrading = val ?? false;
                  if (showAITrading) {
                    aiTradeResults = AISimulationPage.simulateResults(
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
          ],
        ),
      ),
    );
  }

  // 5. 매매 전략 영역
  Widget _buildStrategySection() {
    if (!shouldShowAdUnlockButton()) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 타이틀과 시뮬레이션 버튼
              Row(
                children: [
                  const Text(
                    '매매 전략',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  OutlinedButton(
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(fontSize: 15),
                    ),
                    child: const Text('AI 매매 전략 시뮬레이션'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 전략 테이블
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {
                  0: IntrinsicColumnWidth(),
                  1: FlexColumnWidth(),
                },
                children: [
                  TableRow(
                    children: [
                      _StrategyCell('추천 매수 가격', isHeader: true),
                      _StrategyCell('${parsedStrategy?['buy_price'] ?? '-'}'),
                    ],
                  ),
                  TableRow(
                    children: [
                      _StrategyCell('추천 매도 가격', isHeader: true),
                      _StrategyCell('${parsedStrategy?['sell_price'] ?? '-'}'),
                    ],
                  ),
                  TableRow(
                    children: [
                      _StrategyCell('예상 기대 수익', isHeader: true),
                      _StrategyCell(
                        '${parsedStrategy?['expected_return'] ?? '-'}',
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      _StrategyCell('AI 요약', isHeader: true),
                      _StrategyCell('${parsedStrategy?['summary'] ?? '-'}'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 히스토리 버튼
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () async {
                    final response = await http.get(Uri.parse(strategyUrl));
                    if (response.statusCode == 200) {
                      final List<dynamic> history = json.decode(
                        utf8.decode(response.bodyBytes),
                      );
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              backgroundColor: Colors.white,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 500,
                                  maxWidth: 380,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 18,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          '매매 전략 히스토리',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.deepPurple,
                                          ),
                                          onPressed:
                                              () => Navigator.of(context).pop(),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 18, thickness: 1),
                                    Expanded(
                                      child: Scrollbar(
                                        thumbVisibility: true,
                                        child: ListView.separated(
                                          itemCount: history.length,
                                          separatorBuilder:
                                              (_, __) =>
                                                  const Divider(height: 18),
                                          itemBuilder: (context, idx) {
                                            final strat = history[idx];
                                            return Card(
                                              elevation: 1,
                                              color: Colors.grey[50],
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 14,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.calendar_today,
                                                          size: 16,
                                                          color:
                                                              Colors.deepPurple,
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          strat['analysis_date'] ??
                                                              '-',
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 15,
                                                            color:
                                                                Colors
                                                                    .deepPurple,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    _HistoryRow(
                                                      label: '매수',
                                                      value: strat['buy_price'],
                                                    ),
                                                    _HistoryRow(
                                                      label: '매도',
                                                      value:
                                                          strat['sell_price'],
                                                    ),
                                                    _HistoryRow(
                                                      label: '예상 수익',
                                                      value:
                                                          strat['expected_return'],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    const Text(
                                                      '요약',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    Text(
                                                      strat['summary'] ?? '-',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.black87,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                    } else {
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder:
                              (_) => Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                        size: 36,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        '전략 히스토리 불러오기 실패',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 15),
                  ),
                  child: const Text('히스토리'),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // 카드 스타일로 광고 버튼 감싸기
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16),
          child: Center(
            child: ElevatedButton.icon(
              onPressed:
                  _rewardedAd == null
                      ? null
                      : () =>
                          _showRewardedAd(scrollController: _scrollController),
              icon: const Icon(Icons.ondemand_video, color: Colors.white),
              label: const Text('광고 보고 전략 보기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ),
        ),
      );
    }
  }
}

// 정보 카드용 위젯
class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoItem({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// 체크박스용 위젯
class _CheckBoxItem extends StatelessWidget {
  final bool value;
  final String label;
  final Color color;
  final ValueChanged<bool?> onChanged;
  const _CheckBoxItem({
    required this.value,
    required this.label,
    required this.color,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// 전략 테이블 셀 위젯
class _StrategyCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  const _StrategyCell(this.text, {this.isHeader = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
      ),
    );
  }
}

// 히스토리 행 위젯
class _HistoryRow extends StatelessWidget {
  final String label;
  final dynamic value;
  const _HistoryRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.deepPurple,
            ),
          ),
          Text(value?.toString() ?? '-', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// 사용자 ID 가져오기/생성 함수
Future<String> getOrCreateUserId() async {
  final prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('user_id');
  if (userId == null) {
    userId = const Uuid().v4();
    await prefs.setString('user_id', userId);
  }
  return userId;
}

// iOS 시뮬레이터 여부 확인 함수
Future<bool> isIOSSimulator() async {
  if (!Platform.isIOS) return false;
  final deviceInfo = DeviceInfoPlugin();
  final iosInfo = await deviceInfo.iosInfo;
  // iOS 시뮬레이터는 device name이 "iPhone Simulator" 등으로 나옴
  return !iosInfo.isPhysicalDevice;
}

// IDFA 출력 함수 (iOS 전용)
Future<void> printIDFA() async {
  if (!kDebugMode) return;

  if (!Platform.isIOS) {
    print('IDFA는 iOS에서만 지원됩니다.');
    return;
  }
  try {
    final idfa = await AdvertisingId.id(true);
    print('IDFA: $idfa');
  } catch (e) {
    print('IDFA 가져오기 실패: $e');
  }
}
