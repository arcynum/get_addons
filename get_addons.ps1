
# Create the extract folder - if not exist
if (!(Test-Path "$PSScriptRoot\Extract")) {
    New-Item -Path "$PSScriptRoot" -Name "Extract" -ItemType "directory"
}

# Create the archive folder - it not exist
if (!(Test-Path "$PSScriptRoot\Archive")) {
    New-Item -Path "$PSScriptRoot" -Name "Archive" -ItemType "directory"
}

# Specify the location of your wow classic addon folder.
$WOW_CLASSIC_FOLDER = "C:\Users\Chris Hamilton\Games\Battle.net\World of Warcraft\_classic_\"
$WOW_CLASSIC_ADDONS_FOLDER = "$WOW_CLASSIC_FOLDER\Interface\AddOns"
$WOW_CLASSIC_WTF_FOLDER = "$WOW_CLASSIC_FOLDER\WTF"

# Create a backup folder in the archive folder
$timestamp = Get-Date -Format "yyyy_MM_dd_HH_mm_ss"
New-Item -Path "$PSScriptRoot\Archive\" -Name "$timestamp" -ItemType "directory"

# Backup the current wow addons folder
# Copy-Item "$WOW_CLASSIC_ADDONS_FOLDER" -Destination "$PSScriptRoot\Archive\$timestamp" -Recurse -Force
# Copy-Item "$WOW_CLASSIC_WTF_FOLDER" -Destination "$PSScriptRoot\Archive\$timestamp" -Recurse -Force

# Clear the extract scratch folder
Remove-Item –path "$PSScriptRoot\Extract\*" -Recurse -Force

# The github URL of the addon
$url = 'https://api.github.com/repos/AeroScripts/QuestieDev/releases/latest'

# Fetch the information about the release
$WebResponse =  Invoke-RestMethod -Method 'Get' -Uri $url

# Get the url and name of the latest file
$addonFile = $WebResponse.assets.browser_download_url
$addonFileName = $WebResponse.assets.name

# Download the located version of the file
Invoke-WebRequest -Uri $addonFile -OutFile "$PSScriptRoot\$addonFileName"

# Extract the newer version of the addon into the folder
Expand-Archive -Path "$PSScriptRoot\$addonFileName" -DestinationPath "$PSScriptRoot\Extract\$addonFileName"

# File the folders which contain the toc files
$tocFiles = Get-ChildItem -Path "$PSScriptRoot\Extract\$addonFileName" -Filter *.toc -Recurse -Depth 1
$tocFiles | ForEach-Object { 
    $tocName = $_.Name
    $tocDirectory = $_.Directory
    $tocBaseName = Write-Host $_.BaseName

    # Search for the addon in the wow addons folder
    # Parse the located toc file
    $tocContent = Select-String -Path "$tocDirectory\$tocName" -Pattern '(?:Version:)\s(.*)$'
    $downloadedVersion = $tocContent.Matches.Groups[1].Value

}

# Check if the newest version is up to date

# Delete the older version of the file

# Delete the extracted folder