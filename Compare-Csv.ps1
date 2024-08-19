[CmdletBinding()]
Param(

    [parameter(Mandatory,HelpMessage='Choose a CSV file to compare against.')]
    [ValidatePattern('\.csv$')]
    [String]$CompareFile,
    [parameter(Mandatory,HelpMessage='Choose where to output a CSV.')]
    [String]$Destination,
    [parameter(Mandatory,HelpMessage='What is the header in the source file.')]
    [String]$SourceHeader,
    [parameter(Mandatory,HelpMessage='What is the header in the compare file.')]
    [String]$CompareHeader,
    [Parameter(Mandatory = $false, HelpMessage = 'Path to Save Log Files')]
    [string]$LogPath
)



$timestamp = Get-Date -Format yyyy-MM-dd_HH-mm

if($PSBoundParameters.Keys -contains 'LogPath'){
    Write-Verbose -Message "Creating log file at $LogPath."
    #-- Use Start-Transcript to create a .log file
    #-- If you use "Throw" you'll need to use "Stop-Transcript" before to stop the logging.
    #-- Major Benefit is that Start-Transcript also captures -Verbose and -Debug messages.
    $LogPath = Join-Path -Path $LogPath -ChildPath "$($timestamp)_Compare-Csv.log"
    Start-Transcript -Path "$LogPath" -Append
}
$Status = 'In Progress'



Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework

#-- https://mcpmag.com/articles/2016/06/09/display-gui-message-boxes-in-powershell.aspx?m=1
#-- https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.messageboxbuttons?view=windowsdesktop-8.0
https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.messageboxicon?view=windowsdesktop-8.0
$msgBoxInput =  [System.Windows.MessageBox]::Show('Choose a Source File','Source File','OKCancel','Information')

if($msgBoxInput -ne 'OK'){
    Write-Error "OK was not selected. Terminating."
    Stop-Transcript
    Exit 2
} else {
    #-- https://4sysops.com/archives/how-to-create-an-open-file-folder-dialog-box-with-powershell/
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        Title = 'Source File'
        InitialDirectory = [Environment]::GetFolderPath('MyComputer')
        Filter = 'SpreadSheet (*.csv)|*.csv'
    }
    $null = $FileBrowser.ShowDialog()
    $SourceFile = $FileBrowser.File
    Write-Verbose "SourceFile will be $SourceFile"
}



    ## Import the 2 CSV's
    
    Write-Verbose -Message "Importing $CompareFile" 
    $CompFile = Import-Csv -Path $CompareFile | Sort-Object -Property $CompareHeader -Unique
    $CompFile | Add-Member -MemberType AliasProperty -Name "$SourceHeader" -Value "$CompareHeader"
    Write-Verbose -Message "Importing $SourceFile."
    $SrcFile = Import-Csv -Path $SourceFile | Sort-Object -Property $SourceHeader -Unique

    #-- Combines the 2 csv objects into a single set, then it groups them together based on the Source Header
    #-- It will find the groups that have a count greater than or equal to 2 and select the first oject from there
    #-- Finally it will spit that out into a csv
    ($SrcFile + $CompFile) | Group-Object -Property "$SourceHeader" | Where-Object{$PSitem.Count -ge 2} | ForEach-Object{$PSItem.Group[0]} | Export-Csv -Path "$Destination\$($timestamp)_compare.csv" -NoTypeInformation -Encoding UTF8 -Force

    $Status = 'Completed'
    

    # END: Executes Once. Executes Last. Useful for all things after process, like cleaning up after script. Optional.
    Write-Verbose -Message "Script completed successfully. File saved to $Destination\$($timestamp)_compare.csv"
    if($PSBoundParameters.Keys -contains 'LogPath'){
        Stop-Transcript
    }

    Return $Status




