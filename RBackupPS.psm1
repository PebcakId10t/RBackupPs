#Requires -Module Logging

function Start-RBackupPS {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [Alias("file")]
        [string] $ConfigName,

        [Parameter(Position=1)]
        [ValidateSet("push", "pull", "any")]
        [string] $Mode = "push",

        [Parameter(Position=2)]
        [Alias("root")]
        [string] $LocalBackupRoot,

        [string] $Trunk,

        [Parameter()]
        [Alias("group")]
        [string[]] $IncludeGroups,

        [Parameter()]
        [Alias("nogroup")]
        [string[]] $ExcludeGroups,

        [string] $LogFile,

        [string] $MailTo,

        [switch] $DryRun,

        [switch] $Resync,

        [switch] $Interactive
    )

    begin {
        Write-Debug "`$PSBoundParameters:"
        foreach ($p in $PSBoundParameters.GetEnumerator()) {
            Write-Debug "  $($p.Key): $($p.Value)"
        }

        # Vars set here will be available for path subsitutions, etc.
        $rbackupMachineName = [Environment]::MachineName
        $rbackupConfigName = Split-Path $ConfigName -LeafBase
        $rbackupRunTime = (Get-Date -Format "yyyyMMdd-HHmmss")

        # Shut up stupid unused variable warnings
        Write-Debug "Config name: $rbackupConfigName"
        Write-Debug "Running on host: $rbackupMachineName, at $rbackupRunTime"

        <# Keeps paths cross-platform (replaces \ with /), expands variables. #>
        filter Out-Path {
            $str = $ExecutionContext.InvokeCommand.ExpandString($_)
            $str -replace "\\", "/"
        }

        <# Expands variables in strings #>
        filter Out-Variable {
            $str = $ExecutionContext.InvokeCommand.ExpandString($_)
            $str
        }

        # Source all .ps1 files in private/
        $functions = @(Get-ChildItem -Path "${PSScriptRoot}/private" -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)
        foreach ($func in $functions) {
            try {
                . $func.FullName
            } catch {
                throw "Failed to source '$($func.FullName)'"
            }
        }

        $configParams = @{
            configName = $ConfigName
            localBackupRoot = $LocalBackupRoot
            trunk = $Trunk
        }

        $config = Get-Config @configParams
        $config | Add-Member -NotePropertyMembers @{
            mode = $Mode
            dryRun = $DryRun
            resync = $Resync
        }

        if ($PSBoundParameters['Verbose']) {
            $config | Add-Member -NotePropertyMembers @{
                verbose = $true
            }
        }

        # Start-Logging will disable file logging if $LogFile == "none"/null/false
        # ($null)
        if ($PSBoundParameters.ContainsKey('LogFile') -and -not $LogFile) {
            $LogFile = "none"
        # ('false' / $false)
        } elseif ($LogFile -match "^false$") {
            $LogFile = "none"
        }

        Start-Logging $config $rbackupConfigName $LogFile $MailTo

        Write-Debug ($config | Format-List | Out-String)

        if ($config.logFile) {
            Write-Host "Logging to: $($config.logFile)"
        }
        if ($MailTo) {
            Write-Host "Mail will be sent to: $MailTo"
        }
    }

    process {
        $groups = $config.groups

        :nextGroup foreach ($group in $groups) {
            if (($IncludeGroups -and $group.name -notin $IncludeGroups) -or
                ($ExcludeGroups -and $group.name -in    $ExcludeGroups)) {
                continue nextGroup
            }
            Write-Log "Group: $($group.name)"
            $jobs = $group.jobs
            switch ($Mode) {
                "push" { $jobs = $jobs | Where-Object { -not $_.mode -or $_.mode -eq "push" } }
                "pull" { $jobs = $jobs | Where-Object { $_.mode -eq "pull"} }
                * {}
            }
            if (-not $jobs) {
                Write-Error "No jobs in group '$($group.name)' matching mode '$Mode'"
            }
            $errorsEncountered = 0
            :nextJob foreach ($job in $jobs) {
                if (-not $job.enabled) {
                    Write-Log "Job '$($job.name)' not enabled, skipping"
                    continue nextJob
                }
                $commandline = Get-JobCommand $job $config
                Write-Log ('-'*(([string]$commandline).Length+9))
                Write-Log "Job: '$($job.name)' - $($job.description)"
                Write-Log "Command: $commandline"
                Wait-Logging
                if (-not $Interactive -or (Read-YesNoChoice "Run job '$($job.name)'?" -Default 'Yes')) {
                    try {
                        Invoke-Job $job
                        Write-Log "Job '$($job.name)' done.`n"
                    } catch {
                        Write-Log -Level ERROR -Message $_.Exception.Message
                        $errorsEncountered += 1
                        if ($group.skipOnFail) {
                            Write-Log -Level WARNING `
                                -Message "Skip on fail set, skipping remaining jobs in group '$($group.name)'"
                            continue nextGroup
                        } else {
                            continue nextJob
                        }
                    }
                }
            }
            Wait-Logging
        }
    }

    end {
        if ($MailTo) {
            $credFile = ${env:MAIL_CONFIG}
            $creds = Get-Content -Path $credFile -Raw | ConvertFrom-Json
            $pswd = ConvertTo-SecureString $creds.MAIL_PASS -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($creds.MAIL_USER, $pswd)
            $server, $port = $creds.MAIL_SERVER.Split(':')
            $from = $creds.MAIL_FROM ? $creds.MAIL_FROM : $creds.MAIL_USER

            $mailParams = @{
                To = $MailTo
                From = $from
                Credential = $credential
                SmtpServer = $server
                Port = $port
                Subject = If ($errorsEncountered -gt 0) {"Backup script error"} else {"Backup script success"}
                Body = "Backup has run with ${errorsEncountered} error(s).  See log for details."
                UseSsl = $true
            }

            Write-Host "Emailing log...`n" -ForegroundColor Green
            $mailParams.Attachments = $config.logFile

            Send-MailMessage @mailParams
        }
    }
}
