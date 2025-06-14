import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:usdt_signal/AISimulationPage.dart';
import 'package:usdt_signal/widgets.dart';
import 'api_service.dart';

class ChartOnlyPage extends StatefulWidget {
  final List<ChartData> exchangeRates;
  final List<ChartData> kimchiPremium;
  final List strategyList;
  final Map<String, dynamic> usdtMap; // USDT 데이터 맵
  final List<USDTChartData> usdtChartData;
  final List aiTradeResults;
  final double kimchiMin;
  final double kimchiMax;

  // AI/김프 매매 체크박스 초기값을 받을 수 있도록 파라미터 추가
  final bool initialShowAITrading;
  final bool initialShowGimchiTrading;

  // 기존 생성자
  const ChartOnlyPage({
    super.key,
    required this.exchangeRates,
    required this.kimchiPremium,
    required this.usdtMap,
    required this.usdtChartData,
    required this.aiTradeResults,
    required this.kimchiMin,
    required this.kimchiMax,
    required this.strategyList,
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
       aiTradeResults = model.aiTradeResults,
       kimchiMin = model.kimchiMin,
       kimchiMax = model.kimchiMax,
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
      aiTradeResults = AISimulationPage.simulateResults(
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
      aiTradeResults = AISimulationPage.gimchiSimulateResults(
        widget.exchangeRates,
        widget.strategyList,
        widget.usdtMap,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoZoomToAITrades();
      });
    }
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FA),
      appBar: AppBar(
        title: const Text(
          "차트 추세 분석",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
          child: Column(
            children: [
              _buildChartCard(chartHeight),
              const SizedBox(height: 8),
              _buildCheckboxCard(),
            ],
          ),
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
                minimum: getUsdtMin(widget.usdtChartData),
                maximum: getUsdtMax(widget.usdtChartData),
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
                    minimum: widget.kimchiMin - 0.5,
                    maximum: widget.kimchiMax + 0.5,
                  ),
              ],
              zoomPanBehavior: _zoomPanBehavior,
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries>[
                if (!(showAITrading || showGimchiTrading))
                  // 일반 라인 차트 (USDT)
                  LineSeries<USDTChartData, DateTime>(
                    name: 'USDT',
                    dataSource: widget.usdtChartData,
                    xValueMapper: (USDTChartData data, _) => data.time,
                    yValueMapper: (USDTChartData data, _) => data.close,
                    color: Colors.blue,
                    animationDuration: 0,
                  )
                else
                  // 기존 캔들 차트
                  CandleSeries<USDTChartData, DateTime>(
                    name: 'USDT',
                    dataSource: widget.usdtChartData,
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
                    dataSource: widget.exchangeRates,
                    xValueMapper: (ChartData data, _) => data.time,
                    yValueMapper: (ChartData data, _) => data.value,
                    color: Colors.green,
                    animationDuration: 0,
                  ),
                if (showKimchiPremium)
                  LineSeries<ChartData, DateTime>(
                    name: '김치 프리미엄(%)',
                    dataSource: widget.kimchiPremium,
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
        // 오른쪽 상단에 리셋 아이콘 버튼 추가
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
              icon: const Icon(
                Icons.close_fullscreen,
                color: Colors.deepPurple,
              ),
              tooltip: '차트 이전',
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ],
    );
  }

  void _autoZoomToAITrades() {
    bool show = showAITrading || showGimchiTrading;
    if (show && aiTradeResults.isNotEmpty && widget.usdtChartData.isNotEmpty) {
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
            CheckBoxItem(
              value: showExchangeRate,
              label: '환율',
              color: Colors.green,
              onChanged:
                  (val) => setState(() => showExchangeRate = val ?? true),
            ),
            CheckBoxItem(
              value: showKimchiPremium,
              label: '김치 프리미엄',
              color: Colors.orange,
              onChanged:
                  (val) => setState(() => showKimchiPremium = val ?? true),
            ),
            CheckBoxItem(
              value: showAITrading,
              label: 'AI 매수/매도',
              color: Colors.deepPurple,
              onChanged: (val) {
                setState(() {
                  showAITrading = val ?? false;
                  if (showAITrading) {
                    showGimchiTrading = false; // AI 매매가 켜지면 김프 매매는 꺼짐
                    showKimchiPremium = false; // AI 매매가 켜지면 김치 프리미엄은 꺼짐
                    showExchangeRate = false; // AI 매매가 켜지면 환율은 꺼짐

                    aiTradeResults = AISimulationPage.simulateResults(
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
              label: '김프 매수/매도',
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

                  final results = AISimulationPage.gimchiSimulateResults(
                    widget.exchangeRates,
                    widget.strategyList,
                    widget.usdtMap,
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
                    label: '김치 프리미엄 배경',
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
                  IconButton(
                    icon: const Icon(
                      Icons.help_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    tooltip: '김치 프리미엄 배경 설명',
                    padding: const EdgeInsets.all(0), // 아이콘 버튼 여백 최소화
                    constraints: const BoxConstraints(), // 아이콘 버튼 크기 최소화
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              title: const Text('김치 프리미엄 배경이란?'),
                              content: const Text(
                                '차트의 배경색은 김치 프리미엄 값에 따라 달라집니다. '
                                '프리미엄이 높을수록 빨간색, 낮을수록 파란색에 가깝게 표시되어 '
                                '김치 프리미엄에 따른 매수 매도 시점을 시각적으로 파악할 수 있습니다. '
                                '이 기능은 김치 프리미엄의 변동성을 한눈에 파악하는 데 도움을 줍니다.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('확인'),
                                ),
                              ],
                            ),
                      );
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
  final List strategyList;
  final Map<String, dynamic> usdtMap;
  final List<USDTChartData> usdtChartData;
  final List aiTradeResults;
  final double kimchiMin;
  final double kimchiMax;

  ChartOnlyPageModel({
    required this.exchangeRates,
    required this.kimchiPremium,
    required this.strategyList,
    required this.usdtMap,
    required this.usdtChartData,
    required this.aiTradeResults,
    required this.kimchiMin,
    required this.kimchiMax,
  });
}
