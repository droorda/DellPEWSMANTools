<#
Invoke-RacAdm.ps1 -

_author_ = Douglas Roorda _version_ = 1.0


This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
$ScriptPath = split-path $Script:MyInvocation.MyCommand.Path -parent

function Invoke-RacAdm {
    [CmdletBinding()]
    Param(
        $racexe            = "$ScriptPath\BIN\rac5\racadm.exe"
        ,
        $DracInfo
        ,
        [switch]$ignoreCertFailures
        ,
        [string]$command
        ,
        [Switch]$ReturnData
        ,
        [int]$TimeOut = 90000
        ,
        [int]$RetryCount = 6
        ,
        [int]$RetryDelay = 300
    )
    begin {
        Write-Verbose "-------------Start $($myInvocation.InvocationName) IN '$((Get-MyFunctionLocation).ScriptName)' -----------------"
        Write-Verbose "  From Script:'$($myInvocation.ScriptName)' - At Line:$($myInvocation.ScriptLineNumber) char:$($myInvocation.OffsetInLine)"
        Write-Verbose "  Line '$($myInvocation.Line.Trim())'"
        $myInvocation.BoundParameters.GetEnumerator()  | ForEach-Object { Write-Verbose "  BoundParameter   : '$($_.key)' = '$($_.Value)'" }
        $myInvocation.UnboundArguments | ForEach-Object { Write-Verbose "  UnboundArguments : '$_'" }

        @($racexe) | foreach-object {
            if (Test-path ($_)) {
                write-Verbose "Verified Access to '$_'"
            } else {
                throw "Unable to access '$_'"
            }
        }

        for($i=0; $i -le $RetryCount; $i++){
            write-verbose "racadm command attempt $($i + 1)"
            $racArgs = @()
            if (-not $ignoreCertFailures){
                $racArgs += '-S'
            }
            $racArgs += '-r'
            $racArgs += $DracInfo.HostName
            $racArgs += '-u'
            $racArgs += $DracInfo.Credential.UserName
            $racArgs += '-p'
            $racArgs += $DracInfo.Credential.GetNetworkCredential().Password
            $racArgs += $command

            # $return = &$racexe -S -r $($DracInfo.HostName) -u $($DracInfo.Credential.UserName) -p $($DracInfo.Credential.GetNetworkCredential().Password) $($command.split(" ")) 2>&1

            Write-Verbose "Invoke-Executable -sExeFile $racexe -cArgs ($($racArgs -join ',')) -TimeOut $TimeOut -Verbose"
            $Results = Invoke-Executable -sExeFile $racexe -cArgs $racArgs -TimeOut $TimeOut -Verbose


            if ($Results.ExitCode -ne 0) {
                write-warning "Attempt $($i + 1)`n         Error $($Results.ExitCode) on $($DracInfo.HostName) running command $command`n         $($Results.StdErr)`n         $($Results.StdOut)"
                Start-Sleep -s $RetryDelay
                # if ($i -eq 3) {
                #     write-warning "Triggering Reset of iDRAC"
                #     Restart-DRAC $DracInfo -ignoreCertFailures:$ignoreCertFailures

                # }
                return $Results.ExitCode
            } else {
                Write-Verbose "Command Succeded"
                # Start-Sleep -s 30
                if ($ReturnData) {
                    return (ConvertFrom-RacAdm $Results.StdOut)
                } else {
                    return $Results.ExitCode
                }
            }
        }
    }
    End {
        Write-Verbose "--------------END- $($myInvocation.InvocationName) -----------------"
    }
}
