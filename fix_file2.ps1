$content = Get-Content "F:\management_projet\frontend_management\dodome\lib\features\home\presentation\pages\home_screen.dart" -Raw

# Fix the corrupted newlines first
$content = $content -replace "`n", "`n"

# Fix the missing closing brace for _DashboardTopBar and comment indentation
$pattern = @"
}\n\n// ---------------------------------------------------------------------------
// En-tête opérationnel
// ---------------------------------------------------------------------------

class _OperationalHeader extends StatelessWidget {
"@

$replacement = @"
}
}

// ---------------------------------------------------------------------------
// En-tête opérationnel
// ---------------------------------------------------------------------------

class _OperationalHeader extends StatelessWidget {
"@

$content = $content -replace [regex]::Escape($pattern), $replacement

Set-Content "F:\management_projet\frontend_management\dodome\lib\features\home\presentation\pages\home_screen.dart" -Value $content -Encoding UTF8

Write-Host "Fix applied"