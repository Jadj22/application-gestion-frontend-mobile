$apiKey = $env:STITCH_API_KEY
$projectId = "9235544124643662404"
$headers = @{
    "Content-Type" = "application/json"
    "X-Goog-Api-Key" = $apiKey
}

function Invoke-StitchMcp {
    param(
        [string]$Method,
        [hashtable]$Params
    )

    $body = @{
        jsonrpc = "2.0"
        id = 1
        method = $Method
        params = $Params
    } | ConvertTo-Json -Depth 10 -Compress

    return Invoke-RestMethod -Uri "https://stitch.googleapis.com/mcp" `
        -Method Post `
        -Headers $headers `
        -Body $body `
        -TimeoutSec 300
}

Write-Host "Listing screens for project $projectId..."
$screens = Invoke-StitchMcp -Method "tools/call" -Params @{
    name = "list_screens"
    arguments = @{
        projectId = $projectId
    }
}
$screens | ConvertTo-Json -Depth 30 | Out-File -Encoding utf8 "designs/stitch/opstrack_screens_list.json"
Write-Host "Screens saved."

Write-Host "Generating DODOME dashboard..."
$prompt = @"
MOBILE Home Dashboard for DODOME inventory management app (French B2B). Style: Floating UI glassmorphism, premium editorial. Colors: primary #6C8EA4, secondary #102A3A, background #FAF9FB. Header: user avatar with green online dot, French date label, greeting Salut [name]. Hero banner with gradient and text Optimisez votre flux de travail. Bento grid: 3 stat cards (Total articles, Disponibles, Maintenance). Capsule search bar Rechercher un article. Horizontal scroll alert cards: Entretien urgent, Rupture de stock with halo shadows. Recent activity list with thumbnails. Bottom nav: Accueil, Articles, Stock, Entretien, Plus. FAB add button. Language French. 390px mobile.
"@

$generate = Invoke-StitchMcp -Method "tools/call" -Params @{
    name = "generate_screen_from_text"
    arguments = @{
        projectId = $projectId
        prompt = $prompt
        deviceType = "MOBILE"
        modelId = "GEMINI_3_1_PRO"
    }
}
$generate | ConvertTo-Json -Depth 30 | Out-File -Encoding utf8 "designs/stitch/generate_dashboard_result.json"
Write-Host "Generation result saved."
