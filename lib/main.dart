import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:usdt_signal/l10n/app_localizations.dart';
import 'ChartOnlyPage.dart';
import 'AISimulationPage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb을 사용하기 위해 import
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'OnboardingPage.dart'; // 온보딩 페이지 import
import 'package:shared_preferences/shared_preferences.dart'; // 이미 import 되어 있음
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api_service.dart';
import 'utils.dart';
import 'widgets.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart'; // ATT 패키지 import 추가
import 'package:permission_handler/permission_handler.dart';
import 'anonymous_chat_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart'; // url_launcher 패키지 import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await Firebase.initializeApp();

    // Crashlytics 에러 자동 수집 활성화
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Analytics 초기화 및 사용자 식별
    await _initializeAnalytics();

    await printIDFA();
  }

  runApp(const MyApp());
}

Future<void> _initializeAnalytics() async {
  try {
    final analytics = FirebaseAnalytics.instance;

    // Analytics 수집 활성화
    await analytics.setAnalyticsCollectionEnabled(true);

    // 사용자 ID 설정 (익명 사용자도 추적 가능)
    final userId = await getOrCreateUserId();
    await analytics.setUserId(id: userId);

    // 앱 버전 정보 가져오기
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    // 사용자 속성 설정
    await analytics.setUserProperty(
      name: 'platform',
      value: Platform.isIOS ? 'ios' : 'android',
    );
    await analytics.setUserProperty(name: 'app_version', value: appVersion);
    await analytics.setUserProperty(
      name: 'app_name',
      value: packageInfo.appName,
    );

    print(
      'Firebase Analytics 초기화 완료 - User ID: $userId, App Version: $appVersion',
    );
  } catch (e) {
    print('Firebase Analytics 초기화 실패: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ko'), Locale('zh')],
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

    // 온보딩 완료 이벤트 로깅
    if (!kIsWeb) {
      await FirebaseAnalytics.instance.logEvent(
        name: 'onboarding_completed',
        parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      );
    }

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

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
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
  StrategyMap? latestStrategy;
  List<USDTChartData> usdtChartData = [];
  Map<DateTime, USDTChartData> usdtMap = {};
  List<StrategyMap> strategyList = [];

  AdsStatus _adsStatus = AdsStatus.unload; // 광고 상태 관리

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

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
  TodayCommentAlarmType _todayCommentAlarmType =
      TodayCommentAlarmType.off; // enum으로 변경

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SimulationCondition.instance.load();
    _initAll();
    _startPolling();

    // 앱 시작 이벤트 로깅
    if (!kIsWeb) {
      _logAppStart();
    }
  }

  Future<void> _logAppStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;

      await FirebaseAnalytics.instance.logEvent(
        name: 'app_start',
        parameters: {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'is_first_launch': onboardingDone ? 'false' : 'true',
        },
      );
    } catch (e) {
      print('앱 시작 이벤트 로깅 실패: $e');
    }
  }

  Future<void> _initAll() async {
    if (!kIsWeb) {
      await _requestATT();
      _setupFCMPushSettings();
      await MobileAds.instance.initialize();
      _loadRewardedAd();
    }

    await _loadAllApis();

    if (!kIsWeb) {
      _todayCommentAlarmType = await TodayCommentAlarmTypePrefs.loadFromPrefs();

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final settings =
            await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
          final result = await FirebaseMessaging.instance.requestPermission();
          if (result.authorizationStatus == AuthorizationStatus.authorized ||
              result.authorizationStatus == AuthorizationStatus.provisional) {
            await showAlarmSettingDialog(context);
          }
        }
      });
    }
  }

  void _startPolling() {
    Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!mounted) return; // 위젯이 마운트되지 않은 경우 early return
      if (usdtChartData.isEmpty || usdtMap.isEmpty || exchangeRates.isEmpty) {
        return;
      }

      final usdt = await api.fetchLatestUSDTData();
      if (usdt != null && usdtChartData.isNotEmpty) {
        setState(() {
          usdtChartData.safeLast?.close = usdt;
          final key = usdtChartData.safeLast?.time; // 시간 문자열로 변환
          if (usdtMap.containsKey(key)) {
            usdtMap[key]?.close = usdt;
          }
        });
      }

      final exchangeRate = await api.fetchLatestExchangeRate();
      if (exchangeRate != null) {
        exchangeRates.safeLast?.value = exchangeRate;
      }

      setState(() {
        kimchiPremium.safeLast?.value = gimchiPremium(
          usdtChartData.safeLast?.close ?? 0,
          exchangeRates.safeLast?.value ?? 0,
        );
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ATT 권한 요청 함수 추가
  Future<void> _requestATT() async {
    if (Platform.isIOS) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }
  }

  void _setupFCMPushSettings() async {
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

    // FCM 토큰 얻기
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      print('FCM Token: $token');

      // 서버에 토큰을 저장(POST)해야 푸시를 받을 수 있습니다.
      if (token != null) {
        await ApiService.saveFcmTokenToServer(token);
      }
    } catch (e) {
      print('FCM 토큰을 가져오는 중 오류 발생: $e');
      _showRetryDialog();
      return;
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
    if (message.notification != null && context.mounted) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(
                message.notification!.title ?? '알림',
                style: const TextStyle(fontSize: 16),
              ),
              content: Text(message.notification!.body ?? ''),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n(context).close),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _loadAllApis() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      // 0단계: 캐시된 전략 데이터 먼저 로드
      await _loadCachedStrategy();

      // 1단계: 빠른 데이터만 먼저 로드 (AI 전략 제외)
      final fastResults = await Future.wait([
        api.fetchExchangeRateData(),
        api.fetchUSDTData(),
        api.fetchKimchiPremiumData(),
      ]);

      exchangeRates = fastResults[0] as List<ChartData>;
      usdtMap = fastResults[1] as Map<DateTime, USDTChartData>;
      kimchiPremium = fastResults[2] as List<ChartData>;

      final exchangeRate = await api.fetchLatestExchangeRate();
      if (exchangeRate != null) {
        exchangeRates.safeLast?.value = exchangeRate;
      }

      // usdtChartData 파싱
      usdtChartData = [];
      usdtMap.forEach((key, value) {
        final close = value.close;
        final high = value.high;
        final low = value.low;
        final open = value.open;
        usdtChartData.add(USDTChartData(key, open, close, high, low));
      });
      usdtChartData.sort((a, b) => a.time.compareTo(b.time));

      kimchiPremium.safeLast?.value = gimchiPremium(
        usdtChartData.safeLast?.close ?? 0,
        exchangeRates.safeLast?.value ?? 0,
      );

      // 2단계: UI 먼저 표시 (캐시된 전략 포함)
      setState(() {
        kimchiMin = kimchiPremium
            .map((e) => e.value)
            .reduce((a, b) => a < b ? a : b);
        kimchiMax = kimchiPremium
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b);

        chartOnlyPageModel = ChartOnlyPageModel(
          exchangeRates: exchangeRates,
          kimchiPremium: kimchiPremium,
          strategyList: strategyList, // 캐시된 전략 또는 빈 리스트
          usdtMap: usdtMap,
          usdtChartData: usdtChartData,
          kimchiMin: kimchiMin,
          kimchiMax: kimchiMax,
        );

        _loading = false; // UI 즉시 표시
        _loadError = null;
      });

      // 3단계: AI 전략은 백그라운드에서 로드 (캐시가 있어도 최신 데이터 확인)
      _loadStrategyInBackground();
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

  // 캐시된 전략 데이터를 로드하는 함수
  Future<void> _loadCachedStrategy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStrategyJson = prefs.getString('cached_strategy');

      if (cachedStrategyJson != null) {
        final cachedData = jsonDecode(cachedStrategyJson);
        if (cachedData is List && cachedData.isNotEmpty) {
          strategyList =
              cachedData
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
          latestStrategy = strategyList.isNotEmpty ? strategyList.first : null;
          print('📱 캐시된 전략 데이터 로드 완료: ${strategyList.length}개');
        }
      }
    } catch (e) {
      print('❌ 캐시된 전략 데이터 로드 실패: $e');
    }
  }

  // 전략 데이터를 캐시에 저장하는 함수
  Future<void> _saveStrategyToCache(List<StrategyMap> strategies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_strategy', jsonEncode(strategies));
      print('💾 전략 데이터 캐시 저장 완료');
    } catch (e) {
      print('❌ 전략 데이터 캐시 저장 실패: $e');
    }
  }

  // AI 전략을 백그라운드에서 로드하는 함수
  Future<void> _loadStrategyInBackground() async {
    try {
      print('🔄 AI 전략 백그라운드 로딩 시작...');
      final strategyData = await api.fetchStrategy();

      if (strategyData != null && mounted) {
        setState(() {
          strategyList = strategyData;
          latestStrategy = strategyList.isNotEmpty ? strategyList.first : null;

          // chartOnlyPageModel 업데이트
          chartOnlyPageModel = ChartOnlyPageModel(
            exchangeRates: exchangeRates,
            kimchiPremium: kimchiPremium,
            strategyList: strategyList,
            usdtMap: usdtMap,
            usdtChartData: usdtChartData,
            kimchiMin: kimchiMin,
            kimchiMax: kimchiMax,
          );
        });

        // 새로운 전략 데이터를 캐시에 저장
        await _saveStrategyToCache(strategyData);
        print('✅ AI 전략 백그라운드 로딩 완료');
      }
    } catch (e) {
      print('❌ AI 전략 백그라운드 로딩 실패: $e');
      // 전략 로딩 실패해도 앱은 계속 동작
    }
  }

  void _loadRewardedAd() async {
    try {
      MapEntry<String, String>? adUnitEntry;

      if (kDebugMode) {
        if (Platform.isIOS) {
          /*
          adUnitEntry = MapEntry(
            'rewarded_ad',
            'ca-app-pub-3940256099942544/1712485313',
          );
          */
          adUnitEntry = await ApiService.fetchRewardedAdUnitId();
        } else if (Platform.isAndroid) {
          /*
          adUnitEntry = MapEntry(
            'rewarded_ad',
            'ca-app-pub-3940256099942544/5224354917',
          );
          */
          adUnitEntry = await ApiService.fetchRewardedAdUnitId();
        }
      } else {
        adUnitEntry = await ApiService.fetchRewardedAdUnitId();
      }

      if (adUnitEntry == null || adUnitEntry.value.isEmpty) {
        print('광고 ID를 받아오지 못했습니다.');
        setState(() {
          _adsStatus = AdsStatus.shown; // 광고 ID가 없으면 바로 전략 공개
        });
        return;
      }

      if (adUnitEntry.key == 'rewarded_ad') {
        // 보상형 광고 로드
        RewardedAd.load(
          adUnitId: adUnitEntry.value,
          request: const AdRequest(nonPersonalizedAds: true),
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) {
              setState(() {
                _rewardedAd = ad;
                _adsStatus = AdsStatus.load;
              });
              print('Rewarded Ad Loaded Successfully');
            },
            onAdFailedToLoad: (error) {
              setState(() {
                _rewardedAd = null;
                _adsStatus = AdsStatus.shown; // 광고 로드 실패 시 전략 공개
              });
              print('Failed to load rewarded ad: ${error.message}');
              print('AD Unit ID: ${adUnitEntry?.value}');
            },
          ),
        );
      } else if (adUnitEntry.key == 'initial_ad') {
        // 전면 광고 로드
        InterstitialAd.load(
          adUnitId: adUnitEntry.value,
          request: const AdRequest(nonPersonalizedAds: true),
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) {
              // 전면 광고를 바로 보여주거나, 원하는 시점에 ad.show() 호출
              setState(() {
                _interstitialAd = ad;
                _adsStatus = AdsStatus.load; // 광고가 로드되면 상태 변경
              });
            },
            onAdFailedToLoad: (error) {
              setState(() {
                _interstitialAd = null;
                _adsStatus = AdsStatus.shown; // 광고 로드 실패 시 전략 공개
              });
              print('Failed to load interstitial ad: ${error.message}');
            },
          ),
        );
      } else {
        print('알 수 없는 광고 타입: ${adUnitEntry.key}');
        setState(() {
          _adsStatus = AdsStatus.shown; // 알 수 없는 광고 타입은 전략 공개
        });
      }
    } catch (e, s) {
      print('Ad load exception: $e\n$s');
      setState(() {
        _adsStatus = AdsStatus.shown; // 예외 발생 시 전략 공개
      });
    }
  }

  void _showAdsView({required ScrollController scrollController}) {
    if (_rewardedAd != null) {
      _showRewardAd(scrollController);
      return;
    }

    if (_interstitialAd != null) {
      _showInterstitialAd(scrollController);
      return;
    }
  }

  void _showInterstitialAd(ScrollController scrollController) {
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => print('전면 광고가 표시됨'),
      onAdDismissedFullScreenContent: (ad) {
        print('전면 광고가 닫힘');
        ad.dispose();

        setState(() {
          _adsStatus = AdsStatus.shown; // 광고가 성공적으로 표시되면 상태 변경
        });

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
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('전면 광고 표시 실패: $error');
        ad.dispose();
        _loadRewardedAd();

        setState(() {
          _adsStatus = AdsStatus.shown; // 광고 표시 실패 시 전략 공개
        });
      },
    );
    _interstitialAd!.show();
  }

  void _showRewardAd(ScrollController scrollController) {
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => print('보상형 광고가 표시됨'),
      onAdDismissedFullScreenContent: (ad) {
        print('보상형 광고가 닫힘');
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('보상형 광고 표시 실패: $error');
        ad.dispose();
      },
    );
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        setState(() {
          _adsStatus = AdsStatus.shown; // 광고가 성공적으로 표시되면 상태 변경
        });
        ad?.dispose();

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

  // 조건 체크 함수
  Card? shouldShowAdUnlockButton() {
    if (kIsWeb) return null; // 웹에서는 광고 버튼 표시 안 함
    if (_adsStatus == AdsStatus.shown) return null; // 전략이 이미 공개된 경우

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16),
        child: Center(
          child: ElevatedButton.icon(
            onPressed: _getShowStrategyButtonHandler(),
            icon: const Icon(Icons.ondemand_video, color: Colors.white),
            label: Text(l10n(context).seeAdsAndStrategy),
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
            title: Text(l10n(context).loadingFail),
            content: const Text('데이터를 불러오는데 실패했습니다.\n다시 시도하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n(context).no),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _loadAllApis();
                },
                child: const Text('예'),
              ),
            ],
          ),
    );
  }

  // 2. 포그라운드 복귀 시 알림 권한 체크
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (kIsWeb) return; // 웹에서는 앱 라이프사이클 이벤트를 처리하지 않음

    if (state == AppLifecycleState.resumed) {
      // 앱 포그라운드 복귀 이벤트 로깅
      try {
        await FirebaseAnalytics.instance.logEvent(
          name: 'app_resumed',
          parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
        );
      } catch (e) {
        print('앱 복귀 이벤트 로깅 실패: $e');
      }

      bool hasPermission = await _hasNotificationPermission();
      if (!hasPermission &&
          _todayCommentAlarmType != TodayCommentAlarmType.off) {
        setState(() {
          _todayCommentAlarmType = TodayCommentAlarmType.off; // 권한이 없으면 알림 끄기
          _todayCommentAlarmType.saveToPrefs(); // 상태 업데이트
        });
      }
    }
  }

  // 3. 권한 체크 함수 (iOS는 FCM, Android는 permission_handler)
  Future<bool> _hasNotificationPermission() async {
    if (Platform.isIOS) {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } else {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
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
            _buildTodayComment(usdtChartData.safeLast),
            _buildTodayInfoCard(
              usdtChartData.safeLast,
              exchangeRates.safeLast,
              kimchiPremium.safeLast,
            ),
            const SizedBox(height: 4),
            _buildChartCard(chartHeight),
            const SizedBox(height: 8),
            _buildStrategySection(),
            if (kDebugMode)
              TextButton(
                onPressed: () => throw Exception(),
                child: Text(l10n(context).throw_test_exception),
              ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FA),
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n(context).usdt_signal,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => OnboardingPage(
                          onFinish: () {
                            Navigator.of(context).pop();
                          },
                        ),
                    fullscreenDialog: true,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 2.0), // 정말 최소 간격
                child: Icon(
                  Icons.help_outline,
                  color: Colors.deepPurple,
                  size: 22,
                ),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.chat_outlined, color: Colors.deepPurple),
              onPressed: () async {
                // 채팅 시작 이벤트 로깅
                if (!kIsWeb) {
                  await FirebaseAnalytics.instance.logEvent(
                    name: 'chat_started',
                    parameters: {
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                    },
                  );
                }

                // 채팅봇 페이지로 네비게이트
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AnonymousChatPage(),
                  ),
                );
              },
            ),
        ],
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
    double exchangeRateValue = exchangeRates.safeLast?.value ?? 0;

    if (_selectedStrategyTabIndex == 0) {
      buyPrice = latestStrategy?['buy_price'] ?? 0;
      sellPrice = latestStrategy?['sell_price'] ?? 0;
    } else {
      buyPrice =
          (exchangeRateValue *
              (1 + SimulationCondition.instance.kimchiBuyThreshold / 100));
      sellPrice =
          (exchangeRateValue *
              (1 + SimulationCondition.instance.kimchiSellThreshold / 100));
    }

    // 디자인 강조: 배경색, 아이콘, 컬러 분기
    Color bgColor;
    IconData icon;
    Color iconColor;

    // 오늘 날짜에 대한 코멘트 생성
    if (usdtPrice <= buyPrice) {
      comment = l10n(context).buyWin;
      bgColor = Colors.green.shade50;
      icon = Icons.trending_up;
      iconColor = Colors.green;
    } else if (usdtPrice > sellPrice) {
      comment = l10n(context).sellWin;
      bgColor = Colors.red.shade50;
      icon = Icons.trending_down;
      iconColor = Colors.red;
    } else {
      comment = l10n(context).justSee;
      // 관망 구간
      bgColor = Colors.yellow.shade50;
      icon = Icons.remove_red_eye;
      iconColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6.0),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bgColor.withOpacity(0.7)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
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
          IconButton(
            iconSize: 30,
            icon: Icon(
              _todayCommentAlarmType == TodayCommentAlarmType.ai ||
                      _todayCommentAlarmType == TodayCommentAlarmType.kimchi
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color:
                  _todayCommentAlarmType == TodayCommentAlarmType.kimchi
                      ? Colors
                          .orange // 김프 알림이면 오렌지색
                      : _todayCommentAlarmType == TodayCommentAlarmType.ai
                      ? Colors
                          .deepPurple // AI 알림이면 딥퍼플
                      : Colors.grey, // OFF면 회색
            ),
            tooltip: '알림 설정',
            onPressed: () async {
              await showAlarmSettingDialog(context);
            },
          ),
        ],
      ),
    );
  }

  // 알림 옵션 위젯 빌더 (enum 타입으로 변경)
  Widget _buildAlarmOptionTile(
    BuildContext context,
    TodayCommentAlarmType value,
    TodayCommentAlarmType selected,
    String text,
  ) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ),
            if (isSelected) const Icon(Icons.check, color: Colors.deepPurple),
          ],
        ),
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
              label: l10n(context).usdt,
              value:
                  todayUsdt != null ? todayUsdt.close.toStringAsFixed(1) : '-',
              color: Colors.blue,
            ),
            InfoItem(
              label: l10n(context).exchangeRate,
              value:
                  todayRate != null ? todayRate.value.toStringAsFixed(1) : '-',
              color: Colors.green,
            ),
            InfoItem(
              label: l10n(context).gimchiPremiem,
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
                double kimchiPremiumValue =
                    ((usdtValue - exchangeRate) / exchangeRate * 100);

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
                    name: l10n(context).usdt,
                    dataSource: usdtChartData,
                    xValueMapper: (USDTChartData data, _) => data.time,
                    yValueMapper: (USDTChartData data, _) => data.close,
                    color: Colors.blue,
                    animationDuration: 0,
                  )
                else
                  // 기존 캔들 차트
                  CandleSeries<USDTChartData, DateTime>(
                    name: l10n(context).usdt,
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
                    name: l10n(context).exchangeRate,
                    dataSource: exchangeRates,
                    xValueMapper: (ChartData data, _) => data.time,
                    yValueMapper: (ChartData data, _) => data.value,
                    color: Colors.green,
                    animationDuration: 0,
                  ),
                if (showKimchiPremium)
                  LineSeries<ChartData, DateTime>(
                    name: '${l10n(context).gimchiPremiem}(%)',
                    dataSource: kimchiPremium,
                    xValueMapper: (ChartData data, _) => data.time,
                    yValueMapper: (ChartData data, _) => data.value,
                    color: Colors.orange,
                    yAxisName: 'kimchiAxis',
                    animationDuration: 0,
                  ),
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
                if (chartOnlyPageModel == null) return;

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

    // AI 전략이 아직 로드되지 않은 경우 로딩 표시
    if (strategyList.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16),
          child: Column(
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
              const SizedBox(height: 16),
              Text(
                'AI 전략을 분석 중입니다...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '잠시만 기다려주세요',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
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
                tabs: [
                  Tab(text: l10n(context).aiStrategy),
                  Tab(text: l10n(context).gimchiStrategy),
                ],
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
      l10n(context).seeStrategy,
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide.none,
        borderRadius: BorderRadius.zero,
      ),
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
                  '${l10n(context).buy}: $buyPriceStr',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${l10n(context).sell}: $sellPriceStr',
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
                  '${l10n(context).gain}: $profitRateStr',
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
                                if (type == SimulationType.kimchi)
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.of(context).pop();
                                      await AISimulationPage.showKimchiStrategyUpdatePopup(
                                        context,
                                      );
                                    },
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.changeStrategy,
                                    ),
                                  ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(l10n(context).close),
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
                label: Text(
                  l10n(context).runSimulation,
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
                        : () async {
                          // 시뮬레이션 시작 이벤트 로깅
                          if (!kIsWeb) {
                            await FirebaseAnalytics.instance.logEvent(
                              name: 'simulation_started',
                              parameters: {
                                'type':
                                    type == SimulationType.ai ? 'ai' : 'kimchi',
                                'timestamp':
                                    DateTime.now().millisecondsSinceEpoch,
                              },
                            );
                          }

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
            const SizedBox(height: 8),
            // 코인 정보 사이트 링크 추가
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.link, color: Colors.blue),
                label: Text(
                  l10n(context).coinInfoSite,
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  foregroundColor: Colors.blue,
                ),
                onPressed: () async {
                  final url = Uri.parse('http://coinpang.org');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 알림 설정 다이얼로그 함수 분리
  Future<void> showAlarmSettingDialog(BuildContext context) async {
    final prevType = _todayCommentAlarmType;
    final updatedType = await showDialog<TodayCommentAlarmType>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l10n(context).selectReceiveAlert,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAlarmOptionTile(
                context,
                TodayCommentAlarmType.ai,
                _todayCommentAlarmType,
                l10n(context).aIalert,
              ),
              _buildAlarmOptionTile(
                context,
                TodayCommentAlarmType.kimchi,
                _todayCommentAlarmType,
                l10n(context).gimpAlert,
              ),
              _buildAlarmOptionTile(
                context,
                TodayCommentAlarmType.off,
                _todayCommentAlarmType,
                l10n(context).turnOffAlert,
              ),
            ],
          ),
        );
      },
    );

    if (updatedType == null) {
      // 다이얼로그가 취소되거나 닫힌 경우
      return;
    }

    if (updatedType != prevType) {
      // 알림을 켜는 경우 권한 체크
      if (prevType == TodayCommentAlarmType.off &&
          (updatedType == TodayCommentAlarmType.ai ||
              updatedType == TodayCommentAlarmType.kimchi)) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final goToSettings = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text(l10n(context).needPermission),
                  content: const Text(
                    '알림을 받으려면 기기 설정에서 알림 권한을 허용해야 합니다.\n설정으로 이동하시겠습니까?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n(context).cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(l10n(context).moveToSetting),
                    ),
                  ],
                ),
          );
          if (goToSettings == true) {
            await openAppSettings();
          }
          // 권한 허용 전까지는 알림 상태를 변경하지 않음
          return;
        }
      }

      // 알림 타입이 변경될 때 서버에 저장
      final isSuccess = await ApiService.saveAndSyncUserData({
        UserDataKey.pushType: updatedType.name,
      });

      if (isSuccess) {
        setState(() {
          _todayCommentAlarmType = updatedType;
          _todayCommentAlarmType.saveToPrefs();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n(context).failedToSaveAlarm)),
        );
      }
    }
  }

  Widget _buildGimchiStrategyTab() {
    final exchangeRateValue = exchangeRates.safeLast?.value ?? 0;
    final buyPrice =
        (exchangeRateValue *
            (1 + SimulationCondition.instance.kimchiBuyThreshold / 100));
    final sellPrice =
        (exchangeRateValue *
            (1 + SimulationCondition.instance.kimchiSellThreshold / 100));

    final profitRate =
        SimulationCondition.instance.kimchiSellThreshold -
        SimulationCondition.instance.kimchiBuyThreshold;

    final buyPriceStr = buyPrice.toStringAsFixed(1);
    final sellPriceStr = sellPrice.toStringAsFixed(1);

    final strategy =
        'USDT가 $buyPriceStr(${SimulationCondition.instance.kimchiBuyThreshold}%) 이하일 때 ${l10n(context).buy}, '
        '$sellPriceStr(${SimulationCondition.instance.kimchiSellThreshold}%) 이상일 때 ${l10n(context).sell}';
    final profitRateStr = '+${profitRate.toStringAsFixed(1)}%';

    return makeStrategyTab(
      SimulationType.kimchi,
      l10n(context).seeStrategy,
      buyPrice,
      sellPrice,
      profitRateStr,
      strategy,
    );
  }

  // 광고 보고 매매 전략 보기 버튼의 onPressed 핸들러 함수 분리
  VoidCallback? _getShowStrategyButtonHandler() {
    // 버튼을 활성화 후 액션 연동
    if (_adsStatus == AdsStatus.load) {
      return () => _showAdsView(scrollController: _scrollController);
    }

    // 버튼을 비활성화 상태로 유지
    return null;
  }
}
