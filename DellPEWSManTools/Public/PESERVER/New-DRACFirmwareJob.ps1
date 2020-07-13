<#
New-DRACFirmwareJob.ps1 - Gets infor from the ESX host via WSMan API

_author_ = Douglas Roorda _version_ = 1.0


This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
function New-DRACFirmwareJob {
    <#
    .SYNOPSIS
    Describe the function here
    .DESCRIPTION
    Describe the function in more detail
    .EXAMPLE
    Give an example of how to use it
    .EXAMPLE
    Give another example of how to use it
    .PARAMETER computername
    The computer name to query. Just one.
    .PARAMETER logname
    The name of a file to write failed computer names to. Defaults to errors.txt.
    #>
    [CmdletBinding(
                    DefaultParameterSetName='General',
                    PositionalBinding=$false,
                    SupportsShouldProcess=$true,
                    ConfirmImpact='low'
                    )]
    # [OutputType([null])]
    param
    (
        [Parameter(
            Mandatory=$True,
            HelpMessage='iDRAC'
        )]
        $iDRACSession,

        [Parameter(
            Mandatory=$True,
            HelpMessage='Update to deploy to server'
        )]
        $Update,

        $Device,

        [Parameter(
            Mandatory=$True,
            HelpMessage='Credentials for iDRAC'
        )]
        [System.Management.Automation.PSCredential]
        $Credential,

        [String]
        $SourceServer      = "https://downloads.dell.com/",

        [String]
        $LocalCachePath = "$env:temp\DellUpdates\",

        [switch]
        $ignoreCertFailures,

        [switch]
        $LocalCache,

        [Parameter(
            ParameterSetName='Wait'
        )]
		[Switch]
        $Wait,

        [Parameter(
            ParameterSetName='Passthru'
        )]
		[Switch]
        $Passthru
    )

    begin {
        Write-Verbose "-------------Start $($myInvocation.InvocationName) IN '$((Get-MyFunctionLocation).ScriptName)' -----------------"
        Write-Verbose "  From Script:'$($myInvocation.ScriptName)' - At Line:$($myInvocation.ScriptLineNumber) char:$($myInvocation.OffsetInLine)"
        Write-Verbose "  Line '$($myInvocation.Line.Trim())'"
        $myInvocation.BoundParameters.GetEnumerator()  | ForEach-Object { Write-Verbose "  BoundParameter   : '$($_.key)' = '$($_.Value)'" }
        $myInvocation.UnboundArguments | ForEach-Object { Write-Verbose "  UnboundArguments : '$_'" }

        Write-Verbose "------Update--------"
        $Update | out-string | Write-Verbose
        Write-Verbose "------Update.Category--------"
        $Update.Category | out-string | Write-Verbose
        Write-Verbose "--------------------"

        try {
            $UpdateName = "$($Update.path.split("/")[-1])"
            $UpdateURI  = "$SourceServer$($Update.path)"
            $UpdatePath = "$LocalCachePath$(($Update.path.Split("/")| Select-Object -SkipLast 1 ) -join("\"))\"
        } catch {
            Throw "Unable to Parse Update object"
        }

        $WriteProgressParam = @{
            Id               = get-random
            Activity         = $UpdateName
            # status           = "Prepairing"
            status = "Getting Status of existing Jobs"
            PercentComplete  = 0
        }
        write-progress @WriteProgressParam

        # $DracAllJobs = @()
        # $DracCurrentJobs = Get-PEConfigurationJobStatus -iDRACSession $iDRACSession
        # $DracCurrentJobs | Where-Object {$DracAllJobs.InstanceID -notcontains $_.InstanceID} | ForEach-Object {
        #     $_ | Add-Member -MemberType NoteProperty -Name "Visible" -Value $false
        #     $DracAllJobs += $_
        # }
        # $DracAllJobs | where {$_.Visible}

        Try {
            $DracExistingJobs = Get-PEConfigurationJobStatus -iDRACSession $iDRACSession
        } Catch {
            Try {
                $DracExistingJobs = Get-PEConfigurationJobStatus -iDRACSession $iDRACSession
            } Catch {
                Throw $_
            }
        }
        Write-Verbose "------DracExistingJobs--------"
        $DracExistingJobs | Format-Table | out-string | Write-Verbose
        Write-Verbose "----------Update--------------"
        $Update           | Format-Table | out-string | Write-Verbose
        Write-Verbose "------------------------------"
        if ($Device){
            if ($DracExistingJobs | Where-Object {$_.JobStatus -eq 'Scheduled'} | Where-Object {$_.Name -eq "update:$($Device.InstanceID)"}){
                write-progress @WriteProgressParam -Completed
                Write-Warning "Job for this device is already present."
                return
            } else {
                Write-Verbose '------------------------'
                $DracExistingJobs | Where-Object {$_.JobStatus -eq 'Scheduled'} | ForEach-Object{Write-Verbose "$($_.name)"}
                Write-Verbose '------------------------'
                Write-Verbose "'update:$($Device.InstanceID)'"
                Write-Verbose '------------------------'
            }
        }


        $WriteProgressParam.status           = "Checking status of cached install source"
        $WriteProgressParam.PercentComplete  = 10
        write-progress @WriteProgressParam

        Write-Verbose "Checking if '$LocalCachePath' exists"
        if (-not (Test-Path $LocalCachePath)){
            Write-Verbose "Making $LocalCachePath"
            New-Item $LocalCachePath -type directory -ErrorAction Stop | Write-Verbose
        }
        Write-Verbose "Checking if '$UpdatePath' exists"
        if (-not (Test-Path $UpdatePath)){
            Write-Verbose "      Making $UpdatePath"
            New-Item $UpdatePath -type directory -ErrorAction Stop | Write-Verbose
        }
        Write-Verbose "Checking if '$UpdatePath$UpdateName' exists"
        if (Test-Path "$UpdatePath$UpdateName"){
            $UpdateFile = Get-Item -Path $UpdatePath$UpdateName
            if ($Update.size -ne $UpdateFile.Length){
                Write-Verbose "Local instance of update is invalid"
                $UpdateFile | Remove-Item -Force
            }
        }
        if (Test-Path "$UpdatePath$UpdateName") {
            Write-Verbose "Local instance of update exists"
        } else {
            Write-Verbose "    DownLoading $UpdateName"
            $WriteProgressParam.status           = "Downloading update from $SourceServer"
            # $WriteProgressParam.CurrentOperation = "Downloading update from $SourceServer"
            $WriteProgressParam.PercentComplete  = 20
            write-progress @WriteProgressParam
            try {
                (New-Object System.Net.WebClient).DownloadFile($UpdateURI,"$UpdatePath$UpdateName")
            } catch {
                write-progress @WriteProgressParam -Completed
                throw "Unable to download $UpdateName"
            }
        }
        Write-Verbose "    Uploading $UpdateName"
        $WriteProgressParam.status           = "Uploading to iDrac"
        # $WriteProgressParam.CurrentOperation = "Uploading update to iDrac"
        $WriteProgressParam.PercentComplete  = 30
        write-progress @WriteProgressParam
        $DracInfo = @{
            HostName   = $iDRACSession.ComputerName
            Credential = $Credential
        }
        Invoke-RacAdm -DracInfo $DracInfo -command "update -f $UpdatePath$UpdateName" -ignoreCertFailures:$ignoreCertFailures | Write-Verbose
        $DracCurrentJobs = Get-PEConfigurationJobStatus -iDRACSession $iDRACSession
        $DracCurrentJobs | where-object  {$DracAllJobs.InstanceID -notcontains $_.InstanceID} | ForEach-Object {
            $DracJob = $_
            Write-Verbose $DracJob
        }

        # $DracAllJobs = $DracCurrentJobs
        $WriteProgressParam.status           = "Uploading to iDrac Finished"
        $WriteProgressParam.PercentComplete  = 60
        write-progress @WriteProgressParam
        if ($Passthru){
            write-progress @WriteProgressParam -Completed
            return $DracJob
        } elseif ($Wait) {
            $WriteProgressParam.status           = "Waiting for job to Finish Staging/Installing"
            write-progress @WriteProgressParam
            Write-Verbose "      Waiting for job to Finish Staging/Installing"

            Write-Verbose "Wait-PEConfigurationJob -JobID $($DracJob.InstanceID)"
            Try {
                Wait-PEConfigurationJob -JobID $DracJob.InstanceID -iDRACSession $iDRACSession -Activity 'Waiting for Job ...'
            } catch {
                Write-warning $_.exception.message
            }

            if       ($DracJob.JobStatus -eq 'Downloading'){
                if (@('CE','iDRAC with Lifecycle Controller') -contains $update.Category.value) {
                    $WriteProgressParam.status = "Waiting for $($update.Category.value) to shutdown"
                    $WriteProgressParam.PercentComplete  = 80
                    write-progress @WriteProgressParam
                    Write-Verbose "          $($WriteProgressParam.status)"
                    while (Test-Connection -ComputerName $iDRACSession.ComputerName -Count 3 -Quiet -ErrorAction SilentlyContinue) {
                        Start-Sleep -Seconds 1
                    }
                    $WriteProgressParam.status = "Waiting for $($update.Category.value) to reboot"
                    $WriteProgressParam.PercentComplete  = 83
                    write-progress @WriteProgressParam
                    Write-Verbose "          $($WriteProgressParam.status)"
                    while (-not (Test-Connection -ComputerName $iDRACSession.ComputerName -Count 3 -Quiet -ErrorAction SilentlyContinue)) {
                        Start-Sleep -Seconds 1
                    }
                    $WriteProgressParam.status = "Waiting for $($update.Category.value) to finish loading"
                    $WriteProgressParam.PercentComplete  = 85
                    write-progress @WriteProgressParam
                    Write-Verbose "          $($WriteProgressParam.status)"
                    Start-Sleep -Seconds 180
                }
                # $WriteProgressParam.status           = "Rebooting"
                # $WriteProgressParam.PercentComplete  = 90
                # if ($update.Category.value -eq 'CE'){
                #     $WriteProgressParam.status = "Waiting for Chassis Management Controller to reboot"
                #     write-progress @WriteProgressParam
                #     Write-Verbose "Waiting for Chassis Management Controller Reboot"
                #     sleep -s 120
                # }
                # if ($update.Category.value -eq 'iDRAC with Lifecycle Controller'){
                #     $WriteProgressParam.status = "Waiting for iDrac to reboot"
                #     write-progress @WriteProgressParam
                #     Write-Verbose "          Waiting for iDrac Reboot"
                #     sleep -s 180
                #     while ($update.vendorVersion -ne $DracInfo.DCIM.iDRACCardView.FirmwareVersion) {
                #         try {
                #             $DracInfo.DCIM.iDRACCardView = Get-PEDRACInformation -iDRACSession $iDRACSession -ErrorAction Stop
                #         } catch {
                #             write-warning "Error polling iDRAC $($_.exception.message)"
                #             sleep -s 20
                #         }
                #     }
                # }
                # Write-Verbose "        Update Finished Successfully"
            } elseif ($DracJob.JobStatus -eq 'Scheduled'){
                Write-Verbose "        Update Job scheduled for next reboot"
            } else {
                Write-Verbose "        Update Finished with a Status of $($DracJob.JobStatus)"
            }
        #     # $DracCurrentJobs = Get-PEConfigurationJobStatus -iDRACSession $iDRACSession
        #     # $DracAllJobs = $DracCurrentJobs
        }
        write-progress @WriteProgressParam -Completed
    }
    process {
    }
    End {
        # Try {
        #     $DracCurrentJobs = Get-PEConfigurationJobStatus -iDRACSession $iDRACSession
        # } catch {
        #     sleep -s 60
        #     Try {
        #         $DracCurrentJobs = Get-PEConfigurationJobStatus -iDRACSession $iDRACSession
        #     } catch {
        #         write-warning "Error polling iDRAC $($_.exception.message)"
        #     }
        # }
        Write-Verbose "--------------END- $($myInvocation.InvocationName) -----------------"
    }
}
