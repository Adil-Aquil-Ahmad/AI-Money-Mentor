class FinancialProfile {
  String name;
  int age;
  double income;
  double expenses;
  double savings;
  double investments;
  double debt;
  int emergencyMonths;
  bool hasInsurance;
  String goals;
  String riskProfile; // 'Low', 'Medium', 'High'

  FinancialProfile({
    required this.name,
    required this.age,
    required this.income,
    required this.expenses,
    required this.savings,
    required this.investments,
    required this.debt,
    required this.emergencyMonths,
    required this.hasInsurance,
    required this.goals,
    required this.riskProfile,
  });

  factory FinancialProfile.initial() => FinancialProfile(
    name: '',
    age: 0,
    income: 0,
    expenses: 0,
    savings: 0,
    investments: 0,
    debt: 0,
    emergencyMonths: 0,
    hasInsurance: false,
    goals: '',
    riskProfile: 'Medium',
  );
}
