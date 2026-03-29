import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../components/common/glass_card.dart';
import '../../components/common/custom_slider.dart';
import '../../services/api_service.dart';
import '../portfolio_tracker/portfolio_tracker_screen.dart' show PortfolioState;

class FireCalculatorScreen extends StatefulWidget {
  const FireCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<FireCalculatorScreen> createState() => _FireCalculatorScreenState();
}

class _FireCalculatorScreenState extends State<FireCalculatorScreen> {
  double sip = 25000;
  double returnRate = 12;
  double corpus = 50000000;
  double currentInv = 1500000;
  double expenses = 60000;

  bool _isLoading = false;
  bool _seededFromPortfolio = false;

  int _yearsToFire = 0;
  double _fireNumber = 0;
  double _totalInvested = 0;
  double _returnsGained = 0;
  List<Map<String, dynamic>> _chartData = [];

  @override
  void initState() {
    super.initState();
    _seedFromPortfolio();
    _runCalculation();
  }

  void _seedFromPortfolio() {
    if (PortfolioState.totalInvested > 0) {
      currentInv = PortfolioState.currentValue;
      if (PortfolioState.monthlyTotalSip > 0) {
        sip = PortfolioState.monthlyTotalSip;
      }
      _seededFromPortfolio = true;
    }
  }

  void _runLocalCalc() {
    double currentWealth = currentInv;
    int years = 0;
    double totalInv = currentInv;
    final monthlyRate = returnRate / 100 / 12;
    final List<Map<String, dynamic>> data = [];

    data.add({'year': 0, 'invested': totalInv.round(), 'returns': 0, 'total': currentWealth.round()});

    for (int y = 1; y <= 30; y++) {
      for (int m = 0; m < 12; m++) {
        currentWealth += currentWealth * monthlyRate + sip;
        totalInv += sip;
      }
      data.add({
        'year': y,
        'invested': totalInv.round(),
        'returns': (currentWealth - totalInv).round(),
        'total': currentWealth.round(),
      });
      if (currentWealth >= corpus && years == 0) years = y;
    }

    setState(() {
      _yearsToFire = years == 0 ? -1 : years;
      _fireNumber = expenses * 12 * 25;
      _totalInvested = data.lastWhere((d) => (d['total'] as int) >= corpus,
              orElse: () => data.last)['invested'] as double? ??
          totalInv;
      _returnsGained = (data.lastWhere((d) => (d['total'] as int) >= corpus,
                  orElse: () => data.last)['returns'] as int)
              .toDouble();
      _chartData = data.where((d) => (d['year'] as int) % 2 == 0).take(15).toList();
    });
  }

  Future<void> _runCalculation() async {
    setState(() => _isLoading = true);
    try {
      final result = await apiService.post<Map<String, dynamic>>(
        '/fire',
        body: {
          'monthly_sip': sip,
          'expected_return': returnRate,
          'target_corpus': corpus,
          'current_investments': currentInv,
          'monthly_expenses': expenses,
          'inflation_rate': 6.0,
        },
        requireAuth: false,
      );
      final projection = (result['projection'] as List<dynamic>?) ?? [];
      setState(() {
        _yearsToFire = (result['years_to_target'] as num?)?.toInt() ?? 0;
        _fireNumber = (result['fire_number'] as num?)?.toDouble() ?? expenses * 12 * 25;
        _totalInvested = (result['total_invested'] as num?)?.toDouble() ?? 0;
        _returnsGained = (result['wealth_gained'] as num?)?.toDouble() ?? 0;
        _chartData = projection
            .where((d) => (d['year'] as int) % 2 == 0)
            .take(15)
            .map((d) => {
                  'year': d['year'],
                  'invested': d['invested'],
                  'returns': d['gains'],
                  'total': d['value'],
                })
            .toList();
      });
    } catch (_) {
      _runLocalCalc();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isTablet = MediaQuery.of(context).size.width < 1024;
    final padding = isMobile ? 16.0 : 32.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile, isDark),
          SizedBox(height: isMobile ? 20 : 32),
          if (isMobile)
            _buildMobileLayout(isDark)
          else if (isTablet)
            _buildTabletLayout(isDark)
          else
            _buildDesktopLayout(isDark),
          SizedBox(height: isMobile ? 80 : 24),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile, bool isDark) {
    final brandSecondary = AppColors.getBrandSecondary(isDark);
    final secondaryGradient = AppColors.getSecondaryGradient(isDark);

    return Row(
      children: [
        Container(
          width: isMobile ? 44 : 56,
          height: isMobile ? 44 : 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: secondaryGradient),
            boxShadow: [
              BoxShadow(color: brandSecondary.withOpacity(0.5), blurRadius: 20),
            ],
          ),
          child: Icon(Icons.local_fire_department, color: Colors.white, size: isMobile ? 22 : 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    LinearGradient(colors: [AppColors.getTextPrimary(isDark), brandSecondary])
                        .createShader(b),
                child: Text(
                  'FIRE Calculator',
                  style: TextStyle(
                    fontSize: isMobile ? 24 : 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
              ),
              Text(
                'Financial Independence, Retire Early.',
                style: TextStyle(
                    fontSize: isMobile ? 12 : 15, color: AppColors.getTextTertiary(isDark)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Column(
      children: [
        _buildInputPanel(isDark),
        const SizedBox(height: 20),
        _buildResultsGrid(crossAxisCount: 2, isDark: isDark),
        const SizedBox(height: 20),
        _buildChartCard(height: 260, isDark: isDark),
      ],
    );
  }

  Widget _buildTabletLayout(bool isDark) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 1, child: _buildInputPanel(isDark)),
            const SizedBox(width: 20),
            Expanded(flex: 1, child: _buildResultsGrid(crossAxisCount: 2, isDark: isDark)),
          ],
        ),
        const SizedBox(height: 20),
        _buildChartCard(height: 300, isDark: isDark),
      ],
    );
  }

  Widget _buildDesktopLayout(bool isDark) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: _buildInputPanel(isDark)),
            const SizedBox(width: 24),
            Expanded(
              flex: 7,
              child: Column(
                children: [
                  _buildResultsGrid(crossAxisCount: 4, isDark: isDark),
                  const SizedBox(height: 24),
                  _buildChartCard(height: 320, isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputPanel(bool isDark) {
    final brandPrimary = AppColors.getBrandPrimary(isDark);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Variables',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
          ),
          Divider(color: AppColors.getBorder(isDark, 0.1), height: 24),
          if (_seededFromPortfolio)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: brandPrimary.withOpacity(0.08),
                  border: Border.all(color: brandPrimary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, color: brandPrimary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Values seeded from your Portfolio  '
                        '(₹${(PortfolioState.currentValue / 100000).toStringAsFixed(1)}L invested·'
                        '₹${(PortfolioState.monthlyTotalSip / 1000).toStringAsFixed(1)}K/mo SIP)',
                        style: TextStyle(
                            fontSize: 11,
                            color: brandPrimary,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          CustomSlider(
            label: 'Monthly SIP',
            value: sip.clamp(1000, 500000).toDouble(),
            min: 1000,
            max: 500000,
            suffix: '₹',
            onChanged: (v) {
              setState(() => sip = v);
              _debounceCalc();
            },
          ),
          const SizedBox(height: 16),
          CustomSlider(
            label: 'Expected Return',
            value: returnRate,
            min: 4,
            max: 30,
            suffix: '%',
            onChanged: (v) {
              setState(() => returnRate = v);
              _debounceCalc();
            },
          ),
          const SizedBox(height: 16),
          CustomSlider(
            label: 'Target Corpus',
            value: corpus,
            min: 1000000,
            max: 100000000,
            suffix: '₹',
            onChanged: (v) {
              setState(() => corpus = v);
              _debounceCalc();
            },
          ),
          const SizedBox(height: 16),
          CustomSlider(
            label: 'Current Investments',
            value: currentInv.clamp(0, 50000000).toDouble(),
            min: 0,
            max: 50000000,
            suffix: '₹',
            onChanged: (v) {
              setState(() => currentInv = v);
              _debounceCalc();
            },
          ),
          const SizedBox(height: 16),
          CustomSlider(
            label: 'Monthly Expenses',
            value: expenses,
            min: 10000,
            max: 200000,
            suffix: '₹',
            onChanged: (v) {
              setState(() => expenses = v);
              _debounceCalc();
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.getOverlay(isDark, 0.05),
              border: Border.all(color: AppColors.getBorder(isDark, 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: brandPrimary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark), height: 1.5),
                      children: [
                        const TextSpan(text: 'Your '),
                        TextSpan(
                          text: 'FIRE Number',
                          style: TextStyle(color: AppColors.getBrandSecondary(isDark), fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                            text: ' is 25× annual expenses, assuming a 4% safe withdrawal rate.'),
                      ],
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

  bool _debounceActive = false;
  void _debounceCalc() {
    if (!_debounceActive) {
      _debounceActive = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        _debounceActive = false;
        _runLocalCalc();
      });
    }
  }

  Widget _buildResultsGrid({required int crossAxisCount, required bool isDark}) {
    final brandPrimary = AppColors.getBrandPrimary(isDark);
    final brandSecondary = AppColors.getBrandSecondary(isDark);

    final cards = [
      _ResultData(
        title: 'Years to Target',
        value: _yearsToFire == -1 ? '30+ yrs' : '$_yearsToFire yrs',
        color: brandPrimary,
        icon: Icons.access_time_rounded,
      ),
      _ResultData(
        title: 'FIRE Number',
        value: '₹${(_fireNumber / 100000).toStringAsFixed(1)}L',
        subtitle: 'To never work again',
        color: brandSecondary,
        icon: Icons.local_fire_department,
      ),
      _ResultData(
        title: 'Total Invested',
        value: '₹${(_totalInvested / 100000).toStringAsFixed(1)}L',
        color: isDark ? const Color(0xFF2475AC) : AppColors.lightPrimaryDark,
        icon: Icons.pie_chart_outline,
      ),
      _ResultData(
        title: 'Wealth Gained',
        value: '₹${(_returnsGained / 100000).toStringAsFixed(1)}L',
        subtitle: 'From compounding',
        color: isDark ? const Color(0xFF733E85) : AppColors.lightAccentGreen,
        icon: Icons.trending_up,
      ),
    ];

    if (crossAxisCount == 4) {
      return Row(
        children: cards.map((c) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: c == cards.last ? 0 : 14),
            child: _buildResultCard(c, isDark),
          ),
        )).toList(),
      );
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: crossAxisCount == 2 ? 0.95 : 1.0,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards.map((c) => _buildResultCard(c, isDark)).toList(),
    );
  }

  Widget _buildResultCard(_ResultData card, bool isDark) {
    return GlassCard(
      backgroundColor: card.color.withOpacity(0.08),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: card.color.withOpacity(0.2),
                ),
                child: Icon(card.icon, color: card.color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.title,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.getTextTertiary(isDark), fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_isLoading)
            SizedBox(
                height: 24, width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.getBrandPrimary(isDark)))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  card.value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: card.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (card.subtitle != null)
                  Text(
                    card.subtitle!,
                    style: TextStyle(fontSize: 11, color: AppColors.getTextTertiary(isDark)),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildChartCard({required double height, required bool isDark}) {
    final brandPrimary = AppColors.getBrandPrimary(isDark);
    final brandSecondary = AppColors.getBrandSecondary(isDark);

    final investedSpots = _chartData
        .map((d) => FlSpot(
              (d['year'] as int).toDouble(),
              ((d['invested'] as num) / 100000).toDouble(),
            ))
        .toList();
    final returnsSpots = _chartData
        .map((d) => FlSpot(
              (d['year'] as int).toDouble(),
              ((d['returns'] as num) / 100000).toDouble(),
            ))
        .toList();

    return GlassCard(
      glowColor: brandSecondary,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Wealth Growth Curve',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(isDark)),
              ),
              const Spacer(),
              _legendDot(brandPrimary, 'Invested', isDark),
              const SizedBox(width: 12),
              _legendDot(brandSecondary, 'Returns', isDark),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: height,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: brandPrimary))
                : (_chartData.isEmpty
                    ? Center(
                        child: Text('Move sliders to see projection',
                            style: TextStyle(color: AppColors.getTextTertiary(isDark))),
                      )
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: AppColors.getOverlay(isDark, 0.05),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 52,
                                getTitlesWidget: (v, _) => Text(
                                  '₹${v.toStringAsFixed(0)}L',
                                  style: TextStyle(
                                      fontSize: 10, color: AppColors.getTextTertiary(isDark)),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) => Text(
                                  'Y${v.toInt()}',
                                  style: TextStyle(
                                      fontSize: 10, color: AppColors.getTextTertiary(isDark)),
                                ),
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: investedSpots,
                              isCurved: true,
                              color: isDark ? const Color(0xFF2475AC) : AppColors.lightPrimaryDark,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    (isDark ? const Color(0xFF2475AC) : AppColors.lightPrimaryDark).withOpacity(0.4),
                                    (isDark ? const Color(0xFF2475AC) : AppColors.lightPrimaryDark).withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                            LineChartBarData(
                              spots: returnsSpots,
                              isCurved: true,
                              color: brandSecondary,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    brandSecondary.withOpacity(0.4),
                                    brandSecondary.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (bars) => bars
                                  .map((b) => LineTooltipItem(
                                        '₹${b.y.toStringAsFixed(1)}L',
                                        const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.getTextTertiary(isDark))),
      ],
    );
  }
}

class _ResultData {
  final String title;
  final String value;
  final String? subtitle;
  final Color color;
  final IconData icon;

  const _ResultData({
    required this.title,
    required this.value,
    this.subtitle,
    required this.color,
    required this.icon,
  });
}
