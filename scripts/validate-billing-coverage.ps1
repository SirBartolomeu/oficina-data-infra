param(
    [int]$Minimum = 80,
    [string]$UnitResultsDirectory = 'test-results/billing',
    [string]$IntegrationResultsDirectory = 'test-results/billing-dynamo'
)

$ErrorActionPreference = 'Stop'

function Read-BillingLines([string]$directory) {
    $reports = @(Get-ChildItem -LiteralPath $directory -Recurse -Filter 'coverage.cobertura.xml')
    if ($reports.Count -ne 1) { throw "Esperado um relatório Cobertura em $directory; encontrados $($reports.Count)." }
    [xml]$coverage = Get-Content -LiteralPath $reports[0].FullName
    $packages = @($coverage.coverage.packages.package | Where-Object { $_.name -eq 'Oficina.Billing' })
    if ($packages.Count -ne 1) { throw "Pacote Oficina.Billing ausente ou duplicado em $directory." }
    $lines = @{}
    foreach ($class in @($packages[0].classes.class)) {
        foreach ($line in @($class.lines.line)) {
            $key = "$($class.filename):$($line.number)"
            $hit = [int]$line.hits -gt 0
            if ($lines.ContainsKey($key)) { $lines[$key] = $lines[$key] -or $hit }
            else { $lines[$key] = $hit }
        }
    }
    if ($lines.Count -eq 0) { throw "Nenhuma linha instrumentada de Oficina.Billing em $directory." }
    return $lines
}

$unit = Read-BillingLines $UnitResultsDirectory
$integration = Read-BillingLines $IntegrationResultsDirectory
if ($unit.Count -ne $integration.Count) { throw 'As suítes instrumentaram conjuntos diferentes de linhas.' }
$covered = 0
foreach ($key in $unit.Keys) {
    if (-not $integration.ContainsKey($key)) { throw "Linha instrumentada ausente na integração: $key" }
    if ($unit[$key] -or $integration[$key]) { $covered++ }
}
$percent = [math]::Round(100.0 * $covered / $unit.Count, 2)
Write-Output "Cobertura Billing: $covered/$($unit.Count) linhas ($percent%). Mínimo: $Minimum%."
if ($covered * 100 -lt $Minimum * $unit.Count) { throw "Cobertura Billing abaixo de $Minimum%." }
