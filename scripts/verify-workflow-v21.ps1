param([string]$EvidenceDirectory = '')
$ErrorActionPreference = 'Stop'
$appRoot = Split-Path $PSScriptRoot -Parent
if (-not $EvidenceDirectory) { $EvidenceDirectory = Join-Path $appRoot '..\..\Wang-B-Agent\design\workflow-v2.1\evidence' }
$evidencePath = [System.IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Force -Path $evidencePath | Out-Null
Push-Location $appRoot
try {
  $workflowFiles = @(Get-ChildItem 'tests/workflow-v2.1*.test.mjs' | Sort-Object Name | ForEach-Object { $_.FullName })
  $allFiles = @(Get-ChildItem 'tests/*.test.mjs' | Sort-Object Name | ForEach-Object { $_.FullName })
  & node --disable-warning=ExperimentalWarning --test --test-reporter=tap @workflowFiles > (Join-Path $evidencePath 'workflow-v2.1.tap') 2>&1
  $workflowExit = $LASTEXITCODE
  & node --disable-warning=ExperimentalWarning --test --test-reporter=tap @allFiles > (Join-Path $evidencePath 'all-app-node-tests.tap') 2>&1
  $allExit = $LASTEXITCODE
  $tap = Get-Content -LiteralPath (Join-Path $evidencePath 'workflow-v2.1.tap') -Raw
  $cases = @(1..17 | ForEach-Object {
    $id = 'WF-{0:00}' -f $_
    $match = [regex]::Match($tap, "(?m)^(not ok|ok) \d+ - ($id .*)$")
    $status = if (-not $match.Success) { 'NOT_RUN' } elseif ($match.Groups[1].Value -eq 'ok') { 'PASS' } else { 'FAIL' }
    $assertionLine = (Select-String -LiteralPath 'tests/workflow-v2.1.test.mjs' -Pattern "test\('$id ").LineNumber
    [ordered]@{ id = $id; status = $status; testName = $match.Groups[2].Value.Trim(); assertions = "tests/workflow-v2.1.test.mjs:$assertionLine"; log = 'workflow-v2.1.tap' }
  })
  $sourcePatterns = @('entry/src/main/ets/services/WorkflowV21*','tests/workflow-v2.1*','scripts/verify-workflow-v21.ps1',
    'entry/src/main/ets/services/FocusConsent.ts','entry/src/main/ets/services/AppState.ets','entry/src/main/ets/services/StorageService.ets',
    'entry/src/main/ets/models/AppTypes.ets','entry/src/main/ets/pages/AppTabs.ets','entry/src/main/ets/pages/SettingsPage.ets',
    'entry/src/main/ets/pages/GuidePage.ets','entry/src/main/ets/focusanchoragentextability/FocusAnchor*.ets')
  $sources = @(Get-ChildItem $sourcePatterns -File | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = [System.IO.Path]::GetRelativePath($appRoot, $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
  })
  $allTap = Get-Content -LiteralPath (Join-Path $evidencePath 'all-app-node-tests.tap') -Raw
  $builds = @('entry','wear' | ForEach-Object {
    $buildLog = Join-Path $evidencePath ($_ + '-build.log')
    $buildStatus = if (-not (Test-Path -LiteralPath $buildLog)) { 'NOT_RUN' } elseif ((Get-Content $buildLog -Raw) -match 'BUILD SUCCESSFUL') { 'PASS' } else { 'FAIL' }
    [ordered]@{ module = $_; status = $buildStatus; log = $_ + '-build.log'; note = 'SDK compilation only; physical devices unverified' }
  })
  $report = [ordered]@{ generatedAt = [DateTimeOffset]::UtcNow.ToString('o'); node = (& node --version); platform = [System.Environment]::OSVersion.ToString();
    commands = @('node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/workflow-v2.1*.test.mjs','node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/*.test.mjs');
    workflowExitCode = $workflowExit; allTestsExitCode = $allExit; totalTests = [int]([regex]::Match($allTap, '(?m)^# tests (\d+)').Groups[1].Value); cases = $cases; builds = $builds;
    e2e = @(@{ id='E2E-01';status='BLOCKED';reason='Real Agent Provider not configured/verified' },@{ id='E2E-02';status='BLOCKED';reason='Real Agent-to-phone restart evidence unavailable' },@{ id='E2E-03';status='BLOCKED';reason='No paired phone/watch receipt evidence' },@{ id='E2E-04';status='BLOCKED';reason='Device capabilities require physical/authorized platform tests' }); sources = $sources }
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidencePath 'workflow-v2.1-results.json') -Encoding utf8
  Write-Output "WF cases: $(@($cases | Where-Object status -eq 'PASS').Count)/17 PASS; workflow exit=$workflowExit; all-tests exit=$allExit"
  Write-Output "Report: $(Join-Path $evidencePath 'workflow-v2.1-results.json')"
  if ($workflowExit -ne 0 -or $allExit -ne 0 -or @($cases | Where-Object status -ne 'PASS').Count -gt 0) { exit 1 }
} finally { Pop-Location }
