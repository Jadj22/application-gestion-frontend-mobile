$apiKey = $env:STITCH_API_KEY
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

Write-Host "Listing projects..."
$projects = Invoke-StitchMcp -Method "tools/call" -Params @{
    name = "list_projects"
    arguments = @{}
}
$projects | ConvertTo-Json -Depth 30 | Out-File -Encoding utf8 "designs/stitch/projects_list.json"
Write-Host "Projects saved."

Write-Host "Listing screens for project 12050982197159909585..."
$screens = Invoke-StitchMcp -Method "tools/call" -Params @{
    name = "list_screens"
    arguments = @{
        projectId = "projects/12050982197159909585"
    }
}
$screens | ConvertTo-Json -Depth 30 | Out-File -Encoding utf8 "designs/stitch/screens_list.json"
Write-Host "Screens saved."
