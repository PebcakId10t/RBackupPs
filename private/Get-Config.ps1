<# Get backup config #>
function Get-Config {
    param(
        [string] $configName,
        # Override params
        [string] $remote,
        [string] $root,
        [string] $trunk
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

    #region Overrides
    # (Different param sets, only one should be nonnull)
    if ($root) {
        $config | Add-Member -MemberType NoteProperty -Name 'root' -Value $root -Force
    } elseif ($remote) {
        # [$user@]$remote[:$root]
        if ($remote -like '*@*') { $user, $remote = $remote.Split('@', 2) }
        if ($remote -like '*:*') { $remote, $root = $remote.Split(':', 2) }
        $config | Add-Member -MemberType NoteProperty -Name 'remote' -Value $remote -Force
        if ($root) { $config | Add-Member -MemberType NoteProperty -Name 'root' -Value $root -Force }
        if ($user) { $config | Add-Member -MemberType NoteProperty -Name 'user' -Value $user -Force }
    }
    if ($trunk) {
        $config | Add-Member -MemberType NoteProperty -Name 'trunk' -Value $trunk -Force
    }
    #endregion

    #region Requirements
    if ($config.type -notin @('local', 'cloud', 'host')) {
        throw "${file} - config `"type`" must be one of: [`"local`", `"cloud`", `"host`"]"
    } 

    # These are not required if you only want to use "source" and "destination"
    # absolute paths for backups.
    if (-not $config.root) {
        Write-Warning "${file} - no `"root`" set.  Should be root of backup."
    }

    if ($config.type -in @('cloud', 'host') -and -not $config.remote) {
        Write-Warning "${file} - no `"remote`" set.  Should be target machine/rclone remote."
    }
    #endregion

    #region Defaults
    # Trunk - local/cloud: $machineName, host: empty string
    $machineName = [Environment]::MachineName
    if (-not ($config | Get-Member -Name 'trunk' -MemberType NoteProperty)) {
        if ($config.type -in @('local', 'cloud')) {
            $config | Add-Member -MemberType NoteProperty -Name 'trunk' -Value $machineName
        } else {
            $config | Add-Member -MemberType NoteProperty -Name 'trunk' -Value ""
        }
    }

    # "host" backup types are to a networked host. Jobs can use rclone or rsync.
    # Rclone takes care of user auth when setting up a new remote but rsync will
    # need to be told what user to connect as. If not specified, get current user.
    # (USERNAME - windows, USER - linux/mac)
    if (-not ($config | Get-Member -Name 'user' -MemberType NoteProperty)) {
        $user = $env:USERNAME ?? $env:USER
        $config | Add-Member -MemberType NoteProperty -Name 'user' -Value $user
        Write-Warning "${file} - `"host`" config with unset `"user`", assuming default ($user)"
    }
    #endregion

    return $config
}
