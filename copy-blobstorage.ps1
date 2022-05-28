#region Install AZCopy

# Make sure AZ Copy is installed and is in the path

$AzCopy = get-command "azcopy.exe" -ErrorAction SilentlyContinue
if ($null -eq $AzCopy) {
    Write-Host "AzCopy not found. Downloading..."
    #Download AzCopy
    Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows" -OutFile AzCopy.zip -UseBasicParsing
    #unzip azcopy
    Write-Host "unzip azcopy.zip"
    Expand-Archive ./AzCopy.zip ./AzCopy -Force
    # Copy AzCopy to current dir
    Get-ChildItem ./AzCopy/*/azcopy.exe | Copy-Item -Destination "./AzCopy.exe"
    $AzCopy = "./azcopy.exe"
} else {
    $AZCopy = $AzCopy.source
}
#endregion Install AZCopy

#region Source Blob Storage Information

# Define source, source contains the blob (with file name) and SAS Token
$SourceURI = "https://<storage_account_name>.blob.core.windows.net/"
$SourceBlobContainer = "[container_name]"
$SourceSASToken = "[SAS_Token]"
$SourceFullPath = "$($SourceURI)$($SourceBlobContainer)$($SourceSASToken)"

#endregion source Blob Storage Information

#region Destination Blob Storage Information

# Define destination for fileshare
$DestFullPath = "C:\temp\"

<# Define destination for blob container
$DestStgAccURI ="https://<storage_account_name>.blob.core.windows.net/"
$DestBlobContainer = "[container_name]/"
$DestSASToken = "[SAS_Token]"
$DestFullPath = "$($DestStgAccURI)$($DestBlobContainer)$($DestSASToken)"
#>

#endregion Destination Blob Storage Information


# Get file list from Blob Container
$FileListSource = ./azcopy.exe list $SourceFullPath

# trim it down so that only filename remains
$FileList = $FileListSource | Where-object {$_ -match "Content Length:"} | % {$_.split(";")[0].split(": ")[1]}

#region Copy and Deletion

foreach ($File in $FileList) {
    Write-Host "copy blob from $File to  $($DestFullPath)$File"
    # copy the file to local storage
    $result = ./AzCopy.exe copy "$($SourceURI)$($SourceBlobContainer)/$($File)$($SourceSASToken)" $DestFullPath/ --recursive
    # If the copy appears to be successful delete the source
    $result
    if ($result -contains "Final Job Status: Completed") {
        ./AzCopy.exe remove "$($SourceURI)$($SourceBlobContainer)/$($File)$($SourceSASToken)"
    }
}
#endregion Copy and Deletion
