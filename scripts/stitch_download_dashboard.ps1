$apiKey = $env:STITCH_API_KEY
$projectId = "9235544124643662404"
$screenId = "92bd859f2c3848cabd8931c4821d94ff"
$outDir = "designs/stitch/Dashboard_DODOME"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$headers = @{
    "Content-Type" = "application/json"
    "X-Goog-Api-Key" = $apiKey
}

function Invoke-StitchMcp {
    param([string]$Method, [hashtable]$Params)
    $body = @{ jsonrpc = "2.0"; id = 1; method = $Method; params = $Params } | ConvertTo-Json -Depth 10 -Compress
    return Invoke-RestMethod -Uri "https://stitch.googleapis.com/mcp" -Method Post -Headers $headers -Body $body -TimeoutSec 300
}

Write-Host "Fetching screen $screenId..."
$screen = Invoke-StitchMcp -Method "tools/call" -Params @{
    name = "get_screen"
    arguments = @{
        projectId = $projectId
        screenId = $screenId
    }
}
$screen | ConvertTo-Json -Depth 30 | Out-File -Encoding utf8 "$outDir/meta.json"

$htmlUrl = $screen.result.structuredContent.screens[0].htmlCode.downloadUrl
$shotUrl = $screen.result.structuredContent.screens[0].screenshot.downloadUrl

if (-not $htmlUrl) {
    $jsonText = $screen.result.content[0].text | ConvertFrom-Json
    $htmlUrl = $jsonText.screens[0].htmlCode.downloadUrl
    $shotUrl = $jsonText.screens[0].screenshot.downloadUrl
}

Write-Host "Downloading HTML..."
Invoke-WebRequest -Uri $htmlUrl -OutFile "$outDir/design.html"
Write-Host "Downloading screenshot..."
Invoke-WebRequest -Uri $shotUrl -OutFile "$outDir/screenshot.png"
Write-Host "Done."
