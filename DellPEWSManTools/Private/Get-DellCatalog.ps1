function Get-DellCatalog
{
    [OutputType([xml])]
    Param
    (
        [string]
        $DellCatalog  = "https://downloads.dell.com/Catalog/Catalog.gz"
        ,
        [string]
        $UpdateStageFolder = "$env:temp\DellUpdates\"
    )

    Begin {
        if (-not (Test-Path -PathType Container -Path $UpdateStageFolder)) {
            if (Test-Path -PathType Container -Path (split-path -Path $UpdateStageFolder)) {
                $UpdateStageFolder = New-Item -Path $UpdateStageFolder -ItemType Directory -ErrorAction Stop
            } else {
                Throw "Invalid Dell Update Stage Folder"
            }
        } else {
            $UpdateStageFolder = Get-iTem -path $UpdateStageFolder
        }
    }
    Process
    {
        $inFile  = "${UpdateStageFolder}$(Split-Path -Path $DellCatalog -Leaf)"
        $outFile = ($infile -replace '\.gz$','.xml')
        if ( Test-Path -path $inFile ) { Remove-Item -path $inFile }

        try {
            $remoteLastModified = [System.Net.HttpWebRequest]::Create("$DellCatalog").GetResponse().LastModified -as [DateTime]
        } catch {
            try {
                $remoteLastModified = [System.Net.HttpWebRequest]::Create("$DellCatalog").GetResponse().LastModified -as [DateTime]
            } catch {
                Write-Verbose $_
                throw "Unable to Check for latest Version of $DellCatalog"
            }
        }

        if (Test-Path $outFile){
            Write-Verbose "Age difference of cached catalog $([int]($remoteLastModified - (Get-Item $outFile).LastWriteTime).Totalhours) hr"
            if ([int]($remoteLastModified - (Get-Item $outFile).LastWriteTime).Totalhours -gt 1){
                Remove-Item $outFile -ErrorAction Continue
            } else {
                Write-Verbose "Using Cached Catalog.xml"
            }
        }

        if (-not (Test-Path $outFile)){
            Write-Verbose "Downloading $DellCatalog"
            try {
                (New-Object System.Net.WebClient).DownloadFile($DellCatalog,$inFile)
            } catch {
                Write-Warning "Unable to download the Dell Catalog, Will Retry"
                Start-Sleep -s 300
                try {
                    (New-Object System.Net.WebClient).DownloadFile($DellCatalog,$inFile)
                } catch {
                    Write-Verbose $_
                    throw "Unable to download the Dell Catalog"
                }
            }
            Expand-GZip -FullName $inFile -NewName $outFile
            Remove-Item $inFile -ErrorAction SilentlyContinue
            (Get-Item "$outFile").CreationTime   = $remoteLastModified
            (Get-Item "$outFile").LastAccessTime = $remoteLastModified
            (Get-Item "$outFile").LastWriteTime  = $remoteLastModified
        #    Remove-Item $outFile -ErrorAction SilentlyContinue
        }
        [xml]$XmlCatalog = Get-Content -Path $outFile
        $XmlCatalog
        # $XmlCatalog | Select-XML -Xpath "//Manifest/SoftwareComponent" | Select-Object -ExpandProperty "node"
        if (([int]((get-date) - $remoteLastModified).TotalDays) -gt 45){
            write-Warning "Dell Catalog is $([int]((get-date) - $remoteLastModified).TotalDays) Days old"
        } else {
            Write-Verbose "Dell Catalog is $([int]((get-date) - $remoteLastModified).TotalDays) Days old"
        }

    }
}
