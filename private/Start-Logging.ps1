<#
Enable logging to console and possibly file.

Options/precedence - script param may temporarily override config
1. Script param:
     'console'   - No logging module required, use color 'Write-Log' wrapper
     'default'   - Console + default logfile
     *           - Console + filename
2. If logFile in config and $logTo != console, log to $config.logFile
3. If $logTo == console but we want to send email, log to default file
#>

function Start-Logging {
    param(
        [object] $config,
        [string] $configName,
        [string] $logTo,
        [string] $mailTo
    )

    $logDefault = Join-Path $HOME ".local" "state" "rbackup-${configName}.log" | Out-Path
    $timeFormat = ($config.timeFormat) ? $config.timeFormat : "yyyy-MM-dd HH:mm:ssK"
    $logFormat = "[%{timestamp:+${timeFormat}}] %{level:-7} %{message}"
    $logFile = $null

    if ($logTo) {
        if ($logTo -ne 'console') {
            $logFile = $logTo -eq "default" ? $logDefault : $logTo
        }
    }
    elseif ($config.logFile -and $config.logFile -ne 'console') {
        $logFile = $config.logFile | Out-Path
    }

    if ($mailTo -and -not $logFile) {
        $logFile = $logDefault
    }

    if ($logFile) {
        # Module @ https://github.com/RootITUp/Logging
        # Using this only for logging to file
        if (Get-Module -ListAvailable -Name 'Logging') {
            Import-Module -Name 'Logging'

            if (Test-Path -Path $logFile -PathType Leaf) {
                Write-Host "Truncating log: $logFile"
                Remove-Item -Path $logFile
            }
            Add-LoggingTarget -Name File -Configuration @{
                Format = $logFormat; Level = "INFO"; Path = $logFile
            }
        }

    }

    <#
    ## Separating console logging from file logging.  Using Logging module
    ## only for the latter.  Allows console logging to be synchronous and
    ## fixes confirmation prompts being printed before job commandlines.

    ## I don't need any "quiet" mode for my backups but if someone wanted
    ## one it shouldn't be hard to implement. I might mess with it later.
    ## For now, console logging is loglevel INFO.  Commandlines print at
    ## this level, so the -Interactive flag needs loglevel INFO or higher
    ## to be of any use.
    #>
    function Script:Write-Logger {
        param(
            [Parameter()]
            [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
            [string]$Level = 'INFO',
    
            [Parameter(Position=0, Mandatory)]
            [string]$Message
        )
        $color = switch($Level) {
            "DEBUG"   { 'Green'  }
            "INFO"    { 'Blue'   }
            "WARNING" { 'Yellow' }
            "ERROR"   { 'Red'    }
        }
        Write-Host $Level.PadRight(8) -ForegroundColor $color -NoNewline
        Write-Host "$Message"
        if (Get-Module -Name 'Logging') { Write-Log -Level:$Level $Message }
    }

    # Add to config, used by each job commandline
    $config | Add-Member -MemberType NoteProperty -Name 'logFile' -Value $logFile -Force
}
