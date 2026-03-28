import 'dart:io';

void main() {
  final file = File(r'd:\flutter\ethackathon\ethackathon\lib\screens\portfolio_tracker\portfolio_tracker_screen.dart');
  var content = file.readAsStringSync();

  // Make sure isDark is available in build methods
  content = content.replaceAll(
    'Widget build(BuildContext context) {',
    'Widget build(BuildContext context) {\n    final isDark = Theme.of(context).brightness == Brightness.dark;'
  );

  // 1. Opacity and borders
  final opacityExp = RegExp(r'Colors\.white\.withOpacity\(([^)]+)\)');
  content = content.replaceAllMapped(opacityExp, (m) => 'AppColors.getBorder(isDark, ${m.group(1)})');
  
  final whiteOpacityExp = RegExp(r'AppColors\.whiteOpacity\(([^)]+)\)');
  content = content.replaceAllMapped(whiteOpacityExp, (m) => 'AppColors.getBorder(isDark, ${m.group(1)})');

  // 2. Text colors that should adapt (safe heuristics based on context)
  final textWhiteExp = RegExp(r'TextStyle\([^)]*color:\s*Colors\.white[^)]*\)');
  content = content.replaceAllMapped(textWhiteExp, (m) => m.group(0)!.replaceAll('Colors.white', 'AppColors.getTextPrimary(isDark)'));

  final textTertExp = RegExp(r'TextStyle\([^)]*color:\s*AppColors\.textTertiary[^)]*\)');
  content = content.replaceAllMapped(textTertExp, (m) => m.group(0)!.replaceAll('AppColors.textTertiary', 'AppColors.getTextTertiary(isDark)'));

  final textSecExp = RegExp(r'TextStyle\([^)]*color:\s*AppColors\.textSecondary[^)]*\)');
  content = content.replaceAllMapped(textSecExp, (m) => m.group(0)!.replaceAll('AppColors.textSecondary', 'AppColors.getTextSecondary(isDark)'));

  // Fix TabBar label colors
  content = content.replaceAll('labelColor: Colors.white', 'labelColor: AppColors.getTextPrimary(isDark)');
  // Fix Chart tick labels
  content = content.replaceAll('color: Colors.white)', 'color: AppColors.getTextTertiary(isDark))');

  // Undo for pie chart text which is explicitly inside 'PieChartSectionData' where color is usually white on colored slice
  final pieExp = RegExp(r'(PieChartSectionData\([^\]]+)AppColors\.getTextPrimary\(isDark\)');
  content = content.replaceAllMapped(pieExp, (m) => '${m.group(1)}Colors.white');

  // Undo for Slidable Action which might use white text
  final slidableExp = RegExp(r"(Text\('Edit',\s*style:\s*TextStyle\(color:\s*)AppColors\.getTextPrimary\(isDark\)(\)\))");
  content = content.replaceAllMapped(slidableExp, (m) => '${m.group(1)}Colors.white${m.group(2)}');

  // Undo for the blue briefcase icon
  final briefcaseExp = RegExp(r'(Icon\(Icons\.work_outline_rounded,\s*color:\s*)AppColors\.getTextPrimary\(isDark\)');
  content = content.replaceAllMapped(briefcaseExp, (m) => '${m.group(1)}Colors.white');

  // Replaces generic icon white with text primary
  final iconWhiteExp = RegExp(r'(Icon\([^,]+,\s*color:\s*)Colors\.white');
  content = content.replaceAllMapped(iconWhiteExp, (m) => '${m.group(1)}AppColors.getTextPrimary(isDark)');

  // Fix the brief case again just in case
  content = content.replaceAllMapped(briefcaseExp, (m) => '${m.group(1)}Colors.white');

  // Add AppColors import if missing
  if (!content.contains('import \'../../theme/app_colors.dart\';')) {
    content = 'import \'../../theme/app_colors.dart\';\n' + content;
  }

  file.writeAsStringSync(content);
  print('Portfolio Tracker updated!');
}
