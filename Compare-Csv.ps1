[CmdletBinding()]
Param(

    [Parameter(Mandatory = $false, HelpMessage = 'Path to Save Log Files')]
    [string]$LogPath,
    [Parameter(Mandatory = $false, HelpMessage = 'Number of threads to run simultaniously.')]
    [int]$ThreadLimit = (Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfLogicalProcessors * 8
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




#-- https://4sysops.com/archives/how-to-create-an-open-file-folder-dialog-box-with-powershell/
$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
    Description = 'Choose a destination folder to save the comparison file to.'
    RootFolder = 'Desktop'
    ShowNewFolderButton = $true
}
$null = $FolderBrowser.ShowDialog()
if($FolderBrowser.SelectedPath -eq ''){
    Write-Error "No folder path selected. Terminating."
    if($PSBoundParameters.Keys -contains 'LogPath'){
        Stop-Transcript
    }
    Exit 2
} else {
    $Destination = $FolderBrowser.SelectedPath
    Write-Verbose "Destination folder will be $Destination"
}



#-- https://mcpmag.com/articles/2016/06/09/display-gui-message-boxes-in-powershell.aspx?m=1
#-- https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.messageboxbuttons?view=windowsdesktop-8.0
#--https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.messageboxicon?view=windowsdesktop-8.0
$msgBoxInput =  [System.Windows.MessageBox]::Show('Choose a Source File to begin comparison. Headers from the Source File will be written to comparison file.','Source File','OKCancel','Information')

if($msgBoxInput -ne 'OK'){
    Write-Error "OK was not selected. Terminating."
    if($PSBoundParameters.Keys -contains 'LogPath'){
        Stop-Transcript
    }
    Exit 2
} else {
    #-- https://4sysops.com/archives/how-to-create-an-open-file-folder-dialog-box-with-powershell/
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        Title = 'Source File'
        InitialDirectory = [Environment]::GetFolderPath('MyComputer')
        Filter = 'SpreadSheet (*.csv)|*.csv'
        Multiselect = $false
    }
    $null = $FileBrowser.ShowDialog()
    if($FileBrowser.FileName -eq ''){
        Write-Error "File was not selected. Terminating."
        if($PSBoundParameters.Keys -contains 'LogPath'){
            Stop-Transcript
        }
        Exit 2
    } else {
        $SourceFile = "$($FileBrowser.FileName)"
        Write-Verbose "SourceFile will be $SourceFile"
    }

}

#-- Will need to make this a function for source and compare on next refactor
#-- https://mcpmag.com/articles/2016/06/09/display-gui-message-boxes-in-powershell.aspx?m=1
#-- https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.messageboxbuttons?view=windowsdesktop-8.0
#-- https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.messageboxicon?view=windowsdesktop-8.0
$msgBoxInput =  [System.Windows.MessageBox]::Show('Choose a file to compare to the source file','Compare File','OKCancel','Information')

if($msgBoxInput -ne 'OK'){
    Write-Error "OK was not selected. Terminating."
    if($PSBoundParameters.Keys -contains 'LogPath'){
        Stop-Transcript
    }
    Exit 2
} else {
    #-- https://4sysops.com/archives/how-to-create-an-open-file-folder-dialog-box-with-powershell/
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        Title = 'Compare File'
        InitialDirectory = [Environment]::GetFolderPath('MyComputer')
        Filter = 'SpreadSheet (*.csv)|*.csv'
        Multiselect = $false
    }
    $null = $FileBrowser.ShowDialog()
    if($FileBrowser.FileName -eq ''){
        Write-Error "File was not selected. Terminating."
        if($PSBoundParameters.Keys -contains 'LogPath'){
            Stop-Transcript
        }
        Exit 2
    } else {
        $CompareFile = "$($FileBrowser.FileName)"
        Write-Verbose "Compare File will be $CompareFile"
    }

}

#-- Create a function for these during next refactor
try{
    Write-Verbose -Message "Importing $SourceFile."
    $SrcFile = Import-Csv -Path $SourceFile -Encoding UTF8
    #-- https://stackoverflow.com/questions/25764366/how-to-get-the-value-of-header-in-csv
    $msgBoxInput =  [System.Windows.MessageBox]::Show('Choose the header to compare in the source file. This should contain the relevant data that exists between the two files.','Source Header','OK','Information')

    $SourceHeader = $SrcFile[0].PSobject.Properties.Name | Out-GridView -Title 'Source Header' -PassThru -ErrorAction Stop

} catch {
    Write-Error "Unable to select Source Header: $($PSitem.Exception.Message)"
    if($PSBoundParameters.Keys -contains 'LogPath'){
        Stop-Transcript
    }
    Exit 2
}

try{
    Write-Verbose -Message "Importing $CompareFile" 
    $CompFile = Import-Csv -Path $CompareFile -Encoding UTF8
    #-- https://stackoverflow.com/questions/25764366/how-to-get-the-value-of-header-in-csv
    $msgBoxInput =  [System.Windows.MessageBox]::Show('Choose the header to compare in the compare file. This should contain the relevant data that exists between the two files.','Compare Header','OK','Information')

    $CompareHeader = $CompFile[0].PSobject.Properties.Name | Out-GridView -Title 'Compare Header' -PassThru -ErrorAction Stop
} catch {
    Write-Error "Unable to select Compare Header: $($PSitem.Exception.Message)"
    if($PSBoundParameters.Keys -contains 'LogPath'){
        Stop-Transcript
    }
    Exit 2
}

#-- Progress bar
$srcCount = $SrcFile.Count
Write-Verbose "Total count of items is $srcCount"
$currentSrcCount = 0




#-- Alias property so that they can be grouped and compared

#$CompFile | Add-Member -MemberType AliasProperty -Name "$SourceHeader" -Value "$CompareHeader"

#-- Combines the 2 csv objects into a single set, then it groups them together based on the Source Header
#-- It will find the groups that have a count greater than or equal to 2 and select the first oject from there
#-- Finally it will spit that out into a csv
#-- compare object does work quickly but doesn't keep the source CSV info like we want
#($SrcFile + $CompFile) | Group-Object -Property "$SourceHeader" | Where-Object{$PSitem.Count -ge 2} | ForEach-Object{$PSItem.Group[0]} | Export-Csv -Path "$Destination\$($timestamp)_compare.csv" -NoTypeInformation -Encoding UTF8 -Force
#-- Getting inconsistent results, will need to go back to the Foreach loop
$SrcFile = $SrcFile | Sort-Object -Property $SourceHeader
$CompFile = $CompFile | Sort-Object -Property $CompareHeader

#-- Create a multi-threaded workload




function Compare-ComparisonFile{
    [CmdletBinding()]
    param(
        $srcItem,
        $SourceHeader,
        $CompFile,
        $CompareHeader,
        $Destination,
        $timestamp
    )

    $compCount = $CompFile.count
    $currentCompCount = 0
    foreach($j in $CompFile){
        $currentCompCount++
        Write-Progress -Activity "Searching $($j.$CompareHeader) as a match." -Status "$currentCompCount out of $compCount" -PercentComplete (($currentCompCount/$compCount) * 100) -Id 2 -ParentId 1

        if($srcItem.$SourceHeader -ieq $j.$CompareHeader){

            Write-Verbose "$($srcItem.$SourceHeader) Matched $($j.$CompareHeader), now appending to comparison csv."
            $srcItem | Export-Csv -Path "$Destination\$($timestamp)_compare.csv" -NoTypeInformation -Encoding UTF8 -Force -Append
            break
        } else {
            Write-Verbose "$($i.$SourceHeader) did not match $($j.$CompareHeader)"
        }

    }
}

#-- https://stackoverflow.com/questions/7162090/how-do-i-start-a-job-of-a-function-i-just-defined
#-- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/start-job?view=powershell-7.4


Foreach($i in $SrcFile){
    $jobs = Get-Job
    $currentSrcCount++
    Write-Progress -Activity "Searching for Matches to $($i.$SourceHeader)" -Status "$currentSrcCount out of $srcCount" -PercentComplete (($currentSrcCount/$srcCount) * 100) -Id 1
    if($jobs.Count -lt $ThreadLimit){
        $GetCompareFunc = $(Get-Command Compare-ComparisonFile).Definition
        Start-Job -ScriptBlock {
            param(
                $srcItem,
                $SourceHeader,
                $CompFile,
                $CompareHeader,
                $Destination,
                $timestamp
            )
            Invoke-Expression "function Compare-ComparisonFile {$using:GetCompareFunc}"
            Compare-ComparisonFile -srcItem $srcItem -SourceHeader $SourceHeader -CompFile $CompFile -CompareHeader $CompareHeader -Destination $Destination -timestamp $timestamp
        } -ArgumentList $i, $SourceHeader, $CompFile, $CompareHeader, $Destination, $timestamp 
    } else {
        Write-Verbose "Hit thread limit of $ThreadLimit. Waiting on Jobs to complete."
        while($jobs.Count -ge $ThreadLimit){
            $jobs = Get-Job
            foreach($t in $jobs){
                if($t.State -eq 'Completed'){
                    Write-Verbose "Job ID $t was complete, now removing job and continuing."
                    Remove-Job -Name $t.Name -ErrorAction SilentlyContinue
                }
            }
            
        }
    }


}

$Status = 'Completed'


# END: Executes Once. Executes Last. Useful for all things after process, like cleaning up after script. Optional.
Write-Verbose -Message "Script completed successfully. File saved to $Destination\$($timestamp)_compare.csv"
if($PSBoundParameters.Keys -contains 'LogPath'){
    Stop-Transcript
}

Return $Status




