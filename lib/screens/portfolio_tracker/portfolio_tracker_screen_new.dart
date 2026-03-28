import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../components/common/glass_card.dart';
import '../../utils/responsive_design.dart';

class PortfolioItem {
  final String name;
  final double value;
  final Color color;

  PortfolioItem({
    required this.name,
    required this.value,
    required this.color,
  });
}

class PortfolioTrackerScreen extends StatefulWidget {
  const PortfolioTrackerScreen({Key? key}) : super(key: key);

  @override
  State<PortfolioTrackerScreen> createState() =>
      _PortfolioTrackerScreenState();
}

class _PortfolioTrackerScreenState extends State<PortfolioTrackerScreen> {
  bool _isOverview = true;

  final List<PortfolioItem> portfolioData = [
    PortfolioItem(
      name: 'Equity Mutual Funds',
      value: 650000,
      color: AppColors.primary,
    ),
    PortfolioItem(
      name: 'Direct Stocks',
      value: 250000,
      color: AppColors.secondary,
    ),
    PortfolioItem(
      name: 'Fixed Deposits',
      value: 400000,
      color: Color(0xFF733E85),
    ),
    PortfolioItem(
      name: 'Gold/SGBs',
      value: 150000,
      color: Color(0xFF2475AC),
    ),
    PortfolioItem(
      name: 'EPF/PPF',
      value: 350000,
      color: Color(0xFF153C6A),
    ),
  ];

  final double totalValue = 1800000;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveDesign.isMobile(context);
    final padding = ResponsiveDesign.getPadding(context);
    final headerFontSize = ResponsiveDesign.getHeaderFontSize(context);
    final spacingMajor = ResponsiveDesign.getSpacingMajor(context);
    final spacingMedium = ResponsiveDesign.getSpacingMedium(context);
    final chartHeight = ResponsiveDesign.getChartHeight(context) * 0.9;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (isMobile)
            _buildMobileHeader(headerFontSize, spacingMedium)
          else
            _buildDesktopHeader(headerFontSize, spacingMedium),
          SizedBox(height: spacingMajor),
          // Content
          if (_isOverview)
            _buildOverviewContent(isMobile, spacingMajor, spacingMedium, chartHeight)
          else
            _buildProjectionsContent(isMobile, spacingMajor, spacingMedium, chartHeight),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(double headerFontSize, double spacingMedium) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.white, AppColors.secondary],
          ).createShader(bounds),
          child: Text(
            'Portfolio Tracker',
            style: TextStyle(
              fontSize: headerFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(height: spacingMedium),
        const Text(
          'Analyze and align investments with your goals',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: spacingMedium),
        Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: AppColors.whiteOpacity(0.05),
              border: Border.all(
                color: AppColors.whiteOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabButton('Overview', 0),
                _buildTabButton('Projections', 1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(double headerFontSize, double spacingMedium) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.white, AppColors.secondary],
              ).createShader(bounds),
              child: Text(
                'Portfolio Tracker',
                style: TextStyle(
                  fontSize: headerFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(height: spacingMedium),
            const Text(
              'Analyze and align investments with your goals',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textTertiary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: AppColors.whiteOpacity(0.05),
            border: Border.all(
              color: AppColors.whiteOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabButton('Overview', 0),
              _buildTabButton('Projections', 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewContent(bool isMobile, double spacingMajor, double spacingMedium, double chartHeight) {
    return Column(
      children: [
        // Total Portfolio Card
        GlassCard(
          glowColor: AppColors.primary,
          padding: EdgeInsets.all(spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Portfolio Value',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: spacingMedium),
              Text(
                '₹${(totalValue / 1000000).toStringAsFixed(2)}M',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: spacingMedium),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: AppColors.whiteOpacity(0.1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacingMajor),
        // Allocation Grid
        GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 2 : 3,
            crossAxisSpacing: spacingMedium,
            mainAxisSpacing: spacingMedium,
            childAspectRatio: 1.0,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: portfolioData.map((item) {
            final percentage = (item.value / totalValue) * 100;
            return GlassCard(
              backgroundColor: item.color.withOpacity(0.1),
              padding: EdgeInsets.all(spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.color.withOpacity(0.2),
                    ),
                    child: Icon(
                      Icons.trending_up,
                      color: item.color,
                      size: 16,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProjectionsContent(bool isMobile, double spacingMajor, double spacingMedium, double chartHeight) {
    return GlassCard(
      glowColor: AppColors.secondary,
      padding: EdgeInsets.all(spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Projection',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: spacingMedium),
          Container(
            height: chartHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.whiteOpacity(0.05),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 64,
                    color: AppColors.secondary.withOpacity(0.3),
                  ),
                  SizedBox(height: spacingMedium),
                  const Text(
                    'Portfolio Growth Chart',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = (index == 0 && _isOverview) ||
        (index == 1 && !_isOverview);

    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isOverview = index == 0;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isActive
                ? AppColors.whiteOpacity(0.15)
                : Colors.transparent,
            border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? AppColors.primary
                  : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
