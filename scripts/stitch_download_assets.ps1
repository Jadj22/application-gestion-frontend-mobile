$outDir = Join-Path $PSScriptRoot "..\designs\stitch\Dashboard_DODOME"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$htmlUrl = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sX2FiYjRkZDg0MzNiYTQ2NTk4NTQ3MmQ0NzAyZjkyNWMyEgsSBxC6sfC63hMYAZIBIwoKcHJvamVjdF9pZBIVQhM5MjM1NTQ0MTI0NjQzNjYyNDA0&filename=&opi=96797242"
$shotUrl = "https://lh3.googleusercontent.com/aida/AP1WRLv9wNn6ImGzWqop4G8uEN1xCgx1JcpACoDY7Sg1FTZ-4pNRlj9z6_e6VBRliVdKbdyOGUdoOVz8RFJyDL8RTp3jPacs2OM17Z2czCvFHnWxQD4TQ5yQS8Tl7vC90BNNqUjJHlKjGxF-EKOgd323D3PXxvuHMHC2CxV_m0yL6neCBiluAVlaHgFc9pcL9uKjbds-bOpeKoc1izVjFGWvcqnM1I4ItDhVjTF6W2-b8Kjf7kC0UvijmiepXTo"

Invoke-WebRequest -Uri $htmlUrl -OutFile (Join-Path $outDir "design.html")
Invoke-WebRequest -Uri $shotUrl -OutFile (Join-Path $outDir "screenshot.png")
Write-Host "Assets downloaded to $outDir"
