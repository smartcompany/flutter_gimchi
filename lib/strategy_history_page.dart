import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'simulation_page.dart';
import 'simulation_model.dart';
import 'api_service.dart';
import 'l10n/app_localizations.dart';
import 'utils.dart';

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
    return Column(
      children: [
        // 드래그 핸들
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // 제목
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Icon(
                widget.simulationType == SimulationType.kimchi
                    ? Icons.trending_up
                    : Icons.psychology,
                color: Colors.deepPurple,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                widget.simulationType == SimulationType.kimchi
                    ? l10n(context).kimchiStrategyHistory
                    : l10n(context).aiStrategyHistory,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  // 현재 모달만 닫기
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 내용
        Expanded(
          child:
              loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '오류가 발생했습니다',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: TextStyle(color: Colors.red[600]),
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
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n(context).noStrategyData,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                  : _buildStrategyList(),
        ),
      ],
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

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => _showKimchiStrategyDetail(context, date),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: Colors.deepPurple,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${DateFormat('yyyy/MM/dd').format(date)} ${l10n(context).strategy}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey[400],
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

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => _showStrategyDetail(context, strategy, date),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          color: Colors.deepPurple,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${DateFormat('yyyy/MM/dd').format(date)} ${l10n(context).strategy}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey[400],
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

    if (SimulationCondition.instance.useTrend) {
      // 서버에서 받은 김치 프리미엄 트렌드 데이터 사용
      (buyThreshold, sellThreshold) = SimulationModel.getKimchiThresholds(
        trendData: widget.premiumTrends?[date],
      );
    }

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
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  '매수: ${buyThreshold.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  '매도: ${sellThreshold.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
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
    return Column(
      children: [
        if (strategy['summary'] != null) ...[
          Text(
            strategy['summary'],
            style: const TextStyle(fontSize: 14, color: Colors.black87),
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
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '매수: ${NumberFormat('#,##0').format(strategy['buy_price'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (strategy['sell_price'] != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '매도: ${NumberFormat('#,##0').format(strategy['sell_price'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
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
                      '${DateFormat('yyyy/MM/dd').format(date)} ${AppLocalizations.of(context)!.strategy}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.deepPurple),
                      onPressed: () {
                        // 현재 다이얼로그만 닫기
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
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
        );
      },
    );
  }

  void _showKimchiStrategyDetail(BuildContext context, DateTime date) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '${DateFormat('yyyy/MM/dd').format(date)} ${l10n(context).kimchiStrategy}',
            ),
            content: _buildKimchiStrategyDetail(context, date),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }

  Widget _buildKimchiStrategyDetail(BuildContext context, DateTime date) {
    var (buyThreshold, sellThreshold) = (
      SimulationCondition.instance.kimchiBuyThreshold,
      SimulationCondition.instance.kimchiSellThreshold,
    );

    if (SimulationCondition.instance.useTrend) {
      // 서버에서 받은 김치 프리미엄 트렌드 데이터 사용
      (buyThreshold, sellThreshold) = SimulationModel.getKimchiThresholds(
        trendData: widget.premiumTrends?[date],
      );
    }

    return Text(
      AppLocalizations.of(context)!.kimchiStrategyComment(
        double.parse(buyThreshold.toStringAsFixed(1)),
        double.parse(sellThreshold.toStringAsFixed(1)),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildAIStrategyDetail(BuildContext context, StrategyMap strategy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (strategy['summary'] != null) ...[
          Text(strategy['summary'], style: const TextStyle(fontSize: 16)),
        ],
        const SizedBox(height: 12),
        if (strategy['buy_price'] != null) ...[
          Text(
            '매수 가격: ${NumberFormat('#,##0').format(strategy['buy_price'])}원',
            style: const TextStyle(fontSize: 14, color: Colors.green),
          ),
        ],
        if (strategy['sell_price'] != null) ...[
          Text(
            '매도 가격: ${NumberFormat('#,##0').format(strategy['sell_price'])}원',
            style: const TextStyle(fontSize: 14, color: Colors.red),
          ),
        ],
      ],
    );
  }
}
