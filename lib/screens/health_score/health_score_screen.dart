import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../components/common/glass_card.dart';
import '../../services/api_service.dart';

class HealthScoreCategory {
  final String name;
  final IconData icon;
  final int score;
  final int maxScore;
  final Color color;
  final String description;

  HealthScoreCategory({
    required this.name,
    required this.icon,
    required this.score,
    required this.maxScore,
    required this.color,
    required this.description,
  });
}

class HealthScoreScreen extends StatefulWidget {
  const HealthScoreScreen({Key? key}) : super(key: key);

  @override
  State<HealthScoreScreen> createState() => _HealthScoreScreenState();
}

class _HealthScoreScreenState extends State<HealthScoreScreen>
    with SingleTickerProviderStateMixin {
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  late int score;
  late AnimationController _animationController;
  late Animation<double> _scoreAnimation;

  late final List<HealthScoreCategory> categories = [
    HealthScoreCategory(
      name: 'Emergency Fund',
      icon: Icons.shield_outlined,
      score: 25,
      maxScore: 25,
      color: AppColors.primary,
      description: 'Excellent! You have 6 months of expenses saved.',
    ),
    HealthScoreCategory(
      name: 'Savings Rate',
      icon: Icons.savings,
      score: 18,
      maxScore: 25,
      color: AppColors.secondary,
      description: 'Good, but try pushing savings to 35% of income.',
    ),
    HealthScoreCategory(
      name: 'Investments',
      icon: Icons.trending_up,
      score: 12,
      maxScore: 25,
      color: const Color(0xFF733E85),
      description:
          'Needs work. SIPs should be increased to reach your goal.',
    ),
    HealthScoreCategory(
      name: 'Debt & Insurance',
      icon: Icons.favorite_outline,
      score: 17,
      maxScore: 25,
      color: const Color(0xFF2475AC),
      description: 'No debt, but ensure term life coverage is adequate.',
    ),
  ];

  bool _isLoading = false;
  List<String> _suggestions = [];
  String _apiMessage = '';

  @override
  void initState() {
    super.initState();
    score = 72;
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scoreAnimation = Tween<double>(begin: 0, end: score.toDouble()).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _loadHealthScore();
  }

  Future<void> _loadHealthScore() async {
    setState(() => _isLoading = true);
    try {
      final result = await apiService.get<Map<String, dynamic>>(
        '/health-score',
        requireAuth: false,
      );
      if (result['score'] != null) {
        final newScore = (result['score'] as num).toInt();
        final cats = result['categories'] as Map<String, dynamic>? ?? {};
        final subs = <HealthScoreCategory>[];
        final catIcons = {
          'Emergency Fund': Icons.shield_outlined,
          'Savings Rate': Icons.savings,
          'Investments': Icons.trending_up,
          'Debt & Insurance': Icons.favorite_outline,
        };
        final catColors = [
          AppColors.getBrandPrimary(isDark),
          AppColors.getBrandSecondary(isDark),
          (isDark ? const Color(0xFF733E85) : AppColors.lightSecondary),
          (isDark ? const Color(0xFF2475AC) : AppColors.lightPrimaryDark),
        ];
        int ci = 0;
        cats.forEach((name, info) {
          final catData = info as Map<String, dynamic>;
          subs.add(HealthScoreCategory(
            name: name,
            icon: catIcons[name] ?? Icons.check_circle_outline,
            score: (catData['score'] as num?)?.toInt() ?? 0,
            maxScore: (catData['max'] as num?)?.toInt() ?? 25,
            color: catColors[ci++ % catColors.length],
            description: catData['status']?.toString() ?? '',
          ));
        });
        final suggestions = (result['suggestions'] as List<dynamic>? ?? [])
            .map((s) => s.toString())
            .toList();
        setState(() {
          score = newScore;
          if (subs.isNotEmpty) {
            categories
              ..clear()
              ..addAll(subs);
          }
          _suggestions = suggestions;
          _apiMessage = result['message']?.toString() ?? '';
        });
        _animationController.reset();
        _scoreAnimation =
            Tween<double>(begin: 0, end: newScore.toDouble())
                .animate(CurvedAnimation(
                    parent: _animationController, curve: Curves.easeOut));
        _animationController.forward();
      }
    } catch (_) {
      // Use fallback data silently
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _refreshScore() {
    _loadHealthScore();
  }

  String _getGrade(int s) {
    if (s >= 80) return 'A';
    if (s >= 60) return 'B';
    if (s >= 40) return 'C';
    if (s >= 20) return 'D';
    return 'F';
  }

  Color _getGradeColor(int s) {
    if (s >= 80) return AppColors.getBrandPrimary(isDark);
    if (s >= 60) return AppColors.getBrandSecondary(isDark);
    if (s >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final padding = isMobile ? 12.0 : 32.0;
    final headerFontSize = isMobile ? 24.0 : 32.0;
    final scoreCircleSize = isMobile ? 140.0 : 180.0;
    final scoreFontSize = isMobile ? 40.0 : 56.0;
    final gradeFontSize = isMobile ? 28.0 : 40.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [AppColors.getTextPrimary(isDark), AppColors.getBrandPrimary(isDark)],
                      ).createShader(bounds),
                      child: Text(
                        'Money Health Score',
                        style: TextStyle(
                          fontSize: headerFontSize,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your financial credit score',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextTertiary(isDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _refreshScore,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AppColors.getGlassBg(isDark, 0.05),
                          border: Border.all(
                            color: AppColors.getBorder(isDark, 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 14,
                              color: AppColors.getBrandPrimary(isDark),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Refresh',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.getTextPrimary(isDark),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [AppColors.getTextPrimary(isDark), AppColors.getBrandPrimary(isDark)],
                          ).createShader(bounds),
                          child: Text(
                            'Money Health Score',
                            style: TextStyle(
                              fontSize: headerFontSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your financial credit score, evaluated across 4 pillars.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextTertiary(isDark),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _refreshScore,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AppColors.getGlassBg(isDark, 0.05),
                          border: Border.all(
                            color: AppColors.getBorder(isDark, 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 16,
                              color: AppColors.getBrandPrimary(isDark),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Refresh Score',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.getTextPrimary(isDark),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          SizedBox(height: isMobile ? 20 : 32),
          // Main Score Area
          isMobile
              ? Column(
                  children: [
                    // Circular Score
                    GlassCard(
                      glowColor: AppColors.getBrandPrimary(isDark),
                      padding: EdgeInsets.all(isMobile ? 24 : 48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: scoreCircleSize,
                            height: scoreCircleSize,
                            child: AnimatedBuilder(
                              animation: _scoreAnimation,
                              builder: (context, child) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Background circle
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color:
                                              AppColors.getGlassBg(isDark, 0.1),
                                          width: 6,
                                        ),
                                      ),
                                    ),
                                    // Progress circle
                                    CustomPaint(
                                      size: Size(scoreCircleSize, scoreCircleSize),
                                      painter: CircleProgressPainter(
                                        progress: _scoreAnimation.value / 100,
                                        color: AppColors.getBrandPrimary(isDark),
                                        strokeWidth: 6,
                                      ),
                                    ),
                                    // Text
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _scoreAnimation.value
                                              .toStringAsFixed(0),
                                          style: TextStyle(
                                            fontSize: scoreFontSize,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.getTextPrimary(isDark),
                                          ),
                                        ),
                                        Text(
                                          'Out of 100',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.getTextTertiary(isDark),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          SizedBox(height: isMobile ? 16 : 24),
                          Column(
                            children: [
                            Text(
                                'Overall Grade',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.getTextTertiary(isDark),
                                ),
                              ),
                              SizedBox(height: isMobile ? 2 : 4),
                              Text(
                                'Grade ${_getGrade(score.toInt())}',
                                style: TextStyle(
                                  fontSize: gradeFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: _getGradeColor(score.toInt()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 32),
                    // Category Breakdown
                    Column(
                      children: List.generate(categories.length, (index) {
                        final category = categories[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            backgroundColor: category.color
                                .withOpacity(0.1),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            category.icon,
                                            color: category.color,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              category.name,
                                              style:
                                                  const TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${category.score}/${category.maxScore}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.getTextPrimary(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    value: category.score /
                                        category.maxScore,
                                    backgroundColor:
                                        AppColors.getTextPrimary(isDark).withOpacity(
                                            0.1),
                                    valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(category.color),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  category.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.getTextTertiary(isDark),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Circular Score
                    Expanded(
                      child: GlassCard(
                        glowColor: AppColors.getBrandPrimary(isDark),
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: AnimatedBuilder(
                                animation: _scoreAnimation,
                                builder: (context, child) {
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Background circle
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.getGlassBg(isDark, 0.1),
                                            width: 8,
                                          ),
                                        ),
                                      ),
                                      // Progress circle
                                      CustomPaint(
                                        size: const Size(180, 180),
                                        painter: CircleProgressPainter(
                                          progress: _scoreAnimation.value / 100,
                                          color: AppColors.getBrandPrimary(isDark),
                                          strokeWidth: 8,
                                        ),
                                      ),
                                      // Text
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _scoreAnimation.value
                                                .toStringAsFixed(0),
                                            style: TextStyle(
                                              fontSize: 56,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.getTextPrimary(isDark),
                                            ),
                                          ),
                                          Text(
                                            'Out of 100',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.getTextTertiary(isDark),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            Column(
                              children: [
                                Text(
                                  'Overall Grade',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.getTextTertiary(isDark),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Grade ${_getGrade(score.toInt())}',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: _getGradeColor(score.toInt()),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Category Breakdown
                    Expanded(
                      child: Column(
                        children: List.generate(categories.length, (index) {
                          final category = categories[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: category.color
                                  .withOpacity(0.1),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(
                                              category.icon,
                                              color: category.color,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                category.name,
                                                style:
                                                    const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${category.score}/${category.maxScore}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.getTextPrimary(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      minHeight: 4,
                                      value: category.score /
                                          category.maxScore,
                                      backgroundColor:
                                          AppColors.getTextPrimary(isDark).withOpacity(
                                              0.1),
                                      valueColor:
                                          AlwaysStoppedAnimation<
                                              Color>(category.color),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    category.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.getTextTertiary(isDark),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
          SizedBox(height: isMobile ? 16 : 32),
          // Recommendation
          GlassCard(
            backgroundColor: (isDark ? const Color(0xFF733E85) : AppColors.lightSecondary).withOpacity(0.1),
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isMobile ? 48 : 64,
                        height: isMobile ? 48 : 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.getBrandSecondary(isDark),
                              (isDark ? const Color(0xFF733E85) : AppColors.lightSecondary)
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.getBrandSecondary(isDark).withOpacity(0.4),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.trending_up,
                          color: AppColors.getTextPrimary(isDark),
                          size: isMobile ? 24 : 32,
                        ),
                      ),
                      SizedBox(height: isMobile ? 12 : 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Targeted Recommendation',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.getTextSecondary(isDark),
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Your weakest area is ',
                                ),
                                TextSpan(
                                  text: 'Investments (12/25)',
                                  style: TextStyle(
                                    color: AppColors.getBrandSecondary(isDark),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      '. Start an additional SIP of ₹5,000.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
              : Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.getBrandSecondary(isDark), (isDark ? const Color(0xFF733E85) : AppColors.lightSecondary)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.getBrandSecondary(isDark).withOpacity(0.4),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: AppColors.getTextPrimary(isDark),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Targeted Recommendation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.getTextSecondary(isDark),
                                height: 1.6,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'Your weakest area is ',
                                ),
                                TextSpan(
                                  text: 'Investments (12/25)',
                                  style: TextStyle(
                                    color: AppColors.getBrandSecondary(isDark),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      '. Based on your ₹1L income, having only ₹10,000 invested scores low. We recommend starting an additional SIP of ₹5,000 immediately.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.getGlassBg(isDark, 0.1),
                        border: Border.all(
                          color: AppColors.getBorder(isDark, 0.2),
                        ),
                      ),
                      child: Text(
                        'View Plan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          SizedBox(height: isMobile ? 16 : 24),
          // ── API Suggestions Panel ──────────────────────────────────────────
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.getBrandPrimary(isDark)),
              ),
            )
          else if (_suggestions.isNotEmpty) ...[
            if (_apiMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  backgroundColor: AppColors.getBrandPrimary(isDark).withOpacity(0.06),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.getBrandPrimary(isDark), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _apiMessage,
                          style: TextStyle(
                              fontSize: 14, color: AppColors.getTextSecondary(isDark), height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            GlassCard(
              backgroundColor: const Color(0xFF153C6A).withOpacity(0.3),
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: AppColors.getBrandSecondary(isDark), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Action Items',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._suggestions.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.getBrandSecondary(isDark).withOpacity(0.2),
                              border: Border.all(
                                  color: AppColors.getBrandSecondary(isDark).withOpacity(0.4)),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getBrandSecondary(isDark),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextSecondary(isDark),
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          SizedBox(height: isMobile ? 80 : 24),
        ],
      ),
    );
  }
}

class CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const startAngle = -3.14159 / 2;
    final sweepAngle = 2 * 3.14159 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
