param(
    [string]$OutputRoot = 'exports',
    [ValidateSet('oficina-os', 'oficina-execution', 'oficina-billing', 'oficina-auth-lambda')]
    [string[]]$SelectedServices = @('oficina-os', 'oficina-execution', 'oficina-billing')
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$exportRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputRoot))
$allowedRoot = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
if (-not $exportRoot.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Os repositórios locais devem ser criados dentro do workspace.'
}

$dirty = & git -C $repoRoot status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Registre as alterações do repositório de origem antes da extração.' }
$branch = (& git -C $repoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or -not $branch) { throw 'A origem precisa estar em uma branch nomeada.' }
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()

$shared = @('.gitattributes', '.gitignore', '.dockerignore', 'global.json', 'NuGet.config', 'LICENSE')
$services = [ordered]@{
    'oficina-os' = @('src', 'tests/OficinaMvp.Domain.Tests', 'tests/OficinaMvp.Integration.Tests', 'tests/OficinaMvp.Postgres.Tests', 'services/Oficina.Auth', 'services/Oficina.Auth.Tests', 'scripts/validate-os-coverage.py', '.github/workflows/os-ci.yml')
    'oficina-execution' = @('services/Oficina.Execution', 'services/Oficina.Execution.Tests', 'services/Oficina.Execution.Postgres.Tests', '.github/workflows/execution-ci.yml')
    'oficina-billing' = @('services/Oficina.Billing', 'services/Oficina.Billing.Tests', 'services/Oficina.Billing.Dynamo.Tests', 'docs/runbooks/refund-reconciliation.md', '.github/workflows/billing-ci.yml')
    'oficina-auth-lambda' = @('services/Oficina.Auth', 'services/Oficina.Auth.Tests', 'scripts/aws-demo/build-auth-lambda.ps1', '.github/workflows/auth-ci.yml')
}

if (-not (Test-Path -LiteralPath $exportRoot)) { New-Item -ItemType Directory -Path $exportRoot | Out-Null }
foreach ($service in $SelectedServices) {
    $target = Join-Path $exportRoot $service
    if (Test-Path -LiteralPath $target) { throw "Destino já existe: $target. Não será sobrescrito." }
    & git clone --quiet --no-hardlinks --single-branch --branch $branch -- $repoRoot $target
    if ($LASTEXITCODE -ne 0) { throw "Falha ao clonar $service." }

    & git -C $target branch -M main
    if ($LASTEXITCODE -ne 0) { throw "Falha ao criar main em $service." }
    & git -C $target remote remove origin
    if ($LASTEXITCODE -ne 0) { throw "Falha ao remover o remote local em $service." }
    & git -C $target rm -r --quiet -- .
    if ($LASTEXITCODE -ne 0) { throw "Falha ao preparar a árvore de $service." }
    $keep = @($shared) + @($services[$service])
    & git -C $target restore --source=HEAD --staged --worktree -- $keep
    if ($LASTEXITCODE -ne 0) { throw "Falha ao restaurar os arquivos de $service." }

    $description = switch ($service) {
        'oficina-os' { 'API de ordens de serviço e orquestração da Saga.' }
        'oficina-execution' { 'Catálogo, estoque e execução de reparos.' }
        'oficina-billing' { 'Orçamentos e pagamentos em DynamoDB.' }
        'oficina-auth-lambda' { 'Autenticação serverless de clientes por CPF e JWT.' }
    }
    $testProject = switch ($service) {
        'oficina-os' { 'tests/OficinaMvp.Integration.Tests' }
        'oficina-execution' { 'services/Oficina.Execution.Tests' }
        'oficina-billing' { 'services/Oficina.Billing.Tests' }
        'oficina-auth-lambda' { 'services/Oficina.Auth.Tests' }
    }
    @(
        "# $service",
        '',
        $description,
        '',
        'Este repositório foi extraído do histórico Git do projeto `oficina-mvp`.',
        ("Commit de origem: " + $sourceCommit + "."),
        '',
        '```powershell',
        "dotnet test $testProject --configuration Release",
        '```',
        '',
        $(if ($service -eq 'oficina-auth-lambda') {
            'O workflow em `.github/workflows` testa e empacota a Function; após configurar OIDC, atualiza o código da Lambda na AWS.'
        } else {
            'O workflow em `.github/workflows` executa testes, publica a imagem no ECR por OIDC e aciona o deploy K3s por SSM quando as variáveis GitHub estiverem configuradas.'
        })
    ) | Set-Content -LiteralPath (Join-Path $target 'README.md') -Encoding utf8

    & git -C $target add -A
    if ($LASTEXITCODE -ne 0) { throw "Falha ao preparar o commit de $service." }
    & git -C $target commit --quiet -m "Isola $service em repositorio independente"
    if ($LASTEXITCODE -ne 0) { throw "Falha ao registrar o commit de $service." }
    "Preparado: $target"
}
