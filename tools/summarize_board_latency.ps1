param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$events = @(Get-Content -LiteralPath $InputPath | ForEach-Object {
    if ($_ -match 'BOARD_LATENCY (\{.*\})') { $Matches[1] | ConvertFrom-Json }
})
$errors = @($events | Where-Object event -eq 'error')
if ($errors.Count) { throw 'The run contains query errors; do not report a success-only latency summary.' }
$queries = @($events | Where-Object event -eq 'query' | Sort-Object sample)
$frames = @($events | Where-Object event -eq 'frame' | Sort-Object sample)
if ($queries.Count -ne 34 -or $frames.Count -ne 34) {
    throw "Expected 34 queries and frames, got $($queries.Count) and $($frames.Count)."
}
for ($index = 0; $index -lt 34; $index++) {
    if ($queries[$index].sample -ne ($index + 1) -or $frames[$index].sample -ne ($index + 1)) {
        throw 'Missing or duplicated sample IDs.'
    }
    if ($queries[$index].from_cache -or -not $queries[$index].first_page -or $queries[$index].mine) {
        throw 'The run contains a cached response or a different query.'
    }
    if ($queries[$index].documents -ne $frames[$index].documents) {
        throw 'Query and rendered sample document counts disagree.'
    }
}

function Get-LatencyStats([double[]]$Microseconds) {
    $sorted = @($Microseconds | Sort-Object)
    $count = $sorted.Count
    if ($count % 2) { $median = $sorted[[int][math]::Floor($count / 2)] }
    else { $median = ($sorted[$count / 2 - 1] + $sorted[$count / 2]) / 2 }
    [ordered]@{
        samples = $count
        median_ms = [math]::Round($median / 1000, 3)
        p95_ms = [math]::Round($sorted[[int][math]::Ceiling(0.95 * $count) - 1] / 1000, 3)
        mean_ms = [math]::Round(($sorted | Measure-Object -Average).Average / 1000, 3)
        min_ms = [math]::Round($sorted[0] / 1000, 3)
        max_ms = [math]::Round($sorted[-1] / 1000, 3)
    }
}

$measuredQueries = @($queries | Where-Object sample -ge 5)
$measuredFrames = @($frames | Where-Object sample -ge 5)
$frameOverhead = @($measuredFrames | ForEach-Object { $_.first_frame_us - $_.load_us })
$documentCounts = @($queries.documents | Sort-Object -Unique)
$summary = [ordered]@{
    test_date = '2026-10-14'
    environment = 'Physical Android device; Flutter profile; actual authenticated Firestore client'
    query_description = 'Active posts ordered by createdAt and document ID, first page, limit 20, Source.server'
    protocol = '1 first query, 3 warmups, 30 measured queries; one second after each completed Flutter frame'
    total_queries = $queries.Count
    response_document_counts = $documentCounts
    stable_document_count = ($documentCounts.Count -eq 1)
    cached_responses = @($queries | Where-Object from_cache).Count
    first_query_ms = [math]::Round($queries[0].query_us / 1000, 3)
    first_query_to_frame_ms = [math]::Round($frames[0].first_frame_us / 1000, 3)
}
$summary['query_response'] = Get-LatencyStats $measuredQueries.query_us
$summary['model_decoding'] = Get-LatencyStats $measuredQueries.decode_us
$summary['load_to_flutter_frame'] = Get-LatencyStats $measuredFrames.first_frame_us
$summary['after_load_to_flutter_frame'] = Get-LatencyStats $frameOverhead
$summary['limitations'] = @(
    'Client-observed SDK query duration includes network and SDK overhead; not isolated server execution time.',
    'Frame completion uses addPostFrameCallback; it does not measure raster completion or physical display latency.',
    'No previous-version server benchmark was run; no speed improvement percentage is established.',
    'No application content, account identifiers or tokens are stored in these metrics.'
)
$json = $summary | ConvertTo-Json -Depth 8
Set-Content -LiteralPath $OutputPath -Value $json -Encoding utf8
$json
