<# Complete the job commandline, set and return it #>
function Get-JobCommand {
    param(
        [object] $job,
        [object] $config
    )

    $exec = $job.command.exec
    $cmdline = @($exec)

    # rclone "check" if no subcommand specified
    if ($job.command.exec -match "rclone(\.exe)?$") {
        $cmdline += ($job.command.subcommand ?
            $job.command.subcommand :
            "check")
    }

    # Extra verbose if -verbose, else normal verbose
    if ($config.verbose) {
        $cmdline += "-vv"
    } else {
        $cmdline += "-v"
    }
    if ($config.dryRun) {
        $cmdline += "--dry-run"
    }
    if ($config.logFile) {
        $cmdline += @("--log-file", $config.logFile)
    }

    # Variables for substitution
    $user = $job.command.user ?? $job.user ?? $config.user
    $root = $config.root
    $remote = $config.remote ?? ''
    $remotePath = ($remote -and $config.type -ne "local") ? "${remote}:${root}" : "$root"
    if ($config.type -eq "host") {
        if ($job.command.exec -match "rsync(\.exe)?$") {
            if ($remote -and $remote -notmatch "^.*@.*") {
                $remote = "${user}@${remote}"
                $remotePath = "${user}@${remotePath}"
            }
        }
    }
    # If no "trunk" defined for job, use config trunk
    # (?? preserves $job.trunk if empty string)
    $trunk = ($job.trunk ?? $config.trunk) | Out-Path

    # Filtering - rclone
    if ($job.command.exec -match "rclone(\.exe)?$") {
        if ($job.filterFrom -is [String]) {
            $ff = $job.filterFrom | Out-Path
            # If bisync, "--filters-file" replaces "--filter-from"
            if ($job.command.subcommand -eq "bisync") {
                $cmdline += @("--filters-file", $ff)
            } else {
                $cmdline += @("--filter-from", $ff)
            }
        } elseif ($job.excludeFrom -is [String]) {
            $ef = $job.excludeFrom | Out-Path
            $cmdline += @("--exclude-from", $ef)
        } elseif ($job.includeFrom -is [String]) {
            $if = $job.includeFrom | Out-Path
            $cmdline += @("--include-from", $if)
        }
        # For bisync, add "--resync-mode" flag if resyncing.
        # If job specifies the resyncMode to use, use that, otherwise "newer"
        if ($job.command.subcommand -eq "bisync" -and $config.resync) {
            if ($job.resyncMode) {
                $cmdline += @("--resync-mode", $job.resyncMode)
            } else {
                $cmdline += @("--resync-mode", "newer")
            }
        }
    }

    # Filtering - rsync
    elseif ($job.command.exec -match "rsync(\.exe)?$") {
        if ($job.excludeFrom -is [String]) {
            $ef = $job.excludeFrom | Out-Path
            $cmdline += @("--exclude-from", $ef)
        } elseif ($job.includeFrom -is [String]) {
            $if = $job.includeFrom | Out-Path
            $cmdline += @("--include-from", $if)
        }
    }

    # Remaining args in "args" array
    if ($job.command.args -is [Array]) {
        $cmdline += ($job.command.args | Out-Path)
    }

    if ($job | Get-Member -Name 'source') {
        $src = $job.source | Out-Path
    } elseif ($job | Get-Member -Name "sourceRemote") {
        $src = [System.IO.Path]::Combine($remotePath, $trunk, $job.sourceRemote) | Out-Path
        # If sourceRemote is an empty string, we're trying to copy the trunk dir contents?
        # rsync needs trailing '/' to copy contents instead of dir itself
        if ($job.sourceRemote -eq '') { $src += '/' }
    } else {
        $src = ""
    }

    if ($job | Get-Member -Name "destination") {
        $dest = $job.destination | Out-Path
    } elseif ($job | Get-Member -Name "destinationRemote") {
        $dest = [System.IO.Path]::Combine($remotePath, $trunk, $job.destinationRemote) | Out-Path
    } else {
        $dest = ""
    }

    if ($src)  { $cmdline += @($src)  }
    if ($dest) { $cmdline += @($dest) }

    $job | Add-Member -MemberType NoteProperty -Name 'commandline' -Value "$cmdline"
    return $job.commandline
}
