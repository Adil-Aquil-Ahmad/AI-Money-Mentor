import os
import re

files_to_process = [
    r'd:\flutter\ethackathon\ethackathon\lib\screens\portfolio_tracker\portfolio_tracker_screen.dart',
    r'd:\flutter\ethackathon\ethackathon\lib\screens\what_if_simulator\what_if_simulator_screen.dart'
]

theme_check = 'Theme.of(context).brightness == Brightness.dark'

replacements = [
    (r'Colors\.white\.withOpacity\(([^)]+)\)', rf'AppColors.getBorder({theme_check}, \1)'),
    (r'AppColors\.whiteOpacity\(([^)]+)\)', rf'AppColors.getBorder({theme_check}, \1)'),
    (r'Colors\.white', rf'AppColors.getTextPrimary({theme_check})'),
    (r'AppColors\.textTertiary', rf'AppColors.getTextTertiary({theme_check})'),
    (r'AppColors\.textSecondary', rf'AppColors.getTextSecondary({theme_check})'),
]

for file_path in files_to_process:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    for pattern, replacement in replacements:
        content = re.sub(pattern, replacement, content)

    # Some manual fixes: we don't want to replace Colors.white where it's explicitly needed 
    # to not change (like in gradients if we wanted them white, but here changing to textPrimary is fine)
    # Actually, in GlassCard inner gradient we do want it. Wait, GlassCard is already fixed separately.
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
        
print("Replacements complete!")
