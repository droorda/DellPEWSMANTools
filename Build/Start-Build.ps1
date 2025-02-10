param(
    [String]
    $Task    = 'Build' # build is the default task, add support to deploy later
    ,
    [String]
    $FeedUrl = $Credentials.NuGet.UserName
    ,
    [String]
    $ApiKey  = $Credentials.NuGet.GetNetworkCredential().Password
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

$env:FeedUrl = $FeedUrl
$env:ApiKey  = $ApiKey
$env:Beta    = $Beta

# dependencies
Import-Module  -Name PackageManagement
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
if(-not (Get-Module -ListAvailable PSDepend))
{
    & (Resolve-Path "$PSScriptRoot\helpers\Install-PSDepend.ps1")
}
Import-Module PSDepend
$null = Invoke-PSDepend -Path "$PSScriptRoot\build.requirements.psd1" -Install -Import -Force

Set-BuildEnvironment -Force

Invoke-Build -File $PSScriptRoot\InvokeBuild.ps1 -Task $Task