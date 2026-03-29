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
    name: 'Alex',
    age: 28,
    income: 100000,
    expenses: 40000,
    savings: 50000,
    investments: 120000,
    debt: 0,
    emergencyMonths: 4,
    hasInsurance: true,
    goals: 'Buy a house in 5 years',
    riskProfile: 'Medium',
  );
}
