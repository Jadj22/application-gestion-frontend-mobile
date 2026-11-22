$content = Get-Content "F:\management_projet\frontend_management\dodome\lib\features\home\presentation\pages\home_screen.dart" -Raw

# Fix the missing closing brace for _DashboardTopBar and comment indentation
$content = $content -replace "}\s+\n\s+// ---------------------------------------------------------------------------\n// En-tête opérationnel\n// ---------------------------------------------------------------------------\n\n\nclass _OperationalHeader", "}\n}\n\n// ---------------------------------------------------------------------------\n// En-tête opérationnel\n// ---------------------------------------------------------------------------\n\nclass _OperationalHeader"

Set-Content "F:\management_projet\frontend_management\dodome\lib\features\home\presentation\pages\home_screen.dart" -Value $content -Encoding UTF8

Write-Host "Fix applied"