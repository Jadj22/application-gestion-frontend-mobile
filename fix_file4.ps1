$content = Get-Content "F:\management_projet\frontend_management\dodome\lib\features\home\presentation\pages\home_screen.dart" -Raw

# Fix corrupted literal \n sequences
$content = $content -replace '\\n', "`n"

# Fix the missing closing brace for _DashboardTopBar
$pattern = "}\n\n// ---------------------------------------------------------------------------\n// En-tête opérationnel\n// ---------------------------------------------------------------------------\n\nclass _OperationalHeader extends StatelessWidget {"
$replacement = "}\n}\n\n// ---------------------------------------------------------------------------\n// En-tête opérationnel\n// ---------------------------------------------------------------------------\n\nclass _OperationalHeader extends StatelessWidget {"

$content = $content -replace [regex]::Escape($pattern), $replacement

Set-Content "F:\management_projet\frontend_management\dodome\lib\features\home\presentation\pages\home_screen.dart" -Value $content -Encoding UTF8

Write-Host "Fix applied"