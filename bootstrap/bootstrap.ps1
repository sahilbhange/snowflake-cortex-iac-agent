# bootstrap.ps1 — Apply all Snowflake Terraform stacks in dependency order.
#
# Usage: .\bootstrap.ps1 [-Env test]
#
# Each stack maintains its own Terraform state in its own directory.
# Applies are human-gated — you will be prompted before every apply.
# Skipping any step stops the bootstrap; re-run from that step manually.

param(
  [string]$Env = "test"
)

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$RepoRoot  = Split-Path -Parent $ScriptDir
$Base      = "$RepoRoot\live\$Env"

if (-not (Test-Path $Base)) {
  Write-Error "Environment directory not found: $Base"
  exit 1
}

$script:StepNum = 1

function Invoke-Stack {
  param(
    [string]$Label,
    [string]$StackRel,    # relative to live\<env>\
    [string]$Config,      # filename under configs\
    [string]$Note = ""    # optional warning printed before plan
  )

  Write-Host ""
  Write-Host ("━" * 54) -ForegroundColor Cyan
  Write-Host ("  STEP {0}: {1}" -f $script:StepNum, $Label) -ForegroundColor Cyan
  Write-Host ("━" * 54) -ForegroundColor Cyan
  $script:StepNum++

  if ($Note) {
    Write-Host "  ⚠  $Note" -ForegroundColor Yellow
    Write-Host ""
  }

  Set-Location "$Base\$StackRel"

  Write-Host "`n→ terraform init" -ForegroundColor DarkCyan
  terraform init -upgrade -input=false | Select-Object -Last 5

  Write-Host "`n→ terraform plan" -ForegroundColor DarkCyan
  $planOut = New-TemporaryFile
  terraform plan -no-color `
    -var-file="..\..\account.auto.tfvars" `
    -var-file="..\..\configs\$Config" |
    Tee-Object -FilePath $planOut

  $forceNew = Select-String -Path $planOut -SimpleMatch "# forces replacement" -Quiet
  if ($forceNew) {
    Write-Host "`nHIGH RISK: plan includes ForceNew replacement actions (# forces replacement)." -ForegroundColor Red
    Write-Host "Do not apply. Investigate the replacement above." -ForegroundColor Red
    exit 2
  }

  Write-Host ""
  $confirm = Read-Host "  Apply '$Label'? [y/N]"
  if ($confirm -match "^[Yy]$") {
    terraform apply `
      -var-file="..\..\account.auto.tfvars" `
      -var-file="..\..\configs\$Config"
    Write-Host "  ✓ Applied" -ForegroundColor Green
  } else {
    Write-Host "  Skipped — directory: live\$Env\$StackRel" -ForegroundColor Yellow
    Write-Host "  Bootstrap stopped. Re-run manually from that directory when ready." -ForegroundColor Yellow
    Set-Location $RepoRoot
    exit 0
  }

  Set-Location $RepoRoot
}

Write-Host ""
Write-Host ("╔" + ("═" * 54) + "╗") -ForegroundColor Green
Write-Host "║   Snowflake Terraform Bootstrap                      ║" -ForegroundColor Green
Write-Host ("║   ENV: {0,-47}║" -f $Env) -ForegroundColor Green
Write-Host ("╚" + ("═" * 54) + "╝") -ForegroundColor Green
Write-Host ""
Write-Host "  Stacks apply in dependency order."
Write-Host "  Each stack owns its own terraform.tfstate."
Write-Host "  You will be prompted [y/N] before every apply."
Write-Host ""

Invoke-Stack `
  -Label     "Account Governance — Roles" `
  -StackRel  "account_governance\roles" `
  -Config    "create_role.tfvars"

Invoke-Stack `
  -Label     "Platform — Databases" `
  -StackRel  "platform\databases" `
  -Config    "create_database.tfvars"

Invoke-Stack `
  -Label     "Account Governance — Users" `
  -StackRel  "account_governance\users" `
  -Config    "create_users.tfvars"

Invoke-Stack `
  -Label     "Platform — Warehouses" `
  -StackRel  "platform\warehouses" `
  -Config    "create_warehouse.tfvars"

Invoke-Stack `
  -Label     "Platform — Resource Monitors" `
  -StackRel  "platform\resource_monitors" `
  -Config    "create_resource_monitor.tfvars"

Invoke-Stack `
  -Label     "Platform — Storage Integrations S3" `
  -StackRel  "platform\storage_integrations_s3" `
  -Config    "create_storage_integration_s3.tfvars" `
  -Note      "Requires SnowSQL. Confirm snowsql_connection in account.auto.tfvars is configured."

Invoke-Stack `
  -Label     "Workloads — Schemas" `
  -StackRel  "workloads\schemas" `
  -Config    "create_schema.tfvars"

Invoke-Stack `
  -Label     "Platform — Network Rules" `
  -StackRel  "platform\network_rules" `
  -Config    "create_network_rules.tfvars"

Invoke-Stack `
  -Label     "Platform — External Access Integrations" `
  -StackRel  "platform\external_access_integrations" `
  -Config    "create_external_access_integrations.tfvars" `
  -Note      "Requires SnowSQL. Confirm snowsql_connection in account.auto.tfvars is configured."

Invoke-Stack `
  -Label     "Workloads — Stages" `
  -StackRel  "workloads\stages" `
  -Config    "create_stage_s3.tfvars"

Write-Host ""
Write-Host ("╔" + ("═" * 54) + "╗") -ForegroundColor Green
Write-Host "║   Bootstrap complete — all stacks applied            ║" -ForegroundColor Green
Write-Host ("╚" + ("═" * 54) + "╝") -ForegroundColor Green
Write-Host ""
