import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'simulation_page.dart';
import 'simulation_model.dart';
import 'api_service.dart';
import 'l10n/app_localizations.dart';
import 'utils.dart';
import 'dialogs/liquid_glass_dialog.dart';

class StrategyHistoryPage extends StatefulWidget {
  final SimulationType simulationType;
  final List<ChartData> usdExchangeRates;
  final Map<DateTime, USDTChartData> usdtMap;
  final List<StrategyMap>? strategies; // 전략 데이터 추가
  final Map<DateTime, Map<String, double>>? premiumTrends; // 김치 프리미엄 트렌드 데이터

  const StrategyHistoryPage({
    Key? key,
    required this.simulationType,
    required this.usdExchangeRates,
    required this.usdtMap,
    this.strategies, // 선택적 파라미터
    this.premiumTrends,
  }) : super(key: key);

  @override
  State<StrategyHistoryPage> createState() => _StrategyHistoryPageState();
}

class _StrategyHistoryPageState extends State<StrategyHistoryPage> {
  List<StrategyMap>? strategies;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    strategies = widget.strategies;
    loading = false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                cs.surfaceContainerHigh.withValues(alpha: 0.98),
                cs.surface.withValues(alpha: 0.96),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border(
              top: BorderSide(
                color: cs.outline.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 제목
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.simulationType == SimulationType.kimchi
                          ? Icons.trending_up
                          : Icons.psychology,
                      color: cs.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.simulationType == SimulationType.kimchi
                          ? l10n(context).kimchiStrategyHistory
                          : l10n(context).aiStrategyHistory,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: cs.onSurfaceVariant,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        // 현재 모달만 닫기
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.35)),
              // 내용
              Expanded(
                child:
                    loading
                        ? Center(
                          child: CircularProgressIndicator(
                            color: cs.primary,
                          ),
                        )
                        : error != null
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: cs.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '오류가 발생했습니다',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: cs.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                error!,
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.85),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                        : strategies == null || strategies!.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n(context).noStrategyData,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        )
                        : _buildStrategyList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyList() {
    if (widget.simulationType == SimulationType.kimchi) {
      // 김프 매매: usdtMap의 날짜 기준으로 정렬
      final sortedDates =
          widget.usdtMap.keys.toList()..sort((a, b) => b.compareTo(a)); // 최신순

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          // 해당 날짜의 전략 데이터는 동적으로 생성 (trend 기반)

          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context)
                          .colorScheme
                          .surfaceContainerHigh
                          .withValues(alpha: 0.95),
                      Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.88),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => _showKimchiStrategyDetail(context, date),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${DateFormat('yyyy/MM/dd').format(date)} ${l10n(context).strategy}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildKimchiStrategyInfo(context, date),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else {
      // AI 매매: strategyList의 날짜 기준으로 정렬
      final sortedStrategies = List<StrategyMap>.from(strategies!)
        ..sort((a, b) {
          final dateA = DateTime.parse(a['analysis_date']);
          final dateB = DateTime.parse(b['analysis_date']);
          return dateB.compareTo(dateA); // 최신순
        });

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedStrategies.length,
        itemBuilder: (context, index) {
          final strategy = sortedStrategies[index];
          final date = DateTime.parse(strategy['analysis_date']);

          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context)
                          .colorScheme
                          .surfaceContainerHigh
                          .withValues(alpha: 0.95),
                      Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.88),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => _showStrategyDetail(context, strategy, date),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${DateFormat('yyyy/MM/dd').format(date)} ${l10n(context).strategy}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildAIStrategyInfo(context, strategy),
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
  }

  Widget _buildKimchiStrategyInfo(BuildContext context, DateTime date) {
    // 김프 전략 정보 표시
    var (buyThreshold, sellThreshold) = (
      SimulationCondition.instance.kimchiBuyThreshold,
      SimulationCondition.instance.kimchiSellThreshold,
    );

    // 추세 기반 전략 제거 - 항상 기본 임계값 사용
    (buyThreshold, sellThreshold) = SimulationModel.getKimchiThresholds(
      trendData: null,
      exchangeRates: widget.usdExchangeRates,
      targetDate: date,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF14532D).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  '매수: ${buyThreshold.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF86EFAC),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFF87171).withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  '매도: ${sellThreshold.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFECACA),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAIStrategyInfo(BuildContext context, StrategyMap strategy) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (strategy['summary'] != null) ...[
          Text(
            strategy['summary'],
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.92),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            if (strategy['buy_price'] != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF14532D).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '매수: ${NumberFormat('#,##0').format(strategy['buy_price'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF86EFAC),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (strategy['sell_price'] != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFF87171).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '매도: ${NumberFormat('#,##0').format(strategy['sell_price'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFECACA),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showStrategyDetail(
    BuildContext context,
    StrategyMap strategy,
    DateTime date,
  ) {
    // 기존의 _showStrategyDialog와 동일한 로직 사용
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final cs = Theme.of(context).colorScheme;
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
                      cs.surfaceContainerHigh.withValues(alpha: 0.98),
                      cs.surface.withValues(alpha: 0.94),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: cs.outline.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${DateFormat('yyyy/MM/dd').format(date)} ${AppLocalizations.of(context)!.strategy}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: cs.onSurface,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: cs.primary,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              // 현재 다이얼로그만 닫기
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (widget.simulationType == SimulationType.kimchi) ...[
                        _buildKimchiStrategyDetail(context, date),
                      ] else ...[
                        _buildAIStrategyDetail(context, strategy),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(l10n(context).close),
                        ),
                      ),
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

  void _showKimchiStrategyDetail(BuildContext context, DateTime date) {
    LiquidGlassDialog.show(
      context: context,
      title: Text(
        '${DateFormat('yyyy/MM/dd').format(date)} ${l10n(context).kimchiStrategy}',
      ),
      content: _buildKimchiStrategyDetail(context, date),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n(context).close),
        ),
      ],
    );
  }

  Widget _buildKimchiStrategyDetail(BuildContext context, DateTime date) {
    var (buyThreshold, sellThreshold) = (
      SimulationCondition.instance.kimchiBuyThreshold,
      SimulationCondition.instance.kimchiSellThreshold,
    );

    // 추세 기반 전략 제거 - 항상 기본 임계값 사용
    (buyThreshold, sellThreshold) = SimulationModel.getKimchiThresholds(
      trendData: null,
      exchangeRates: widget.usdExchangeRates,
      targetDate: date,
    );

    return Text(
      AppLocalizations.of(context)!.kimchiStrategyComment(
        double.parse(buyThreshold.toStringAsFixed(1)),
        double.parse(sellThreshold.toStringAsFixed(1)),
      ),
      style: TextStyle(
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurface,
        height: 1.45,
      ),
    );
  }

  Widget _buildAIStrategyDetail(BuildContext context, StrategyMap strategy) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (strategy['summary'] != null) ...[
          Text(
            strategy['summary'],
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (strategy['buy_price'] != null) ...[
          Text(
            '매수 가격: ${NumberFormat('#,##0').format(strategy['buy_price'])}원',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF86EFAC),
            ),
          ),
        ],
        if (strategy['sell_price'] != null) ...[
          Text(
            '매도 가격: ${NumberFormat('#,##0').format(strategy['sell_price'])}원',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFFECACA),
            ),
          ),
        ],
      ],
    );
  }
}
