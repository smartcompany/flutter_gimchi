import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:usdt_signal/l10n/app_localizations.dart';
import 'ChartOnlyPage.dart';
import 'simulation_page.dart';
import 'simulation_model.dart';
import 'dart:io';
import 'dialogs/liquid_glass_dialog.dart';
import 'package:flutter/foundation.dart'; // kIsWeb을 사용하기 위해 import
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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
import 'news_splash_view.dart';
import 'dialogs/purchase_confirmation_dialog.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await Firebase.initializeApp();

    // Crashlytics 에러 자동 수집 활성화
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Analytics 초기화 및 사용자 식별
    await _initializeAnalytics();

    await printIDFA();

    // USB로 연결된 디버그 모드에서 화면 잠자기 방지
    // 디버그 모드로 실행할 때는 일반적으로 USB로 연결되어 있음
    if (kDebugMode) {
      await WakelockPlus.enable();
      print('USB 디버그 모드: 화면 잠자기 방지 활성화');
    }
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
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ko'), Locale('zh')],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
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
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: 1.0, // 시스템 폰트 크기 설정을 무시하고 고정
      ),
      child: Builder(
        builder: (context) {
          if (_loading) {
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          }
          if (_onboardingDone) {
            return const MyHomePage();
          }
          return OnboardingPage(onFinish: _finishOnboarding);
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
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
  Map<DateTime, Map<String, double>>? premiumTrends; // 서버에서 받은 김치 프리미엄 트렌드 데이터

  AdsStatus _adsStatus = AdsStatus.unload; // 광고 상태 관리
  bool _showAdOverlay = true; // 광고 오버레이 표시 여부

  static const String _removeAdsProductId = 'com.smartcompany.usdtsignal.noads';
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _removeAdsProduct;
  bool _hasAdFreePass = false;
  bool _isPurchasing = false;

  RewardedAd? _rewardedAd;
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerAdLoaded = false; // 배너 광고 로드 완료 플래그

  double kimchiMin = 0;
  double kimchiMax = 0;
  SimulationYieldData? aiYieldData;
  SimulationYieldData? gimchiYieldData;

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
  ScrollController _scrollController = ScrollController();

  // PlotBand 표시 여부 상태 추가
  bool showKimchiPlotBands = false;
  int _selectedStrategyTabIndex = 0; // 0: AI 매매 전략, 1: 김프 매매 전략
  TodayCommentAlarmType _todayCommentAlarmType =
      TodayCommentAlarmType.off; // enum으로 변경

  // 뉴스 정보
  NewsItem? _latestNews;
  bool _showNewsBanner = false; // 배너 표시 여부

  // 수익률 표시 모드 (true: 연수익률, false: 총 수익률) - AI와 김프 동시 전환
  bool _showAnnualYield = false;

  final PageController _infoPageController = PageController();
  int _infoPageIndex = 0;
  FundingRateInfo? _xrpFundingRate;
  bool _isFundingRateLoading = false;
  DateTime? _fundingRateFetchedAt;
  String _fundingRateSource = 'binance';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    SimulationCondition.instance.load();

    if (!kIsWeb) {
      MobileAds.instance.initialize();
      _requestAppTracking();
      _setupFCMPushSettings();
    }

    _initializeDataPipelines();
    _startPolling();
    _loadLatestNews(); // 별도로 비동기 호출

    // 앱 시작 이벤트 로깅
    if (!kIsWeb) {
      _logAppStart();
    }
  }

  void _initializeDataPipelines() {
    Future(() async {
      // Settings 로드 후 다른 API들과 In-App Purchase 초기화

      await ApiService.shared.loadSettings();

      await _initAPIs();
      await _initInAppPurchase();

      if (kIsWeb) {
        return;
      }

      if (_hasAdFreePass) {
        return;
      }

      // Settings는 이미 로드되었으므로 바로 광고 로드
      _loadRewardedAd();
      _loadBannerAd();
    });
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

  Future<void> _initAPIs() async {
    await _loadAllApis();

    if (!kIsWeb) {
      _todayCommentAlarmType = await TodayCommentAlarmTypePrefs.loadFromPrefs();

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (Platform.isIOS) {
          // iOS: Firebase Messaging 권한 요청
          final settings =
              await FirebaseMessaging.instance.getNotificationSettings();
          if (settings.authorizationStatus ==
              AuthorizationStatus.notDetermined) {
            final result = await FirebaseMessaging.instance.requestPermission();
            if (result.authorizationStatus == AuthorizationStatus.authorized ||
                result.authorizationStatus == AuthorizationStatus.provisional) {
              await showAlarmSettingDialog(context);
            }
          }
        } else if (Platform.isAndroid) {
          // Android: 첫 실행 시에만 알림 설정 다이얼로그 표시
          final prefs = await SharedPreferences.getInstance();
          final alarmSettingConfigured = prefs.containsKey(
            'todayCommentAlarmType',
          );

          if (!alarmSettingConfigured) {
            // 설정이 저장되어 있지 않으면 (첫 실행)
            final status = await Permission.notification.status;
            if (!status.isGranted) {
              // Android 13 이상: 시스템 권한 팝업 표시
              final result = await Permission.notification.request();
              // 권한 요청 후 허용된 경우에만 알림 설정 다이얼로그 표시
              if (result.isGranted) {
                await showAlarmSettingDialog(context);
              }
            } else {
              // Android 13 미만: 권한이 이미 부여되어 있으므로 바로 알림 설정 다이얼로그 표시
              await showAlarmSettingDialog(context);
            }
          }
        }
      });
    }
  }

  Future<void> _initInAppPurchase() async {
    if (kIsWeb) return;
    try {
      final available = await _iap.isAvailable();
      if (!available) return;

      _purchaseSubscription ??= _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {},
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _isPurchasing = false;
          });
        },
      );

      final response = await _iap.queryProductDetails({_removeAdsProductId});
      if (mounted && response.productDetails.isNotEmpty) {
        setState(() {
          _removeAdsProduct = response.productDetails.first;
        });
      }

      // restore를 호출하여 기존 구매 내역을 확인 (iOS, Android 모두)
      await _iap.restorePurchases();
      debugPrint('인앱 결제 복원 완료');
    } catch (e) {
      print('인앱 결제 초기화 실패: $e');
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    print(
      '[Main] _handlePurchaseUpdates called with ${purchaseDetailsList.length} items',
    );

    final matchingPurchase =
        purchaseDetailsList
            .where(
              (purchaseDetails) =>
                  purchaseDetails.productID == _removeAdsProductId,
            )
            .firstOrNull;

    if (matchingPurchase == null) {
      print(
        '[Main] No matching purchase found for product: $_removeAdsProductId',
      );
      return;
    }

    print(
      '[Main] Matching purchase found: ${matchingPurchase.productID}, status: ${matchingPurchase.status}',
    );

    switch (matchingPurchase.status) {
      case PurchaseStatus.pending:
        print('[Main] Purchase pending');
        if (mounted) {
          setState(() {
            _isPurchasing = true;
          });
        }
        break;
      case PurchaseStatus.purchased:
        print('[Main] Purchase successful (purchased)');
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _hasAdFreePass = true;
            _adsStatus = AdsStatus.shown;
          });
          _disposeAds();
          print('[Main] Ad-free pass activated');
          // 구매 완료 시 팝업 닫기는 Dialog 내부에서 처리함
        }
        break;
      case PurchaseStatus.restored:
        print('[Main] Purchase restored successfully');
        if (kDebugMode) {
          break;
        }

        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _hasAdFreePass = true;
            _adsStatus = AdsStatus.shown;
          });
          _disposeAds();
          print('[Main] Ad-free pass activated from restore');
        }
        break;
      case PurchaseStatus.error:
        print('[Main] Purchase error: ${matchingPurchase.error?.message}');
        if (mounted) {
          setState(() {
            _isPurchasing = false;
          });
        }
        break;
      case PurchaseStatus.canceled:
        print('[Main] Purchase canceled');
        if (mounted) {
          setState(() {
            _isPurchasing = false;
          });
        }
        break;
    }

    if (matchingPurchase.pendingCompletePurchase) {
      print('[Main] Completing purchase...');
      _iap.completePurchase(matchingPurchase);
    }
  }

  Future<void> _buyAdRemoval() async {
    if (_removeAdsProduct == null || _isPurchasing) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PurchaseConfirmationDialog(
            product: _removeAdsProduct!,
            iap: _iap,
          ),
    );
  }

  void _disposeAds() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdLoaded = false;
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  void _showStrategyDirectly() {
    setState(() {
      _adsStatus = AdsStatus.shown;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _startPolling() {
    Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!mounted) return; // 위젯이 마운트되지 않은 경우 early return
      if (usdtChartData.isEmpty || usdtMap.isEmpty || exchangeRates.isEmpty) {
        return;
      }

      final usdt = await ApiService.shared.fetchLatestUSDTData();
      if (usdt != null && usdtChartData.isNotEmpty) {
        setState(() {
          usdtChartData.safeLast?.close = usdt;
          final key = usdtChartData.safeLast?.time; // 시간 문자열로 변환
          if (usdtMap.containsKey(key)) {
            usdtMap[key]?.close = usdt;
          }
        });
      }

      final exchangeRate = await ApiService.shared.fetchLatestExchangeRate();
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

  Future<void> _loadXrpFundingRate({bool force = false}) async {
    if (_isFundingRateLoading) return;
    final lastFetched = _fundingRateFetchedAt;
    if (!force &&
        lastFetched != null &&
        DateTime.now().difference(lastFetched).inSeconds < 30) {
      return;
    }
    setState(() {
      _isFundingRateLoading = true;
    });

    final result =
        _fundingRateSource == 'bybit'
            ? await ApiService.shared.fetchXrpFundingRateBybit()
            : await ApiService.shared.fetchXrpFundingRate();
    if (!mounted) return;

    setState(() {
      _isFundingRateLoading = false;
      if (result != null) {
        _xrpFundingRate = result;
        _fundingRateFetchedAt = DateTime.now();
      }
    });
  }

  void _toggleFundingRateSource() {
    setState(() {
      _fundingRateSource =
          _fundingRateSource == 'binance' ? 'bybit' : 'binance';
      _xrpFundingRate = null;
      _fundingRateFetchedAt = null;
    });
    _loadXrpFundingRate(force: true);
  }

  // 배너 광고 로드
  void _loadBannerAd() async {
    if (_hasAdFreePass) return;
    try {
      MapEntry<String, String>? adUnitEntry;

      adUnitEntry = ApiService.shared.bannerAdUnitId;

      if (adUnitEntry == null || adUnitEntry.value.isEmpty) {
        print('배너 광고 ID를 받아오지 못했습니다.');
        print('Settings 상태: ${ApiService.shared.settings}');
        print(
          'Android Banner AD Key: ${ApiService.shared.settings?['android_banner_ad']}',
        );
        return;
      }

      print('배너 광고 로드 시도 - Type: ${adUnitEntry.key}, ID: ${adUnitEntry.value}');

      // 적응형 배너 크기 가져오기
      final AdSize? adSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            MediaQuery.of(context).size.width.truncate(),
          );

      // 기존 배너 광고 정리
      _bannerAd?.dispose();

      // 로드 상태 초기화
      if (mounted) {
        setState(() {
          _bannerAd = null;
          _isBannerAdLoaded = false;
        });
      }

      final newBannerAd = BannerAd(
        adUnitId: adUnitEntry.value,
        size: adSize ?? AdSize.banner, // adSize가 null이면 기본 배너
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('Banner ad loaded');
            // 로드 성공 시에만 _bannerAd 설정 및 플래그 설정
            if (mounted && ad is BannerAd) {
              setState(() {
                _bannerAd = ad;
                _isBannerAdLoaded = true;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            print('Banner ad failed to load: $error');
            ad.dispose();
            if (mounted) {
              setState(() {
                _bannerAd = null;
                _isBannerAdLoaded = false;
              });
            }
          },
        ),
      );

      // load() 호출 - onAdLoaded 콜백에서만 _bannerAd가 설정됨
      newBannerAd.load();
    } catch (e) {
      print('배너 광고 로드 실패: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _infoPageController.dispose();
    _purchaseSubscription?.cancel();
    _disposeAds();
    super.dispose();
  }

  // ATT 권한 요청 함수 추가
  Future<void> _requestAppTracking() async {
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
        await ApiService.shared.saveFcmTokenToServer(token);
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
      LiquidGlassDialog.show(
        context: context,
        title: Text(
          message.notification!.title ?? '알림',
          style: const TextStyle(fontSize: 18),
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
      );
    }
  }

  Future<void> _loadAllApis() async {
    setState(() {
      _loading = true;
    });

    try {
      // Settings 로드 후 다른 API들을 동시에 진행
      final results = await Future.wait([
        ApiService.shared.fetchExchangeRateData(),
        ApiService.shared.fetchUSDTData(),
        ApiService.shared.fetchKimchiPremiumData(),
      ]);

      print("api들 로딩 완료");

      exchangeRates = results[0] as List<ChartData>;
      usdtMap = results[1] as Map<DateTime, USDTChartData>;
      kimchiPremium = results[2] as List<ChartData>;

      final exchangeRate = await ApiService.shared.fetchLatestExchangeRate();
      if (exchangeRate != null) {
        exchangeRates.safeLast?.value = exchangeRate;
      }

      // usdtChartData 등 기존 파싱 로직은 필요시 추가
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

      // 메인 화면 로딩 완료 후 백그라운드에서 전략 데이터 로딩
      _loadStrategyInBackground();

      setState(() {
        kimchiMin = kimchiPremium
            .map((e) => e.value)
            .reduce((a, b) => a < b ? a : b);
        kimchiMax = kimchiPremium
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b);
        _loading = false;
      });

      unawaited(_loadXrpFundingRate(force: true));
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (context.mounted) {
        _showRetryDialog();
      }
    }
  }

  void _loadRewardedAd() async {
    if (_hasAdFreePass) return;
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
          adUnitEntry = ApiService.shared.rewardedAdUnitId;
        } else if (Platform.isAndroid) {
          /*
          adUnitEntry = MapEntry(
            'rewarded_ad',
            'ca-app-pub-3940256099942544/5224354917',
          );
          */
          adUnitEntry = ApiService.shared.rewardedAdUnitId;
        }
      } else {
        adUnitEntry = ApiService.shared.rewardedAdUnitId;
      }

      if (adUnitEntry == null || adUnitEntry.value.isEmpty) {
        print('광고 ID를 받아오지 못했습니다.');
        print('Settings 상태: ${ApiService.shared.settings}');
        print('Android AD Key: ${ApiService.shared.settings?['android_ad']}');
        setState(() {
          _adsStatus = AdsStatus.shown; // 광고 ID가 없으면 바로 전략 공개
        });
        return;
      }

      print('광고 로드 시도 - Type: ${adUnitEntry.key}, ID: ${adUnitEntry.value}');

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
        ad.dispose();

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
  Widget? shouldShowAdUnlockButton() {
    if (kIsWeb) return null; // 웹에서는 광고 버튼 표시 안 함

    if (_adsStatus == AdsStatus.shown || _hasAdFreePass) return null;

    final aiReturn =
        aiYieldData != null
            ? (_showAnnualYield
                ? '${aiYieldData!.annualYield.toStringAsFixed(2)}%'
                : '${aiYieldData!.totalReturn.toStringAsFixed(1)}%')
            : '-';
    final aiDays =
        !_showAnnualYield && aiYieldData?.tradingDays != null
            ? ' (${aiYieldData!.tradingDays} 🗓️)'
            : '';
    final gimchiReturn =
        gimchiYieldData != null
            ? (_showAnnualYield
                ? '${gimchiYieldData!.annualYield.toStringAsFixed(2)}%'
                : '${gimchiYieldData!.totalReturn.toStringAsFixed(1)}%')
            : '-';
    final gimchiDays =
        !_showAnnualYield && gimchiYieldData?.tradingDays != null
            ? ' (${gimchiYieldData!.tradingDays} 🗓️)'
            : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildYieldInfoTile(
            context,
            title:
                _showAnnualYield
                    ? _getAnnualYieldTitle(context, isAi: true)
                    : l10n(context).aiReturn,
            valueText: aiReturn,
            detailText: aiDays,
            onTap: () {
              setState(() {
                _showAnnualYield = !_showAnnualYield;
              });
            },
          ),
          const SizedBox(height: 8),
          _buildYieldInfoTile(
            context,
            title:
                _showAnnualYield
                    ? _getAnnualYieldTitle(context, isAi: false)
                    : l10n(context).gimchiReturn,
            valueText: gimchiReturn,
            detailText: gimchiDays,
            onTap: () {
              setState(() {
                _showAnnualYield = !_showAnnualYield;
              });
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _removeAdsProduct == null || _isPurchasing
                      ? null
                      : _buyAdRemoval,
              icon:
                  _isPurchasing
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                      : const Icon(Icons.star, size: 20, color: Colors.amber),
              label: Text(
                l10n(context).removeAdsCta,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                minimumSize: const Size(double.infinity, 56),
                fixedSize: const Size(double.infinity, 56),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _getShowStrategyButtonHandler(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                minimumSize: const Size(double.infinity, 56),
                fixedSize: const Size(double.infinity, 56),
              ),
              child: Text(
                l10n(context).todayStrategyAfterAds,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 연수익률 제목 생성 (언어별로 AI/김프 구분)
  String _getAnnualYieldTitle(BuildContext context, {required bool isAi}) {
    final locale = Localizations.localeOf(context);

    if (locale.languageCode == 'en') {
      // 영어: "AI APY" / "K-Premium APY"
      final annualYieldText = l10n(context).extimatedYearGain;
      return isAi ? 'AI $annualYieldText' : 'K-Premium $annualYieldText';
    } else if (locale.languageCode == 'ko') {
      // 한국어: "AI 매매 연수익률" / "김프 매매 연수익률"
      return isAi ? 'AI 매매 연수익률' : '김프 매매 연수익률';
    } else if (locale.languageCode == 'zh') {
      // 중국어: "AI 交易年收益率" / "泡菜溢价 交易年收益率"
      return isAi ? 'AI 交易年收益率' : '泡菜溢价 交易年收益率';
    }

    return l10n(context).extimatedYearGain;
  }

  Widget _buildYieldInfoTile(
    BuildContext context, {
    required String title,
    required String valueText,
    required String detailText,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.swap_horiz,
                    size: 16,
                    color: cs.primary.withValues(alpha: 0.85),
                  ),
                ],
              ],
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: valueText,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  if (detailText.isNotEmpty)
                    TextSpan(
                      text: detailText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 광고 오버레이 (결제 안 한 경우만 표시)
  Widget _buildAdOverlay() {
    if (_hasAdFreePass) {
      return const SizedBox.shrink();
    }

    if (!_showAdOverlay) {
      return const SizedBox.shrink();
    }

    // 광고가 로드되지 않았거나 null이면 표시하지 않음
    if (_bannerAd == null || !_isBannerAdLoaded) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 100, // 충분한 높이 확보
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          // 배너 광고
          Expanded(child: Center(child: AdWidget(ad: _bannerAd!))),
          // 툴팁 메시지
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.45),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n(context).adClickInstruction,
                    style: TextStyle(
                      fontSize: 16,
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // X 버튼
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAdOverlay = false;
                    });
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 최신 뉴스 로드 (별도로 비동기 호출)
  Future<void> _loadLatestNews() async {
    try {
      final news = await ApiService.fetchLatestNews();
      if (mounted && news != null) {
        // SharedPreferences에서 읽은 뉴스 ID 확인
        final prefs = await SharedPreferences.getInstance();
        final readNewsIds = prefs.getStringList('read_news_ids') ?? [];

        // 이미 읽은 뉴스인지 확인
        if (!readNewsIds.contains(news.id.toString())) {
          setState(() {
            _latestNews = news;
            _showNewsBanner = true;
          });
        }
      }
    } catch (e) {
      print('최신 뉴스 로드 실패: $e');
      // 실패해도 메인 화면에는 영향 없음
    }
  }

  // 뉴스 배너 닫기
  Future<void> _dismissNewsBanner() async {
    if (_latestNews == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final readNewsIds = prefs.getStringList('read_news_ids') ?? [];

      // 현재 뉴스 ID를 읽은 목록에 추가
      if (!readNewsIds.contains(_latestNews!.id.toString())) {
        readNewsIds.add(_latestNews!.id.toString());
        await prefs.setStringList('read_news_ids', readNewsIds);
      }

      setState(() {
        _showNewsBanner = false;
      });
    } catch (e) {
      print('뉴스 배너 닫기 실패: $e');
    }
  }

  // 백그라운드에서 전략 데이터 로딩
  Future<void> _loadStrategyInBackground() async {
    try {
      // 김치 프리미엄 트렌드와 함께 전략 데이터 가져오기
      final response = await ApiService.shared.fetchStrategyWithKimchiTrends();

      if (mounted && response != null) {
        final newStrategyList =
            List<StrategyMap>.from(response['strategies'] ?? []);
        final newLatestStrategy =
            newStrategyList.isNotEmpty ? newStrategyList.first : null;

        Map<DateTime, Map<String, double>>? nextPremiumTrends = premiumTrends;
        if (response['kimchiTrends'] != null) {
          print('서버에서 받은 김치 트렌드 데이터 개수: ${response['kimchiTrends'].length}');
          nextPremiumTrends = <DateTime, Map<String, double>>{};
          (response['kimchiTrends'] as Map).forEach((dateStr, trendData) {
            try {
              final date = DateTime.parse(dateStr.toString());
              final Map<String, double> data = {};
              (trendData as Map).forEach((key, value) {
                final stringKey = key.toString();
                if (value is num) {
                  data[stringKey] = value.toDouble();
                }
              });
              nextPremiumTrends![date] = data;
            } catch (e) {
              print('날짜 파싱 에러: $dateStr, $e');
            }
          });
          print('변환된 premiumTrends 개수: ${nextPremiumTrends.length}');
        }

        double? buyFee;
        double? sellFee;
        final settings = ApiService.shared.settings;
        if (settings != null) {
          final upbitFees = settings['upbit_fees'] as Map<String, dynamic>?;
          if (upbitFees != null) {
            buyFee = (upbitFees['buy_fee'] as num?)?.toDouble();
            sellFee = (upbitFees['sell_fee'] as num?)?.toDouble();
          }
        }

        final simInitialKrw =
            await SimulationCondition.instance.getInitialCapitalKrw();
        if (!mounted) return;

        final newAiYield = SimulationModel.getYieldForAISimulation(
          exchangeRates,
          newStrategyList,
          usdtMap,
          initialKRW: simInitialKrw,
          buyFee: buyFee,
          sellFee: sellFee,
        );

        final newGimchiYield = SimulationModel.getYieldForGimchiSimulation(
          exchangeRates,
          newStrategyList,
          usdtMap,
          nextPremiumTrends,
          initialKRW: simInitialKrw,
          buyFee: buyFee,
          sellFee: sellFee,
        );

        final newChartModel = ChartOnlyPageModel(
          exchangeRates: exchangeRates,
          kimchiPremium: kimchiPremium,
          strategyList: newStrategyList,
          usdtMap: usdtMap,
          usdtChartData: usdtChartData,
          kimchiMin: kimchiMin,
          kimchiMax: kimchiMax,
          premiumTrends: nextPremiumTrends,
        );

        setState(() {
          strategyList = newStrategyList;
          latestStrategy = newLatestStrategy;
          premiumTrends = nextPremiumTrends;
          aiYieldData = newAiYield;
          gimchiYieldData = newGimchiYield;
          chartOnlyPageModel = newChartModel;
        });

        print('전략 데이터 로딩 완료');
      }
    } catch (e) {
      chartOnlyPageModel = null;
      print('전략 데이터 로딩 실패: $e');
      // 전략 데이터 로딩 실패는 메인 화면에 영향을 주지 않음
    }
  }

  void _showRetryDialog() {
    LiquidGlassDialog.show(
      context: context,
      barrierDismissible: false,
      title: Text(l10n(context).loadingFail),
      content: Text(l10n(context).failedToload),
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
          child: Text(l10n(context).yes),
        ),
      ],
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
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
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

    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final double chartHeight =
        isLandscape
            ? mediaQuery.size.height *
                0.6 // 가로모드: 60%
            : mediaQuery.size.height * 0.25; // 세로모드: 기존 30%

    final singleChildScrollView = SingleChildScrollView(
      controller: _scrollController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
        child: Column(
          children: [
            // 섹션 1: 현재 값 정보 + 차트
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  _buildTodayInfoCard(
                    usdtChartData.safeLast,
                    exchangeRates.safeLast,
                    kimchiPremium.safeLast,
                  ),
                  _buildChartCard(chartHeight),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // 섹션 2: 현재 매수 구간 + 매매 전략
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  FutureBuilder<Widget>(
                    future: _buildTodayComment(usdtChartData.safeLast),
                    builder: (context, snapshot) {
                      return snapshot.data ?? const SizedBox();
                    },
                  ),
                  _buildStrategySection(),
                ],
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => throw Exception(),
                child: Text(l10n(context).throw_test_exception),
              ),
            ],
          ],
        ),
      ),
    );

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            toolbarHeight: 48,
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: !kIsWeb ? _buildChatIcon() : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n(context).usdt_signal,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
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
                      padding: const EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.help_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
            iconTheme: IconThemeData(
              color: Theme.of(context).colorScheme.onSurface,
              size: 22,
            ),
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.92),
                        Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.75),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.6),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              if (!kIsWeb) ...[
                // 알림 아이콘
                _buildNotificationIcon(),
              ],
            ],
          ),
          body: SafeArea(child: singleChildScrollView),
        ),
        // 전체 화면 뉴스 스플래시 뷰
        if (_showNewsBanner && _latestNews != null)
          NewsSplashView(news: _latestNews!, onDismiss: _dismissNewsBanner),
      ],
    );
  }

  Future<Widget> _buildTodayComment(USDTChartData? todayUsdt) async {
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
      // 김치 프리미엄 매수/매도 가격 계산
      final prices = SimulationModel.getKimchiTradingPrices(
        exchangeRateValue: exchangeRateValue,
        premiumTrends: premiumTrends,
        targetDate: todayUsdt?.time,
        exchangeRates: exchangeRates,
      );
      buyPrice = prices.buyPrice;
      sellPrice = prices.sellPrice;
    }

    final cs = Theme.of(context).colorScheme;
    // 디자인 강조: 배경색, 아이콘, 컬러 분기 (다크 대응)
    Color bgColor;
    IconData icon;
    Color iconColor;

    // 오늘 날짜에 대한 코멘트 생성
    if (usdtPrice <= buyPrice) {
      comment = l10n(context).buyWin;
      bgColor = const Color(0xFF153528).withValues(alpha: 0.95);
      icon = Icons.trending_up;
      iconColor = const Color(0xFF4ADE80);
    } else if (usdtPrice > sellPrice) {
      comment = l10n(context).sellWin;
      bgColor = const Color(0xFF3D181C).withValues(alpha: 0.95);
      icon = Icons.trending_down;
      iconColor = const Color(0xFFF87171);
    } else {
      comment = l10n(context).justSee;
      bgColor = const Color(0xFF3A3420).withValues(alpha: 0.95);
      icon = Icons.remove_red_eye;
      iconColor = const Color(0xFFFBBF24);
    }

    return Stack(
      children: [
        // 원래 알림 카드
        Container(
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  comment,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 광고 오버레이 (결제 안 한 경우만 표시)
        _buildAdOverlay(),
      ],
    );
  }

  // 알림 옵션 위젯 빌더 (enum 타입으로 변경)
  Widget _buildAlarmOptionTile(
    BuildContext context,
    TodayCommentAlarmType value,
    TodayCommentAlarmType selected,
    String text,
    String? description,
  ) {
    final isSelected = value == selected;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer.withValues(alpha: 0.55) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cs.primary.withValues(alpha: 0.35) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                      color: cs.onSurface,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check, color: cs.primary),
          ],
        ),
      ),
    );
  }

  // 챗팅 아이콘 빌더
  Widget _buildChatIcon() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 16.0),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.65),
        shape: BoxShape.circle,
        border: Border.all(color: cs.outline.withValues(alpha: 0.45), width: 1),
      ),
      child: InkWell(
        onTap: () async {
          // 채팅 시작 이벤트 로깅
          if (!kIsWeb) {
            await FirebaseAnalytics.instance.logEvent(
              name: 'chat_started',
              parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
            );
          }

          // 채팅봇 페이지로 네비게이트
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AnonymousChatPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(Icons.support_agent, color: cs.onSecondaryContainer, size: 20),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // 알림 아이콘 빌더
  Widget _buildNotificationIcon() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color:
            _todayCommentAlarmType == TodayCommentAlarmType.kimchi
                ? cs.tertiaryContainer.withValues(alpha: 0.55)
                : _todayCommentAlarmType == TodayCommentAlarmType.ai
                ? cs.primaryContainer.withValues(alpha: 0.55)
                : cs.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color:
              _todayCommentAlarmType == TodayCommentAlarmType.kimchi
                  ? cs.tertiary.withValues(alpha: 0.5)
                  : _todayCommentAlarmType == TodayCommentAlarmType.ai
                  ? cs.primary.withValues(alpha: 0.45)
                  : cs.outline.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          await showAlarmSettingDialog(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            _todayCommentAlarmType == TodayCommentAlarmType.ai ||
                    _todayCommentAlarmType == TodayCommentAlarmType.kimchi
                ? Icons.notifications_active
                : Icons.notifications_off,
            color:
                _todayCommentAlarmType == TodayCommentAlarmType.kimchi
                    ? cs.tertiary
                    : _todayCommentAlarmType == TodayCommentAlarmType.ai
                    ? cs.primary
                    : cs.onSurfaceVariant,
            size: 20,
          ),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // 1. 오늘 데이터 카드
  Widget _buildTodayInfoCard(
    USDTChartData? todayUsdt,
    ChartData? todayRate,
    ChartData? todayKimchi,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: Column(
        children: [
          SizedBox(
            height: 78,
            child: PageView(
              controller: _infoPageController,
              onPageChanged: (index) {
                setState(() {
                  _infoPageIndex = index;
                });
                if (index == 1) {
                  _loadXrpFundingRate();
                }
              },
              children: [
                _buildTodayInfoRow(todayUsdt, todayRate, todayKimchi),
                _buildXrpFundingRateRow(),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildInfoPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildTodayInfoRow(
    USDTChartData? todayUsdt,
    ChartData? todayRate,
    ChartData? todayKimchi,
  ) {
    const usdtAccent = Color(0xFF7EB8FF);
    const rateAccent = Color(0xFF86EFAC);
    const kimchiAccent = Color(0xFFFBBF24);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoItem(
          label: l10n(context).usdt,
          value: todayUsdt != null ? todayUsdt.close.toStringAsFixed(1) : '-',
          color: usdtAccent,
        ),
        InfoItem(
          label: l10n(context).exchangeRate,
          value: todayRate != null ? todayRate.value.toStringAsFixed(1) : '-',
          color: rateAccent,
        ),
        InfoItem(
          label: l10n(context).gimchiPremiem,
          value:
              todayKimchi != null
                  ? '${todayKimchi.value.toStringAsFixed(2)}%'
                  : '-',
          color: kimchiAccent,
        ),
      ],
    );
  }

  Widget _buildXrpFundingRateRow() {
    if (_isFundingRateLoading && _xrpFundingRate == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(l10n(context).fundingRateLoading),
        ],
      );
    }

    final rate = _xrpFundingRate;
    final interval = rate?.fundingIntervalHours ?? 8;
    final isBybit = _fundingRateSource == 'bybit';
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        InfoItem(
          label: l10n(context).xrpFundingRateTitle,
          value:
              rate != null
                  ? '${rate.annualizedRatePercent.toStringAsFixed(2)}%'
                  : '-',
          color: const Color(0xFFC4B5FD),
        ),
        InfoItem(
          label: l10n(context).fundingRateInterval(interval),
          value:
              rate != null
                  ? '${rate.fundingRatePercent.toStringAsFixed(4)}%'
                  : '-',
          color: const Color(0xFF5EEAD4),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ElevatedButton(
            onPressed: _toggleFundingRateSource,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(72, 34),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(
              isBybit
                  ? l10n(context).fundingRateSourceBybit
                  : l10n(context).fundingRateSourceBinance,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPageIndicator() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = _infoPageIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 8 : 6,
          height: isActive ? 8 : 6,
          decoration: BoxDecoration(
            color: isActive ? cs.primary : cs.outlineVariant.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildChartCard(double chartHeight) {
    final cs = Theme.of(context).colorScheme;
    final chartSurface = cs.surfaceContainerHighest;
    final axisLabelColor = cs.onSurfaceVariant;
    final gridColor = cs.outline.withValues(alpha: 0.28);
    final axisLineColor = cs.outline.withValues(alpha: 0.55);

    List<PlotBand> kimchiPlotBands =
        showKimchiPlotBands ? getKimchiPlotBands() : [];

    final simulationType =
        _selectedStrategyTabIndex == 0
            ? SimulationType.ai
            : SimulationType.kimchi;
    final nextPoint = SimulationModel.getNextTradingPoint(
      simulationType: simulationType,
      latestStrategy: latestStrategy,
      exchangeRates: exchangeRates,
      usdtChartData: usdtChartData,
      premiumTrends: premiumTrends,
      currentPrice: usdtChartData.safeLast?.close,
    );

    return Stack(
      children: [
        Container(
          height: chartHeight,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            decoration: BoxDecoration(
              color: chartSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
            ),
            child: SfCartesianChart(
              plotAreaBackgroundColor: chartSurface,
              plotAreaBorderColor: axisLineColor,
              plotAreaBorderWidth: 0,
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

              legend: Legend(
                isVisible: true,
                position: LegendPosition.bottom,
                textStyle: TextStyle(color: axisLabelColor, fontSize: 12),
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
                axisLine: AxisLine(color: axisLineColor, width: 1),
                majorGridLines: MajorGridLines(color: gridColor, width: 1),
                labelStyle: TextStyle(color: axisLabelColor, fontSize: 11),
              ),
              primaryYAxis: NumericAxis(
                rangePadding: ChartRangePadding.auto,
                labelFormat: '{value}',
                numberFormat: NumberFormat("###,##0.0"),
                minimum: getUsdtMin(usdtChartData),
                maximum: getUsdtMax(usdtChartData),
                axisLine: AxisLine(color: axisLineColor, width: 1),
                majorGridLines: MajorGridLines(color: gridColor, width: 1),
                labelStyle: TextStyle(color: axisLabelColor, fontSize: 11),
              ),
              axes: <ChartAxis>[
                if (showKimchiPremium)
                  NumericAxis(
                    name: 'kimchiAxis',
                    opposedPosition: true,
                    labelFormat: '{value}%',
                    numberFormat: NumberFormat("##0.0"),
                    axisLine: AxisLine(color: axisLineColor, width: 1),
                    majorGridLines: MajorGridLines(color: gridColor, width: 1),
                    labelStyle: TextStyle(color: axisLabelColor, fontSize: 11),
                    majorTickLines: MajorTickLines(
                      size: 2,
                      color: cs.error,
                    ),
                    rangePadding: ChartRangePadding.round,
                    minimum: kimchiMin - 0.5,
                    maximum: kimchiMax + 0.5,
                  ),
              ],
              zoomPanBehavior: _zoomPanBehavior,
              tooltipBehavior: TooltipBehavior(enable: true),
              annotations: [
                if (nextPoint != null)
                  CartesianChartAnnotation(
                    widget: BlinkingMarker(
                      image:
                          nextPoint.isBuy
                              ? ChartOnlyPage.buyMarkerImage
                              : ChartOnlyPage.sellMarkerImage,
                      tooltipMessage: getTooltipMessage(
                        l10n(context),
                        simulationType,
                        nextPoint.isBuy,
                        nextPoint.price,
                        nextPoint.kimchiPremium,
                      ),
                    ),
                    coordinateUnit: CoordinateUnit.point,
                    x: DateTime.now(),
                    y: nextPoint.price,
                  ),
                if (usdtChartData.isNotEmpty)
                  CartesianChartAnnotation(
                    widget: const BlinkingDot(
                      color: Color(0xFF7EB8FF),
                      size: 8,
                    ),
                    coordinateUnit: CoordinateUnit.point,
                    x: usdtChartData.last.time,
                    y: usdtChartData.last.close,
                  ),
              ],
              series: <CartesianSeries>[
                if (!(showAITrading || showGimchiTrading))
                  // 일반 라인 차트 (USDT)
                  LineSeries<USDTChartData, DateTime>(
                    name: l10n(context).usdt,
                    dataSource: usdtChartData,
                    xValueMapper: (USDTChartData data, _) => data.time,
                    yValueMapper: (USDTChartData data, _) => data.close,
                    color: const Color(0xFF7EB8FF),
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
                    bearColor: const Color(0xFF7EB8FF),
                    bullColor: const Color(0xFFF87171),
                    animationDuration: 0,
                  ),
                // 환율 그래프를 showExchangeRate가 true일 때만 표시
                if (showExchangeRate)
                  LineSeries<ChartData, DateTime>(
                    name: l10n(context).exchangeRate,
                    dataSource: exchangeRates,
                    xValueMapper: (ChartData data, _) => data.time,
                    yValueMapper: (ChartData data, _) => data.value,
                    color: const Color(0xFF86EFAC),
                    animationDuration: 0,
                  ),
                if (showKimchiPremium)
                  LineSeries<ChartData, DateTime>(
                    name: '${l10n(context).gimchiPremiem}(%)',
                    dataSource: kimchiPremium,
                    xValueMapper: (ChartData data, _) => data.time,
                    yValueMapper: (ChartData data, _) => data.value,
                    color: const Color(0xFFFBBF24),
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
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.4),
              ),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: cs.primary),
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
          right: 3, // 3픽셀 오른쪽으로 이동 (10-3=7)
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.4),
              ),
            ),
            child: IconButton(
              icon:
                  chartOnlyPageModel == null
                      ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            cs.primary,
                          ),
                        ),
                      )
                      : Icon(
                        Icons.open_in_full,
                        color: cs.primary,
                      ),
              tooltip: chartOnlyPageModel == null ? '차트 데이터 로딩 중...' : '차트 확대',
              onPressed:
                  chartOnlyPageModel == null
                      ? null
                      : () {
                        // ChartOnlyPage로 전달
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => ChartOnlyPage.fromModel(
                                  chartOnlyPageModel!,
                                ),
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
        const Color(0xFF2563EB),
        const Color(0xFFDC2626),
        t,
      )!.withValues(alpha: 0.55);

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

    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      initialIndex: _selectedStrategyTabIndex, // 초기 선택 탭 적용
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: cs.primary,
              dividerColor: cs.outline.withValues(alpha: 0.35),
              labelStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.normal,
              ),
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
              height: 250,
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  FutureBuilder<Widget>(
                    future: _buildAiStrategyTab(),
                    builder: (context, snapshot) {
                      return snapshot.data ?? const SizedBox();
                    },
                  ),
                  FutureBuilder<Widget>(
                    future: _buildGimchiStrategyTab(),
                    builder: (context, snapshot) {
                      return snapshot.data ?? const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 기존 AI 매매 전략 UI --- 분리된 메소드
  Future<Widget> _buildAiStrategyTab() async {
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

  Future<Widget> makeStrategyTab(
    SimulationType type,
    String title,
    buyPrice,
    sellPrice,
    String profitRateStr,
    strategy,
  ) async {
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

    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n(context).buy}: $buyPriceStr',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: onSurface,
                  ),
                ),
                Text(
                  '${l10n(context).sell}: $sellPriceStr',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: onSurface,
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: onSurface,
                  ),
                ),
                // 전략보기 버튼
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.lightbulb_outline,
                    color: cs.primary,
                    size: 16,
                  ),
                  label: Text(
                    title,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.85)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    LiquidGlassDialog.show(
                      context: context,
                      title: Row(
                        children: [
                          Icon(
                            Icons.lightbulb,
                            color: cs.tertiary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(title)),
                        ],
                      ),
                      content: SingleChildScrollView(
                        child: Text(
                          strategy != null &&
                                  strategy is String &&
                                  strategy.isNotEmpty
                              ? strategy
                              : l10n(context).strategySummaryEmpty,
                        ),
                      ),
                      actions: [
                        if (type == SimulationType.kimchi)
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              final sortedDates = usdtMap.keys.toList()..sort();
                              final defaultStartDate =
                                  sortedDates.isNotEmpty
                                      ? sortedDates.first
                                      : null;
                              final defaultEndDate =
                                  sortedDates.isNotEmpty
                                      ? sortedDates.last
                                      : null;
                              await SimulationPage.showKimchiStrategyUpdatePopup(
                                context,
                                defaultStartDate: defaultStartDate,
                                defaultEndDate: defaultEndDate,
                                availableDates: sortedDates,
                              );
                            },
                            child: Text(
                              AppLocalizations.of(context)!.changeStrategy,
                            ),
                          ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n(context).close),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.bar_chart, color: cs.primary),
                label: Text(
                  l10n(context).runSimulation,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.85)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: cs.primary,
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
                              builder: (_) {
                                final settings = ApiService.shared.settings;
                                print(
                                  'SimulationPage에 전달하는 settings: $settings',
                                );
                                if (settings != null) {
                                  final upbitFees =
                                      settings['upbit_fees']
                                          as Map<String, dynamic>?;
                                  print(
                                    'SimulationPage에 전달하는 upbit_fees: $upbitFees',
                                  );
                                }
                                return SimulationPage(
                                  simulationType: type,
                                  usdtMap: usdtMap,
                                  strategyList: strategyList,
                                  usdExchangeRates: exchangeRates,
                                  premiumTrends: premiumTrends,
                                  chartOnlyPageModel: chartOnlyPageModel,
                                  settings: settings,
                                );
                              },
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
                icon: Icon(Icons.link, color: cs.secondary),
                label: Text(
                  l10n(context).coinInfoSite,
                  style: TextStyle(
                    color: cs.secondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  foregroundColor: cs.secondary,
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
  Future<TodayCommentAlarmType?> showAlarmSettingDialog(
    BuildContext context,
  ) async {
    final prevType = _todayCommentAlarmType;
    final updatedType = await LiquidGlassDialog.show<TodayCommentAlarmType>(
      context: context,
      title: Column(
        children: [
          Text(l10n(context).selectReceiveAlert, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            l10n(context).selectReceiveAlertSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAlarmOptionTile(
            context,
            TodayCommentAlarmType.ai,
            _todayCommentAlarmType,
            l10n(context).aIalert,
            l10n(context).aIalertDescription,
          ),
          _buildAlarmOptionTile(
            context,
            TodayCommentAlarmType.kimchi,
            _todayCommentAlarmType,
            l10n(context).gimpAlert,
            l10n(context).gimpAlertDescription,
          ),
          _buildAlarmOptionTile(
            context,
            TodayCommentAlarmType.off,
            _todayCommentAlarmType,
            l10n(context).turnOffAlert,
            null,
          ),
        ],
      ),
    );

    if (updatedType == null) {
      // 다이얼로그가 취소되거나 닫힌 경우
      return null;
    }

    if (updatedType != prevType) {
      // 알림을 켜는 경우 권한 체크
      if (prevType == TodayCommentAlarmType.off &&
          (updatedType == TodayCommentAlarmType.ai ||
              updatedType == TodayCommentAlarmType.kimchi)) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final goToSettings = await LiquidGlassDialog.show<bool>(
            context: context,
            title: Text(l10n(context).needPermission),
            content: Text(l10n(context).permissionRequiredMessage),
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
          );
          if (goToSettings == true) {
            await openAppSettings();
          }
          // 권한 허용 전까지는 알림 상태를 변경하지 않음
          return null;
        }
      }

      // 알림 타입이 변경될 때 서버에 저장
      final isSuccess = await ApiService.shared.saveAndSyncUserData({
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
    return updatedType;
  }

  Future<Widget> _buildGimchiStrategyTab() async {
    final exchangeRateValue = exchangeRates.safeLast?.value ?? 0;

    // 이미 로드된 김치 프리미엄 트렌드 데이터 사용
    final todayDate = exchangeRates.safeLast?.time;
    final (buyThreshold, sellThreshold) = SimulationModel.getKimchiThresholds(
      trendData: premiumTrends?[todayDate],
      exchangeRates: exchangeRates,
      targetDate: todayDate,
    );

    final buyPrice = (exchangeRateValue * (1 + buyThreshold / 100));
    final sellPrice = (exchangeRateValue * (1 + sellThreshold / 100));

    final profitRate = sellThreshold - buyThreshold;

    final buyPriceStr = buyPrice.toStringAsFixed(1);
    final sellPriceStr = sellPrice.toStringAsFixed(1);

    final strategy =
        'USDT가 $buyPriceStr(${buyThreshold.toStringAsFixed(1)}%) 이하일 때 ${l10n(context).buy}, '
        '$sellPriceStr(${sellThreshold.toStringAsFixed(1)}%) 이상일 때 ${l10n(context).sell}';
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
    if (_hasAdFreePass) {
      return _showStrategyDirectly;
    }

    // 버튼을 활성화 후 액션 연동
    if (_adsStatus == AdsStatus.load) {
      return () => _showAdsView(scrollController: _scrollController);
    }

    // 버튼을 비활성화 상태로 유지
    return null;
  }
}
