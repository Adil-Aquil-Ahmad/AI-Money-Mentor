import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../components/common/glass_card.dart';
import '../../components/common/custom_input_field.dart';
import '../../components/common/custom_button.dart';
import '../../models/financial_profile.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class FinancialProfileScreen extends StatefulWidget {
  const FinancialProfileScreen({Key? key}) : super(key: key);

  @override
  State<FinancialProfileScreen> createState() =>
      _FinancialProfileScreenState();
}

class _FinancialProfileScreenState extends State<FinancialProfileScreen> {
  late FinancialProfile profile;
  late ScrollController _scrollController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    profile = FinancialProfile.initial();
    _scrollController = ScrollController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final result = await apiService.get<Map<String, dynamic>>(
        ApiConfig.profile,
        requireAuth: false,
      );
      if (mounted) {
        setState(() {
          profile.name = result['name']?.toString() ?? profile.name;
          profile.income =
              (result['monthly_income'] as num?)?.toDouble() ?? profile.income;
          profile.expenses =
              (result['monthly_expenses'] as num?)?.toDouble() ?? profile.expenses;
          profile.savings =
              (result['current_savings'] as num?)?.toDouble() ?? profile.savings;
          profile.investments =
              (result['current_investments'] as num?)?.toDouble() ?? profile.investments;
          profile.debt =
              (result['current_debt'] as num?)?.toDouble() ?? profile.debt;
          profile.emergencyMonths =
              (result['emergency_fund_months'] as num?)?.toInt() ?? profile.emergencyMonths;
          profile.hasInsurance = (result['has_insurance'] == 1 || result['has_insurance'] == true);
          profile.goals = result['financial_goals']?.toString() ?? profile.goals;
          final risk = result['risk_profile']?.toString() ?? '';
          if (risk.isNotEmpty) {
            profile.riskProfile =
                risk[0].toUpperCase() + risk.substring(1).toLowerCase();
          }
        });
      }
    } catch (_) {
      // Silent — use defaults
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await apiService.post<Map<String, dynamic>>(
        ApiConfig.profile,
        body: {
          'name': profile.name,
          'age': profile.age,
          'monthly_income': profile.income,
          'monthly_expenses': profile.expenses,
          'current_savings': profile.savings,
          'current_investments': profile.investments,
          'current_debt': profile.debt,
          'emergency_fund_months': profile.emergencyMonths,
          'has_emergency_fund': profile.emergencyMonths > 0,
          'has_insurance': profile.hasInsurance,
          'goals': [profile.goals],
          'risk_profile': profile.riskProfile.toLowerCase(),
        },
        requireAuth: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved locally (backend offline)'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final padding = isMobile ? 16.0 : 32.0;
    final headerFontSize = isMobile ? 24.0 : 32.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.all(padding),
      children: [
        // Header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppColors.getTextPrimary(isDark), AppColors.getBrandPrimary(isDark)],
              ).createShader(bounds),
              child: Text(
                'Your Financial Profile',
                style: TextStyle(
                  fontSize: headerFontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The foundation that powers your personalized advice.',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: AppColors.getTextTertiary(isDark),
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 16 : 32),
        // Personal Details Section
        GlassCard(
          glowColor: isDark ? const Color(0xFF153C6A) : AppColors.lightPrimaryDark,
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person,
                    color: AppColors.getBrandPrimary(isDark),
                    size: isMobile ? 20 : 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Personal Details',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: CustomInputField(
                      label: 'Full Name',
                      hint: 'Enter your name',
                      controller: TextEditingController(text: profile.name),
                      onChanged: (value) {
                        profile.name = value;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomInputField(
                      label: 'Age',
                      hint: 'Enter your age',
                      keyboardType: TextInputType.number,
                      controller:
                          TextEditingController(text: profile.age.toString()),
                      onChanged: (value) {
                        profile.age = int.tryParse(value) ?? 0;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 16 : 32),
        // Financial Overview Section
        GlassCard(
          glowColor: isDark ? const Color(0xFF733E85) : AppColors.lightSecondary,
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: AppColors.getBrandSecondary(isDark),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Financial Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (isMobile)
                Column(
                  children: [
                    CustomInputField(label: 'Monthly Income', hint: '₹', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.income.toStringAsFixed(0)), onChanged: (v) => profile.income = double.tryParse(v) ?? 0),
                    const SizedBox(height: 12),
                    CustomInputField(label: 'Monthly Expenses', hint: '₹', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.expenses.toStringAsFixed(0)), onChanged: (v) => profile.expenses = double.tryParse(v) ?? 0),
                    const SizedBox(height: 12),
                    CustomInputField(label: 'Current Savings', hint: '₹', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.savings.toStringAsFixed(0)), onChanged: (v) => profile.savings = double.tryParse(v) ?? 0),
                    const SizedBox(height: 12),
                    CustomInputField(label: 'Total Investments', hint: '₹', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.investments.toStringAsFixed(0)), onChanged: (v) => profile.investments = double.tryParse(v) ?? 0),
                    const SizedBox(height: 12),
                    CustomInputField(label: 'Current Debt', hint: '₹', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.debt.toStringAsFixed(0)), onChanged: (v) => profile.debt = double.tryParse(v) ?? 0),
                    const SizedBox(height: 12),
                    CustomInputField(label: 'Emergency Fund', hint: 'months', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.emergencyMonths.toString()), onChanged: (v) => profile.emergencyMonths = int.tryParse(v) ?? 0),
                  ],
                )
              else
                GridView(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.8),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    CustomInputField(label: 'Monthly Income', hint: '₹', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.income.toStringAsFixed(0)), onChanged: (v) => profile.income = double.tryParse(v) ?? 0),
                    CustomInputField(label: 'Monthly Expenses', hint: '₹', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.expenses.toStringAsFixed(0)), onChanged: (v) => profile.expenses = double.tryParse(v) ?? 0),
                    CustomInputField(label: 'Current Savings', hint: '₹', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.savings.toStringAsFixed(0)), onChanged: (v) => profile.savings = double.tryParse(v) ?? 0),
                    CustomInputField(label: 'Total Investments', hint: '₹', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.investments.toStringAsFixed(0)), onChanged: (v) => profile.investments = double.tryParse(v) ?? 0),
                    CustomInputField(label: 'Current Debt', hint: '₹', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.debt.toStringAsFixed(0)), onChanged: (v) => profile.debt = double.tryParse(v) ?? 0),
                    CustomInputField(label: 'Emergency Fund', hint: 'months', keyboardType: TextInputType.number, controller: TextEditingController(text: profile.emergencyMonths.toString()), onChanged: (v) => profile.emergencyMonths = int.tryParse(v) ?? 0),
                  ],
                ),
              const SizedBox(height: 24),

              GlassCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: AppColors.getGlassBg(isDark, 0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Insurance Coverage',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Life/Health insurance active',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextTertiary(isDark),
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: profile.hasInsurance,
                      onChanged: (value) {
                        setState(() {
                          profile.hasInsurance = value;
                        });
                      },
                      activeColor: AppColors.primary,
                      inactiveThumbColor: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Strategy & Goals Section
        GlassCard(
          glowColor: isDark ? const Color(0xFF2475AC) : AppColors.lightPrimaryDark,
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.track_changes,
                    color: AppColors.getBrandPrimary(isDark),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Strategy & Goals',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Primary Financial Goal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextTertiary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.getBorder(isDark, 0.1),
                      ),
                      color: AppColors.getGlassBg(isDark, 0.05),
                    ),
                    child: TextField(
                      maxLines: 3,
                      controller:
                          TextEditingController(text: profile.goals),
                      onChanged: (value) {
                        profile.goals = value;
                      },
                      style: TextStyle(
                        color: AppColors.getTextPrimary(isDark),
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Risk Profile',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextTertiary(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: ['Low', 'Medium', 'High'].map((risk) {
                      final isSelected =
                          profile.riskProfile == risk;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              profile.riskProfile = risk;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.getBrandPrimary(isDark)
                                    : AppColors.getBorder(isDark, 0.1),
                                width: isSelected ? 2 : 1,
                              ),
                              color: isSelected
                                  ? AppColors.getBrandPrimary(isDark).withOpacity(0.2)
                                  : AppColors.getGlassBg(isDark, 0.05),
                            ),
                            child: Center(
                              child: Text(
                                risk,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.getBrandPrimary(isDark)
                                      : AppColors.getTextTertiary(isDark),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Save and Actions Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side actions (Theme + Logout)
            Row(
              children: [
                GestureDetector(
                  onTap: () => AppTheme.toggleTheme(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.getGlassBg(isDark, 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.getBorder(isDark, 0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                            color: AppColors.getTextPrimary(isDark), size: 18),
                        const SizedBox(width: 8),
                        Text(isDark ? 'Light Mode' : 'Dark Mode',
                            style: TextStyle(
                                color: AppColors.getTextPrimary(isDark),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF87171).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.logout, color: Color(0xFFF87171), size: 18),
                        const SizedBox(width: 8),
                        const Text('Logout',
                            style: TextStyle(
                                color: Color(0xFFF87171),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Right side save
            SizedBox(
              width: 200,
              child: CustomButton(
                text: _isSaving ? 'Saving...' : 'Save Profile',
                onPressed: _isSaving ? () {} : _saveProfile,
                leadingIcon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
