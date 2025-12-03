import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:usdt_signal/ChartOnlyPage.dart'; // ChartOnlyPageModel import 추가
import 'package:usdt_signal/api_service.dart';
import 'package:usdt_signal/simulation_model.dart';
import 'package:usdt_signal/strategy_history_page.dart';
import 'utils.dart';

enum SimulationType { ai, kimchi }

class SimulationPage extends StatefulWidget {
  final SimulationType simulationType;
  final Map<DateTime, USDTChartData> usdtMap;
  final List<StrategyMap> strategyList;
  final List<ChartData> usdExchangeRates;
  final Map<DateTime, Map<String, double>>? premiumTrends; // 김치 프리미엄 트렌드 데이터

  // ChartOnlyPageModel을 직접 받는 생성자 추가
  final ChartOnlyPageModel? chartOnlyPageModel;

  const SimulationPage({
    super.key,
    required this.simulationType,
    required this.usdtMap,
    required this.strategyList,
    required this.usdExchangeRates,
    this.premiumTrends,
    this.chartOnlyPageModel,
  });

  static Future<bool> showKimchiStrategyUpdatePopup(
    BuildContext context, {
    bool showSameDatesAsAI = false,
    bool showUseTrend = false,
  }) async {
    final result = await showDialog<Map<String, Object>>(
      context: context,
      builder: (context) {
        double buy = SimulationCondition.instance.kimchiBuyThreshold;
        double sell = SimulationCondition.instance.kimchiSellThreshold;
        bool sameAsAI = SimulationCondition.instance.matchSameDatesAsAI;
        bool useTrend = SimulationCondition.instance.useTrend;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n(context).changeStrategy),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(l10n(context).buyBase),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: buy.toString(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final n = double.tryParse(v);
                            if (n != null && n >= -10 && n <= 10) {
                              setState(() {
                                buy = n;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(l10n(context).sellBase),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: sell.toString(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final n = double.tryParse(v);
                            if (n != null && n >= -10 && n <= 10) {
                              setState(() {
                                sell = n;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (showSameDatesAsAI)
                    Row(
                      children: [
                        Checkbox(
                          value: sameAsAI,
                          onChanged: (val) {
                            setState(() {
                              sameAsAI = val ?? false;
                            });
                          },
                        ),
                        Text(l10n(context).sameAsAI),
                      ],
                    ),
                  if (showUseTrend)
                    Row(
                      children: [
                        Checkbox(
                          value: useTrend,
                          onChanged: (val) {
                            setState(() {
                              useTrend = val ?? false;
                            });
                          },
                        ),
                        Text(l10n(context).useTrendBasedStrategy),
                      ],
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n(context).cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'buy': buy,
                      'sell': sell,
                      'sameAsAI': sameAsAI,
                      'useTrend': useTrend,
                    });
                  },
                  child: Text(l10n(context).confirm),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      final buy = result['buy'] as double;
      final sell = result['sell'] as double;
      final sameAsAI = result['sameAsAI'] as bool;
      final useTrend = result['useTrend'] as bool;

      final isSuccess = await ApiService.saveAndSyncUserData({
        UserDataKey.gimchiBuyPercent: buy,
        UserDataKey.gimchiSellPercent: sell,
      });

      if (isSuccess) {
        await SimulationCondition.instance.saveKimchiBuyThreshold(buy);
        await SimulationCondition.instance.saveKimchiSellThreshold(sell);
        await SimulationCondition.instance.saveMatchSameDatesAsAI(sameAsAI);
        await SimulationCondition.instance.saveUseTrend(useTrend);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n(context).failedToSaveSettings)),
        );
      }

      return isSuccess;
    }
    return false;
  }

  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage>
    with SingleTickerProviderStateMixin {
  List<StrategyMap>? strategies;
  List<SimulationResult> results = [];
  bool loading = true;
  String? error;
  bool isCardExpanded = true; // 카드 확장/축소 상태

  // 소수점 4자리까지 표시하는 포맷
  final NumberFormat krwFormat = NumberFormat("#,##0.#", "ko_KR");
  double totalProfitRate = 0; // 총 수익률 변수 추가

  @override
  void initState() {
    super.initState();
    runSimulation();

    // 애니메이션 컨트롤러 및 애니메이션 초기화
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> runSimulation() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // apiService 대신 생성자에서 받은 데이터 사용
      final usdtMap = widget.usdtMap;
      final usdExchangeRates = widget.usdExchangeRates;
      final strategyList = widget.strategyList;

      if (widget.simulationType == SimulationType.ai) {
        final simResults = SimulationModel.simulateResults(
          usdExchangeRates,
          strategyList,
          usdtMap,
        );

        setState(() {
          strategies = List<StrategyMap>.from(strategyList);
          results = simResults;
          loading = false;
        });
      } else if (widget.simulationType == SimulationType.kimchi) {
        final simResults = SimulationModel.gimchiSimulateResults(
          usdExchangeRates,
          strategyList,
          usdtMap,
          widget.premiumTrends,
        );

        setState(() {
          strategies = List<StrategyMap>.from(strategyList);
          results = simResults;
          loading = false;
        });
      }
    } catch (e) {
      print('Error during simulation: $e');
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  // 이전 AI 전략을 찾는 헬퍼 함수
  StrategyMap? _findPreviousAIStrategy(DateTime targetDate) {
    if (strategies == null || strategies!.isEmpty) return null;

    // 날짜를 내림차순으로 정렬 (최신순)
    final sortedStrategies = List<StrategyMap>.from(strategies!)..sort((a, b) {
      final dateA = DateTime.parse(a['analysis_date']);
      final dateB = DateTime.parse(b['analysis_date']);
      return dateB.compareTo(dateA);
    });

    // targetDate보다 이전 날짜 중에서 가장 가까운 전략을 찾기
    for (final strategy in sortedStrategies) {
      final strategyDate = DateTime.parse(strategy['analysis_date']);
      if (strategyDate.isBefore(targetDate)) {
        return strategy;
      }
    }

    return null; // 이전 전략이 없으면 null 반환
  }

  void _showStrategyDialog(BuildContext context, DateTime date) {
    var strategy = strategies?.firstWhere(
      (s) => DateTime.parse(s['analysis_date']).isSameDate(date),
      orElse: () => {},
    );

    // AI 전략에서 해당 날짜에 전략이 없으면 이전 전략을 찾아서 사용
    DateTime displayDate = date; // 표시할 날짜 (기본값은 요청한 날짜)
    if (widget.simulationType == SimulationType.ai &&
        (strategy == null || strategy.isEmpty)) {
      strategy = _findPreviousAIStrategy(date);
      // 이전 전략을 찾았으면 그 전략의 날짜를 표시 날짜로 사용
      if (strategy != null && strategy.isNotEmpty) {
        displayDate = DateTime.parse(strategy['analysis_date']);
      }
    }

    var (buyThreshold, sellThreshold) = (
      SimulationCondition.instance.kimchiBuyThreshold,
      SimulationCondition.instance.kimchiSellThreshold,
    );

    if (widget.simulationType == SimulationType.kimchi) {
      // 서버에서 받은 김치 프리미엄 트렌드 데이터 사용
      (buyThreshold, sellThreshold) = SimulationModel.getKimchiThresholds(
        trendData: widget.premiumTrends?[date],
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${displayDate.toCustomString()} ${l10n(context).strategy}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.deepPurple),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.simulationType == SimulationType.ai &&
                    strategy != null &&
                    strategy.isNotEmpty) ...[
                  _StrategyDialogRow(
                    label: l10n(context).buyPrice,
                    value: '${strategy['buy_price']}',
                  ),
                  _StrategyDialogRow(
                    label: l10n(context).sellPrice,
                    value: '${strategy['sell_price']}',
                  ),
                  _StrategyDialogRow(
                    label: l10n(context).expectedGain,
                    value: '${strategy['expected_return']}',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n(context).summary,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strategy['summary'] ?? '',
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ] else ...[
                  Text(
                    widget.simulationType == SimulationType.kimchi
                        ? l10n(context).kimchiStrategyComment(
                          double.parse(buyThreshold.toStringAsFixed(1)),
                          double.parse(sellThreshold.toStringAsFixed(1)),
                        )
                        : (strategy != null && strategy.isNotEmpty)
                        ? '${strategy['summary'] ?? '전략 정보'}'
                        : '해당 날짜에 대한 전략이 없습니다.',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FA),
      appBar: AppBar(
        title: Text(
          widget.simulationType == SimulationType.kimchi
              ? l10n(context).gimchBaseTrade
              : l10n(context).aiBaseTrade,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions:
            widget.simulationType == SimulationType.kimchi
                ? [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.deepPurple),
                    onPressed: () async {
                      final success =
                          await SimulationPage.showKimchiStrategyUpdatePopup(
                            context,
                            showSameDatesAsAI: true,
                            showUseTrend: true,
                          );
                      if (success) {
                        runSimulation();
                      }
                    },
                  ),
                ]
                : null,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // 메인 콘텐츠
            loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(child: Text('${l10n(context).error}: $error'))
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(context),
                      const SizedBox(height: 24),
                      Text(
                        l10n(context).tradeTimeline,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (results.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(l10n(context).noStrategyData),
                          ),
                        )
                      else
                        ...results.expand((r) {
                          List<Widget> widgets = [_buildBuyCard(context, r)];
                          if (r.sellDate != null) {
                            widgets.add(const SizedBox(height: 12));
                            widgets.add(_buildSellCard(context, r));
                          }
                          widgets.add(const SizedBox(height: 12));
                          return widgets;
                        }),
                      // 버텀 시트 공간 확보 (화면 높이의 40% + 여유 공간)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.35,
                      ),
                    ],
                  ),
                ),
            // 버텀 시트 (오버레이)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildBottomSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    if (loading || results.isEmpty) {
      return const SizedBox.shrink();
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.4, // 초기 크기 (모든 컨텐츠가 보이도록)
      minChildSize: 0.12, // 최소 크기
      maxChildSize: 0.4, // 최대 크기 (초기 크기와 동일)
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // 스크롤이 끝에 도달했을 때 시트가 확장되지 않도록 함
              if (notification is ScrollEndNotification) {
                if (scrollController.position.pixels == 0) {
                  // 스크롤이 맨 위에 있을 때만 드래그 가능
                }
              }
              return false;
            },
            child: ListView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              children: [
                // 드래그 핸들
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 성과 지표 & 차트로 보기 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n(context).performanceMetrics,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.show_chart,
                        color: Colors.deepPurple,
                        size: 16,
                      ),
                      label: Text(
                        l10n(context).seeWithChart,
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.deepPurple),
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
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => ChartOnlyPage.fromModel(
                                  widget.chartOnlyPageModel!,
                                  initialShowAITrading:
                                      widget.simulationType ==
                                      SimulationType.ai,
                                  initialShowGimchiTrading:
                                      widget.simulationType ==
                                      SimulationType.kimchi,
                                ),
                            fullscreenDialog: true,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPerformanceMetrics(context),
                const SizedBox(height: 24),
                _buildViewHistoryButton(context),
                // 하단 SafeArea 고려
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.simulationType == SimulationType.ai
                        ? Icons.psychology
                        : Icons.trending_up,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.simulationType == SimulationType.ai
                            ? l10n(context).aiSimulatedTradeTitle
                            : l10n(context).kimchiSimulatedTradeTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n(context).initialCapital,
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 차트 라인 (플레이스홀더)
            Container(
              height: 2,
              width: 100,
              color: Colors.deepPurple.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            // Period
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n(context).tradingPerioid,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                Builder(
                  builder: (context) {
                    if (results.isEmpty) return const Text("-");
                    final startDate =
                        results.first.buyDate?.toCustomString() ?? "";
                    final endDate = results.last.analysisDate.toCustomString();
                    return Text(
                      "$startDate - $endDate",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Total Gain
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n(context).totalGain,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                Builder(
                  builder: (context) {
                    final double totalGain =
                        results.isNotEmpty
                            ? (results.last.finalKRW - 1000000)
                            : 0;
                    final double totalGainPercent =
                        results.isNotEmpty
                            ? (results.last.finalKRW / 1000000 * 100 - 100)
                            : 0;
                    return RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:
                                "${totalGain >= 0 ? '+' : ''}${krwFormat.format(totalGain.round())} ",
                            style: TextStyle(
                              color:
                                  totalGain >= 0
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          TextSpan(
                            text: "(${totalGainPercent.toStringAsFixed(2)}%)",
                            style: TextStyle(
                              color:
                                  totalGain >= 0
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyButton(
    BuildContext context,
    DateTime? date,
    Color color,
  ) {
    return OutlinedButton(
      onPressed: () {
        if (date != null) {
          _showStrategyDialog(context, date);
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        l10n(context).seeStrategy,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBuyCard(BuildContext context, SimulationResult r) {
    final color = const Color(0xFFC62828); // Red 800
    final bgColor = const Color(0xFFFFEBEE); // Red 50
    final iconBgColor = const Color(0xFFFFCDD2); // Red 100

    return GestureDetector(
      onTap: () {
        if (r.buyDate != null) {
          _showStrategyDialog(context, r.buyDate!);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.north_east, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n(context).buy,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.buyDate?.toCustomString() ?? "-",
                  style: TextStyle(
                    color: color.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              "₩${krwFormat.format(r.buyPrice)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            _buildStrategyButton(context, r.buyDate, color),
          ],
        ),
      ),
    );
  }

  Widget _buildSellCard(BuildContext context, SimulationResult r) {
    final color = const Color(0xFF1565C0); // Blue 700
    final bgColor = const Color(0xFFE3F2FD); // Blue 50
    final iconBgColor = const Color(0xFFBBDEFB); // Blue 100

    return GestureDetector(
      onTap: () {
        if (r.sellDate != null) {
          _showStrategyDialog(context, r.sellDate!);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.south_east, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n(context).sell,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.sellDate?.toCustomString() ?? "-",
                  style: TextStyle(
                    color: color.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              r.sellPrice != null ? "₩${krwFormat.format(r.sellPrice!)}" : "-",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            _buildStrategyButton(context, r.sellDate, color),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetrics(BuildContext context) {
    final double totalGain =
        results.isNotEmpty ? (results.last.finalKRW / 1000000 * 100 - 100) : 0;

    String annualYieldText = "0.00%";
    if (results.isNotEmpty) {
      final firstDate = results.first.buyDate;
      final lastDate = results.last.analysisDate;
      if (firstDate != null) {
        final days = lastDate.difference(firstDate).inDays;
        if (days >= 1) {
          final years = days / 365.0;
          final totalReturn = results.last.finalKRW / 1000000;
          final annualYield =
              (years > 0) ? (pow(totalReturn, 1 / years) - 1) * 100 : 0.0;
          if (!annualYield.isNaN && !annualYield.isInfinite) {
            annualYieldText = "${annualYield.toStringAsFixed(2)}%";
          }
        }
      }
    }

    final finalValue = results.isNotEmpty ? results.last.finalKRW : 1000000;
    final finalValueText = "₩${(finalValue / 1000000).toStringAsFixed(2)}M";

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            l10n(context).totalGain,
            "${totalGain.toStringAsFixed(2)}%",
            const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            l10n(context).extimatedYearGain,
            annualYieldText,
            Colors.deepPurple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            l10n(context).finalValue,
            finalValueText,
            Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewHistoryButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder:
                (context) => DraggableScrollableSheet(
                  initialChildSize: 0.9,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder:
                      (context, scrollController) => Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: StrategyHistoryPage(
                          simulationType: widget.simulationType,
                          usdExchangeRates: widget.usdExchangeRates,
                          usdtMap: widget.usdtMap,
                          strategies: widget.strategyList,
                          premiumTrends: widget.premiumTrends,
                        ),
                      ),
                ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          l10n(context).viewAllStrategyHistory,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 김치 프리미엄 시뮬레이션 함수
}

class SimulationYieldData {
  final double totalReturn; // 총 수익률 (%)
  final int tradingDays; // 거래 기간 (일)
  final double annualYield; // 연수익률 (%)

  SimulationYieldData({
    required this.totalReturn,
    required this.tradingDays,
    required this.annualYield,
  });
}

class SimulationResult {
  final DateTime analysisDate;
  final DateTime? buyDate;
  final double buyPrice;
  final DateTime? sellDate;
  final double? sellPrice;
  final double profit;
  final double profitRate;
  final double finalKRW;
  final double? finalUSDT;
  final double? usdExchangeRateAtBuy; // ← 추가
  final double? usdExchangeRateAtSell; // ← 추가

  SimulationResult({
    required this.analysisDate,
    required this.buyDate,
    required this.buyPrice,
    this.sellDate,
    this.sellPrice,
    required this.profit,
    required this.profitRate,
    required this.finalKRW,
    this.finalUSDT,
    this.usdExchangeRateAtBuy, // ← 추가
    this.usdExchangeRateAtSell, // ← 추가
  });

  // 매도시 김치 프리미엄 계산 함수
  double gimchiPremiumAtSell() {
    if (usdExchangeRateAtSell == null || sellPrice == null) {
      return 0.0; // 매도 가격이 없으면 프리미엄 계산 불가
    }

    return ((sellPrice! - usdExchangeRateAtSell!) /
        usdExchangeRateAtSell! *
        100);
  }

  // 매수시 김치 프리미엄 계산 함수
  double gimchiPremiumAtBuy() {
    if (usdExchangeRateAtBuy == null) {
      return 0.0; // 매수 가격이 없으면 프리미엄 계산 불가
    }

    return ((buyPrice - usdExchangeRateAtBuy!) / usdExchangeRateAtBuy! * 100);
  }
}

class _StrategyDialogRow extends StatelessWidget {
  final String label;
  final String value;
  const _StrategyDialogRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
