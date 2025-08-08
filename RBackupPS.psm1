function Start-RBackupPS {
    [CmdletBinding(DefaultParameterSetName='Local')]
    param(
        [Parameter(Mandatory, Position=0)]
        [Alias("file")]
        [string] $ConfigFile,

        [Parameter(Position=1)]
        [ValidateSet("push", "pull", "any")]
        [string] $Mode = "push",

        [Parameter(ParameterSetName='Local')]
        [string] $Root,

        [Parameter(ParameterSetName='Nonlocal')]
        [string] $Remote,

        [string] $Trunk,

        [Alias("group")]
        [string[]] $IncludeGroups,

        [Alias("nogroup")]
        [string[]] $ExcludeGroups,

        [string] $LogTo,

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

        # Available for path subsitutions
        $machineName = [Environment]::MachineName
        $configName = Split-Path $ConfigFile -LeafBase
        $datetime = (Get-Date -Format "yyyy-MM-dd-HHmmss")
        $date = (Get-Date -Format "yyyy-MM-dd")

        # Shut up stupid unused variable warnings
        Write-Debug "Config name: $configName"
        Write-Debug "Running on host: $machineName, on $date"
        Write-Debug "$datetime"

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
            configName = $ConfigFile
            remote = $Remote
            root = $Root
            trunk = $Trunk
        }

        $config = Get-Config @configParams
        $config | Add-Member -NotePropertyMembers @{
            mode = $Mode
            dryRun = $DryRun
            resync = $Resync
            interactive = $Interactive
        }

        if ($PSBoundParameters['Verbose']) {
            $config | Add-Member -MemberType NoteProperty -Name 'verbose' -Value $true -Force
        }

        # Start-Logging:
        #   - console|$null|null|no|none|$false|false...
        #     Disable logging module and use colorized Write-Host instead
        if ($PSBoundParameters.ContainsKey('LogTo') -and -not $LogTo) {
            $LogTo = 'console'
        } elseif ($LogTo -match "^false|no(ne)?|nul|null$") {
            $LogTo = 'console'
        }

        Start-Logging $config $configName $LogTo $MailTo

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
            Script:Write-Logger " "
            Script:Write-Logger "Group: $($group.name)"
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
                    Script:Write-Logger "Job '$($job.name)' not enabled, skipping"
                    continue nextJob
                }
                $commandline = Get-JobCommand $job $config
                Script:Write-Logger " "
                Script:Write-Logger "Job: '$($job.name)' - $($job.description)"
                Script:Write-Logger "Command: $commandline"
                Script:Write-Logger ('-'*(([string]$commandline).Length+9))
                # Wait-Logging
                if (-not $Interactive -or (Read-YesNoChoice "`nRun job '$($job.name)'?" -Default 'Yes')) {
                    try {
                        Invoke-Job $job
                        Script:Write-Logger "Job '$($job.name)' done.`n"
                    } catch {
                        Script:Write-Logger -Level ERROR -Message $_.Exception.Message
                        $errorsEncountered += 1
                        if ($group.skipOnFail) {
                            Script:Write-Logger -Level WARNING `
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
