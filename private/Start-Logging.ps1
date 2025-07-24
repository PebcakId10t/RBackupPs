<#
Start logging to console.  If logging to file has not been explicitly
disabled, start logging to file if set in script args or config.

Logging options, order of precedence:
1. script param (valid options: file name, "none", or "default")
   ("none" disables logging to file just for this invocation, even if
   logFile is set in config, "default" logs to default defined below)
2. "logFile" defined in config
3. default log file if -MailTo specified but no logFile given

using https://github.com/RootITUp/Logging
#>
function Start-Logging {
    param(
        [object] $config,
        [string] $configName,
        [string] $logFile,
        [string] $mailTo
    )

    $logTo = $null
    $logDefault = Join-Path $HOME ".local" "state" "rbackup-${configName}.log" | Out-Path

    if ($logFile) {
        if ($logFile -ne "none") {
            $logTo = ($logFile -eq "default") ? $logDefault : $logFile
        }
    }
    elseif ($config.logFile) {
        $logTo = $config.logFile | Out-Path
    }

    if ($mailTo -and -not $logTo) {
        $logTo = $logDefault
    }

    # Remove previous log
    if ($logTo -and (Test-Path -Path $logTo -PathType Leaf)) {
        Write-Host "Truncating log:", $logTo
        Remove-Item -Path $logTo
    }

    $timeFormat = ($config.timeFormat) ? $config.timeFormat : "yyyy-MM-dd HH:mm:ssK"
    $logFormat = "[%{timestamp:+${timeFormat}}] %{level:-7} %{message}"
    # Console
    Add-LoggingTarget -Name Console -Configuration @{ Format = $logFormat;
        Level = "INFO"; ColorMapping = @{ 'INFO'='Blue' ; 'DEBUG'='Green'}}
    # File
    if ($logTo) {
        Add-LoggingTarget -Name File -Configuration @{ Format = $logFormat;
        Level = "INFO"; Path = $logTo }
    }

    # Add to config, used by each job commandline
    $config | Add-Member -MemberType NoteProperty -Name 'logFile' -Value $logTo -Force
}
