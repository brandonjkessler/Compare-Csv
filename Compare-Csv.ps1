
Param(
    [parameter(Mandatory,HelpMessage='Choose a CSV file to start with.')]
    [ValidatePattern('\.csv$')]
    [String]$SourceFile,
    [parameter(Mandatory,HelpMessage='Choose a CSV file to compare against.')]
    [ValidatePattern('\.csv$')]
    [String]$CompareFile,
    [parameter(Mandatory,HelpMessage='Choose where to output a CSV.')]
    [ValidatePattern('\.csv$')]
    [String]$Destination,
    [parameter(Mandatory,HelpMessage='What is the header in the source file.')]
    [ValidatePattern('\.csv$')]
    [String]$SourceHeader,
    [parameter(Mandatory,HelpMessage='What is the header in the compare file.')]
    [String]$CompareHeader


)

Start-Transcript -Path "$PSScriptRoot\$((Get-Date -Format yyyy-MM-dd_HH-mm)).log" -Append

## Validate File types
Write-Host "Validating file is in CSV format."
if($SourceFile.Name -notmatch ".csv"){
    Write-Error "$SourceFile is not in CSV Format. Please only use CSV formatted files."
    Exit 1
}
if($CompareFile.Name -notmatch ".csv"){
    Write-Error "$CompareFile is not in CSV Format. Please only use CSV formatted files."
    Exit 1
}
if($Destination.Name -notmatch ".csv"){
    Write-Error "$Destination is not in CSV format. Please include the .csv extenstion in your name."
    Exit 1
}

## Import the 2 CSV's
$SourceFile = Import-Csv -Path $SourceFile
$CompareFile = Import-CSV -Path $CompareFile

# Set up Source and Compare Header to make sure there's something in the CSV's that match
$SourceHeader =  ($SourceFile | Get-Member | Where-Object{$_ -match "$SourceHeader"}).Name
$CompareHeader = ($CompareFile | Get-Member | Where-Object{$_ -match "$CompareHeader"}).Name



$SourceFile | ForEach-Object{
    Write-Host "Checking $($_.'$SourceHeader')"
     if($(($CompareFile)."$CompareHeader") -eq $($_."$SourceHeader")){
        Write-Host "$($_.'$SourceHeader') Found. Writing to $($Destination)." -ForegroundColor Green
        $_ | Export-Csv -Path $Destination -Append -Encoding UTF8 -NoTypeInformation
     }
 }

 Stop-Transcript