import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:usdt_signal/simulation_page.dart';
import 'package:usdt_signal/widgets.dart';
import 'package:usdt_signal/l10n/app_localizations.dart';
import 'api_service.dart';
import 'utils.dart';
import 'simulation_model.dart';
import 'dialogs/liquid_glass_dialog.dart';

class ChartOnlyPage extends StatefulWidget {
  final List<ChartData> exchangeRates;
  final List<ChartData> kimchiPremium;
  final List<StrategyMap> strategyList;
  final Map<DateTime, USDTChartData> usdtMap; // USDT 데이터 맵
  final List<USDTChartData> usdtChartData;
  final double kimchiMin;
  final double kimchiMax;
  final Map<DateTime, Map<String, double>>? premiumTrends; // 김치 프리미엄 트렌드 데이터

  // AI/김프 매매 체크박스 초기값을 받을 수 있도록 파라미터 추가
  final bool initialShowAITrading;
  final bool initialShowGimchiTrading;

  static const buyMarkerImage = AssetImage('assets/markers/arrow_shape_up.png');
  static const sellMarkerImage = AssetImage(
    'assets/markers/arrow_shape_down.png',
  );

  // 기존 생성자
  const ChartOnlyPage({
    super.key,
    required this.exchangeRates,
    required this.kimchiPremium,
    required this.usdtMap,
    required this.usdtChartData,
    required this.kimchiMin,
    required this.kimchiMax,
    required this.strategyList,
    this.premiumTrends,
    this.initialShowAITrading = false,
    this.initialShowGimchiTrading = false,
  });

  // 모델을 받는 생성자도 초기값 전달 가능하게 수정
  ChartOnlyPage.fromModel(
    ChartOnlyPageModel model, {
    Key? key,
    this.initialShowAITrading = false,
    this.initialShowGimchiTrading = false,
  }) : exchangeRates = model.exchangeRates,
       kimchiPremium = model.kimchiPremium,
       strategyList = model.strategyList,
       usdtMap = model.usdtMap,
       usdtChartData = model.usdtChartData,
       kimchiMin = model.kimchiMin,
       kimchiMax = model.kimchiMax,
       premiumTrends = model.premiumTrends,
       super(key: key);

  @override
  State<ChartOnlyPage> createState() => _ChartOnlyPageState();
}

class _ChartOnlyPageState extends State<ChartOnlyPage> {
  bool showKimchiPremium = true;
  bool showAITrading = false;
  bool showGimchiTrading = false;
  bool showExchangeRate = true;
  bool showKimchiPlotBands = false;
  List aiTradeResults = [];
  bool _markersVisible = true;

  final _zoomPanBehavior = ZoomPanBehavior(
    enablePinching: true,
    enablePanning: true,
    enableDoubleTapZooming: true,
    zoomMode: ZoomMode.xy,
  );

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

    // 초기 체크박스 상태를 위젯 파라미터로부터 세팅
    showAITrading = widget.initialShowAITrading;
    showGimchiTrading = widget.initialShowGimchiTrading;

    // 체크박스에 따라 필요한 동작 자동 실행
    if (showAITrading) {
      showGimchiTrading = false;
      showKimchiPremium = false;
      showExchangeRate = false;
      aiTradeResults = SimulationModel.simulateResults(
        widget.exchangeRates,
        widget.strategyList,
        widget.usdtMap,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoZoomToAITrades();
      });
    } else if (showGimchiTrading) {
      showAITrading = false;
      showKimchiPremium = false;
      showExchangeRate = false;
      aiTradeResults = SimulationModel.gimchiSimulateResults(
        widget.exchangeRates,
        widget.strategyList,
        widget.usdtMap,
        widget.premiumTrends,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoZoomToAITrades();
      });
    }
  }

  @override
  void dispose() {
    // 마커를 숨겨서 크래시 방지
    _markersVisible = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final double chartHeight =
        isLandscape
            ? mediaQuery.size.height *
                0.8 // 가로모드: 화면 높이의 80%
            : mediaQuery.size.height * 0.6; // 세로모드: 기존 60%

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          setState(() {
            _markersVisible = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          toolbarHeight: 48,
          title: Text(
            l10n(context).chartTrendAnalysis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF1E293B),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF1E293B), size: 22),
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.85),
                      Colors.white.withOpacity(0.7),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE0E7FF), // 연한 보라
                Color(0xFFF3E8FF), // 연한 핑크
                Color(0xFFFFF1F2), // 연한 핑크 화이트
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8,
              ),
              child: Column(
                children: [
                  _buildChartCard(chartHeight, l10n(context)),
                  const SizedBox(height: 8),
                  _buildCheckboxCard(l10n(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 3. 차트 카드
  Widget _buildChartCard(double chartHeight, AppLocalizations l10n) {
    List<PlotBand> kimchiPlotBands =
        showKimchiPlotBands ? getKimchiPlotBands() : [];

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: chartHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _buildMainChart(l10n, kimchiPlotBands),
            ),
          ),
        ),
        // 왼쪽 상단에 리셋 버튼 추가
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.deepPurple),
              tooltip: l10n.resetChart,
              onPressed: () {
                setState(() {
                  _zoomPanBehavior.reset();
                });
              },
            ),
          ),
        ),
        // 오른쪽 상단에 닫기 버튼
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.deepPurple),
              tooltip: l10n.backToPreviousChart,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ],
    );
  }

  // 메인 차트 빌드 함수
  Widget _buildMainChart(
    AppLocalizations l10n,
    List<PlotBand> kimchiPlotBands,
  ) {
    // 다음 매수/매도 시점 가져오기
    final simulationType = () {
      if (showAITrading) return SimulationType.ai;
      if (showGimchiTrading) return SimulationType.kimchi;

      return SimulationType.ai;
    }();

    // 매수/매도 포인트 계산
    ({double price, double kimchiPremium})? buyPoint;
    ({double price, double kimchiPremium})? sellPoint;

    final currentExchangeRate =
        (widget.exchangeRates.isNotEmpty)
            ? widget.exchangeRates.last.value
            : 0.0;

    if (showAITrading || showGimchiTrading) {
      if (simulationType == SimulationType.ai) {
        if (widget.strategyList.isNotEmpty) {
          final latestStrategy = widget.strategyList.last;
          final buyPrice =
              (latestStrategy['buy_price'] as num?)?.toDouble() ?? 0;
          final sellPrice =
              (latestStrategy['sell_price'] as num?)?.toDouble() ?? 0;

          if (buyPrice > 0) {
            final kp =
                currentExchangeRate != 0
                    ? ((buyPrice - currentExchangeRate) /
                        currentExchangeRate *
                        100)
                    : 0.0;
            buyPoint = (price: buyPrice, kimchiPremium: kp);
          }
          if (sellPrice > 0) {
            final kp =
                currentExchangeRate != 0
                    ? ((sellPrice - currentExchangeRate) /
                        currentExchangeRate *
                        100)
                    : 0.0;
            sellPoint = (price: sellPrice, kimchiPremium: kp);
          }
        }
      } else if (simulationType == SimulationType.kimchi) {
        if (widget.exchangeRates.isNotEmpty &&
            widget.usdtChartData.isNotEmpty) {
          final exchangeRateValue = widget.exchangeRates.last.value;
          if (exchangeRateValue > 0) {
            // 추세 기반 전략 제거 - 항상 기본 임계값 사용
            final (
              buyThreshold,
              sellThreshold,
            ) = SimulationModel.getKimchiThresholds(
              trendData: null,
              exchangeRates: widget.exchangeRates,
              targetDate: widget.usdtChartData.last.time,
            );

            final buyPrice = exchangeRateValue * (1 + buyThreshold / 100);
            final sellPrice = exchangeRateValue * (1 + sellThreshold / 100);

            buyPoint = (price: buyPrice, kimchiPremium: buyThreshold);
            sellPoint = (price: sellPrice, kimchiPremium: sellThreshold);
          }
        }
      }
    } else {
      // 아무것도 체크 안되어 있을 때는 기존 로직대로 하나만 표시 (AI 기준)
      final nextPoint = SimulationModel.getNextTradingPoint(
        simulationType: SimulationType.ai,
        latestStrategy: widget.strategyList.last,
        exchangeRates: widget.exchangeRates,
        usdtChartData: widget.usdtChartData,
        premiumTrends: widget.premiumTrends,
        currentPrice: widget.usdtChartData.safeLast?.close,
      );

      if (nextPoint != null) {
        if (nextPoint.isBuy) {
          buyPoint = (
            price: nextPoint.price,
            kimchiPremium: nextPoint.kimchiPremium,
          );
        } else {
          sellPoint = (
            price: nextPoint.price,
            kimchiPremium: nextPoint.kimchiPremium,
          );
        }
      }
    }

    return SfCartesianChart(
      onTooltipRender: (TooltipArgs args) => _handleTooltipRender(args, l10n),
      legend: const Legend(isVisible: true, position: LegendPosition.bottom),
      margin: const EdgeInsets.all(10),
      primaryXAxis: _buildPrimaryXAxis(kimchiPlotBands),
      primaryYAxis: _buildPrimaryYAxis(),
      axes: _buildAxes(),
      zoomPanBehavior: _zoomPanBehavior,
      tooltipBehavior: TooltipBehavior(enable: true),
      annotations: [
        if (buyPoint != null)
          CartesianChartAnnotation(
            widget: BlinkingMarker(
              image: ChartOnlyPage.buyMarkerImage,
              tooltipMessage: getTooltipMessage(
                l10n,
                simulationType,
                true, // isBuy
                buyPoint.price,
                buyPoint.kimchiPremium,
              ),
            ),
            coordinateUnit: CoordinateUnit.point,
            x: DateTime.now(),
            y: buyPoint.price,
          ),
        if (sellPoint != null)
          CartesianChartAnnotation(
            widget: BlinkingMarker(
              image: ChartOnlyPage.sellMarkerImage,
              tooltipMessage: getTooltipMessage(
                l10n,
                simulationType,
                false, // isBuy
                sellPoint.price,
                sellPoint.kimchiPremium,
              ),
            ),
            coordinateUnit: CoordinateUnit.point,
            x: DateTime.now(),
            y: sellPoint.price,
          ),
        if (widget.usdtChartData.isNotEmpty)
          CartesianChartAnnotation(
            widget: const BlinkingDot(color: Colors.blue, size: 8),
            coordinateUnit: CoordinateUnit.point,
            x: widget.usdtChartData.last.time,
            y: widget.usdtChartData.last.close,
          ),
      ],
      series: [..._buildChartSeries(l10n)],
    );
  }

  // X축 설정
  DateTimeAxis _buildPrimaryXAxis(List<PlotBand> kimchiPlotBands) {
    return DateTimeAxis(
      edgeLabelPlacement: EdgeLabelPlacement.shift,
      intervalType: DateTimeIntervalType.days,
      dateFormat: DateFormat.yMd(),
      rangePadding: ChartRangePadding.additionalEnd,
      initialZoomFactor: 0.9,
      initialZoomPosition: 0.8,
      plotBands: kimchiPlotBands,
    );
  }

  // Y축 설정
  NumericAxis _buildPrimaryYAxis() {
    return NumericAxis(
      rangePadding: ChartRangePadding.auto,
      labelFormat: '{value}',
      numberFormat: NumberFormat("###,##0.0"),
      minimum: getUsdtMin(widget.usdtChartData),
      maximum: getUsdtMax(widget.usdtChartData),
    );
  }

  // 추가 축들 설정
  List<ChartAxis> _buildAxes() {
    return <ChartAxis>[
      if (showKimchiPremium)
        NumericAxis(
          name: 'kimchiAxis',
          opposedPosition: true,
          labelFormat: '{value}%',
          numberFormat: NumberFormat("##0.0"),
          majorTickLines: const MajorTickLines(size: 2, color: Colors.red),
          rangePadding: ChartRangePadding.round,
          minimum: widget.kimchiMin - 0.5,
          maximum: widget.kimchiMax + 0.5,
        ),
    ];
  }

  // 차트 시리즈들 빌드
  List<CartesianSeries> _buildChartSeries(AppLocalizations l10n) {
    List<CartesianSeries> series = [];

    // USDT 차트 (라인 또는 캔들)
    if (showAITrading || showGimchiTrading) {
      series.add(_buildUSDTCandleSeries(l10n));
    } else {
      series.add(_buildUSDTLineSeries(l10n));
    }

    // 환율 차트
    if (showExchangeRate) {
      series.add(_buildExchangeRateSeries(l10n));
    }

    // 김치 프리미엄 차트
    if (showKimchiPremium) {
      series.add(_buildKimchiPremiumSeries(l10n));
    }

    // AI 매수/매도 포인트
    if ((showAITrading || showGimchiTrading) && aiTradeResults.isNotEmpty) {
      series.addAll(_buildAITradingSeries(l10n));
    }

    return series;
  }

  // USDT 라인 시리즈
  LineSeries<USDTChartData, DateTime> _buildUSDTLineSeries(
    AppLocalizations l10n,
  ) {
    return LineSeries<USDTChartData, DateTime>(
      name: l10n.usdt,
      dataSource: widget.usdtChartData,
      xValueMapper: (USDTChartData data, _) => data.time,
      yValueMapper: (USDTChartData data, _) => data.close,
      color: Colors.blue,
      animationDuration: 0,
    );
  }

  // USDT 캔들 시리즈
  CandleSeries<USDTChartData, DateTime> _buildUSDTCandleSeries(
    AppLocalizations l10n,
  ) {
    return CandleSeries<USDTChartData, DateTime>(
      name: l10n.usdt,
      dataSource: widget.usdtChartData,
      xValueMapper: (USDTChartData data, _) => data.time,
      lowValueMapper: (USDTChartData data, _) => data.low,
      highValueMapper: (USDTChartData data, _) => data.high,
      openValueMapper: (USDTChartData data, _) => data.open,
      closeValueMapper: (USDTChartData data, _) => data.close,
      bearColor: Colors.blue,
      bullColor: Colors.red,
      animationDuration: 0,
    );
  }

  // 환율 시리즈
  LineSeries<ChartData, DateTime> _buildExchangeRateSeries(
    AppLocalizations l10n,
  ) {
    return LineSeries<ChartData, DateTime>(
      name: l10n.exchangeRate,
      dataSource: widget.exchangeRates,
      xValueMapper: (ChartData data, _) => data.time,
      yValueMapper: (ChartData data, _) => data.value,
      color: Colors.green,
      animationDuration: 0,
    );
  }

  // 김치 프리미엄 시리즈
  LineSeries<ChartData, DateTime> _buildKimchiPremiumSeries(
    AppLocalizations l10n,
  ) {
    return LineSeries<ChartData, DateTime>(
      name: l10n.kimchiPremiumPercent,
      dataSource: widget.kimchiPremium,
      xValueMapper: (ChartData data, _) => data.time,
      yValueMapper: (ChartData data, _) => data.value,
      color: Colors.orange,
      yAxisName: 'kimchiAxis',
      animationDuration: 0,
    );
  }

  // AI 매수/매도 시리즈들
  List<ScatterSeries> _buildAITradingSeries(AppLocalizations l10n) {
    return [
      ScatterSeries<dynamic, DateTime>(
        name: showAITrading ? l10n.aiBuy : l10n.kimchiPremiumBuy,
        dataSource: aiTradeResults.toList(),
        xValueMapper: (r, _) => r.buyDate,
        yValueMapper: (r, _) => r.buyPrice,
        markerSettings: MarkerSettings(
          isVisible: _markersVisible,
          shape: DataMarkerType.image,
          image: ChartOnlyPage.buyMarkerImage, // 매수 신호 - 위쪽 화살표
          width: 24,
          height: 24,
        ),
      ),
      ScatterSeries<dynamic, DateTime>(
        name: showAITrading ? l10n.aiSell : l10n.kimchiPremiumSell,
        dataSource: aiTradeResults.where((r) => r.sellDate != null).toList(),
        xValueMapper: (r, _) => r.sellDate!,
        yValueMapper: (r, _) => r.sellPrice!,
        markerSettings: MarkerSettings(
          isVisible: _markersVisible,
          shape: DataMarkerType.image,
          image: ChartOnlyPage.sellMarkerImage, // 틴트 컬러 - 빨간색
          width: 24,
          height: 24,
        ),
      ),
    ];
  }

  // 툴팁 렌더링 처리
  void _handleTooltipRender(TooltipArgs args, AppLocalizations l10n) {
    final pointIndex = args.pointIndex?.toInt() ?? 0;
    final clickedPoint = args.dataPoints?[pointIndex];
    if (clickedPoint == null) return;

    // Date로 부터 환율 정보를 얻는다.
    final exchangeRate = getExchangeRate(clickedPoint.x);
    final usdtValue = getUsdtValue(clickedPoint.x);
    // 김치 프리미엄 계산은 USDT 값과 환율을 이용
    double kimchiPremiumValue;

    // AI 매도, 김프 매도 일 경우 김치 프리미엄은 simulationResult의 usdExchageRateAtSell을 사용 계산
    if (args.header == l10n.aiSell || args.header == l10n.kimchiPremiumSell) {
      final simulationResult = getSimulationResult(clickedPoint.x);
      kimchiPremiumValue = simulationResult?.gimchiPremiumAtSell() ?? 0.0;
    } else if (args.header == l10n.aiBuy ||
        args.header == l10n.kimchiPremiumBuy) {
      final simulationResult = getSimulationResult(clickedPoint.x);
      kimchiPremiumValue = simulationResult?.gimchiPremiumAtBuy() ?? 0.0;
    } else {
      if (exchangeRate != 0) {
        kimchiPremiumValue = ((usdtValue - exchangeRate) / exchangeRate * 100);
      } else {
        kimchiPremiumValue = 0.0;
      }
    }

    String newText =
        '${args.text}\n${l10n.gimchiPremiem}: ${kimchiPremiumValue.toStringAsFixed(2)}%';

    // '환율' 시리즈의 툴팁에만 변동률 추가
    if (args.header == l10n.exchangeRate && pointIndex > 0) {
      final prevRate = widget.exchangeRates[pointIndex - 1].value;
      final currentRate = widget.exchangeRates[pointIndex].value;
      if (prevRate != 0) {
        final changePercent = (currentRate - prevRate) / prevRate * 100;
        final sign = changePercent >= 0 ? '+' : '';
        newText +=
            '\n${l10n.changeFromPreviousDay('$sign${changePercent.toStringAsFixed(2)}')}';
      }
    }
    // 툴팁 텍스트를 기존 텍스트에 김치 프리미엄 값을 추가
    args.text = newText;
  }

  void _autoZoomToAITrades() {
    bool show = showAITrading || showGimchiTrading;
    if (show && aiTradeResults.isNotEmpty && widget.usdtChartData.isNotEmpty) {
      // AI 매수/매도 날짜 리스트
      final allDates = [
        ...aiTradeResults.where((r) => r.buyDate != null).map((r) => r.buyDate),
        ...aiTradeResults
            .where((r) => r.sellDate != null)
            .map((r) => r.sellDate!),
      ];
      if (allDates.isNotEmpty) {
        allDates.sort();
        DateTime aiStart = allDates.first;
        DateTime aiEnd = allDates.last;

        // 여유를 위해 좌우로 2~3일 추가
        aiStart = aiStart.subtract(const Duration(days: 2));
        aiEnd = aiEnd.add(const Duration(days: 2));

        // 전체 차트 날짜 범위
        final chartStart = widget.usdtChartData.first.time;
        final chartEnd = widget.usdtChartData.last.time;
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

  Widget _buildCheckboxCard(AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 16,
              runSpacing: 12,
              children: [
                CheckBoxItem(
                  value: showExchangeRate,
                  label: l10n.exchangeRate,
                  color: Colors.green,
                  onChanged:
                      (val) => setState(() => showExchangeRate = val ?? true),
                ),
                CheckBoxItem(
                  value: showKimchiPremium,
                  label: l10n.kimchiPremium,
                  color: Colors.orange,
                  onChanged:
                      (val) => setState(() => showKimchiPremium = val ?? true),
                ),
                CheckBoxItem(
                  value: showAITrading,
                  label: l10n.aiBuySell,
                  color: Colors.deepPurple,
                  onChanged: (val) {
                    setState(() {
                      showAITrading = val ?? false;
                      if (showAITrading) {
                        showGimchiTrading = false; // AI 매매가 켜지면 김프 매매는 꺼짐
                        showKimchiPremium = false; // AI 매매가 켜지면 김치 프리미엄은 꺼짐
                        showExchangeRate = false; // AI 매매가 켜지면 환율은 꺼짐

                        aiTradeResults = SimulationModel.simulateResults(
                          widget.exchangeRates,
                          widget.strategyList,
                          widget.usdtMap,
                        );
                        _autoZoomToAITrades();
                      } else {
                        aiTradeResults = [];
                      }
                    });
                  },
                ),
                CheckBoxItem(
                  value: showGimchiTrading,
                  label: l10n.kimchiPremiumBuySell,
                  color: Colors.teal,
                  onChanged: (val) async {
                    setState(() {
                      showGimchiTrading = val ?? false;
                    });
                    if (showGimchiTrading) {
                      setState(() {
                        showAITrading = false; // 김프 매매가 켜지면 AI 매매는 꺼짐
                        showKimchiPremium = false;
                        showExchangeRate = false; // 김프 매매가 켜지면 환율은 꺼짐
                      });

                      final results = SimulationModel.gimchiSimulateResults(
                        widget.exchangeRates,
                        widget.strategyList,
                        widget.usdtMap,
                        null, // premiumTrends는 서버에서 받아와야 함
                      );
                      setState(() {
                        aiTradeResults = results;
                      });
                      _autoZoomToAITrades();
                    } else {
                      setState(() {
                        aiTradeResults = [];
                      });
                    }
                  },
                ),
                // === 프리미엄 배경 PlotBand 표시/숨김 체크박스 + 도움말 버튼 추가 ===
                SizedBox(
                  height: 36, // 다른 CheckBoxItem 높이와 맞추기 (필요시 조정)
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CheckBoxItem(
                        value: showKimchiPlotBands,
                        label: l10n.kimchiPremiumBackground,
                        color: Colors.blue,
                        onChanged: (val) {
                          setState(() {
                            showKimchiPlotBands = val ?? true;
                            if (showKimchiPlotBands) {
                              showKimchiPremium = false; // 배경이 켜지면 김치 프리미엄도 켜짐
                            }
                          });
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.help_outline,
                            color: Colors.blue,
                            size: 16,
                          ),
                          tooltip:
                              l10n.kimchiPremiumBackgroundDescriptionTooltip,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          onPressed: () {
                            LiquidGlassDialog.show(
                              context: context,
                              title: Text(l10n.whatIsKimchiPremiumBackground),
                              content: Text(
                                l10n.kimchiPremiumBackgroundDescription,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(l10n.confirm),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 아래 함수들은 main.dart에서 복사해서 사용하거나 import 하세요.
  double? getUsdtMin(List<USDTChartData> data) {
    if (data.isEmpty) return null;
    final min = data.map((e) => e.low).reduce((a, b) => a < b ? a : b) * 0.98;
    return min < 1300 ? 1300 : min;
  }

  double? getUsdtMax(List<USDTChartData> data) {
    if (data.isEmpty) return null;
    final max = data.map((e) => e.high).reduce((a, b) => a > b ? a : b);
    return max * 1.02;
  }

  // 환율 데이터를 날짜로 조회하는 함수 추가
  double getExchangeRate(DateTime date) {
    // 날짜가 같은 환율 데이터 찾기 (날짜만 비교)
    for (final rate in widget.exchangeRates) {
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
    for (final usdt in widget.usdtChartData) {
      if (usdt.time.year == date.year &&
          usdt.time.month == date.month &&
          usdt.time.day == date.day) {
        return usdt.close;
      }
    }
    return 0.0;
  }

  // 시뮬레이션 결과를 날짜로 조회하는 함수 추가
  SimulationResult? getSimulationResult(DateTime date) {
    for (final result in aiTradeResults) {
      if (result.buyDate != null) {
        final buyDate = result.buyDate;
        if (buyDate.year == date.year &&
            buyDate.month == date.month &&
            buyDate.day == date.day) {
          return result;
        }
      }
      if (result.sellDate != null) {
        final sellDate = result.sellDate!;
        if (sellDate.year == date.year &&
            sellDate.month == date.month &&
            sellDate.day == date.day) {
          return result;
        }
      }
    }
    return null;
  }

  List<PlotBand> getKimchiPlotBands() {
    List<PlotBand> kimchiPlotBands = [];
    DateTime bandStart = widget.kimchiPremium.first.time;

    double maxGimchRange = widget.kimchiMax - widget.kimchiMin;
    Color? previousColor;
    for (int i = 0; i < widget.kimchiPremium.length; i++) {
      final data = widget.kimchiPremium[i];
      double t = ((data.value - widget.kimchiMin) / maxGimchRange).clamp(
        0.0,
        1.0,
      );
      Color bandColor = Color.lerp(
        Colors.blue,
        Colors.red,
        t,
      )!.withOpacity(0.6);

      kimchiPlotBands.add(
        PlotBand(
          isVisible: true,
          start: bandStart,
          end: data.time,
          gradient: LinearGradient(
            colors: [(previousColor ?? bandColor), bandColor],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      );

      bandStart = data.time;
      previousColor = bandColor;
    }
    return kimchiPlotBands;
  }
}

class ChartOnlyPageModel {
  final List<ChartData> exchangeRates;
  final List<ChartData> kimchiPremium;
  final List<StrategyMap> strategyList;
  final Map<DateTime, USDTChartData> usdtMap;
  final List<USDTChartData> usdtChartData;
  final double kimchiMin;
  final double kimchiMax;
  final Map<DateTime, Map<String, double>>? premiumTrends;

  ChartOnlyPageModel({
    required this.exchangeRates,
    required this.kimchiPremium,
    required this.strategyList,
    required this.usdtMap,
    required this.usdtChartData,
    required this.kimchiMin,
    required this.kimchiMax,
    this.premiumTrends,
  });
}
