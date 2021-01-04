function Get-PESoftwareUpdateFile
{
    Param
    (
        [string]
        $DellCatalogAddress  = "https://downloads.dell.com"
        ,
        [string]
        $UpdateStageFolder = "$env:temp\DellUpdates\"
        ,
        [System.Xml.XmlElement]
        $SoftwareUpdate
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
    Process {
        $LocalCacheFile = "$UpdateStageFolder$($SoftwareUpdate.path.Replace('/','\'))"
        if (Test-Path $LocalCacheFile) {
            if ((Get-FileHash -Path $LocalCacheFile -Algorithm MD5).Hash -eq $SoftwareUpdate.hashMD5) {
                Return
            } else {
                Remove-Item -Path $LocalCacheFile
            }
        }
        $LocalCachePath = split-path -Path $LocalCacheFile
        [URI]$UpdateURI = "$DellCatalogAddress/$($SoftwareUpdate.path)"
        Write-Verbose "Checking if '$LocalCachePath' exists"
        if (-not (Test-Path $LocalCachePath)){
            Write-Verbose "Making $LocalCachePath"
            New-Item $LocalCachePath -type directory -ErrorAction Stop | Write-Verbose
        }

        Write-Verbose "    DownLoading $UpdateName"
        try {
            (New-Object System.Net.WebClient).DownloadFile($UpdateURI,$LocalCacheFile)
        } catch {
            throw "Unable to download $UpdateName"
        }

    }
    END {
    }
}

