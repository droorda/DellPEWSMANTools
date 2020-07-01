<#
New-PEDRACSession.ps1 - Creates a new PE DRAC session.

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com> _version_ = 1.0
_updated_ - Doug Roorda <droorda@gmail.com> _version_ = 1.1

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
function New-PEDRACSession
{
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='low')]
    [OutputType([Microsoft.Management.Infrastructure.CimSession])]
    param (
        [Parameter (Mandatory)]
        [PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter (Mandatory,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    ParameterSetName='ByIP')]
        [ValidateScript({[System.Net.IPAddress]::TryParse($_,[ref]$null)})]
        [string] $IPAddress,

        [Parameter (Mandatory,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    ParameterSetName='ByName')]
        [ValidateScript({
                        try {
                            if ([System.Net.DNS]::GetHostByName($_).AddressList.IPAddressToString.count -gt 0) {$true} else {$false}
                        } catch {
                            $false
                        }
                    })]
        [string] $HostName,

        [Parameter (
                    ParameterSetName='ByName')]
        [switch] $IgnoreCertFailures,


        [Parameter()]
        [int] $MaxTimeout = 60
    )

    Begin {
        $Params = @{
            Encoding = 'Utf8'
            UseSsl = $true
        }
        if ($IPAddress -or $IgnoreCertFailures)
        {
            $Params.SkipCACheck = $true
            $Params.SkipCNCheck = $true
            $Params.SkipRevocationCheck = $true
            $ComputerName = $IPAddress
        } else {
            $ComputerName = $HostName
        }

        $cimOptions   = New-CimSessionOption @Params
    }

    Process
    {
        Write-Verbose "Creating iDRAC session..."

        if ($PSCmdlet.ShouldProcess($IPAddress,'Create iDRAC session'))
        {
            try
            {
                $session = New-CimSession -Authentication Basic -Credential $Credential -ComputerName $ComputerName -Port 443 -SessionOption $cimOptions -OperationTimeoutSec $MaxTimeout -ErrorAction Stop
            } catch {
                try {
                    Start-Sleep -s 10
                    $session = New-CimSession -Authentication Basic -Credential $Credential -ComputerName $ComputerName -Port 443 -SessionOption $cimOptions -OperationTimeoutSec $MaxTimeout -ErrorAction Stop
                } catch {
                    try {
                        Start-Sleep -s 60
                        $session = New-CimSession -Authentication Basic -Credential $Credential -ComputerName $ComputerName -Port 443 -SessionOption $cimOptions -OperationTimeoutSec $MaxTimeout -ErrorAction Stop
                    } catch {
                        $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                            ([Exception]::new("New-PEDRACSession Failed : $($_.Exception.Message)")),
                            "1",
                            [System.Management.Automation.ErrorCategory]::NotSpecified,
                            $null # $TargetObject # usually the object that triggered the error, if possible
                        ))
                        return

                    }
                }
            }
            if ($session)
            {
                $sysInfo = Get-PESystemInformation -iDRACSession $Session
                Add-Member -inputObject $Session -Name SystemGeneration -Value $([int](([regex]::Match($sysInfo.SystemGeneration,'\d+')).groups[0].Value)) -MemberType NoteProperty
                Add-Member -inputObject $Session -Name SystemType -Value $([regex]::Match($sysInfo.SystemGeneration,'(?<=\s).*').groups[0].Value) -MemberType NoteProperty
                return $session
            }
        }
    }

    End
    {

    }
}