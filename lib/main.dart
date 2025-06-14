import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'ChartOnlyPage.dart';
import 'AISimulationPage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb을 사용하기 위해 import
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'OnboardingPage.dart'; // 온보딩 페이지 import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'utils.dart';
import 'widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await Firebase.initializeApp();

    // Crashlytics 에러 자동 수집 활성화
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    await printIDFA();
  }

  runApp(const MyApp());
}

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

class _MyHomePageState extends State<MyHomePage> {
  final ApiService api = ApiService();
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
  bool showGimchiTrading = false; // 김프 거래 표시 여부 추가
  bool showExchangeRate = true; // 환율 표시 여부 추가
  String? strategyText;
  Map<String, dynamic>? latestStrategy;
  ChartData? latestGimchiStrategy;
  ChartData? latestExchangeRate;
  List<USDTChartData> usdtChartData = [];
  Map<String, dynamic> usdtMap = {};
  List<SimulationResult> aiTradeResults = [];
  List strategyList = [];
  bool _strategyUnlocked = false; // 광고 시청 여부
  RewardedAd? _rewardedAd;

  double kimchiMin = 0;
  double kimchiMax = 0;

  ChartOnlyPageModel? chartOnlyPageModel;

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

  // PlotBand 표시 여부 상태 추가
  bool showKimchiPlotBands = false;
  int _selectedStrategyTabIndex = 0; // 0: AI 매매 전략, 1: 김프 매매 전략

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

    // 앱이 푸시 클릭으로 실행된 경우 알림 팝업
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        showPushAlert(message);
      }
    });

    // 포그라운드
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showPushAlert(message);
    });

    // 백그라운드에서 푸시 클릭
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
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
        Uri.parse(ApiService.fcmTokenUrl),
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
      final results = await Future.wait([
        api.fetchExchangeRateData(),
        api.fetchUSDTData(),
        api.fetchKimchiPremiumData(),
        api.fetchStrategy(),
      ]);
      setState(() {
        exchangeRates = results[0] as List<ChartData>;
        usdtMap = results[1] as Map<String, dynamic>;
        kimchiPremium = results[2] as List<ChartData>;
        strategyList = results[3] as List;

        latestGimchiStrategy = kimchiPremium.first as ChartData?;
        latestExchangeRate = exchangeRates.last as ChartData?;
        latestStrategy = strategyList.first as Map<String, dynamic>?;

        kimchiMin = kimchiPremium
            .map((e) => e.value)
            .reduce((a, b) => a < b ? a : b);
        kimchiMax = kimchiPremium
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b);

        // usdtChartData 등 기존 파싱 로직은 필요시 추가
        if (usdtMap.isNotEmpty) {
          final List<USDTChartData> rate = [];
          usdtMap.forEach((key, value) {
            final close = value['close']?.toDouble() ?? 0;
            final high = value['high']?.toDouble() ?? 0;
            final low = value['low']?.toDouble() ?? 0;
            final open = value['open']?.toDouble() ?? 0;
            rate.add(
              USDTChartData(DateTime.parse(key), open, close, high, low),
            );
          });
          rate.sort((a, b) => a.time.compareTo(b.time));
          usdtChartData = rate;
        }

        chartOnlyPageModel = ChartOnlyPageModel(
          exchangeRates: exchangeRates,
          kimchiPremium: kimchiPremium,
          strategyList: strategyList,
          usdtMap: usdtMap,
          usdtChartData: usdtChartData,
          aiTradeResults: aiTradeResults,
          kimchiMin: kimchiMin,
          kimchiMax: kimchiMax,
        );

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
    bool show = showAITrading || showGimchiTrading;
    if (show && aiTradeResults.isNotEmpty && usdtChartData.isNotEmpty) {
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
  Card? shouldShowAdUnlockButton() {
    if (kIsWeb) return null; // 웹에서는 광고 버튼 표시 안 함
    if (_strategyUnlocked) return null; // 전략이 이미 공개된 경우

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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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

    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final double chartHeight =
        isLandscape
            ? mediaQuery.size.height *
                0.6 // 가로모드: 60%
            : mediaQuery.size.height * 0.3; // 세로모드: 기존 30%

    final singleChildScrollView = SingleChildScrollView(
      controller: _scrollController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
        child: Column(
          children: [
            _buildTodayComment(todayUsdt),
            _buildTodayInfoCard(todayUsdt, todayRate, todayKimchi),
            const SizedBox(height: 4),
            _buildChartCard(chartHeight),
            const SizedBox(height: 8),
            _buildStrategySection(),
            if (kDebugMode)
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

  Widget _buildTodayComment(USDTChartData? todayUsdt) {
    final usdtPrice = todayUsdt?.close ?? 0.0;

    // AI 매매 전략 탭
    double buyPrice = 0.0;
    double sellPrice = 0.0;
    String comment = '';
    double exchangeRateValue = latestExchangeRate?.value ?? 0.0;

    if (_selectedStrategyTabIndex == 0) {
      buyPrice = latestStrategy?['buy_price'] ?? 0;
      sellPrice = latestStrategy?['sell_price'] ?? 0;
    } else {
      buyPrice =
          (exchangeRateValue * (1 + AISimulationPage.kimchiBuyThreshold / 100));
      sellPrice =
          (exchangeRateValue *
              (1 + AISimulationPage.kimchiSellThreshold / 100));
    }

    // 오늘 날짜에 대한 코멘트 생성
    if (usdtPrice <= buyPrice) {
      comment = '⚠️ 현재 매수 유리 구간입니다';
    } else if (usdtPrice > sellPrice) {
      comment = '⚠️ 현재 매도 유리 구간입니다';
    } else {
      comment = '⚠️ 현재 관망 구간입니다';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              comment,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
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
            InfoItem(
              label: 'USDT',
              value:
                  todayUsdt != null ? todayUsdt.close.toStringAsFixed(1) : '-',
              color: Colors.blue,
            ),
            InfoItem(
              label: '환율',
              value:
                  todayRate != null ? todayRate.value.toStringAsFixed(1) : '-',
              color: Colors.green,
            ),
            InfoItem(
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

  // 3. 차트 카드
  Widget _buildChartCard(double chartHeight) {
    List<PlotBand> kimchiPlotBands =
        showKimchiPlotBands ? getKimchiPlotBands() : [];

    return Stack(
      children: [
        Material(
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
              onTooltipRender: (TooltipArgs args) {
                final clickedPoint =
                    args.dataPoints?[(args.pointIndex ?? 0) as int];

                // Date로 부터 환율 정보를 얻는다.
                final exchangeRate = getExchangeRate(clickedPoint.x);
                // Date로 부터 USDT 정보를 얻는다.
                final usdtValue = getUsdtValue(clickedPoint.x);
                // 김치 프리미엄 계산은 USDT 값과 환율을 이용
                double kimchiPremiumValue;

                // AI 매도, 김프 매도 일 경우 김치 프리미엄은 simulationResult의 usdExchageRateAtSell을 사용 계산
                if (args.header == 'AI 매도' || args.header == '김프 매도') {
                  final simulationResult = getSimulationResult(clickedPoint.x);
                  kimchiPremiumValue =
                      simulationResult?.gimchiPremiumAtSell() ?? 0.0;
                } else if (args.header == 'AI 매수' || args.header == '김프 매수') {
                  final simulationResult = getSimulationResult(clickedPoint.x);
                  kimchiPremiumValue =
                      simulationResult?.gimchiPremiumAtBuy() ?? 0.0;
                } else {
                  kimchiPremiumValue =
                      ((usdtValue - exchangeRate) / exchangeRate * 100);
                }

                // 툴팁 텍스트를 기존 텍스트에 김치 프리미엄 값을 추가
                args.text =
                    '${args.text}\n'
                    'Gimchi: ${kimchiPremiumValue.toStringAsFixed(2)}%';
              },

              legend: const Legend(
                isVisible: true,
                position: LegendPosition.bottom,
              ),
              margin: const EdgeInsets.all(10),
              primaryXAxis: DateTimeAxis(
                edgeLabelPlacement: EdgeLabelPlacement.shift,
                intervalType: DateTimeIntervalType.days,
                dateFormat: DateFormat.yMd(),
                rangePadding: ChartRangePadding.additionalEnd,
                initialZoomFactor: 0.9,
                initialZoomPosition: 0.8,
                plotBands: kimchiPlotBands,
              ),
              primaryYAxis: NumericAxis(
                rangePadding: ChartRangePadding.auto,
                labelFormat: '{value}',
                numberFormat: NumberFormat("###,##0.0"),
                minimum: getUsdtMin(usdtChartData),
                maximum: getUsdtMax(usdtChartData),
              ),
              axes: <ChartAxis>[
                if (showKimchiPremium)
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
                    minimum: kimchiMin - 0.5,
                    maximum: kimchiMax + 0.5,
                  ),
              ],
              zoomPanBehavior: _zoomPanBehavior,
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries>[
                if (!(showAITrading || showGimchiTrading))
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
                if ((showAITrading || showGimchiTrading) &&
                    aiTradeResults.isNotEmpty) ...[
                  ScatterSeries<dynamic, DateTime>(
                    name: showAITrading ? 'AI 매수' : '김프 매수',
                    dataSource: aiTradeResults.toList(),
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
                    name: showAITrading ? 'AI 매도' : '김프 매도',
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
        ),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // 원하는 배경색
              borderRadius: BorderRadius.circular(8), // 모서리 둥글게(선택)
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.deepPurple),
              tooltip: '차트 리셋',
              onPressed: () {
                setState(() {
                  _zoomPanBehavior.reset();
                });
              },
            ),
          ),
        ),
        // 확대 버튼 (오른쪽 상단)
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // 원하는 배경색
              borderRadius: BorderRadius.circular(8), // 모서리 둥글게(선택)
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: IconButton(
              icon: const Icon(Icons.open_in_full, color: Colors.deepPurple),
              tooltip: '차트 확대',
              onPressed: () {
                // ChartOnlyPage로 전달
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => ChartOnlyPage.fromModel(chartOnlyPageModel!),
                    fullscreenDialog: true,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // 환율 데이터를 날짜로 조회하는 함수 추가
  double getExchangeRate(DateTime date) {
    // 날짜가 같은 환율 데이터 찾기 (날짜만 비교)
    for (final rate in exchangeRates) {
      if (rate.time.year == date.year &&
          rate.time.month == date.month &&
          rate.time.day == date.day) {
        return rate.value;
      }
    }
    return 0.0;
  }

  // 시뮬레이션 결과를 날짜로 조회하는 함수 추가
  SimulationResult? getSimulationResult(DateTime date) {
    for (final result in aiTradeResults) {
      if (result.buyDate != null) {
        final buyDate = DateTime.parse(result.buyDate);
        if (buyDate.year == date.year &&
            buyDate.month == date.month &&
            buyDate.day == date.day) {
          return result;
        }
      }
      if (result.sellDate != null) {
        final sellDate = DateTime.parse(result.sellDate!);
        if (sellDate.year == date.year &&
            sellDate.month == date.month &&
            sellDate.day == date.day) {
          return result;
        }
      }
    }
    return null;
  }

  // USDT 데이터를 날짜로 조회하는 함수 추가
  double getUsdtValue(DateTime date) {
    for (final usdt in usdtChartData) {
      if (usdt.time.year == date.year &&
          usdt.time.month == date.month &&
          usdt.time.day == date.day) {
        return usdt.close;
      }
    }
    return 0.0;
  }

  List<PlotBand> getKimchiPlotBands() {
    List<PlotBand> kimchiPlotBands = [];
    DateTime bandStart = kimchiPremium.first.time;

    double maxGimchRange = kimchiMax - kimchiMin;

    Color? previousColor;
    for (int i = 0; i < kimchiPremium.length; i++) {
      final data = kimchiPremium[i];

      // 색상 계산: 낮을수록 파랑, 높을수록 빨강 (0~5% 기준)
      double t = ((data.value - kimchiMin) / maxGimchRange).clamp(0.0, 1.0);
      Color bandColor = Color.lerp(
        Colors.blue,
        Colors.red,
        t,
      )!.withOpacity(0.6);

      kimchiPlotBands.add(
        PlotBand(
          isVisible: true,
          start: bandStart, // DateTime
          end: data.time, // DateTime
          gradient: LinearGradient(
            colors: [(previousColor ?? bandColor), bandColor],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      );

      bandStart = data.time; // 다음 시작점 업데이트
      previousColor = bandColor; // 이전 색상 업데이트
    }
    return kimchiPlotBands;
  }

  // 5. 매매 전략 영역
  Widget _buildStrategySection() {
    final adUnlockButton = shouldShowAdUnlockButton();
    if (adUnlockButton != null) {
      return adUnlockButton; // 광고 시청 버튼이 있다면 바로 반환
    }

    return DefaultTabController(
      length: 2,
      initialIndex: _selectedStrategyTabIndex, // 초기 선택 탭 적용
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.deepPurple,
                onTap: (idx) {
                  setState(() {
                    _selectedStrategyTabIndex = idx;
                  });
                },
                tabs: const [Tab(text: 'AI 매매 전략'), Tab(text: '김프 매매 전략')],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(), // ← 이 줄 추가!
                  children: [_buildAiStrategyTab(), _buildGimchiStrategyTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 기존 AI 매매 전략 UI --- 분리된 메소드
  Widget _buildAiStrategyTab() {
    final buyPrice = latestStrategy?['buy_price'];
    final sellPrice = latestStrategy?['sell_price'];
    final profitRate = latestStrategy?['expected_return'];
    final strategy = latestStrategy?['summary'];
    final profitRateStr =
        profitRate != null
            ? (profitRate >= 0
                ? '+${profitRate.toStringAsFixed(2)}%'
                : '${profitRate.toStringAsFixed(2)}%')
            : '-';

    return makeStrategyTab(
      SimulationType.ai,
      '전략 보기',
      buyPrice,
      sellPrice,
      profitRateStr,
      strategy,
    );
  }

  Card makeStrategyTab(
    SimulationType type,
    String title,
    buyPrice,
    sellPrice,
    String profitRateStr,
    strategy,
  ) {
    // 소숫점 첫째자리까지로 변환
    String buyPriceStr =
        buyPrice != null
            ? (buyPrice is num
                ? buyPrice.toStringAsFixed(1)
                : buyPrice.toString())
            : '-';
    String sellPriceStr =
        sellPrice != null
            ? (sellPrice is num
                ? sellPrice.toStringAsFixed(1)
                : sellPrice.toString())
            : '-';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '매수: $buyPriceStr',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '매도: $sellPriceStr',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '수익률: $profitRateStr',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                // 라운드 버튼으로 요약
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.lightbulb, color: Colors.deepPurple),
                    label: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.deepPurple,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade50, // 연보라색 배경
                      foregroundColor: Colors.deepPurple,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              title: Row(
                                children: [
                                  const Icon(
                                    Icons.lightbulb,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(title),
                                ],
                              ),
                              content: SingleChildScrollView(
                                child: Text(
                                  strategy != null &&
                                          strategy is String &&
                                          strategy.isNotEmpty
                                      ? strategy
                                      : '전략 요약 정보가 없습니다.',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('닫기'),
                                ),
                              ],
                            ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.bar_chart, color: Colors.deepPurple),
                label: const Text(
                  '시뮬레이션 해보기',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.deepPurple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: Colors.deepPurple,
                ),
                onPressed:
                    latestStrategy == null
                        ? null
                        : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => AISimulationPage(
                                    simulationType: type,
                                    usdtMap: usdtMap,
                                    strategyList: strategyList,
                                    usdExchangeRates: exchangeRates,
                                    chartOnlyPageModel: chartOnlyPageModel,
                                  ),
                              fullscreenDialog: true,
                            ),
                          );
                        },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGimchiStrategyTab() {
    final buyPrice =
        (latestExchangeRate!.value *
            (1 + AISimulationPage.kimchiBuyThreshold / 100));
    final sellPrice =
        (latestExchangeRate!.value *
            (1 + AISimulationPage.kimchiSellThreshold / 100));

    final profitRate =
        AISimulationPage.kimchiSellThreshold -
        AISimulationPage.kimchiBuyThreshold;
    final strategy =
        '김치 프리미엄이 ${AISimulationPage.kimchiBuyThreshold}% 이하일 때 매수, '
        '${AISimulationPage.kimchiSellThreshold}% 이상일 때 매도';
    final profitRateStr = '+${profitRate.toStringAsFixed(1)}%';

    return makeStrategyTab(
      SimulationType.kimchi,
      '전략 보기',
      buyPrice,
      sellPrice,
      profitRateStr,
      strategy,
    );
  }
}
