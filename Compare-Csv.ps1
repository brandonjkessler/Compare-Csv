
Param(
    [CmdletBinding()]
    [parameter(Mandatory,HelpMessage='Choose a CSV file to start with.')]
    [ValidatePattern('\.csv$')]
    [String]$Source,
    [parameter(Mandatory,HelpMessage='Choose a CSV file to compare against.')]
    [ValidatePattern('\.csv$')]
    [String]$Compare,
    [parameter(Mandatory,HelpMessage='Choose where to output a CSV.')]
    [String]$Destination,
    [parameter(Mandatory,HelpMessage='What is the header in the source file.')]
    [String]$SourceHeader,
    [parameter(Mandatory,HelpMessage='What is the header in the compare file.')]
    [String]$CompareHeader,
    [Parameter(Mandatory = $false, HelpMessage = 'Path to Save Log Files')]
    [string]$LogPath = "$PSScriptRoot"
)

begin{
    #-- BEGIN: Executes First. Executes once. Useful for setting up and initializing. Optional
    if($LogPath -match '\\$'){
        $LogPath = $LogPath.Substring(0,($LogPath.Length - 1))
    }
    Write-Verbose -Message "Creating log file at $LogPath."
    #-- Use Start-Transcript to create a .log file
    #-- If you use "Throw" you'll need to use "Stop-Transcript" before to stop the logging.
    #-- Major Benefit is that Start-Transcript also captures -Verbose and -Debug messages.
    $timestamp = Get-Date -Format yyyy-MM-dd_HH-mm
    Start-Transcript -Path "$LogPath\$($timestamp)_Compare-Csv.log" -Append
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
    Write-Verbose -Message "Importing $SourceFile."
    $SrcFile = Import-Csv -Path $SourceFile
    Write-Verbose -Message "Importing $CompareFile"
    $CompFile = Import-Csv -Path $CompareFile

    # Set up Source and Compare Header to make sure there's something in the CSV's that match
    Write-Verbose -Message "Setting up Source and Compare Headers."
    $SrcHeader =  ($SrcFile | Get-Member | Where-Object{$_ -match "$SourceHeader"}).Name
    Write-Debug -Message "SrcHeader Variable: $SrcHeader"

    $CompHeader = ($CompFile | Get-Member | Where-Object{$_ -match "$CompareHeader"}).Name
    Write-Debug -Message "CompHeader Variable: $CompHeader"



    $SourceFile | ForEach-Object{
        Write-Host "Checking $($_.'$SourceHeader')"
        if($(($CompareFile)."$CompHeader") -eq $($_."$SrcHeader")){
            Write-Host "$($_.'$SourceHeader') Found." -ForegroundColor Green
            try{
                Write-Verbose -Message "Writing information to $($timestamp)_compare.csv located at $Destination"
                $_ | Export-Csv -Path "$Destination\$($timestamp)_compare.csv" -Append -Encoding UTF8 -NoTypeInformation
            } catch {
	            Write-Error $_.Exception.Message
	            Write-Error $_.Exception.ItemName
                $Status = 'Failed'
                Stop-Transcript
                Throw "Script Status: $Status"
            }
        }
    }
    $Status = 'Completed'
}
end{
    # END: Executes Once. Executes Last. Useful for all things after process, like cleaning up after script. Optional.
    Write-Verbose -Message "Script completed successfully. File saved to $Destination\$($timestamp)_compare.csv"
    Stop-Transcript
    Return $Status
}



