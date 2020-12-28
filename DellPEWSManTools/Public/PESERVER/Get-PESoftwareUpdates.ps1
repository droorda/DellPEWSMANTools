
function Get-PESoftwareInventory
{
    [CmdletBinding(DefaultParameterSetName='iDRACSession')]
    # [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    Param
    (
        [Parameter(Mandatory, ParameterSetName='iDRACSession')]
        [Alias("s")]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $iDRACSession
        ,
        [string]
        $DellCatalog  = "https://downloads.dell.com/Catalog/Catalog.gz"
        ,
        [string]
        $UpdateStageFolder = "$env:temp\DellUpdates\"
        ,
        [switch]
        $AllowUnsupported
        ,
        [Parameter(Mandatory, ParameterSetName='SoftwareInventory')]
        [Parameter(HelpMessage='Output from Get-PESoftwareInventory')]
        $PESoftwareInventory
        ,
        [Parameter(Mandatory, ParameterSetName='SoftwareInventory')]
        [Parameter(HelpMessage='Output from (Get-PESystemInformation).SystemID')]
        [int]
        $SystemID
        ,
        [String]
        $osCode
    )

    Begin {
    }
    Process
    {
        if ($PSCmdlet.ParameterSetName -eq 'iDRACSession') {
            Write-Verbose "Get-PESoftwareInventory"
            $PESoftwareInventory = (Get-PESoftwareInventory -iDRACSession $iDRACSession -Installed)
            $SystemID = (Get-PESystemInformation -iDRACSession $iDRACSession).SystemID
        }

        Write-Verbose "Getting Dell Catalog"
        $XmlCatalog = Get-DellCatalog -UpdateStageFolder $UpdateStageFolder -DellCatalog $DellCatalog
        Write-Verbose "Comparing Inventory to Catalog "
        Write-Verbose "Version $($XmlCatalog.Manifest.version)"
        Write-Verbose "SystemID - $SystemID"
        $systemIDhex = '{0:X4}' -f [int]$SystemID
        Write-Verbose "systemIDhex - $systemIDhex"

        $SoftwareBundle = $XmlCatalog.SelectNodes("/Manifest/SoftwareBundle[TargetSystems/Brand/Model[@systemID='061B']]")

    }
}

<#

$Credential = get-credential
$HostName   = "dal-dr-esx01-drac.corp.local.eventphotographygroup.com"
. D:\Projects\DellPEWSMANTools\DellPEWSManTools\Public\PESERVER\Get-PESystemInformation.ps1
. D:\Projects\DellPEWSMANTools\DellPEWSManTools\Public\PEDRAC\New-PEDRACSession.ps1
$iDRACSession = New-PEDRACSession -Credential $Credential -HostName $HostName -ignoreCertFailures -erroraction Stop

. D:\Projects\DellPEWSMANTools\DellPEWSManTools\Public\PESERVER\Get-PESoftwareInventory.ps1
. D:\Projects\DellPEWSMANTools\DellPEWSManTools\Private\Initialize-File.ps1
. D:\Projects\DellPEWSMANTools\DellPEWSManTools\Private\Expand-GZip.ps1
. D:\Projects\DellPEWSMANTools\DellPEWSManTools\Private\Get-DellCatalog.ps1

. D:\Projects\DellPEWSMANTools\DellPEWSManTools\Public\PESERVER\Get-PESoftwareUpdates.ps1
Get-PESoftwareUpdates -iDRACSession $iDRACSession

#>