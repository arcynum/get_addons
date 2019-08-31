
# Function to load the configuration file for use
Function LoadConfig {
    param([string]$Filename)

    $jsonContent = Get-Content -Raw -Path $Filename | ConvertFrom-Json
    return $jsonContent
}

# Function which returns the version of the addon from the TOC file
Function GetAddonVersion {
    param([string]$Path)

    $tocContent = Select-String -Path $Path -Pattern '(?:Version:?)\s(.*)$'
    $version = $tocContent.Matches.Groups[1].Value

    return $version
}

# Get the addon folder name
Function GetDownloadName {
    param($Link)

    # If its one of the shitty cf urls, trim the file off the end
    $cleanLink = $Link -replace "/file", ""

    # Create a tidy download name based on the cleaned up version
    $downloadPath = Split-Path -Path $cleanLink -Leaf
    $splitPath = $downloadPath -split "\."
    return $splitPath[0]
}

# Loop until first layer of TOC files
# Cap the depth at 5 layers to prevent an infinite loop
Function FindTocFiles {
    param([string]$Path)

    $i = 1
    $files = 0
    Do {
        $files = Get-ChildItem -Path $Path -Filter *.toc -Recurse -Depth $i
        $i++
    } While ($files.Count -eq 0 -And $files.Count -le 5)

    return $files
}

# Empty the extract folder
Function EmptyExtracts {
    Remove-Item –path "$PSScriptRoot\Extract\*" -Recurse -Force
}

# Download github versions of addons
Function GithubDownload {
    param(
        [string]$Branch,
        [string]$Release,
        [Parameter(Mandatory=$true)][string]$Url
    )

    # Find the github user and repo in the url
    $urlMatch = $Url | Select-String -Pattern 'github.com\/(.*)\/(.*)'
    $user = $urlMatch.Matches.Groups[1].Value
    $repo = $urlMatch.Matches.Groups[2].Value   

    # Pull the information from the github API
    $apiUrl = ""

    # If the download request is for a specific release
    if ($Release) {
        $apiUrl = "https://api.github.com/repos/$user/$repo/releases/$Release"

        # Fetch the information about the release
        $WebResponse =  Invoke-RestMethod -Method 'Get' -Uri $apiUrl

        # If the release has a download URL
        if ($WebResponse.assets.browser_download_url) {
            return $WebResponse.assets.browser_download_url
        }

        # If the release has a zipball url only
        if ($WebResponse.zipball_url) {
            return $WebResponse.zipball_url
        }
    }
    
    # If the download is for a specific branch
    elseif ($Branch) {
        return "https://github.com/$user/$repo/archive/$Branch.zip"
    }

    # Otherwise just grab the master archive
    else {
        return "https://github.com/$user/$repo/archive/master.zip"
    }
}

# Load the configuration
$CONFIG = LoadConfig -Filename "config.json"

# Create the extract folder - if not exist
if (!(Test-Path "$PSScriptRoot\Extract")) {
    New-Item -Path "$PSScriptRoot" -Name "Extract" -ItemType "directory" | Out-Null
}

# Create the archive folder - it not exist
if (!(Test-Path "$PSScriptRoot\Archive")) {
    New-Item -Path "$PSScriptRoot" -Name "Archive" -ItemType "directory" | Out-Null
}

# Specify the location of your wow classic addon folder.
$WOW_CLASSIC_FOLDER = $CONFIG.wow_classic_folder
$WOW_CLASSIC_ADDONS_FOLDER = "$WOW_CLASSIC_FOLDER\Interface\AddOns"
$WOW_CLASSIC_WTF_FOLDER = "$WOW_CLASSIC_FOLDER\WTF"

# Create a backup folder in the archive folder
$timestamp = Get-Date -Format "yyyy_MM_dd_HH_mm_ss"
New-Item -Path "$PSScriptRoot\Archive\" -Name $timestamp -ItemType "directory" | Out-Null

# Backup the current wow WTF folder
Copy-Item "$WOW_CLASSIC_WTF_FOLDER" -Destination "$PSScriptRoot\Archive\$timestamp" -Recurse -Force

# Clear the extract scratch folder
EmptyExtracts

# Loop through the list of addons to check
$CONFIG.addons | ForEach-Object {
    Write-Host "Processing: $($_.url)"

    # Switch to determine the type of download
    $downloadLink = ""

    if ($_.service -eq "github") {
        $downloadLink = GithubDownload -Release $_.release -Branch $_.branch -Url $_.url
    }
    else {
        $downloadLink = $_.url
    }

    # Get the extract and download path
    # $downloadPath = GetDownloadName -Link $downloadLink
    $downloadPath = GetDownloadName -Link $_.url

    # Download the located version of the file
    Invoke-WebRequest -Uri $downloadLink -OutFile "$PSScriptRoot\Extract\$downloadPath.zip"

    # Extract the newer version of the addon into the folder
    Expand-Archive -Path "$PSScriptRoot\Extract\$downloadPath.zip" -DestinationPath "$PSScriptRoot\Extract\$downloadPath"

    # File the folders which contain the toc files
    $tocFiles = FindTocFiles -Path "$PSScriptRoot\Extract\$downloadPath"

    # Loop through all of the top level addons found
    $tocFiles | ForEach-Object {
        $tocName = $_.Name
        $tocDirectory = $_.Directory

        # Get the name of the addons extracted folder
        $addonFolderName = Split-Path -Path $tocDirectory -Leaf

        # Check if the addon is currently installed
        if (!(Test-Path -Path "$WOW_CLASSIC_ADDONS_FOLDER\$addonFolderName")) {
            Write-Host "$addonFolderName is not currently installed. Installing now."

            # Install the new addon
            Copy-Item $tocDirectory -Destination $WOW_CLASSIC_ADDONS_FOLDER -Recurse -Force

            # Break out of the current loop, as this is a newly installed addon
            return
        }

        # Search for the addon in the wow addons folder
        # Hash the downloaded toc file
        $downloadedTocHash = Get-FileHash "$tocDirectory\$tocName"

        # Hash the currently installed toc file
        $installedTocHash = Get-FileHash "$WOW_CLASSIC_ADDONS_FOLDER\$addonFolderName\$tocName"

        # If the downloaded version does not match the installed version, then replace it
        if ($downloadedTocHash.Hash -ne $installedTocHash.Hash) {

            # Let the user know the addon is out of date
            Write-Host "$addonFolderName is out of date - installing the latest version"

            # Backup the exist addon
            Copy-Item "$WOW_CLASSIC_ADDONS_FOLDER\$addonFolderName" -Destination "$PSScriptRoot\Archive\$timestamp\Addons\$addonFolderName" -Recurse -Force

            # Delete the installed version
            Remove-Item –path "$WOW_CLASSIC_ADDONS_FOLDER\$addonFolderName" -Recurse -Force

            # Install the new version
            Copy-Item $tocDirectory -Destination $WOW_CLASSIC_ADDONS_FOLDER -Recurse -Force


        } else {
            Write-Host "$addonFolderName is already up to date"
        }

    }

}

# Clean up the extracted folder contents
EmptyExtracts
