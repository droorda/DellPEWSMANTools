param(
    [String]
    $Task    = 'Build' # build is the default task, add support to deploy later
    ,
    [String]
    $FeedUrl = $Credentials.NuGet.UserName
    ,
    [securestring]
    $ApiKey  = $Credentials.NuGet.Password
    ,
    [Switch]
    $Beta
    ,
    [Switch]
    $Major
    ,
    [Switch]
    $Minor
)

Write-Host "Starting $Task" -ForegroundColor Cyan
if ($Major) {Write-Host "  Major Version" -ForegroundColor Cyan}
if ($Minor) {Write-Host "  Minor Version" -ForegroundColor Cyan}
if ($Beta ) {Write-Host "  Beta Build"    -ForegroundColor Cyan}

# dependencies
Import-Module  -Name PackageManagement
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
if (-not (Get-Module -ListAvailable PSDepend)) {
    & (Resolve-Path "$PSScriptRoot\helpers\Install-PSDepend.ps1")
}
Import-Module PSDepend
$null = Invoke-PSDepend -Path "$PSScriptRoot\build.requirements.psd1" -Install -Import -Force

Set-BuildEnvironment -Force

Invoke-Build -File $PSScriptRoot\InvokeBuild.ps1 -Task $Task -FeedUrl $FeedUrl -ApiKey $ApiKey -Beta:$Beta -Major:$Major -Minor:$Minor