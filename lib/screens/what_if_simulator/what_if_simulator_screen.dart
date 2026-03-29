import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../theme/app_colors.dart';
import '../../components/common/glass_card.dart';
import '../../services/api_service.dart';

// ─── Scenario definitions ─────────────────────────────────────────────────────
enum SimScenario { sipGrowth, lumpsum, expenseCut, loanPrepay }

extension ScenarioExt on SimScenario {
  String get apiKey {
    switch (this) {
      case SimScenario.sipGrowth: return 'sip_growth';
      case SimScenario.lumpsum: return 'lumpsum';
      case SimScenario.expenseCut: return 'expense_cut';
      case SimScenario.loanPrepay: return 'loan_prepay';
    }
  }

  String get label {
    switch (this) {
      case SimScenario.sipGrowth: return 'SIP Growth';
      case SimScenario.lumpsum: return 'Lumpsum';
      case SimScenario.expenseCut: return 'Expense Cut';
      case SimScenario.loanPrepay: return 'Loan Prepay';
    }
  }

  IconData get icon {
    switch (this) {
      case SimScenario.sipGrowth: return Icons.trending_up;
      case SimScenario.lumpsum: return Icons.savings_outlined;
      case SimScenario.expenseCut: return Icons.content_cut_outlined;
      case SimScenario.loanPrepay: return Icons.account_balance_outlined;
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class WhatIfSimulatorScreen extends StatefulWidget {
  const WhatIfSimulatorScreen({Key? key}) : super(key: key);

  @override
  State<WhatIfSimulatorScreen> createState() => _WhatIfSimulatorScreenState();
}

class _WhatIfSimulatorScreenState extends State<WhatIfSimulatorScreen> {
  SimScenario _scenario = SimScenario.sipGrowth;
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _insight;
  String? _title;
  List<Map<String, dynamic>> _chartData = [];

  @override
  void initState() {
    super.initState();
    _localSimulate();
  }

  double _monthlySip = 10000;
  double _duration = 10;
  double _returnRate = 12;
  double _lumpsum = 500000;
  double _expenseCut = 5000;
  double _loanAmount = 1000000;
  double _loanRate = 10;
  double _loanTenure = 20;
  double _extraEmi = 5000;

  Future<void> _simulate() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _chartData = [];
    });

    final payload = <String, dynamic>{
      'scenario_type': _scenario.apiKey,
      'monthly_amount': _monthlySip,
      'duration_years': _duration.toInt(),
      'expected_return': _returnRate,
      'lumpsum_amount': _lumpsum,
      'expense_reduction': _expenseCut,
      'loan_amount': _loanAmount,
      'loan_rate': _loanRate,
      'extra_emi': _extraEmi,
    };

    try {
      final res = await apiService.post<Map<String, dynamic>>(
        '/whatif',
        body: payload,
        requireAuth: false,
      ).timeout(const Duration(seconds: 2));
      _applyResult(res);
    } catch (_) {
      _localSimulate();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyResult(Map<String, dynamic> res) {
    final yearly = (res['yearly'] as List<dynamic>? ?? [])
        .map((y) => y as Map<String, dynamic>)
        .toList();
    setState(() {
      _result = res['result'] as Map<String, dynamic>?;
      _insight = res['insight']?.toString();
      _title = res['title']?.toString();
      _chartData = yearly;
    });
  }

  void _localSimulate() {
    final n = _duration.toInt() * 12;
    final r = _returnRate / 100 / 12;
    final List<Map<String, dynamic>> data = [];

    if (_scenario == SimScenario.sipGrowth) {
      final sip = _monthlySip;
      for (int y = 0; y <= _duration.toInt(); y++) {
        final m = y * 12;
        double val = r > 0 && m > 0
            ? sip * (math.pow(1 + r, m) - 1) / r * (1 + r)
            : sip.toDouble() * m;
        data.add({'year': y, 'invested': (sip * m).round(), 'value': val.round()});
      }
      final fv = r > 0
          ? sip * (math.pow(1 + r, n) - 1) / r * (1 + r)
          : sip * n;
      setState(() {
        _result = {
          'total_invested': (sip * n).round(),
          'final_value': fv.round(),
          'wealth_gained': (fv - sip * n).round(),
          'return_multiple': sip * n > 0 ? (fv / (sip * n)).toStringAsFixed(2) : '0',
        };
        _insight = 'Your ₹${sip.round()}/month SIP could grow significantly over ${_duration.toInt()} years.';
        _title = 'What if you invest ₹${sip.round()}/month for ${_duration.toInt()} years?';
        _chartData = data;
      });
    } else if (_scenario == SimScenario.lumpsum) {
      final ann = _returnRate / 100;
      for (int y = 0; y <= _duration.toInt(); y++) {
        final val = _lumpsum * math.pow(1 + ann, y);
        data.add({'year': y, 'invested': _lumpsum.round(), 'value': val.round()});
      }
      final fv = _lumpsum * math.pow(1 + ann, _duration.toInt());
      setState(() {
        _result = {
          'invested': _lumpsum.round(),
          'final_value': fv.round(),
          'wealth_gained': (fv - _lumpsum).round(),
          'return_multiple': (_lumpsum > 0 ? fv / _lumpsum : 0).toStringAsFixed(2),
        };
        _insight = 'Your ₹${_lumpsum.round()} could grow over ${_duration.toInt()} years.';
        _title = 'What if you invest ₹${_lumpsum.round()} as lumpsum for ${_duration.toInt()} years?';
        _chartData = data;
      });
    } else if (_scenario == SimScenario.expenseCut) {
      final cut = _expenseCut;
      for (int y = 0; y <= _duration.toInt(); y++) {
        final m = y * 12;
        double val = r > 0 && m > 0
            ? cut * (math.pow(1 + r, m) - 1) / r * (1 + r)
            : cut.toDouble() * m;
        data.add({'year': y, 'invested': (cut * m).round(), 'value': val.round()});
      }
      final fv = r > 0 ? cut * (math.pow(1 + r, n) - 1) / r * (1 + r) : cut * n;
      setState(() {
        _result = {
          'monthly_savings': cut.round(),
          'total_saved': (cut * n).round(),
          'invested_value': fv.round(),
          'extra_wealth': (fv - cut * n).round(),
        };
        _insight = 'Cutting just ₹${cut.round()}/month and investing it could build ₹${fv.round()} over ${_duration.toInt()} years.';
        _title = 'What if you cut ₹${cut.round()}/month and invest it?';
        _chartData = data;
      });
    } else if (_scenario == SimScenario.loanPrepay) {
      final principal = _loanAmount;
      final monthlyRate = _loanRate / 100 / 12;
      final extra = _extraEmi;
      final maxMonths = _loanTenure.toInt() * 12;

      double emi = monthlyRate > 0 
          ? principal * monthlyRate * math.pow(1 + monthlyRate, maxMonths) / (math.pow(1 + monthlyRate, maxMonths) - 1)
          : principal / maxMonths;

      double balance1 = principal;
      double normalInterest = 0;
      for (int i = 0; i < maxMonths; i++) {
        if (balance1 <= 0) break;
        double interest = balance1 * monthlyRate;
        normalInterest += interest;
        balance1 = balance1 + interest - emi;
      }

      double balance2 = principal;
      double newInterest = 0;
      int newMonths = 0;
      while (balance2 > 0 && newMonths < 600) {
        double interest = balance2 * monthlyRate;
        newInterest += interest;
        double payment = math.min(emi + extra, balance2 + interest);
        balance2 = balance2 + interest - payment;
        newMonths++;
      }

      final savedInterest = normalInterest - newInterest;
      final savedMonths = maxMonths - newMonths;

      setState(() {
        _result = {
          'original_tenure': '$maxMonths months (${maxMonths ~/ 12} years)',
          'new_tenure': '$newMonths months (${newMonths ~/ 12} years ${newMonths % 12} months)',
          'months_saved': savedMonths,
          'interest_saved': savedInterest.round(),
          'original_total_interest': normalInterest.round(),
        };
        _insight = 'Adding ₹${extra.round()}/month extra could save you ₹${savedInterest.round()} in interest and close your loan $savedMonths months earlier!';
        _title = 'What if you pay ₹${extra.round()} extra on your loan?';
        _chartData = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final pad = isMobile ? 16.0 : 32.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 24),
          isMobile
              ? Column(
                  children: [
                    _buildControlsPanel(isMobile, isDark),
                    const SizedBox(height: 20),
                    _buildResultsPanel(isMobile, isDark),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 340,
                        child: _buildControlsPanel(isMobile, isDark)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildResultsPanel(isMobile, isDark)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final brandPrimary = AppColors.getBrandPrimary(isDark);
    final brandGradient = AppColors.getBrandGradient(isDark);

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: brandGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: brandPrimary.withOpacity(0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(Icons.help_outline_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (b) => LinearGradient(
                colors: [AppColors.getTextPrimary(isDark), brandPrimary],
              ).createShader(b),
              child: Text(
                'What-If Simulator',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark)),
              ),
            ),
            Text(
              'Test financial decisions before committing to them.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.getTextTertiary(isDark)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlsPanel(bool isMobile, bool isDark) {
    final brandPrimary = AppColors.getBrandPrimary(isDark);
    final brandGradient = AppColors.getBrandGradient(isDark);

    return GlassCard(
      glowColor: isDark ? const Color(0xFF153C6A) : AppColors.lightPrimaryDark,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: brandPrimary, size: 20),
              const SizedBox(width: 8),
              Text('Scenario',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(isDark))),
            ],
          ),
          Divider(color: AppColors.getBorder(isDark, 0.1), height: 24),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SimScenario.values.map((s) {
              final isSel = _scenario == s;
              return GestureDetector(
                onTap: () => setState(() {
                  _scenario = s;
                  _result = null;
                  _chartData = [];
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: isSel
                        ? LinearGradient(colors: brandGradient)
                        : null,
                    color: isSel
                        ? null
                        : AppColors.getGlassBg(isDark, 0.06),
                    border: Border.all(
                      color: isSel
                          ? Colors.transparent
                          : AppColors.getBorder(isDark, 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.icon,
                          size: 14,
                          color: isSel
                              ? Colors.white
                              : AppColors.getTextTertiary(isDark)),
                      const SizedBox(width: 6),
                      Text(s.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isSel
                                  ? Colors.white
                                  : AppColors.getTextTertiary(isDark))),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          ..._buildScenarioInputs(isDark),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _simulate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ).copyWith(
                backgroundColor:
                    WidgetStateProperty.resolveWith((_) => null),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: brandGradient),
                  boxShadow: [
                    BoxShadow(
                      color: brandPrimary.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text('Simulate Outcome',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScenarioInputs(bool isDark) {
    switch (_scenario) {
      case SimScenario.sipGrowth:
        return [
          _slider('Monthly SIP Amount', _monthlySip, 1000, 500000, '₹',
              (v) => setState(() => _monthlySip = v), isDark),
          const SizedBox(height: 16),
          _slider('Investment Duration', _duration, 1, 40, ' Yrs',
              (v) => setState(() => _duration = v), isDark, divisions: 39),
          const SizedBox(height: 16),
          _slider('Expected Annual Return', _returnRate, 4, 30, '%',
              (v) => setState(() => _returnRate = v), isDark, divisions: 52),
        ];
      case SimScenario.lumpsum:
        return [
          _slider('Lumpsum Amount', _lumpsum, 10000, 10000000, '₹',
              (v) => setState(() => _lumpsum = v), isDark),
          const SizedBox(height: 16),
          _slider('Investment Duration', _duration, 1, 40, ' Yrs',
              (v) => setState(() => _duration = v), isDark, divisions: 39),
          const SizedBox(height: 16),
          _slider('Expected Annual Return', _returnRate, 4, 30, '%',
              (v) => setState(() => _returnRate = v), isDark, divisions: 52),
        ];
      case SimScenario.expenseCut:
        return [
          _slider('Monthly Expense Cut', _expenseCut, 500, 100000, '₹',
              (v) => setState(() => _expenseCut = v), isDark),
          const SizedBox(height: 16),
          _slider('Investment Duration', _duration, 1, 40, ' Yrs',
              (v) => setState(() => _duration = v), isDark, divisions: 39),
          const SizedBox(height: 16),
          _slider('Expected Annual Return', _returnRate, 4, 30, '%',
              (v) => setState(() => _returnRate = v), isDark, divisions: 52),
        ];
      case SimScenario.loanPrepay:
        return [
          _slider('Loan Amount', _loanAmount, 100000, 10000000, '₹',
              (v) => setState(() => _loanAmount = v), isDark),
          const SizedBox(height: 16),
          _slider('Loan Interest Rate', _loanRate, 5, 24, '%',
              (v) => setState(() => _loanRate = v), isDark, divisions: 38),
          const SizedBox(height: 16),
          _slider('Loan Tenure', _loanTenure, 1, 30, ' Yrs',
              (v) => setState(() => _loanTenure = v), isDark, divisions: 29),
          const SizedBox(height: 16),
          _slider('Extra EMI / Month', _extraEmi, 500, 100000, '₹',
              (v) => setState(() => _extraEmi = v), isDark),
        ];
    }
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    String suffix,
    ValueChanged<double> onChange,
    bool isDark, {
    int divisions = 100,
  }) {
    final brandPrimary = AppColors.getBrandPrimary(isDark);
    String display;
    if (suffix == '₹') {
      if (value >= 100000) {
        display = '₹${(value / 100000).toStringAsFixed(1)}L';
      } else {
        display = '₹${value.round()}';
      }
    } else if (suffix == '%') {
      display = '${value.toStringAsFixed(1)}%';
    } else {
      display = '${value.round()}$suffix';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: AppColors.getTextTertiary(isDark))),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: brandPrimary.withOpacity(0.12),
              ),
              child: Text(display,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: brandPrimary)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: brandPrimary,
            inactiveTrackColor: AppColors.getGlassBg(isDark, 0.08),
            thumbColor: isDark ? Colors.white : AppColors.lightBackground,
            overlayColor: brandPrimary.withOpacity(0.2),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChange,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsPanel(bool isMobile, bool isDark) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(64),
          child: CircularProgressIndicator(color: AppColors.getBrandPrimary(isDark)),
        ),
      );
    }

    if (_result == null) {
      return _buildEmptyState(isDark);
    }

    return Column(
      children: [
        _buildResultCards(isDark),
        const SizedBox(height: 20),
        if (_chartData.isNotEmpty) _buildChart(isMobile, isDark),
        if (_insight != null) ...[
          const SizedBox(height: 16),
          _buildInsightCard(isDark),
        ],
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final brandPrimary = AppColors.getBrandPrimary(isDark);
    return GlassCard(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.getGlassBg(isDark, 0.04),
            ),
            child: Icon(Icons.tune,
                size: 36, color: AppColors.getTextTertiary(isDark)),
          ),
          const SizedBox(height: 20),
          Text('Ready to Simulate',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 10),
          Text(
            'Adjust the variables on the left and hit\n'
            '"Simulate Outcome" to see your results.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 14, color: AppColors.getTextTertiary(isDark)),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _simulate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Run Default Simulation',
                    style: TextStyle(
                        fontSize: 14,
                        color: brandPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brandPrimary.withOpacity(0.15),
                    border: Border.all(
                        color: brandPrimary.withOpacity(0.4)),
                  ),
                  child: Icon(Icons.arrow_forward,
                      size: 14, color: brandPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCards(bool isDark) {
    final cards = _getResultCards();
    return GridView.count(
      crossAxisCount: cards.length == 4 ? 2 : 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: cards
          .map((c) => _resultCard(c['label']!, c['value']!, c['color']!, isDark))
          .toList(),
    );
  }

  List<Map<String, String>> _getResultCards() {
    if (_result == null) return [];
    final r = _result!;

    switch (_scenario) {
      case SimScenario.sipGrowth:
        return [
          {'label': 'Total Invested', 'value': _fmt(r['total_invested']), 'color': '#94A3B8'},
          {'label': 'Wealth Gained', 'value': _fmt(r['wealth_gained']), 'color': '#E977F5'},
          {'label': 'Final Value', 'value': _fmt(r['final_value']), 'color': '#3DE0FC'},
          {'label': 'Return Multiple', 'value': '${r['return_multiple']}×', 'color': '#10B981'},
        ];
      case SimScenario.lumpsum:
        return [
          {'label': 'Amount Invested', 'value': _fmt(r['invested']), 'color': '#94A3B8'},
          {'label': 'Wealth Gained', 'value': _fmt(r['wealth_gained']), 'color': '#E977F5'},
          {'label': 'Final Value', 'value': _fmt(r['final_value']), 'color': '#3DE0FC'},
          {'label': 'Return Multiple', 'value': '${r['return_multiple']}×', 'color': '#10B981'},
        ];
      case SimScenario.expenseCut:
        return [
          {'label': 'Monthly Savings', 'value': _fmt(r['monthly_savings']), 'color': '#94A3B8'},
          {'label': 'Total Saved', 'value': _fmt(r['total_saved']), 'color': '#E977F5'},
          {'label': 'Invested Value', 'value': _fmt(r['invested_value']), 'color': '#3DE0FC'},
        ];
      case SimScenario.loanPrepay:
        return [
          {'label': 'Interest Saved', 'value': _fmt(r['interest_saved']), 'color': '#10B981'},
          {'label': 'Months Saved', 'value': '${r['months_saved']} mo', 'color': '#3DE0FC'},
          {'label': 'Original Tenure', 'value': r['original_tenure']?.toString() ?? '—', 'color': '#94A3B8'},
          {'label': 'New Tenure', 'value': r['new_tenure']?.toString() ?? '—', 'color': '#E977F5'},
        ];
    }
  }

  String _fmt(dynamic val) {
    if (val == null) return '—';
    final n = val is num ? val.toDouble() : double.tryParse('$val') ?? 0;
    if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(2)}Cr';
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(2)}L';
    if (n >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
    return '₹${n.round()}';
  }

  Widget _resultCard(String label, String value, String hexColor, bool isDark) {
    final color = _hexColor(hexColor);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            width: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: color,
            ),
          ),
          const Spacer(),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: AppColors.getTextTertiary(isDark))),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    final str = hex.replaceFirst('#', '');
    return Color(int.parse('FF$str', radix: 16));
  }

  Widget _buildChart(bool isMobile, bool isDark) {
    final brandPrimary = AppColors.getBrandPrimary(isDark);
    final investedSpots = <BarChartGroupData>[];
    final allValues = _chartData
        .map((d) => (d['value'] as num?)?.toDouble() ?? 0)
        .toList();
    final maxY = allValues.isEmpty ? 1.0 : allValues.reduce((a, b) => a > b ? a : b) * 1.15;

    for (int i = 0; i < _chartData.length; i++) {
      final d = _chartData[i];
      final inv = (d['invested'] as num?)?.toDouble() ?? 0;
      final val = (d['value'] as num?)?.toDouble() ?? 0;
      investedSpots.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: inv,
              color: const Color(0xFF64748B),
              width: isMobile ? 8 : 14,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            BarChartRodData(
              toY: val,
              color: brandPrimary,
              width: isMobile ? 8 : 14,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      glowColor: brandPrimary,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(children: [
                  Icon(Icons.bar_chart_rounded,
                      color: brandPrimary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _title ?? 'Growth Over Time',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(isDark)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(const Color(0xFF64748B), 'Invested', isDark),
              const SizedBox(width: 16),
              _legendDot(brandPrimary, 'Total Value', isDark),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.getBorder(isDark, 0.05),
                      strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (v, _) => Text(
                        v >= 100000
                            ? '₹${(v / 100000).toStringAsFixed(0)}L'
                            : '₹${v.round()}',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.getTextTertiary(isDark)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i >= _chartData.length) return const Text('');
                        return Text(
                          'Y${_chartData[i]['year']}',
                          style: TextStyle(
                              fontSize: 9,
                              color: AppColors.getTextTertiary(isDark)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: investedSpots,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      rod.toY >= 100000
                          ? '₹${(rod.toY / 100000).toStringAsFixed(1)}L'
                          : '₹${rod.toY.round()}',
                      TextStyle(
                          color: AppColors.getTextPrimary(isDark),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: AppColors.getTextTertiary(isDark))),
      ],
    );
  }

  Widget _buildInsightCard(bool isDark) {
    final brandPrimary = AppColors.getBrandPrimary(isDark);
    
    return GlassCard(
      backgroundColor: brandPrimary.withOpacity(0.06),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brandPrimary.withOpacity(0.15),
              border: Border.all(
                  color: brandPrimary.withOpacity(0.3)),
            ),
            child: Icon(Icons.insights,
                size: 18, color: brandPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Insight',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: brandPrimary)),
                const SizedBox(height: 6),
                Text(_insight!,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(isDark),
                        height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
