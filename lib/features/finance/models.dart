const expenseCategories = {
  'fuel': 'وقود / ديزل',
  'maintenance': 'صيانة',
  'wages': 'أجور',
  'equipment': 'معدات',
  'other': 'أخرى'
};

class FinanceTotals {
  final int billed, collected, outstanding, costs;
  final Map<String, int> categories;
  const FinanceTotals(
      {this.billed = 0,
      this.collected = 0,
      this.outstanding = 0,
      this.costs = 0,
      this.categories = const {}});
  factory FinanceTotals.fromMap(Map<String, dynamic> d) => FinanceTotals(
          billed: d['billedAgorot'] ?? 0,
          collected: d['collectedAgorot'] ?? 0,
          outstanding: d['outstandingAgorot'] ?? 0,
          costs: d['costAgorot'] ?? 0,
          categories: {
            for (final c in expenseCategories.keys) c: d['${c}Agorot'] ?? 0
          });
  FinanceTotals operator +(FinanceTotals b) => FinanceTotals(
          billed: billed + b.billed,
          collected: collected + b.collected,
          outstanding: outstanding + b.outstanding,
          costs: costs + b.costs,
          categories: {
            for (final c in expenseCategories.keys)
              c: (categories[c] ?? 0) + (b.categories[c] ?? 0)
          });
  int get profit => collected - costs;
}
