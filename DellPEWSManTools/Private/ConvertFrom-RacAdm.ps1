function ConvertFrom-RacAdm {
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
        SupportsShouldProcess=$True,
        ConfirmImpact='Low',
        DefaultParameterSetName = 'None'
    )]
    # [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param (
        [Parameter(Mandatory=$True)]
        [String]$Text
    )

    begin {
        Write-Verbose "-------------Start $($myInvocation.InvocationName) IN '$((Get-MyFunctionLocation).ScriptName)' : $(Get-Date -Format o) -----------------"
        Write-Verbose "  From Script:'$($myInvocation.ScriptName)' - At Line:$($myInvocation.ScriptLineNumber) char:$($myInvocation.OffsetInLine)"
        Write-Verbose "  Line '$($myInvocation.Line.Trim())'"
        $myInvocation.BoundParameters.GetEnumerator()  | ForEach-Object { Write-Verbose "  BoundParameter   : '$($_.key)' = '$($_.Value)'" }
        $myInvocation.UnboundArguments | ForEach-Object { Write-Verbose "  UnboundArguments : '$_'" }
        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }
        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }
    }
    process {

        [Array]$Text = $Text -Split [Environment]::NewLine

        $Object = [Ordered]@{}
        if ($Text[0] -Match '^Security Alert:.*') {
            if ($Text[1] -Match '^Continuing execution..*') {
                Write-Verbose "$($Text[0])`n         $($Text[1])"
                $Text = $Text | Select-Object -Skip 2
            } else {
                Write-Verbose $Text[0]
                $Text = $Text | Select-Object -Skip 1
            }
        }

        for ($i = 0; $i -lt $Text.Count;) {
            While ((-not "$($Text[$i])".Trim()) -and ($i -lt $Text.Count)) {
                $i++
            }
            if ("$($Text[$i])".Trim() -match '^([^:=]+):$') {
                $Section = $Matches[1]
                $SectionData = [Ordered]@{}
                $i++
                While ("$($Text[$i])".Trim() -match '^([^ ].+) = ?(.*)$') {
                    $ParamName = "$($Matches[1])".Trim()
                    $SectionData[$ParamName] = $Matches[2]
                    $i++
                    While ($Text[$i] -match '^( +)(.*) = ?(.*)') {
                        $ParamName2 = "$($Matches[2])".TrimEnd()
                        $ParamName2 = "$($ParamName.Substring(0,($Matches[1].length)))$ParamName2"
                        $SectionData[$ParamName2] = $Matches[3]
                        $i++
                    }
                }
                $Object[$Section] = [PSCustomObject]$SectionData

            } else {
                Write-Warning $Text[$i]
                $i++
            }
        }

        [PSCustomObject]$Object

        # $Text | ForEach-Object {
        #     if ($_ -match '.+:$') {

        #     }
        # }

        # try {
        #     Throw "Test"
        # } catch {
        #     $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
        #         ([Exception]::new("Test: $($_.Exception.Message)")),
        #         "1",
        #         [System.Management.Automation.ErrorCategory]::NotSpecified,
        #         $PSItem # $TargetObject # usually the object that triggered the error, if possible
        #     ))

        # }
        # if ($PSCmdlet.ShouldProcess("ShouldProcess?")) {
        #     try {
        #         Throw "Test"
        #     } catch {
        #         Write-Warning "$($_.Exception.Message)`n$($_.InvocationInfo.PositionMessage)"
        #         $PSCmdlet.ThrowTerminatingError($PSItem)
        #         # Throw $PSItem
        #     }
        # }
    }
    End {
        Write-Verbose "--------------END- $($myInvocation.InvocationName) : $(Get-Date -Format o) -----------------"
    }
}
