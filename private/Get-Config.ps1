<# Get backup config #>
function Get-Config {
    param(
        [string] $configName,

        # These will override values specified in the config if present
        [string] $trunk,
        [string] $localBackupRoot
    )
 
    $configDir = Join-Path $HOME ".config" "rbackup"
    if (-not (Test-Path $configName)) {
        foreach ($ext in @('', '.json', '.jsonc')) {
            $file = Join-Path $configDir "${configName}${ext}"
            if (Test-Path $file) {
                $config = Get-Content -Path $file -Raw | ConvertFrom-Json        
            }
        }
    } else {
        $config = Get-Content -Path $configName -Raw | ConvertFrom-Json
    }

    if (-not $config) {
        throw "'$configName': Not found"
    }

    # All configs must have backup type
    # Supported types: "local", "cloud", "host"
    if ($config.type -ne "local" `
        -and $config.type -ne "cloud" `
        -and $config.type -ne "host") {
        throw "${file} - required attribute `"type`" must be one of: [`"local`", `"cloud`", `"host`"]"
    } 

    # If backup type is local, $localBackupRoot overrides config "root"
    if ($config.type -eq "local") {
        if ($localBackupRoot) {
            $config | Add-Member -MemberType NoteProperty -Name 'root' -Value $localBackupRoot -Force
        }
    }

    # Override config "trunk" if script param set
    if ($trunk) {
        $config | Add-Member -MemberType NoteProperty -Name 'trunk' -Value $trunk -Force
    }

    # If trunk is not defined either by the script or config, set the default
    $machineName = [Environment]::MachineName
    if (-not [bool]($config.PSObject.Properties.Name -match "trunk")) {
        if ($config.type -eq "local" -or $config.type -eq "cloud") {
            $config | Add-Member -MemberType NoteProperty -Name 'trunk' -Value $machineName
        } else {
            # "host" jobs default trunk is empty string 
            $config | Add-Member -MemberType NoteProperty -Name 'trunk' -Value ""
        }
    }

    # "root" is required for all backup types
    if ($config.root -isnot [String]) {
        throw "${file} - required attribute `"root`" must be set to root of backup."
    }

    # "remote" is required for cloud and host backup types
    if ($config.type -match "^cloud|host$" -and -not $config.remote) {
        throw "${file} - attribute `"remote`" unset.  Cannot run rclone/rsync jobs without it."
    }

    # "host" backup types are to a networked host.  These can run both rclone
    # and rsync jobs.  For rclone jobs (remote type sftp, etc), you specify a
    # username when you set up the remote.  For rsync, you need to supply a
    # username in the config.  If it's not set, we'll default to the current
    # user on this machine.
    if ($config.type -eq "host" -and -not $config.user) {
        $config | Add-Member -MemberType NoteProperty -Name 'user' -Value $env:UserName
        Write-Warning "${file} - `"host`" config with unset `"user`", assuming default ($env:UserName)"
    }

    return $config
}
