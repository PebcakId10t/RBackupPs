<# Complete the job commandline, set and return it #>
function Get-JobCommand {
    param(
        [object] $job,
        [object] $config
    )

    $exec = $job.command.exec
    $cmdline = @($exec)

    ## - Rclone
    if ($job.command.exec -match "rclone(\.exe)?$") {
        # "check" (nondestructive default) if no subcommand specified
        if ($job.command.subcommand) {
            $cmdline += $job.command.subcommand
        } else {
            $cmdline += "check"
        }

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

    ## - Rsync include/exclude
    if ($job.command.exec -match "rsync(\.exe)?$") {
        if ($job.excludeFrom -is [String]) {
            $ef = $job.excludeFrom | Out-Path
            $cmdline += @("--exclude-from", $ef)
        } elseif ($job.includeFrom -is [String]) {
            $if = $job.includeFrom | Out-Path
            $cmdline += @("--include-from", $if)
        }
    }

    ## - Remaining args in "args" array
    if ($job.command.args -is [Array]) {
        $cmdline += ($job.command.args | Out-Path)
    }

    ## - Src & dest

    # If no "trunk" attr in job, use config trunk
    if (-not [bool]($job.PSObject.Properties.Name -match "trunk")) {
        $trunk = $config.trunk
    } else {
        $trunk = $job.trunk
    }

    if ($config.type -eq "local")
    {
        # Local backups can use rclone or rsync.  $config.root is the root of
        # the backup.  (Get-Config ensures $config.root is set for all backup
        # types.)  As destination is expected to be local, no user/host needed.
        $root = $config.root
    }
    elseif ($config.type -eq "host")
    {
        # Host backups can use rclone or rsync.  $root must include not only
        # the root path on the remote system, but also the remote name/address.
        # If the job uses rsync, it also needs the username to connect as.
        # If $config.remote already starts with the username (username@remote),
        # do not add it again.  Get-Config sets the default username if not
        # provided.  If a job specifies its own, use that instead.

        # If job uses rsync...
        if ($job.command.exec -match "rsync(\.exe)?$") {
            # If $config.remote does not already start with username@...
            if ($config.remote -notmatch "^.*@.*") {
                # Prepend the "user" defined at command, job, or config level
                if ($job.command.user) {
                    $config.remote = "$($job.command.user)@$($config.remote)"
                } elseif ($job.user) {
                    $config.remote = "$($job.user)@$($config.remote)"
                } else {
                    $config.remote = "$($config.user)@$($config.remote)"
                }
            }
        }
        $root = "$($config.remote):$($config.root)"
    }
    else
    {
        # Cloud backups use rclone only.  Rclone handles connecting/user auth
        $root = "$($config.remote):$($config.root)"
    }

    # "sourceRemote" is used for restoring from backup ("pull" mode)
    # and is treated just like "destinationRemote" normally is for "push" jobs.
    # It is combined with root and trunk using [System.IO.Path]::Combine()
    # to form the full remote source path.
    if ([bool]($job.PSObject.Properties.Name -match "sourceRemote") -and $config.mode -eq "pull") {
        $src = [System.IO.Path]::Combine($root, $trunk, $job.sourceRemote) | Out-Path
    # "source" is normally used for "push" jobs and is treated as an absolute
    # path to the source directory to back up (it is unmodified except for
    # path separator replacement and variable substitution).  It can also be
    # used with "pull" jobs but only if "sourceRemote" is unset.
    } elseif ([bool]($job.PSObject.Properties.Name -match "source")) {
        $src = $job.source | Out-Path
    }

    # "destination" is the counterpart of "source" for backup restoration
    # ("pull" mode) and is treated as an absolute path to the destination
    # (presumably a local path).  (It can also theoretically be used with
    # "push" jobs to backup to an absolute remote path if desired, such as
    # a path outside of the normal backup root/trunk.
    if ([bool]($job.PSObject.Properties.Name -match "destination$")) {
        $dest = $job.destination | Out-Path
    # "destinationRemote" is the final path component for ordinary ("push")
    # backup jobs and is combined with root and trunk to form the destination
    # for the backup. (If not present or an empty string, the destination path
    # will simply be $root/$trunk)
    } else {
        $dest = [System.IO.Path]::Combine($root, $trunk, $job.destinationRemote) | Out-Path
    }

    $cmdline += @($src, $dest)

    $job | Add-Member -MemberType NoteProperty -Name 'commandline' -Value "$cmdline"
    return $job.commandline
}
