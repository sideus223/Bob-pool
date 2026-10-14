param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [ValidateSet(20, 100, 500, 1000)][int]$PostCount = 1000
)
$ErrorActionPreference = 'Stop'
$events = @(Get-Content -LiteralPath $InputPath | ForEach-Object {
    if ($_ -match '^BOARD_COMPARE (\{.*\})$') { $Matches[1] | ConvertFrom-Json }
})
if (@($events | Where-Object event -eq 'error').Count) { throw 'Failed run; do not summarize success-only samples.' }
$events = @($events | Where-Object {
    if ($null -eq $_.dataset_posts) { $PostCount -eq 1000 -and $_.event -ne 'complete_all' }
    else { $_.dataset_posts -eq $PostCount }
})
$samples = @($events | Where-Object event -eq 'sample' | Sort-Object sequence)
if ($samples.Count -ne 48 -or @($events | Where-Object event -eq 'complete').Count -ne 1) { throw 'Expected a completed run of exactly 48 samples.' }
if (($events | Where-Object event -eq 'complete').samples -ne 48) { throw 'Unexpected completion sample count.' }
for ($index = 0; $index -lt 48; $index++) {
    $sample = $samples[$index]
    $pair = [int][math]::Floor($index / 2) + 1
    $expectedVariant = if (($pair % 2 -eq 1) -eq ($index % 2 -eq 0)) { 'original' } else { 'current' }
    $expectedDocuments = if ($expectedVariant -eq 'original') { $PostCount } else { 20 }
    if ($sample.sequence -ne ($index + 1) -or $sample.pair -ne $pair -or $sample.variant -ne $expectedVariant -or $sample.documents -ne $expectedDocuments -or $sample.from_cache -or $sample.warmup -ne ($pair -le 4)) { throw 'Unexpected ordering, sample count, fixture size, source or warmup classification.' }
}
function Get-ComparisonStats([double[]]$Values) {
    $sorted = @($Values | Sort-Object)
    $n = $sorted.Count
    $median = if ($n % 2) { $sorted[[int][math]::Floor($n / 2)] } else { ($sorted[$n / 2 - 1] + $sorted[$n / 2]) / 2 }
    [ordered]@{
        samples = $n
        median_ms = [math]::Round($median / 1000, 3)
        p95_ms = [math]::Round($sorted[[int][math]::Ceiling(0.95 * $n) - 1] / 1000, 3)
        mean_ms = [math]::Round(($sorted | Measure-Object -Average).Average / 1000, 3)
        min_ms = [math]::Round($sorted[0] / 1000, 3)
        max_ms = [math]::Round($sorted[-1] / 1000, 3)
    }
}
$measured = @($samples | Where-Object { -not $_.warmup })
$original = @($measured | Where-Object variant -eq 'original')
$current = @($measured | Where-Object variant -eq 'current')
$originalStats = Get-ComparisonStats $original.query_us
$currentStats = Get-ComparisonStats $current.query_us
$paired = @(foreach ($pair in 5..24) {
    $old = $original | Where-Object pair -eq $pair
    $new = $current | Where-Object pair -eq $pair
    [ordered]@{
        pair = $pair
        original_query_ms = [math]::Round($old.query_us / 1000, 3)
        current_query_ms = [math]::Round($new.query_us / 1000, 3)
        difference_ms = [math]::Round(($old.query_us - $new.query_us) / 1000, 3)
        reduction_percent = [math]::Round(($old.query_us - $new.query_us) / $old.query_us * 100, 3)
    }
})
$summary = [ordered]@{
    test_date = '2026-10-14'
    environment = 'Physical SM-S931N Android 16 device, same Flutter profile binary and authenticated Firestore client'
    baseline = 'Original pre-pagination query shape from 4848f33 parent; unbounded createdAt descending snapshots, first non-cache response'
    current = 'deleted false, createdAt descending and document ID ordering, limit 20, Source.server'
    dataset = "Same isolated real Firestore collection, $PostCount synthetic active posts, 1024 deterministic varied ASCII content characters per post"
    synthetic_post_count = $PostCount
    protocol = '24 pairs; alternating original-current and current-original; first 4 pairs excluded, 20 measured pairs; 1 second between queries'
    total_queries = 48
    cached_responses = 0
    original_query = $originalStats
    current_query = $currentStats
    median_response_reduction_percent = [math]::Round(($originalStats.median_ms - $currentStats.median_ms) / $originalStats.median_ms * 100, 3)
    original_decoding = Get-ComparisonStats $original.decode_us
    current_decoding = Get-ComparisonStats $current.decode_us
    original_query_and_decoding = Get-ComparisonStats $original.total_us
    current_query_and_decoding = Get-ComparisonStats $current.total_us
    current_faster_pairs = @($paired | Where-Object { $_.difference_ms -gt 0 }).Count
    measured_pairs = $paired
    limitations = @(
        'Query-pattern reconstruction with the same SDK, not a benchmark of the archived original APK as a whole.',
        'Client-observed response duration includes network, SDK processing and initial snapshot delivery; not isolated server computation.',
        'Both query results are server-confirmed; SDK in-memory optimizations are not independently disabled or measured. Disk persistence is disabled.',
        'The old listener is stopped after its first server snapshot. Continuous realtime-update behavior and comment-count listeners are outside this comparison.',
        'No full-screen rendering, user conversion, billing, or all-pages completion improvement is established.',
        'Single device and session, synthetic large dataset; results do not represent the current four-post production query or all user networks.'
    )
}
$json = $summary | ConvertTo-Json -Depth 10
Set-Content -LiteralPath $OutputPath -Value $json -Encoding utf8
$json
