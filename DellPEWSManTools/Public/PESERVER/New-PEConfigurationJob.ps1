<#
New-PETargetedConfigurationJob.ps1 - New PE targeted configuration job.

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com> _version_ = 1.0

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>

Function New-PEConfigurationJob
{
    [CmdletBinding(DefaultParameterSetName='General',
                    SupportsShouldProcess=$true,
                    ConfirmImpact='low')]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory, ParameterSetName='General')]
        [Parameter(Mandatory, ParameterSetName='Passthru')]
        [Parameter(Mandatory, ParameterSetName='Wait')]
        [Alias("s")]
        [ValidateNotNullOrEmpty()]
        $iDRACSession,

        [Parameter(Mandatory,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   ValueFromRemainingArguments=$false,
                   ParameterSetName='General')]
        [Parameter(ParameterSetName='Passthru')]
        [Parameter(ParameterSetName='Wait')]
        $CimClass
        #EG: DCIM_BIOSService
        ,

        [Parameter(Mandatory,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   ValueFromRemainingArguments=$false,
                   ParameterSetName='General')]
        [Parameter(ParameterSetName='Passthru')]
        [Parameter(ParameterSetName='Wait')]
        $InstanceID
        #EG: System.Embedded.1
        ,

        [string]$Namespace = 'root\dcim',

        [Parameter(ParameterSetName='General')]
        [Parameter(ParameterSetName='Passthru')]
        [Parameter(ParameterSetName='Wait')]
        [ValidateSet('None','PowerCycle','Graceful','Forced')]
        $RebootType = 'None',

        [Parameter(ParameterSetName='General')]
        [Parameter(ParameterSetName='Passthru')]
        [Parameter(ParameterSetName='Wait')]
        [Bool]$RebootRequired,

        [Parameter(ParameterSetName='General')]
        [Parameter(ParameterSetName='Passthru')]
        [Parameter(ParameterSetName='Wait')]
        [String] $StartTime = 'TIME_NOW',

        [Parameter(ParameterSetName='General')]
        [Parameter(ParameterSetName='Passthru')]
        [Parameter(ParameterSetName='Wait')]
        [String] $UntilTime,

        [Parameter(ParameterSetName='Wait')]
        [Switch] $Wait,

        [Parameter(ParameterSetName='Passthru')]
        [Switch] $Passthru
    )

    Begin
    {
        write-Verbose "New-PEConfigurationJob -iDRACSession $iDRACSession -CimClass $CimClass -InstanceID $InstanceID"
        $properties=@{}
        (Get-CimInstance -CimSession $iDRACSession -ClassName $CimClass -Namespace $Namespace).PSObject.Properties |
                Where-Object {@('SystemCreationClassName','SystemName','CreationClassName','Name') -contains $_.name} |
                Foreach-Object {
                    Write-Verbose "CIM Property `"$($_.name)`" = $($_.value)"
                    $properties[$_.name] = $_.value
                }
        $instance = New-CimInstance -ClassName $CimClass -Namespace $Namespace -ClientOnly -Key @($properties.keys) -Property $properties

        $Parameters = @{
            Target = $InstanceID
            ScheduledStartTime = $StartTime
        }

        if (-not ($RebootType -eq 'None'))
        {
            $Parameters.Add('RebootJobType',([ConfigJobRebootType]$RebootType -as [int]))
        }

        if ($UntilTime)
        {
            $Parameters.Add('UntilTime',$UntilTime)
        }

        Write-Verbose "Parameters:"
        Write-Verbose ($Parameters | Out-String)
    }

    Process
    {
        if ($PSCmdlet.ShouldProcess($($iDRACSession.ComputerName),'create targeted configuration job'))
        {
            if ($Server.iDRACSession.SystemGeneration -gt 11){
                $Job = Invoke-CimMethod -InputObject $instance -MethodName CreateTargetedConfigJob -CimSession $idracsession -Arguments $Parameters
            } else {
                $Job = Invoke-CimMethod -InputObject $instance -MethodName CreateConfigJob -CimSession $idracsession #-Arguments $Parameters
            }
            if ($Job.ReturnValue -eq 4096)
            {
                if ($PSCmdlet.ParameterSetName -eq 'Passthru')
                {
                    $Job
                }
                elseif ($PSCmdlet.ParameterSetName -eq 'Wait')
                {
                    Write-Verbose 'Starting configuration job ...'
                    Wait-PEConfigurationJob -JobID $Job.Job.EndpointReference.InstanceID -Activity 'Performing BIOS Configuration ..'
                }
            }
            else
            {
                Write-Error $Job.Message
            }
        }
    }
}
