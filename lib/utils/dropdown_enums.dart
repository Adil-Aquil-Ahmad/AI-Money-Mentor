/// Type-safe enum and dropdown utility classes
/// Used throughout the app for dropdown selections with proper typecasting

// Risk Tolerance Options
enum RiskTolerance {
  low,
  medium,
  high,
}

extension RiskToleranceExtension on RiskTolerance {
  String get displayName {
    switch (this) {
      case RiskTolerance.low:
        return 'Low';
      case RiskTolerance.medium:
        return 'Medium';
      case RiskTolerance.high:
        return 'High';
    }
  }

  String get apiValue {
    return displayName.toLowerCase();
  }

  static RiskTolerance fromString(String value) {
    return RiskTolerance.values.firstWhere(
      (e) => e.apiValue == value.toLowerCase(),
      orElse: () => RiskTolerance.medium,
    );
  }

  static List<String> getDisplayNames() {
    return RiskTolerance.values.map((e) => e.displayName).toList();
  }
}

// Investment Goals Options
enum InvestmentGoal {
  homeOwnership,
  retirement,
  childEducation,
  vehiclePurchase,
  businessStartup,
  vacationTrip,
  wealthAccumulation,
  debtRepayment,
}

extension InvestmentGoalExtension on InvestmentGoal {
  String get displayName {
    switch (this) {
      case InvestmentGoal.homeOwnership:
        return 'Home Ownership';
      case InvestmentGoal.retirement:
        return 'Retirement';
      case InvestmentGoal.childEducation:
        return 'Child Education';
      case InvestmentGoal.vehiclePurchase:
        return 'Vehicle Purchase';
      case InvestmentGoal.businessStartup:
        return 'Business Startup';
      case InvestmentGoal.vacationTrip:
        return 'Vacation Trip';
      case InvestmentGoal.wealthAccumulation:
        return 'Wealth Accumulation';
      case InvestmentGoal.debtRepayment:
        return 'Debt Repayment';
    }
  }

  String get apiValue {
    return displayName.replaceAll(' ', '_').toLowerCase();
  }

  static InvestmentGoal fromString(String value) {
    return InvestmentGoal.values.firstWhere(
      (e) => e.displayName.replaceAll(' ', '_').toLowerCase() ==
          value.replaceAll(' ', '_').toLowerCase(),
      orElse: () => InvestmentGoal.retirement,
    );
  }

  static List<String> getDisplayNames() {
    return InvestmentGoal.values.map((e) => e.displayName).toList();
  }
}

// Investment Categories
enum AssetCategory {
  stock,
  mutualFund,
  crypto,
  bond,
  realEstate,
  commodity,
  fixedDeposit,
}

extension AssetCategoryExtension on AssetCategory {
  String get displayName {
    switch (this) {
      case AssetCategory.stock:
        return 'Stock';
      case AssetCategory.mutualFund:
        return 'Mutual Fund';
      case AssetCategory.crypto:
        return 'Cryptocurrency';
      case AssetCategory.bond:
        return 'Bond';
      case AssetCategory.realEstate:
        return 'Real Estate';
      case AssetCategory.commodity:
        return 'Commodity';
      case AssetCategory.fixedDeposit:
        return 'Fixed Deposit';
    }
  }

  String get apiValue {
    return displayName.replaceAll(' ', '_').toLowerCase();
  }

  static AssetCategory fromString(String value) {
    return AssetCategory.values.firstWhere(
      (e) => e.apiValue == value.toLowerCase(),
      orElse: () => AssetCategory.stock,
    );
  }

  static List<String> getDisplayNames() {
    return AssetCategory.values.map((e) => e.displayName).toList();
  }
}

// What-If Scenario Options
enum WhatIfScenario {
  increaseSavings,
  lowerExpenses,
  higherReturns,
  lowerInflation,
  delayedRetirement,
  additionalIncome,
}

extension WhatIfScenarioExtension on WhatIfScenario {
  String get displayName {
    switch (this) {
      case WhatIfScenario.increaseSavings:
        return 'Increase Savings';
      case WhatIfScenario.lowerExpenses:
        return 'Lower Expenses';
      case WhatIfScenario.higherReturns:
        return 'Higher Returns';
      case WhatIfScenario.lowerInflation:
        return 'Lower Inflation';
      case WhatIfScenario.delayedRetirement:
        return 'Delayed Retirement';
      case WhatIfScenario.additionalIncome:
        return 'Additional Income';
    }
  }

  String get apiValue {
    return displayName.replaceAll(' ', '_').toLowerCase();
  }

  static WhatIfScenario fromString(String value) {
    return WhatIfScenario.values.firstWhere(
      (e) => e.apiValue == value.toLowerCase(),
      orElse: () => WhatIfScenario.increaseSavings,
    );
  }

  static List<String> getDisplayNames() {
    return WhatIfScenario.values.map((e) => e.displayName).toList();
  }
}

// Currency Options
enum Currency {
  inr,
  usd,
  eur,
  gbp,
  jpy,
}

extension CurrencyExtension on Currency {
  String get symbol {
    switch (this) {
      case Currency.inr:
        return '₹';
      case Currency.usd:
        return '\$';
      case Currency.eur:
        return '€';
      case Currency.gbp:
        return '£';
      case Currency.jpy:
        return '¥';
    }
  }

  String get code {
    return toString().split('.').last.toUpperCase();
  }

  String get displayName => code;

  static Currency fromString(String value) {
    return Currency.values.firstWhere(
      (e) => e.code == value.toUpperCase(),
      orElse: () => Currency.inr,
    );
  }

  static List<String> getDisplayNames() {
    return Currency.values.map((e) => e.displayName).toList();
  }
}

/// Helper class for dropdown utilities
class DropdownHelper {
  /// Convert display name back to enum
  static T enumFromDisplayName<T>(String displayName, List<T> enumValues) {
    return enumValues.firstWhere(
      (e) => e.toString().split('.').last == displayName.replaceAll(' ', '').toLowerCase(),
      orElse: () => enumValues.first,
    );
  }

  /// Validate and typecast numeric input
  static double castToDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Validate and typecast integer input
  static int castToInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Validate positive number
  static bool isPositive(dynamic value) {
    final num = castToDouble(value);
    return num > 0;
  }

  /// Format currency for display
  static String formatCurrency(double amount, Currency currency) {
    return '${currency.symbol}${amount.toStringAsFixed(2)}';
  }

  /// Parse percentage input (0-100)
  static double parsePercentage(String value) {
    final parsed = double.tryParse(value) ?? 0;
    return parsed.clamp(0, 100);
  }
}
