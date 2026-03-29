
/// Chat Message API Model
class ChatMessageRequest {
  final String userId;
  final String message;
  final List<String>? context;
  final Map<String, dynamic>? transientProfile;

  ChatMessageRequest({
    required this.userId,
    required this.message,
    this.context,
    this.transientProfile,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'message': message,
    if (context != null) 'context': context,
    if (transientProfile != null) 'transient_profile': transientProfile,
  };
}

class ChatMessageResponse {
  final String message;
  final String? advisorThought;
  final Map<String, dynamic>? data;

  ChatMessageResponse({
    required this.message,
    this.advisorThought,
    this.data,
  });

  factory ChatMessageResponse.fromJson(Map<String, dynamic> json) =>
      ChatMessageResponse(
        message: json['response'] ?? json['message'] ?? '',
        advisorThought: json['advisor_thought'],
        data: json['data'],
      );
}

/// Financial Profile API Models
class FinancialProfileRequest {
  final String userId;
  final double monthlyIncome;
  final double savings;
  final String riskTolerance; // 'low', 'medium', 'high'
  final List<String> investmentGoals;
  final int investmentHorizon; // years
  final double currentInvestments;
  final String? currency;

  FinancialProfileRequest({
    required this.userId,
    required this.monthlyIncome,
    required this.savings,
    required this.riskTolerance,
    required this.investmentGoals,
    required this.investmentHorizon,
    required this.currentInvestments,
    this.currency = 'INR',
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'monthly_income': monthlyIncome,
    'savings': savings,
    'risk_tolerance': riskTolerance,
    'investment_goals': investmentGoals,
    'investment_horizon': investmentHorizon,
    'current_investments': currentInvestments,
    'currency': currency,
  };
}

class FinancialProfileResponse {
  final String userId;
  final double monthlyIncome;
  final double savings;
  final String riskTolerance;
  final List<String> investmentGoals;
  final int investmentHorizon;
  final double currentInvestments;
  final Map<String, dynamic>? recommendations;

  FinancialProfileResponse({
    required this.userId,
    required this.monthlyIncome,
    required this.savings,
    required this.riskTolerance,
    required this.investmentGoals,
    required this.investmentHorizon,
    required this.currentInvestments,
    this.recommendations,
  });

  factory FinancialProfileResponse.fromJson(Map<String, dynamic> json) =>
      FinancialProfileResponse(
        userId: json['user_id'] ?? '',
        monthlyIncome: (json['monthly_income'] as num?)?.toDouble() ?? 0.0,
        savings: (json['savings'] as num?)?.toDouble() ?? 0.0,
        riskTolerance: json['risk_tolerance'] ?? 'medium',
        investmentGoals: List<String>.from(json['investment_goals'] ?? []),
        investmentHorizon: json['investment_horizon'] ?? 0,
        currentInvestments: (json['current_investments'] as num?)?.toDouble() ?? 0.0,
        recommendations: json['recommendations'],
      );
}

/// Health Score API Models
class HealthScoreResponse {
  final double overallScore;
  final double savingsScore;
  final double investmentScore;
  final double debtScore;
  final Map<String, dynamic>? details;

  HealthScoreResponse({
    required this.overallScore,
    required this.savingsScore,
    required this.investmentScore,
    required this.debtScore,
    this.details,
  });

  factory HealthScoreResponse.fromJson(Map<String, dynamic> json) =>
      HealthScoreResponse(
        overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
        savingsScore: (json['savings_score'] as num?)?.toDouble() ?? 0.0,
        investmentScore: (json['investment_score'] as num?)?.toDouble() ?? 0.0,
        debtScore: (json['debt_score'] as num?)?.toDouble() ?? 0.0,
        details: json['details'],
      );
}

/// Portfolio API Models
class PortfolioRequest {
  final String userId;
  final List<PortfolioHolding> holdings;

  PortfolioRequest({
    required this.userId,
    required this.holdings,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'holdings': holdings.map((h) => h.toJson()).toList(),
  };
}

class PortfolioHolding {
  final String symbol;
  final int quantity;
  final double purchasePrice;
  final DateTime? purchaseDate;
  final String? category; // 'stock', 'mutual_fund', 'crypto', 'bond'

  PortfolioHolding({
    required this.symbol,
    required this.quantity,
    required this.purchasePrice,
    this.purchaseDate,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'quantity': quantity,
    'purchase_price': purchasePrice,
    if (purchaseDate != null) 'purchase_date': purchaseDate?.toIso8601String(),
    if (category != null) 'category': category,
  };
}

class PortfolioResponse {
  final double totalValue;
  final double totalInvested;
  final double gainLoss;
  final double gainLossPercent;
  final List<PortfolioHoldingResponse> holdings;

  PortfolioResponse({
    required this.totalValue,
    required this.totalInvested,
    required this.gainLoss,
    required this.gainLossPercent,
    required this.holdings,
  });

  factory PortfolioResponse.fromJson(Map<String, dynamic> json) =>
      PortfolioResponse(
        totalValue: (json['total_value'] as num?)?.toDouble() ?? 0.0,
        totalInvested: (json['total_invested'] as num?)?.toDouble() ?? 0.0,
        gainLoss: (json['gain_loss'] as num?)?.toDouble() ?? 0.0,
        gainLossPercent: (json['gain_loss_percent'] as num?)?.toDouble() ?? 0.0,
        holdings: (json['holdings'] as List?)
                ?.map((h) => PortfolioHoldingResponse.fromJson(h))
                .toList() ??
            [],
      );
}

class PortfolioHoldingResponse {
  final String symbol;
  final int quantity;
  final double currentPrice;
  final double totalValue;
  final double gainLoss;

  PortfolioHoldingResponse({
    required this.symbol,
    required this.quantity,
    required this.currentPrice,
    required this.totalValue,
    required this.gainLoss,
  });

  factory PortfolioHoldingResponse.fromJson(Map<String, dynamic> json) =>
      PortfolioHoldingResponse(
        symbol: json['symbol'] ?? '',
        quantity: json['quantity'] ?? 0,
        currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0.0,
        totalValue: (json['total_value'] as num?)?.toDouble() ?? 0.0,
        gainLoss: (json['gain_loss'] as num?)?.toDouble() ?? 0.0,
      );
}

/// FIRE Calculator API Models
class FireCalculatorRequest {
  final String userId;
  final double currentSavings;
  final double annualExpenses;
  final double annualSavings;
  final double expectedAnnualReturn; // percentage
  final double inflationRate; // percentage
  final int currentAge;
  final int targetRetirementAge;

  FireCalculatorRequest({
    required this.userId,
    required this.currentSavings,
    required this.annualExpenses,
    required this.annualSavings,
    required this.expectedAnnualReturn,
    required this.inflationRate,
    required this.currentAge,
    required this.targetRetirementAge,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'current_savings': currentSavings,
    'annual_expenses': annualExpenses,
    'annual_savings': annualSavings,
    'expected_annual_return': expectedAnnualReturn,
    'inflation_rate': inflationRate,
    'current_age': currentAge,
    'target_retirement_age': targetRetirementAge,
  };
}

class FireCalculatorResponse {
  final bool canRetire;
  final int yearsToRetirement;
  final double fireNumber;
  final double currentNetWorth;
  final double projectedNetWorth;

  FireCalculatorResponse({
    required this.canRetire,
    required this.yearsToRetirement,
    required this.fireNumber,
    required this.currentNetWorth,
    required this.projectedNetWorth,
  });

  factory FireCalculatorResponse.fromJson(Map<String, dynamic> json) =>
      FireCalculatorResponse(
        canRetire: json['can_retire'] ?? false,
        yearsToRetirement: json['years_to_retirement'] ?? 0,
        fireNumber: (json['fire_number'] as num?)?.toDouble() ?? 0.0,
        currentNetWorth: (json['current_net_worth'] as num?)?.toDouble() ?? 0.0,
        projectedNetWorth:
            (json['projected_net_worth'] as num?)?.toDouble() ?? 0.0,
      );
}

/// What-If Simulator API Models
class WhatIfSimulatorRequest {
  final String userId;
  final String scenario; // 'increase_savings', 'lower_expenses', etc
  final double percentageChange; // percentage change
  final int yearsAffected; // 0 for permanent

  WhatIfSimulatorRequest({
    required this.userId,
    required this.scenario,
    required this.percentageChange,
    required this.yearsAffected,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'scenario': scenario,
    'percentage_change': percentageChange,
    'years_affected': yearsAffected,
  };
}

class WhatIfSimulatorResponse {
  final String scenario;
  final double originalValue;
  final double newValue;
  final double difference;
  final String impact;

  WhatIfSimulatorResponse({
    required this.scenario,
    required this.originalValue,
    required this.newValue,
    required this.difference,
    required this.impact,
  });

  factory WhatIfSimulatorResponse.fromJson(Map<String, dynamic> json) =>
      WhatIfSimulatorResponse(
        scenario: json['scenario'] ?? '',
        originalValue: (json['original_value'] as num?)?.toDouble() ?? 0.0,
        newValue: (json['new_value'] as num?)?.toDouble() ?? 0.0,
        difference: (json['difference'] as num?)?.toDouble() ?? 0.0,
        impact: json['impact'] ?? '',
      );
}
