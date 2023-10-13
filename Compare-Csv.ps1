[CmdletBinding()]
Param(
    [parameter(Mandatory,HelpMessage='Choose a CSV file to start with.')]
    [ValidatePattern('\.csv$')]
    [String]$SourceFile,
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



begin{

    Function Write-CustomEventLog{
        [cmdletbinding()]
        param(
            [string]$Message,
            [int]$ID = 0001,
            [int]$Category = 0,
            [string]$EventSource = "Custom Event Log"
        )
        if ([System.Diagnostics.EventLog]::Exists('Application') -eq $False -or [System.Diagnostics.EventLog]::SourceExists($EventSource) -eq $False){
            New-EventLog -LogName Application -Source $EventSource  | Out-Null
        }
        Write-EventLog -LogName Application -Source $EventSource -EntryType Information -EventId $ID -Message $Message -Category $Category
    }

    $timestamp = Get-Date -Format yyyy-MM-dd_HH-mm

    #-- BEGIN: Executes First. Executes once. Useful for setting up and initializing. Optional
    if($PSBoundParameters.Keys -contains 'LogPath'){
        Write-Verbose -Message "Creating log file at $LogPath."
        #-- Use Start-Transcript to create a .log file
        #-- If you use "Throw" you'll need to use "Stop-Transcript" before to stop the logging.
        #-- Major Benefit is that Start-Transcript also captures -Verbose and -Debug messages.
        $LogPath = Join-Path -Path $LogPath -ChildPath "$($timestamp)_Compare-Csv.log"
        Start-Transcript -Path "$LogPath" -Append
    }
    $Status = 'In Progress'

}
process{
    #-- PROCESS: Executes second. Executes multiple times based on how many objects are sent to the function through the pipeline. Optional.
    ##-- Test if files exist
    Write-Verbose -Message "Testing if $SourceFile exists."
    if((Test-Path -Path $SourceFile) -ne $true){
        $Status = 'Failed'
        Write-Error "$SourceFile does not exist."
        Stop-Transcript
        Throw "Script Status: $Status"

    }

    Write-Verbose -Message "Testing if $CompareFile exists."
    if((Test-Path -Path $CompareFile) -ne $true){
        $Status = 'Failed'
        Write-Error "$CompareFile does not exist."
        Stop-Transcript
        Throw "Script Status: $Status"
    }


    ## Import the 2 CSV's
    
    Write-Verbose -Message "Importing $CompareFile" 
    $CompFile = Import-Csv -Path $CompareFile
    $CompFile | Add-Member -MemberType AliasProperty -Name "$SourceHeader" -Value "$CompareHeader"
    Write-Verbose -Message "Importing $SourceFile."
    $SrcFile = Import-Csv -Path $SourceFile

    #-- Combines the 2 csv objects into a single set, then it groups them together based on the Source Header
    #-- It will find the groups that have a count greater than or equal to 2 and select the first oject from there
    #-- Finally it will spit that out into a csv
    ($SrcFile + $CompFile) | Group-Object -Property "$SourceHeader" | Where-Object{$PSitem.Count -ge 2} | ForEach-Object{$PSItem.Group[0]} | Export-Csv -Path "$Destination\$($timestamp)_compare.csv" -NoTypeInformation -Encoding UTF8 -Force

    $Status = 'Completed'
    
}
end{
    # END: Executes Once. Executes Last. Useful for all things after process, like cleaning up after script. Optional.
    Write-Verbose -Message "Script completed successfully. File saved to $Destination\$($timestamp)_compare.csv"
    if($PSBoundParameters.Keys -contains 'LogPath'){
        Stop-Transcript
    }

    Return $Status
}



