import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:usdt_signal/ChartOnlyPage.dart'; // ChartOnlyPageModel import 추가
import 'package:usdt_signal/api_service.dart';
import 'package:usdt_signal/simulation_model.dart';
import 'package:usdt_signal/strategy_history_page.dart';
import 'utils.dart';

// ============================================================================
// Liquid Glass 디자인 스타일 정의
// ============================================================================

/// Liquid Glass 색상 팔레트
class _GlassColors {
  // 그라데이션 색상
  static const primaryGradient = [
    Color(0xFF667EEA), // 보라색
    Color(0xFF764BA2), // 진한 보라색
  ];

  static const secondaryGradient = [
    Color(0xFFF093FB), // 핑크
    Color(0xFFF5576C), // 코랄
  ];

  static const backgroundGradient = [
    Color(0xFFE0E7FF), // 연한 보라
    Color(0xFFF3E8FF), // 연한 핑크
    Color(0xFFFFF1F2), // 연한 핑크 화이트
  ];

  // Glass 효과 색상
  static const glassWhite = Color(0xFFFFFFFF);
  static const glassOverlay = Color(0x40FFFFFF);
  static const glassBorder = Color(0x30FFFFFF);

  // 텍스트 색상
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textLight = Color(0xFFFFFFFF);
}

/// 제목/헤더 스타일
class _TitleStyles {
  // AppBar 제목
  static const appBarTitle = TextStyle(
    fontWeight: FontWeight.bold,
    color: _GlassColors.textPrimary,
  );

  // 섹션 제목 (Trade Timeline, Performance Metrics 등)
  static const sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: _GlassColors.textPrimary,
  );

  // 헤더 카드 제목
  static const headerCardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: _GlassColors.textPrimary,
  );

  // 다이얼로그 제목
  static const dialogTitle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
    color: _GlassColors.textPrimary,
  );
}

/// 본문/일반 텍스트 스타일
class _BodyStyles {
  // 일반 본문 텍스트
  static const bodyText = TextStyle(
    fontSize: 18,
    color: _GlassColors.textPrimary,
  );

  // 라벨 텍스트 (헤더 카드의 라벨 등)
  static const labelText = TextStyle(
    fontSize: 16,
    color: _GlassColors.textSecondary,
  );

  // 회색 라벨 텍스트
  static const greyLabelText = TextStyle(
    fontSize: 16,
    color: _GlassColors.textSecondary,
  );
}

/// 버튼 텍스트 스타일
class _ButtonStyles {
  // 작은 버튼 (전략보기, 차트로 보기 등)
  static const smallButton = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  // 큰 버튼 (전체 히스토리 보기 등)
  static const largeButton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );
}

/// 카드 내부 텍스트 스타일
class _CardStyles {
  // 매수/매도 카드 제목
  static const cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: _GlassColors.textPrimary,
  );

  // 매수/매도 카드 날짜
  static const cardDate = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: _GlassColors.textSecondary,
  );

  // 매수/매도 카드 가격
  static const cardPrice = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: _GlassColors.textPrimary,
  );

  // 성과 지표 라벨
  static const metricLabel = TextStyle(
    fontSize: 14,
    color: _GlassColors.textSecondary,
    fontWeight: FontWeight.w600,
  );

  // 성과 지표 값
  static const metricValue = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: _GlassColors.textPrimary,
  );

  // 헤더 카드 값 (Period, Total Gain 등)
  static const headerCardValue = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: _GlassColors.textPrimary,
  );
}

/// 다이얼로그 텍스트 스타일
class _DialogStyles {
  // 다이얼로그 섹션 제목
  static const sectionTitle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 15,
  );

  // 다이얼로그 본문
  static const bodyText = TextStyle(fontSize: 14, color: Colors.black87);
}

enum SimulationType { ai, kimchi }

class SimulationPage extends StatefulWidget {
  final SimulationType simulationType;
  final Map<DateTime, USDTChartData> usdtMap;
  final List<StrategyMap> strategyList;
  final List<ChartData> usdExchangeRates;
  final Map<DateTime, Map<String, double>>? premiumTrends; // 김치 프리미엄 트렌드 데이터

  // ChartOnlyPageModel을 직접 받는 생성자 추가
  final ChartOnlyPageModel? chartOnlyPageModel;

  // Settings 데이터
  final Map<String, dynamic>? settings;

  const SimulationPage({
    super.key,
    required this.simulationType,
    required this.usdtMap,
    required this.strategyList,
    required this.usdExchangeRates,
    this.premiumTrends,
    this.chartOnlyPageModel,
    this.settings,
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

      final isSuccess = await ApiService.shared.saveAndSyncUserData({
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

      // Settings에서 수수료 정보 추출
      double? buyFee;
      double? sellFee;
      if (widget.settings != null) {
        final upbitFees =
            widget.settings!['upbit_fees'] as Map<String, dynamic>?;
        if (upbitFees != null) {
          buyFee = (upbitFees['buy_fee'] as num?)?.toDouble();
          sellFee = (upbitFees['sell_fee'] as num?)?.toDouble();
          print('시뮬레이션 수수료 설정: buyFee=$buyFee%, sellFee=$sellFee%');
        } else {
          print('시뮬레이션 수수료 설정: upbit_fees가 null입니다.');
        }
      } else {
        print('시뮬레이션 수수료 설정: settings가 null입니다.');
      }

      if (widget.simulationType == SimulationType.ai) {
        final simResults = SimulationModel.simulateResults(
          usdExchangeRates,
          strategyList,
          usdtMap,
          buyFee: buyFee,
          sellFee: sellFee,
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
          buyFee: buyFee,
          sellFee: sellFee,
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _GlassColors.glassWhite.withOpacity(0.95),
                      _GlassColors.glassWhite.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _GlassColors.glassBorder,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _GlassColors.primaryGradient[0].withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${displayDate.toCustomString()} ${l10n(context).strategy}',
                            style: _TitleStyles.dialogTitle,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.deepPurple,
                            ),
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
                          style: _DialogStyles.sectionTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strategy['summary'] ?? '',
                          style: _DialogStyles.bodyText,
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
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.simulationType == SimulationType.kimchi
              ? l10n(context).gimchBaseTrade
              : l10n(context).aiBaseTrade,
          style: _TitleStyles.appBarTitle,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _GlassColors.textPrimary),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _GlassColors.glassWhite.withOpacity(0.8),
                    _GlassColors.glassWhite.withOpacity(0.6),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(color: _GlassColors.glassBorder, width: 1),
                ),
              ),
            ),
          ),
        ),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _GlassColors.backgroundGradient,
          ),
        ),
        child: SafeArea(
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
                          style: _TitleStyles.sectionTitle,
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
                            // 매도가 있든 없든 평가금액 표시
                            widgets.add(const SizedBox(height: 12));
                            widgets.add(_buildResultCard(context, r));
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
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _GlassColors.glassWhite.withOpacity(0.9),
                    _GlassColors.glassWhite.withOpacity(0.7),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: _GlassColors.glassBorder, width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _GlassColors.primaryGradient[0].withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
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
                          style: _TitleStyles.sectionTitle,
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.show_chart,
                            color: Colors.deepPurple,
                            size: 16,
                          ),
                          label: Text(
                            l10n(context).seeWithChart,
                            style: _ButtonStyles.smallButton.copyWith(
                              color: Colors.deepPurple,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
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
                _GlassColors.glassWhite.withOpacity(0.7),
                _GlassColors.glassWhite.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _GlassColors.glassBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _GlassColors.primaryGradient,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _GlassColors.primaryGradient[0].withOpacity(
                              0.3,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.simulationType == SimulationType.ai
                            ? Icons.psychology
                            : Icons.trending_up,
                        color: Colors.white,
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
                            style: _TitleStyles.headerCardTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n(context).initialCapital,
                            style: _BodyStyles.labelText,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 차트 라인 (플레이스홀더)
                Container(
                  height: 3,
                  width: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _GlassColors.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Period
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n(context).tradingPerioid,
                      style: _BodyStyles.greyLabelText,
                    ),
                    Builder(
                      builder: (context) {
                        if (results.isEmpty) return const Text("-");
                        final startDate =
                            results.first.buyDate?.toCustomString() ?? "";
                        final endDate =
                            results.last.analysisDate.toCustomString();
                        return Text(
                          "$startDate - $endDate",
                          style: _CardStyles.headerCardValue,
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
                      style: _BodyStyles.greyLabelText,
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
                                style: _CardStyles.cardPrice.copyWith(
                                  color:
                                      totalGain >= 0
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                ),
                              ),
                              TextSpan(
                                text:
                                    "(${totalGainPercent.toStringAsFixed(2)}%)",
                                style: _CardStyles.headerCardValue.copyWith(
                                  color:
                                      totalGain >= 0
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stacked Final KRW (누적 최종 원화)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n(context).stackedFinalKRW,
                      style: _BodyStyles.greyLabelText,
                    ),
                    Builder(
                      builder: (context) {
                        if (results.isEmpty) return const Text("-");
                        final finalKRW = results.last.finalKRW;
                        return Text(
                          "₩${krwFormat.format(finalKRW.round())}",
                          style: _CardStyles.headerCardValue,
                        );
                      },
                    ),
                  ],
                ),
                // 수수료 적용 여부 표시
                Builder(
                  builder: (context) {
                    if (widget.settings == null) return const SizedBox.shrink();
                    final upbitFees =
                        widget.settings!['upbit_fees'] as Map<String, dynamic>?;
                    if (upbitFees == null) return const SizedBox.shrink();
                    final buyFee = (upbitFees['buy_fee'] as num?)?.toDouble();
                    final sellFee = (upbitFees['sell_fee'] as num?)?.toDouble();
                    if (buyFee == null || sellFee == null)
                      return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n(context).upbitFeeApplied(buyFee, sellFee),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyButton(
    BuildContext context,
    DateTime? date,
    Color color,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          child: OutlinedButton(
            onPressed: () {
              if (date != null) {
                _showStrategyDialog(context, date);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n(context).seeStrategy,
              style: _ButtonStyles.smallButton.copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuyCard(BuildContext context, SimulationResult r) {
    final gradient = [
      const Color(0xFFFF6B6B).withOpacity(0.9),
      const Color(0xFFFF8E8E).withOpacity(0.7),
    ];

    return GestureDetector(
      onTap: () {
        if (r.buyDate != null) {
          _showStrategyDialog(context, r.buyDate!);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradient[0], gradient[1]],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.north_east,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n(context).buy,
                      style: _CardStyles.cardTitle.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.buyDate?.toCustomString() ?? "-",
                      style: _CardStyles.cardDate.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      "₩${krwFormat.format(r.buyPrice)}",
                      style: _CardStyles.cardPrice.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStrategyButton(context, r.buyDate, Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSellCard(BuildContext context, SimulationResult r) {
    final gradient = [
      const Color(0xFF4ECDC4).withOpacity(0.9),
      const Color(0xFF44A08D).withOpacity(0.7),
    ];

    return GestureDetector(
      onTap: () {
        if (r.sellDate != null) {
          _showStrategyDialog(context, r.sellDate!);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradient[0], gradient[1]],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.south_east,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n(context).sell,
                      style: _CardStyles.cardTitle.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.sellDate?.toCustomString() ?? "-",
                      style: _CardStyles.cardDate.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      r.sellPrice != null
                          ? "₩${krwFormat.format(r.sellPrice!)}"
                          : "-",
                      style: _CardStyles.cardPrice.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStrategyButton(context, r.sellDate, Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, SimulationResult r) {
    // 매도가 없는 경우 수익과 수익률을 다시 계산
    double currentValue = r.finalKRW;
    double profit = r.profit;
    double profitRate = r.profitRate;
    double? currentUsdtPrice; // 매도가 없는 경우 USDT 가격 저장

    if (r.sellDate == null) {
      // 매도가 안된 경우: 현재 USDT 가격 기준으로 평가금액 계산
      final analysisDate = r.analysisDate;
      final usdtData = widget.usdtMap[analysisDate];
      currentUsdtPrice = usdtData?.close ?? 0.0;
      final usdtAmount = r.finalUSDT ?? 0.0;
      currentValue = currentUsdtPrice * usdtAmount;

      // 이전 거래의 finalKRW 또는 초기 자본을 매수 금액으로 사용
      final buyAmount = _getBuyAmountForResult(r);
      profit = currentValue - buyAmount;
      if (buyAmount > 0) {
        profitRate = (profit / buyAmount) * 100;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽 아이콘
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          // 오른쪽 텍스트 영역
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 첫 번째 줄: 수익 금액과 수익률
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "${l10n(context).gain}: ",
                        style: _CardStyles.cardDate.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text:
                            "${profit >= 0 ? '+' : ''}₩${krwFormat.format(profit.round())} ",
                        style: _CardStyles.cardDate.copyWith(
                          color:
                              profit >= 0
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (profitRate != 0)
                        TextSpan(
                          text:
                              "(${profitRate >= 0 ? '+' : ''}${profitRate.toStringAsFixed(2)}%)",
                          style: _CardStyles.cardDate.copyWith(
                            color:
                                profitRate >= 0
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                // 수수료 표시 (매도가 있는 경우만)
                Builder(
                  builder: (context) {
                    if (r.sellDate == null) return const SizedBox.shrink();
                    if (widget.settings == null) return const SizedBox.shrink();
                    final upbitFees =
                        widget.settings!['upbit_fees'] as Map<String, dynamic>?;
                    if (upbitFees == null) return const SizedBox.shrink();
                    final buyFee = (upbitFees['buy_fee'] as num?)?.toDouble();
                    final sellFee = (upbitFees['sell_fee'] as num?)?.toDouble();
                    if (buyFee == null ||
                        sellFee == null ||
                        (buyFee == 0 && sellFee == 0))
                      return const SizedBox.shrink();

                    // 매수 수수료 계산
                    // buyPrice는 USDT 단가이고, 실제 매수 금액은 totalKRW입니다
                    // 매수 시: 실제 매수 금액 기준으로 수수료 계산
                    // 이전 거래의 finalKRW 또는 초기 자본을 매수 금액으로 사용
                    final buyAmount = _getBuyAmountForResult(r);
                    final buyFeeAmount = buyAmount * (buyFee / 100);

                    // 매도 수수료 계산
                    // sellPrice는 USDT 단가이고, 실제 매도 금액은 usdtAmount * sellPrice입니다
                    // 매도 시: 실제 매도 금액 기준으로 수수료 계산
                    // usdtAmount = buyAmount / buyPrice (buyPrice는 수수료 포함 가격)
                    final usdtAmount = buyAmount / r.buyPrice;
                    // 실제 매도 금액 = usdtAmount * sellPrice (sellPrice는 수수료 미적용 가격)
                    final sellAmount = usdtAmount * (r.sellPrice ?? 0);
                    final sellFeeAmount = sellAmount * (sellFee / 100);

                    print(
                      '수수료 계산: buyAmount=$buyAmount, buyFeeAmount=$buyFeeAmount, sellAmount=$sellAmount, sellFeeAmount=$sellFeeAmount, totalFee=${buyFeeAmount + sellFeeAmount}',
                    );

                    // 총 수수료
                    final totalFee = buyFeeAmount + sellFeeAmount;

                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n(
                          context,
                        ).feeWithAmount(krwFormat.format(totalFee.round())),
                        style: _CardStyles.cardDate.copyWith(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // 두 번째 줄: 최종원화 또는 평가금액
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text:
                            r.sellDate == null
                                ? "${l10n(context).evaluationAmount} "
                                : "${l10n(context).finalKRW} ",
                        style: _CardStyles.cardDate.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: "₩${krwFormat.format(currentValue.round())}",
                        style: _CardStyles.cardDate.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                      if (r.sellDate == null && currentUsdtPrice != null)
                        TextSpan(
                          text:
                              " (${l10n(context).usdt}: ${currentUsdtPrice.toStringAsFixed(1)})",
                          style: _CardStyles.cardDate.copyWith(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 결과 카드에서 사용할 매수 금액 계산
  double _getBuyAmountForResult(SimulationResult r) {
    // 현재 결과의 인덱스 찾기
    final index = results.indexOf(r);
    if (index > 0) {
      // 이전 거래의 finalKRW 사용
      return results[index - 1].finalKRW;
    } else {
      // 첫 거래인 경우 초기 자본 사용
      return 1000000.0;
    }
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
            showInfoIcon: true,
            onInfoTap: () => _showAnnualYieldInfoDialog(context),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    Color valueColor, {
    bool showInfoIcon = false,
    VoidCallback? onInfoTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _GlassColors.glassWhite.withOpacity(0.7),
                _GlassColors.glassWhite.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _GlassColors.glassBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: _CardStyles.metricLabel),
                  if (showInfoIcon) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onInfoTap,
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: _GlassColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: _CardStyles.metricValue.copyWith(color: valueColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnnualYieldInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                l10n(context).extimatedYearGain,
                style: _TitleStyles.dialogTitle,
              ),
            ],
          ),
          content: Text(
            l10n(context).annualYieldDescription,
            style: _DialogStyles.bodyText,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n(context).confirm,
                style: TextStyle(color: Colors.deepPurple),
              ),
            ),
          ],
        );
      },
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
          style: _ButtonStyles.largeButton,
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
            style: _BodyStyles.labelText.copyWith(
              color: Colors.deepPurple,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: _BodyStyles.bodyText),
        ],
      ),
    );
  }
}
