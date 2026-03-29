import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../components/common/glass_card.dart';
import '../../services/api_service.dart';

// ─── In-memory shared portfolio state (so FIRE screen can read it) ────────────
class PortfolioState {
  static double totalInvested = 0;
  static double monthlyTotalSip = 0;
  static double currentValue = 0;

  static void update({
    required double invested,
    required double value,
    required double sip,
  }) {
    totalInvested = invested;
    currentValue = value;
    monthlyTotalSip = sip;
  }
}

// ─── Asset type helpers ───────────────────────────────────────────────────────
const _typeLabels = {
  'stock': 'Direct Stock',
  'mutual_fund': 'Mutual Fund',
  'sip': 'SIP',
  'gold': 'Gold / SGB',
  'crypto': 'Crypto',
  'cash': 'Cash / FD',
  'other': 'Other',
};

Color _colorForType(String type, bool isDark) {
  if (type == 'stock') return AppColors.getBrandSecondary(isDark);
  if (type == 'mutual_fund') return AppColors.getBrandPrimary(isDark);
  if (type == 'sip') return (isDark ? const Color(0xFF733E85) : AppColors.lightSecondary);
  if (type == 'gold') return const Color(0xFFFB923C);
  if (type == 'crypto') return const Color(0xFF10B981);
  if (type == 'cash') return (isDark ? const Color(0xFF2475AC) : AppColors.lightPrimaryDark);
  return const Color(0xFF64748B);
}

String _labelForType(String type) => _typeLabels[type] ?? type;

// ─── Local model ──────────────────────────────────────────────────────────────
class Investment {
  final int? id;
  final String type;
  final String name;
  final String? symbol;
  final double amountInvested;
  final double? quantity;
  final double? avgPrice;
  final double? sipAmount;
  final double currentValue;
  final double gainLossPercent;
  final String? trend;

  Investment({
    this.id,
    required this.type,
    required this.name,
    this.symbol,
    required this.amountInvested,
    this.quantity,
    this.avgPrice,
    this.sipAmount,
    required this.currentValue,
    required this.gainLossPercent,
    this.trend,
  });

  factory Investment.fromJson(Map<String, dynamic> j) => Investment(
        id: j['id'] as int?,
        type: j['type']?.toString() ?? 'other',
        name: j['name']?.toString() ?? j['symbol']?.toString() ?? 'Asset',
        symbol: j['symbol']?.toString(),
        amountInvested: (j['amount_invested'] as num?)?.toDouble() ?? 0,
        quantity: (j['quantity'] as num?)?.toDouble(),
        avgPrice: (j['avg_price'] as num?)?.toDouble(),
        sipAmount: (j['sip_amount'] as num?)?.toDouble(),
        currentValue: (j['current_value'] as num?)?.toDouble() ??
            (j['amount_invested'] as num?)?.toDouble() ?? 0,
        gainLossPercent:
            (j['gain_loss_percent'] as num?)?.toDouble() ?? 0,
        trend: j['trend']?.toString(),
      );
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class PortfolioTrackerScreen extends StatefulWidget {
  const PortfolioTrackerScreen({Key? key}) : super(key: key);

  @override
  State<PortfolioTrackerScreen> createState() => _PortfolioTrackerScreenState();
}

class _PortfolioTrackerScreenState extends State<PortfolioTrackerScreen>
    with SingleTickerProviderStateMixin {
  // Store theme flag so closures don't call Theme.of(context) after dispose
  bool isDark = false;
  bool _disposed = false;

  late TabController _tabController;
  bool _isLoading = false;
  int? _touchedIndex;

  // Data
  List<Investment> _investments = [];
  double _totalInvested = 0;
  double _currentValue = 0;
  List<Map<String, dynamic>> _allocation = [];

  // Projection spots (for projections tab)
  List<FlSpot> _projectionSpots = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPortfolio();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe place to read Theme — always called before build
    isDark = Theme.of(context).brightness == Brightness.dark;
  }

  @override
  void dispose() {
    _disposed = true;
    _tabController.dispose();
    super.dispose();
  }

  // ─── API ───────────────────────────────────────────────────────────────────

  Future<void> _loadPortfolio() async {
    if (_disposed || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final snap = await apiService.get<Map<String, dynamic>>(
        '/investments/portfolio',
        requireAuth: false,
      );
      if (_disposed || !mounted) return;
      _applySnapshot(snap);
    } catch (_) {
      if (_disposed || !mounted) return;
      _loadFallback();
    } finally {
      if (!_disposed && mounted) setState(() => _isLoading = false);
    }
  }

  void _applySnapshot(Map<String, dynamic> snap) {
    final summary = snap['summary'] as Map<String, dynamic>? ?? {};
    final assets = (snap['assets'] as List<dynamic>? ?? [])
        .map((a) => Investment.fromJson(a as Map<String, dynamic>))
        .toList();
    final allocation = (snap['allocation'] as List<dynamic>? ?? [])
        .map((a) => a as Map<String, dynamic>)
        .toList();

    final totalInv = (summary['total_invested'] as num?)?.toDouble() ?? 0;
    final curVal = (summary['current_value'] as num?)?.toDouble() ?? totalInv;
    final sip = assets.fold<double>(
        0, (s, e) => s + (e.sipAmount ?? 0));

    PortfolioState.update(
        invested: totalInv, value: curVal, sip: sip);

    // Build projection spots
    final spots = _buildProjectionSpots(curVal, sip);

    if (_disposed || !mounted) return;
    setState(() {
      _investments = assets;
      _totalInvested = totalInv;
      _currentValue = curVal;
      _allocation = allocation;
      _projectionSpots = spots;
    });
  }

  void _loadFallback() {
    // Use demo data so the screen is never blank
    final demo = [
      {'type': 'mutual_fund', 'name': 'Equity Mutual Funds', 'amount_invested': 650000.0, 'current_value': 720000.0, 'sip_amount': 15000.0, 'gain_loss_percent': 10.8},
      {'type': 'stock', 'name': 'Direct Stocks', 'amount_invested': 250000.0, 'current_value': 280000.0, 'gain_loss_percent': 12.0},
      {'type': 'cash', 'name': 'Fixed Deposits', 'amount_invested': 400000.0, 'current_value': 427600.0, 'gain_loss_percent': 6.9},
      {'type': 'gold', 'name': 'Gold / SGBs', 'amount_invested': 150000.0, 'current_value': 163500.0, 'sip_amount': 3000.0, 'gain_loss_percent': 9.0},
      {'type': 'sip', 'name': 'EPF / PPF', 'amount_invested': 350000.0, 'current_value': 378000.0, 'sip_amount': 5000.0, 'gain_loss_percent': 8.0},
    ];
    final investments = demo
        .map((d) => Investment.fromJson(d as Map<String, dynamic>))
        .toList();
    final totalInv = investments.fold<double>(0, (s, e) => s + e.amountInvested);
    final curVal = investments.fold<double>(0, (s, e) => s + e.currentValue);
    final sip = investments.fold<double>(0, (s, e) => s + (e.sipAmount ?? 0));

    PortfolioState.update(invested: totalInv, value: curVal, sip: sip);

    final typeMap = <String, double>{};
    for (final inv in investments) {
      typeMap[inv.type] = (typeMap[inv.type] ?? 0) + inv.currentValue;
    }
    final allocation = typeMap.entries
        .map((e) => {
              'type': e.key,
              'value': e.value,
              'allocation_percent': (e.value / curVal) * 100,
            })
        .toList()
      ..sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

    if (_disposed || !mounted) return;
    setState(() {
      _investments = investments;
      _totalInvested = totalInv;
      _currentValue = curVal;
      _allocation = allocation;
      _projectionSpots = _buildProjectionSpots(curVal, sip);
    });
  }

  List<FlSpot> _buildProjectionSpots(double base, double monthlySip) {
    final rate = 0.105 / 12; // 10.5% blended annual → monthly
    double wealth = base;
    final spots = [FlSpot(0, base / 100000)];
    for (int y = 1; y <= 10; y++) {
      for (int m = 0; m < 12; m++) {
        wealth = wealth * (1 + rate) + monthlySip;
      }
      spots.add(FlSpot(y.toDouble(), wealth / 100000));
    }
    return spots;
  }

  Future<void> _deleteInvestment(Investment inv) async {
    if (inv.id == null) return;
    try {
      await apiService.delete('/investments/${inv.id}', requireAuth: false);
      if (!_disposed && mounted) await _loadPortfolio();
    } catch (_) {
      if (_disposed || !mounted) return;
      setState(() => _investments.remove(inv));
    }
  }

  Future<void> _addInvestment(Map<String, dynamic> payload) async {
    try {
      await apiService.post('/investments', body: payload, requireAuth: false);
      if (!_disposed && mounted) await _loadPortfolio();
    } catch (_) {
      if (_disposed || !mounted) return;
      final localInv = Investment.fromJson({
        ...payload,
        'current_value': payload['amount_invested'],
        'gain_loss_percent': 0.0,
      });
      setState(() => _investments.insert(0, localInv));
    }
  }

  Future<void> _updateInvestment(int id, Map<String, dynamic> payload) async {
    try {
      await apiService.put('/investments/$id', body: payload, requireAuth: false);
      if (!_disposed && mounted) await _loadPortfolio();
    } catch (_) {}
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final pad = isMobile ? 16.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadPortfolio,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 20),
              _buildSummaryBanner(isMobile),
              const SizedBox(height: 20),
              // Tabs
              _buildTabBar(),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else ...[
                // Tab 0: Overview
                if (_tabController.index == 0) _buildOverviewTab(isMobile),
                // Tab 1: Projections
                if (_tabController.index == 1) _buildProjectionsTab(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  children: [
                    const TextSpan(text: 'Portfolio '),
                    TextSpan(
                      text: 'Tracker',
                      style: TextStyle(color: AppColors.getBrandPrimary(isDark)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Analyze, project, and align your investments with your goals.',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadPortfolio,
          icon: const Icon(Icons.refresh, color: AppColors.primary),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  // ─── Summary Banner (matches HTML <GlassCard> with icon + value + buttons) ─

  Widget _buildSummaryBanner(bool isMobile) {
    final annualReturn = _totalInvested > 0
        ? ((_currentValue - _totalInvested) / _totalInvested * 100)
        : 0.0;
    final valStr = _currentValue >= 10000000
        ? '₹${(_currentValue / 10000000).toStringAsFixed(1)}Cr'
        : '₹${(_currentValue / 100000).toStringAsFixed(0)}L';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            (isDark ? const Color(0xFF153C6A) : AppColors.lightPrimaryDark).withOpacity(0.40),
            (isDark ? const Color(0xFF042142) : AppColors.lightBackground).withOpacity(0.40),
          ],
        ),
        border: Border.all(
          color: AppColors.getBrandPrimary(isDark).withOpacity(0.20),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 18 : 28),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _portfolioValueSection(valStr, annualReturn),
                  const SizedBox(height: 20),
                  _bannerButtons(context),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _portfolioValueSection(valStr, annualReturn)),
                  _bannerButtons(context),
                ],
              ),
      ),
    );
  }

  Widget _portfolioValueSection(String valStr, double annReturn) {
    return Row(
      children: [
        // Briefcase icon in gradient container
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [AppColors.getBrandPrimary(isDark), (isDark ? const Color(0xFF2475AC) : AppColors.lightPrimaryDark)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.getBrandPrimary(isDark).withOpacity(0.3),
                blurRadius: 30,
              ),
            ],
          ),
          child: const Icon(Icons.work_outline_rounded,
              color: Colors.white, size: 32),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total Portfolio Value',
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500)),
            Text(
              valStr,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.trending_up,
                    size: 14, color: AppColors.getBrandPrimary(isDark)),
                const SizedBox(width: 4),
                Text(
                  '+${annReturn.toStringAsFixed(1)}% Annualized Returns',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getBrandPrimary(isDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _bannerButtons(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        OutlinedButton(
          onPressed: () => _showAddSheet(context),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.getBorder(isDark, 0.2)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add Investment',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                colors: [AppColors.getBrandPrimary(isDark), (isDark ? const Color(0xFF2475AC) : AppColors.lightPrimaryDark)],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              child: const Text('Rebalance',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: AppColors.getGlassBg(isDark, 0.05),
        border: Border.all(color: AppColors.getGlassBg(isDark, 0.1)),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient:
              LinearGradient(colors: [(isDark ? const Color(0xFF733E85) : AppColors.lightSecondary), AppColors.secondary]),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '  Holdings  '),
          Tab(text: '  Projections  '),
        ],
      ),
    );
  }

  // ─── Overview Tab ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab(bool isMobile) {
    if (_investments.isEmpty) {
      return _buildEmptyState();
    }

    if (isMobile) {
      return Column(
        children: [
          _buildPieChartCard(isMobile),
          const SizedBox(height: 20),
          _buildHoldingsList(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: _buildPieChartCard(isMobile)),
        const SizedBox(width: 24),
        Expanded(flex: 6, child: _buildHoldingsList()),
      ],
    );
  }

  Widget _buildEmptyState() {
    return GlassCard(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.pie_chart_outline,
              size: 64, color: AppColors.textTertiary.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No investments yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Tap the + button to add your first investment',
              style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(bool isMobile) {
    final total = _allocation.fold<double>(
        0, (s, e) => s + ((e['value'] as num?)?.toDouble() ?? 0));

    return GlassCard(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Asset Allocation',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          Divider(color: AppColors.getBorder(isDark, 0.1), height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (e, r) {
                    setState(() {
                      _touchedIndex = r?.touchedSection?.touchedSectionIndex;
                    });
                  },
                ),
                centerSpaceRadius: 50,
                sectionsSpace: 3,
                sections: _allocation.asMap().entries.map((entry) {
                  final i = entry.key;
                  final d = entry.value;
                  final val = (d['value'] as num?)?.toDouble() ?? 0;
                  final pct = total > 0 ? (val / total) * 100 : 0.0;
                  final type = d['type']?.toString() ?? '';
                  final isTouched = i == _touchedIndex;
                  return PieChartSectionData(
                    color: _colorForType(type, isDark),
                    value: val,
                    title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
                    radius: isTouched ? 60 : 50,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _allocation.map((d) {
              final type = d['type']?.toString() ?? '';
              final pct =
                  (d['allocation_percent'] as num?)?.toDouble() ?? 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _colorForType(type, isDark))),
                  const SizedBox(width: 5),
                  Text(
                    '${_labelForType(type)} ${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldingsList() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Your Holdings',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text('${_investments.length} assets',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
          Divider(color: AppColors.getBorder(isDark, 0.1), height: 20),
          ..._investments.map((inv) => _buildHoldingTile(inv)).toList(),
        ],
      ),
    );
  }

  Widget _buildHoldingTile(Investment inv) {
    final gainColor =
        inv.gainLossPercent >= 0 ? AppColors.success : AppColors.error;
    final typeColor = _colorForType(inv.type, isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.getGlassBg(isDark, 0.04),
          border: Border.all(color: AppColors.getBorder(isDark, 0.08)),
        ),
        child: Row(
          children: [
            // Type badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: typeColor.withOpacity(0.18),
                border: Border.all(color: typeColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  inv.name.isNotEmpty ? inv.name[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: typeColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: typeColor.withOpacity(0.12),
                        ),
                        child: Text(_labelForType(inv.type),
                            style: TextStyle(
                                fontSize: 10,
                                color: typeColor,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (inv.sipAmount != null && inv.sipAmount! > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                          child: Text(
                            'SIP ₹${(inv.sipAmount! / 1000).toStringAsFixed(0)}K/mo',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${(inv.currentValue / 100000).toStringAsFixed(1)}L',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      inv.gainLossPercent >= 0
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 11,
                      color: gainColor,
                    ),
                    Text(
                      '${inv.gainLossPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: gainColor),
                    ),
                  ],
                ),
              ],
            ),
            // Action buttons
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.textTertiary, size: 18),
              color: const Color(0xFF0d2d52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'edit') _showEditSheet(context, inv);
                if (val == 'delete') _confirmDelete(context, inv);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Edit', style: TextStyle(color: Colors.white)),
                    ])),
                PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 16, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Remove',
                          style: TextStyle(color: AppColors.error)),
                    ])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Investment inv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0d2d52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Investment?',
            style: TextStyle(color: Colors.white)),
        content: Text('This will remove "${inv.name}" from your portfolio.',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textTertiary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              _deleteInvestment(inv);
            },
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Projections Tab ──────────────────────────────────────────────────────

  Widget _buildProjectionsTab() {
    return GlassCard(
      glowColor: (isDark ? const Color(0xFF153C6A) : AppColors.lightPrimaryDark),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('10-Year Growth Projection',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Based on current portfolio + SIP contributions',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  '10.5% p.a.',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: _projectionSpots.isEmpty
                ? const Center(
                    child: Text('Add investments to see projections',
                        style: TextStyle(color: AppColors.textTertiary)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                            color: AppColors.getGlassBg(isDark, 0.05),
                            strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 55,
                            getTitlesWidget: (v, _) => Text(
                              '₹${v.toStringAsFixed(0)}L',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Text(
                              'Y${v.toInt()}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary),
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
                          spots: _projectionSpots,
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.primary,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primary.withOpacity(0.35),
                                AppColors.primary.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots
                              .map((s) => LineTooltipItem(
                                    '₹${s.y.toStringAsFixed(1)}L',
                                    const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          // Year labels
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _projectionSpots
                .where((s) => s.x > 0 && s.x.toInt() % 2 == 0)
                .map((s) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.getGlassBg(isDark, 0.05),
                  border: Border.all(color: AppColors.getGlassBg(isDark, 0.1)),
                ),
                child: Column(
                  children: [
                    Text('Year ${s.x.toInt()}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary)),
                    const SizedBox(height: 3),
                    Text('₹${s.y.toStringAsFixed(1)}L',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Add / Edit Investment Sheet ───────────────────────────────────────────

  void _showAddSheet(BuildContext context) {
    _showInvestmentSheet(context, null);
  }

  void _showEditSheet(BuildContext context, Investment inv) {
    _showInvestmentSheet(context, inv);
  }

  void _showInvestmentSheet(BuildContext context, Investment? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final symbolCtrl = TextEditingController(text: existing?.symbol ?? '');
    final amountCtrl = TextEditingController(
        text: existing?.amountInvested.toStringAsFixed(0) ?? '');
    final qtyCtrl = TextEditingController(
        text: existing?.quantity?.toStringAsFixed(0) ?? '');
    final avgPriceCtrl = TextEditingController(
        text: existing?.avgPrice?.toStringAsFixed(0) ?? '');
    final sipCtrl = TextEditingController(
        text: existing?.sipAmount?.toStringAsFixed(0) ?? '');
    // Purchase date defaults to today
    final purchaseDateCtrl = TextEditingController(
        text: existing != null ? '' :
            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().day.toString().padLeft(2,'0')}');

    String selectedType = existing?.type ?? 'mutual_fund';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: false, // CRITICAL on Flutter Web – prevents browser history nav
      builder: (sheetContext) {
        return StatefulBuilder(builder: (ctx, sheetSetState) {
          return Container(
            margin: const EdgeInsets.all(12),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0xFF0a1f3a),
              border: Border.all(color: AppColors.whiteOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 4),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.getBorder(isDark, 0.2),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(isEdit ? 'Edit Investment' : 'Add Investment',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 20),

                // Type selector
                const Text('Asset Type',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _typeLabels.entries.map((e) {
                      final isSelected = e.key == selectedType;
                      final typeColor = _colorForType(e.key, isDark);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Material(
                            color: isSelected
                                ? typeColor.withOpacity(0.2)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () => sheetSetState(
                                  () => selectedType = e.key),
                              splashColor: typeColor.withOpacity(0.3),
                              highlightColor: typeColor.withOpacity(0.1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? typeColor
                                        : AppColors.whiteOpacity(0.15),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(e.value,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? typeColor
                                          : AppColors.textTertiary,
                                    )),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),

                // Name + symbol
                Row(children: [
                  Expanded(child: _field('Name *', nameCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Symbol (e.g. TCS)', symbolCtrl)),
                ]),
                const SizedBox(height: 14),

                // Amount + SIP
                Row(children: [
                  Expanded(
                      child: _field('Amount Invested (₹)', amountCtrl,
                          isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field('Monthly SIP (₹) — optional', sipCtrl,
                          isNumber: true)),
                ]),
                const SizedBox(height: 14),

                // Quantity + avg price
                Row(children: [
                  Expanded(
                      child: _field('Qty — optional', qtyCtrl,
                          isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field('Avg Price (₹) — optional', avgPriceCtrl,
                          isNumber: true)),
                ]),
                const SizedBox(height: 14),

                // Purchase date
                _field('Purchase Date (YYYY-MM-DD)', purchaseDateCtrl),
                const SizedBox(height: 28),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Name is required'),
                              backgroundColor: AppColors.error),
                        );
                        return;
                      }
                      final payload = <String, dynamic>{
                        'type': selectedType,
                        'name': name,
                        'symbol': symbolCtrl.text.trim().isEmpty
                            ? null
                            : symbolCtrl.text.trim(),
                        'amount_invested':
                            double.tryParse(amountCtrl.text) ?? 0,
                        'sip_amount': double.tryParse(sipCtrl.text),
                        'quantity': double.tryParse(qtyCtrl.text),
                        'avg_price': double.tryParse(avgPriceCtrl.text),
                        'purchase_date': purchaseDateCtrl.text.trim().isEmpty
                            ? null
                            : purchaseDateCtrl.text.trim(),
                      };
                      Navigator.pop(ctx);
                      if (isEdit && existing.id != null) {
                        _updateInvestment(existing.id!, payload);
                      } else {
                        _addInvestment(payload);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      isEdit ? 'Update Investment' : 'Add to Portfolio',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textTertiary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.whiteOpacity(0.06),
            border: Border.all(color: AppColors.whiteOpacity(0.12)),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType:
                isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
