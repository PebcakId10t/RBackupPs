# RBackupPs

Python version [here](https://github.com/PebcakId10t/RBackupPy)

PowerShell backup script for rclone/rsync, intended for backing up individual
directories (not full system backups).  Backup jobs are defined in JSON
config files and processed in groups.  Use `-IncludeGroups group1, group2 ...`
to run only certain backup groups while excluding all others or
`-ExcludeGroups ...` to exclude only certain groups while running all others.

A backup group has one or more jobs.  Jobs run sequentially and are typically
used to back up or restore a single directory or directory tree.

You *might* be able to use it for versioned backups of a single directory by
using variables (ex. `$datetime`) in your destination paths.  I don't do
versions so I haven't tested it.  See [variables](#variables) below.

Everything is entered manually into JSON config files, there is no GUI or
config generator or anything like that.  Just a wrapper around rclone/rsync
with some predefined options for flexibility and some convenience features.

Configs are searched for under `$HOME/.config/rbackup/` by default - even on
Windows - but if this doesn't suit you just pass the script the full path to a
file located elsewhere.  Name the configs whatever you like, but mine are named
for whatever host or `rclone` remote they back up to.

I created the first version of this a while back and tweaked it over the years
and finally decided to share it in case someone else might find it helpful.

There could be bugs I don't know about but it works for my personal backups.
Enjoy.

Thank you to the developers of [rclone](https://rclone.org) and
[rsync](https://rsync.samba.org)!

## Dependencies

Logging to a file needs the PowerShell logging module located
[here](https://github.com/RootITUp/Logging).

## Usage

```
Start-RBackupPS [-ConfigFile] <string> [[-Mode] {push | pull | any}]
                [-Root <string>] [-Trunk <string>]
                [-IncludeGroups <string[]>]
                [-ExcludeGroups <string[]>]
                [-LogFile <string>] [-MailTo <string>]
                [-DryRun] [-Resync] [-Interactive]
                [<CommonParameters>]

Start-RBackupPS [-ConfigFile] <string> [[-Mode] {push | pull | any}]
                [-Remote <string>] [-Trunk <string>]
                [-IncludeGroups <string[]>]
                [-ExcludeGroups <string[]>]
                [-LogFile <string>] [-MailTo <string>]
                [-DryRun] [-Resync] [-Interactive]
                [<CommonParameters>]
```

## Parameters

- `-ConfigFile` - Name/path of config file.  If not the absolute path to the config,
RBackupPS will look for any JSON/JSONC files matching the given name in the
`$HOME/.config/rbackup/` directory.

- `-Mode` - Backup mode to run in.  One of: "push" (the default), "pull", or "any".
Affects which jobs are selected to run.  If set to `any`, all jobs of either mode
will be run, in the order they appear in the config.

- `-Root` - For local backups, the root of the local backup.
Overrides config `"root"` value if set.  Use this for backing up to a different
drive/directory than your usual local backups (one-offs, Windows drive letter
changes, etc).

- `-Remote` - For cloud/host backups, the name/address of the remote target.
If `[user@]remote[:root]` format is used, user and/or root will be set from this
also.  Overrides config `"remote"` value if set.  Use this to backup to a
different rclone/rsync remote or host than normal (IP address changed, etc).

- `-Trunk` - Subdirectory of root to write backup to.  For local/cloud backups
defaults to system hostname.  For host backups, defaults to an empty string.
Only changes the config-level trunk value.  Each individual backup job can still
specify its own trunk in the config that will override this.

- `-IncludeGroups` - Backup groups to include (all others will be excluded)

- `-ExcludeGroups` - Backup groups to exclude (all others will be included)

- `-LogFile` - Path to log file, `none`, or `default`.  If `none` is
specified, logging to file will be temporarily disabled.  This applies even if
the user has previously enabled file logging by setting a `"logFile"` value in
the config.  If `default` is specified, the default logfile name is used
(`~/.local/state/rbackup-<$configName>.log`)

- `-MailTo` - Email address to send log to.  If `-MailTo` is specified but no
logfile has been is set, the default logfile is used.

- `-DryRun` - Add `--dry-run` to the commandline for all backups, for testing.

- `-Resync` - Run bisync jobs (jobs that use the `rclone bisync` subcommand) in
resync mode.  Jobs can specify a resync mode with the `"resyncMode"` attribute,
otherwise `"newer"` is used.

- `-Interactive` - Confirm before running each job.

## Backup types and attributes

Each config needs a `"type"` attribute that applies to all groups/jobs defined
in the config and affects the default options as well as what options are
available to configure.  The three backup types available are `"local"`,
`"cloud"`, and `"host"`.

`"local"` and `"cloud"` should be self-explanatory.  `"host"` backups are
intended for replicating things like your music or video library onto other
local networked systems.

### Backup paths: root, trunk ...

> TL;DR:
>
> You don't need to worry about setting `root`, `remote`, or `trunk` in the
> config unless you want to be able to change your backup destination on the fly
> from the commandline.  Setting these in the config allows using relative paths
> to the source and destination and then being able to override the above path
> components using their respective commandline parameters when the situation
> calls for it (for example, when your backup drive gets mounted by Windows to
> a different drive letter than usual).
>  
> If you'd rather keep things simple, you can just use the `source` and
> `destination` attributes for each job and set them to absolute paths.

Backup jobs have a source and destination.  These are either specified as absolute
paths or computed using relative ones.  Set absolute paths using the `source` and
`destination` attributes, or relative paths using `sourceRemote` and
`destinationRemote`.  See [job attributes](#job-attributes) below for more details.

A destination path separated into its constituent components:

```
[remote:]<root>/<trunk>/<destinationRemote>
```

This matches the typical rsync/rclone path:

```
[user@]remote_hostname_or_address:path/to/dest
```

`remote` and `root` are defined at the config level.  They will be shared by all
jobs.

`remote` is the name or address of the target machine (or `rclone` remote) and is
only used for remote backup types (cloud and host).

`root` is the root directory of the backup.  For local backups, it would typically
be the absolute path to the backup drive/volume/directory (ex. "D:/Backup").
For cloud backups, it would be the top level directory of the target remote
where your backups are stored (ex. my Google Drive has a top level folder called
"Backup").  For "host" backups, since these are intended for copying personal
files from one networked computer to another, this will usually be your home
directory on the remote system.

`trunk` is what subdirectory under the root to backup to.  The "trunk" for
most of my local and cloud backups is the hostname of the system the backup
came from, so this is the default for these.  Change this to whatever you want
with the `-Trunk` script argument or by specifying a `"trunk"` value at the top
level of the config.  *Each job may also specify its own "trunk" attribute that
will override the config-level value(s).*

For host backups, the default trunk is an empty string, because host backups
are intended for backing up a directory like `~/Music` on one computer or "host"
to the same location on another one.

### Job modes - push and pull

Jobs have an optional `"mode"` attribute that can be set to either `"push"`
or `"pull"`.  This can be used as a means of separating backup jobs from
backup restoration jobs (and determining which jobs run when the script is
executed). When running the script in either "push" or "pull" mode, only jobs
matching that mode are run.

`"push"` jobs are meant to be backup jobs, while `"pull"` jobs restore backups,
"pulling" backed up files from a remote destination.

There are no technical differences between the two modes or how they work,
only semantics.  Source and destination are computed the same way for both
job types.  See above/below.

If a job does not specify a `"mode"`, it defaults to `"push"`.

### Source and destination

Source and destination can either be specified as absolute paths or relative
paths that depend on `"remote"`, `"root"` and `"trunk"`.  Absolute paths are
always used over relative ones if both are given.

#### Source

Use `"source"` to specify an absolute path to the backup source, or `"sourceRemote"`
to specify a ***remote*** subdirectory or path under `<root>/<trunk>`.  If both
attributes are set, `"source"` (the absolute path one) is used.

If *neither* attribute is set, then *no source will be appended to the command.*
Omit both source attributes for commands that do not need a source path (eg.
commands that only take a single path for the "destination", or no paths at all).

If `"sourceRemote"` is used but is set to an empty string, the source path will
be `[remote:]<root>/<trunk>/` (note the trailing slash).  This will cause
rclone/rsync to copy the contents of the remote "trunk" directory itself.

(If `"sourceRemote"` is used and set to an empty string, the script will ensure
that the combined path `[remote:]<root>/<trunk>/` ends with a trailing slash.
This ensures `rsync` copies the remote "trunk" directory's *contents*, not the
directory itself.  See notes on
[trailing separators](#path-variable-subtitution-and-separators).)

#### Destination

Use `"destination"` to specify an absolute path to the destination, or
`"destinationRemote"` to specify a *remote* subdirectory or path under
`<root>/<trunk>`.  If both are set, `"destination"` (the absolute path) is used.

As with source, if neither destination attribute is set, no destination will be
appended to the command. The same caveat applies here. Use this for commands that
only require one path (the *source* path) or none.

And as with `"sourceRemote"`, if `"destinationRemote"` is used but is set to an
empty string, the destination path is `[remote:]<root>/<trunk>`.  This will cause
rclone or rsync to copy/sync files to the trunk directory itself instead of a
subdirectory of it.

`"sourceRemote"` obviously only makes sense to use if the source is remote, as
would be the case with "pull" jobs (backup restoration), while `"destinationRemote"`
makes more sense with "push" mode.  But note that any of these attributes can be
used in any job type...

Jobs that use both remote-relative attributes may work entirely on the remote
side involving no local files (this may only work with `rclone` jobs which can
copy/move from one remote path to another), whereas the absolute attributes
allow using any arbitrary local or remote path for source and destination.  You
could also copy from one remote to another this way.

If you just want to keep things simple and not have to worry about all this
"root" and "trunk" crap, just set absolute paths with `"source"` and
`"destination"`. Everything else is pretty much optional and just there for
flexibility (changing drives/remotes on the fly, etc).

### Path variable subtitution and separators

All paths have [variable](#variables) subsitution performed and are converted
to POSIX-style paths (backslashes converted to forward slashes).  If a path (or
final path component, ie. `"sourceRemote"` / `"destinationRemote"`) ends with
a path separator, the trailing separator is retained.

Rules regarding trailing separators apply here.  If the source path given is a
directory and it does *not* end with a path separator, `rsync` will copy the
*directory* itself.  If it *does* end with a separator, it copies the directory
*contents*. `rclone` on the other hand will *always* try to copy contents if the
source path is a directory.  It does not (usually) care whether the path ends
with a separator or not, except with certain "subcommands". (`copyto` I believe
is picky about this and will error if one path ends with a separator and the other
does not.)

All paths have backslashes (`\\`) replaced with forward slashes (`/`) as Windows
accepts either one as a path separator, whereas backslashes do not work as
separators on Unix-like systems.

## Config attributes

- `"type"` - Type of backup config (`"local"`, `"cloud"`, or `"host"`).

- `"remote"` - Used by `"cloud"` and `"host"` config types when dealing with
relative paths.  Remote name (`rclone`), address or hostname (`rsync`).

- `"root"` - Root directory of the backup.  Used when dealing with relative paths.
For local backups, "root" might be the absolute path to your backup
drive/volume/directory.  For cloud/host, it could be the top level directory
where backups are stored.  It is appended to the `"remote"` with a colon, as in
`"$remote:$root"`.

- `"user"` - Optional.  Needed for rsync jobs.  If not specified, will default
to the user running the script.  Can be overridden by individual jobs.

- `"trunk"` - Subdirectory of backup root to use.  Will be appended after "root"
(`"$remote:$root/$trunk"`) when using a relative source/destination.  Can be
overridden by individual jobs.

- `"logFile"` - Set the path to the logfile to use.  If this is set, logging to
file can still be disabled for individual script runs by using `-LogTo console`.
(This is helpful with `rclone` as it seems to only be capable of logging to either
the console or a file, not both at the same time.  Use `-l console` if you're in a
hurry to run your normal backup - ie. end of work day - and don't want to go
hunting through logfiles afterward to make sure it worked correctly.)

- `"timeFormat"` - Change the time format for logging if desired.
See [date and time formats](https://learn.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings).

- `"groups"` - The array of backup groups.

## Group attributes

- `"name"` - Group name.  Used for group inclusion/exclusion.

- `"skipOnFail"` - If set, jobs that exit with an error will cause subsequent
jobs in the group to be skipped.

- `"jobs"` - The array of backup jobs.

## Job attributes

- `"enabled"` - Must be set to enable a job to run.

- `"name"` - Job name.

- `"description"` - Optional.  A short description.

- `"mode"` - Options are `"push"`, `"pull"`.  If not set, defaults to `"push"`.
Mostly just a way of controlling which jobs run when the script is called, but
could be used to logically separate backup restoration jobs from backup creation
ones.

- `"trunk"` - Overrides config `"trunk"` per job.  Subdirectory of backup root.

- `"user"` - Optional.  Overrides config-level "user" value for this job.

### Source

- `"source"` - The absolute path to the source.

- `"sourceRemote"` - Path to a remote source, relative to `"root"` and `"trunk"`
(`[remote:]<root>/<trunk>/<sourceRemote>`).  Only used if `"source"` is unset.

### Destination

- `"destination"` - The absolute path to the destination.

- `"destinationRemote"` - Path to a remote destination, relative to `"root"`
and `"trunk"` (`[remote:]<root>/<trunk>/<destinationRemote>`).  Only used if
`"destination"` is unset.

### Optional/extra

- `"resyncMode"` - For `rclone bisync` jobs, resync mode to use.  Defaults to
`"newer"`.

- `"filterFrom"` - `rclone` filtering, see [filtering](#filtering) below.

- `"includeFrom"` - `rsync` or `rclone` filtering, see below.

- `"excludeFrom"` - `rsync` or `rclone` filtering, see below.

### Required attributes

The only real requirements for a backup job are the source/destination and the
command, along with whatever arguments it needs.

See the info above if you want to use relative paths for source/destination.

Local backups can use `rclone` or `rsync`.  Cloud backups use `rclone`, which
should handle all the connection and user details itself, so no "user" is required.
(Run `rclone config` to setup a new remote.)

Host backups can use `rclone` or `rsync`.  If using `rsync`, you'll need to specify
a "user" if different from your current username or rsync will be unable to
connect.  Add this to the top of the config, or to each individual backup job if
they need different usernames.

When using the `"source"` and `"destination"` absolute path attributes, "root",
"trunk", "remote" and "user" are not required or used at all (unless they're
included through a [variable](#variables)).

The `"command"` attribute of a backup job has three components - only one of
which is required.

`"exec"`must *end with* `rclone` or `rsync` (`rclone.exe` or
`rsync.exe` for Windows) for script logic to work.  `"args"` should be an array
of commandline arguments to pass, if any.  You don't need to pass arguments like
`--verbose` or `--dry-run` as these are automatically appended when the script is
run with these arguments.  If using rclone, `"subcommand"` is what rclone
subcommand to use (`copy`, `sync`, etc).  If not specified, it will default to
`"check"`.  (This is to prevent data loss as `check` should be nondestructive.)


## Examples

Minimal "host" config using absolute paths.  (No group name so filtering by
group using `-IncludeGroups ...` isn't possible)
``` json
{
    "type": "host",
    "groups": [
        {
            "jobs": [
                {
                    "enabled": true,
                    "source": "$HOME/",
                    "destination": "me@192.168.1.2:/my/home/dir/",
                    "command": {
                        "exec": "rclone",
                        "subcommand": "sync",
                        "args": [
                        ]
                    }
                }
            ]
        }
    ]
}
```

Another host config.

Music will be synced using
`rsync -avz --progress $HOME/Music/ jdoe@laptop.local:/home/jdoe/Music`.

Videos are synced to the rclone remote named `laptop.local` using
`rclone copy --no-traverse --error-on-no-transfer $HOME/Videos/ laptop.local:/home/jdoe/Videos`.

Overriding "root" and "remote" from the commandline would allow syncing to a
completely different host or location on disk.

``` json
{
    "type": "host",
    "remote": "laptop.local",
    "root": "/home/jdoe/",
    "user": "jdoe",
    "groups": [
        {
            "name": "media",
            "jobs": [
                { 
                    "enabled": true,
                    "name": "my music",
                    "source": "$HOME/Music/",
                    "destinationRemote": "Music",
                    "command": {
                        "exec": "rsync",
                        "args": [
                            "-avz",
                            "--progress"
                        ]
                    }
                },
                {
                    "enabled": true,
                    "name": "videos",
                    "source": "$HOME/Videos/",
                    "destinationRemote": "Videos",
                    "command": {
                        "exec": "rclone",
                        "subcommand": "copy",
                        "args": [
                            "--no-traverse",
                            "--error-on-no-transfer"
                        ]
                    }
                }
            ]
        }
    ]
}
```

My bisynced `~/bin`.  Syncs to/from `drive:Backup/bin`. (If the `"trunk"`
attribute were removed, it would sync to `drive:Backup/<hostname>` because the
default "trunk" for cloud backups is the system hostname.)

`--conflict-suffix $machineName,$remote` causes conflicting files to be given
different extensions and saved to both local and remote sides for later inspection.
Local versions end with the system hostname.  Remote versions end with the remote
name.


``` json
{
    "type": "cloud",
    "remote": "drive",
    "root": "Backup",
    "groups": [
        {
            "name": "bin",
            "jobs": [
                {
                    "enabled": true,
                    "name": "bin",
                    "description": "Shell scripts",
                    "trunk": "bin",
                    "source": "$HOME/bin/",
                    "destinationRemote": "",
                    "filterFrom": "$HOME/.config/rclone/filter/bin.txt",
                    "command": {
                        "exec": "rclone",
                        "subcommand": "bisync",
                        "args": [
                            "--error-on-no-transfer",
                            "--links",
                            "--conflict-resolve",
                            "newer",
                            "--conflict-suffix",
                            "$machineName,$remote",
                            "--resilient",
                            "--recover",
                            "--max-lock",
                            "5m"
                        ]
                    }
                }
            ]
        }    
    ]
}
```


## Other things

### Safety features

Use `-Interactive` to confirm before running each job.  The commandline will be
printed for inspection so you can make sure it looks correct before running it.

Use `-DryRun` to run rclone/rsync in dry-run mode.  No changes will be made.

### Restoring from backup

The easiest way is probably to create a `"pull"`-mode counterpart for every
backup job in your config.  If you prefer you can keep them in a separate group.
The default script mode is "push", so as long as the jobs are marked as "pull"
mode, they should not be executed without explicit user intervention.

Backup and restore in the same group:

``` jsonc
"type": "cloud",
"remote": "remotename",
"root": "backup",
"groups": [
    {
        "name": "home",
        "jobs": [
            {
                "enabled": true,
                "name": "backup home",
                "source": "$HOME/",
                "destinationRemote": "",
                // ...
            },
            {
                "enabled": true,
                "name": "restore home",
                "mode": "pull",
                "sourceRemote": "",
                "destination": "$HOME",
                // ...
            }
        ]
    },
    {
        "name": "bin",
        "jobs": [
            {
                "enabled": true,
                "name": "backup bin",
                "source": "$HOME/bin/",
                "destinationRemote": "bin",
                // ...
            },
            {
                "enabled": true,
                "name": "restore bin",
                "mode": "pull",
                "sourceRemote": "bin",
                "destination": "$HOME/bin",
                // ...
            }
        ]
    }
]
```

Separate groups:

``` jsonc
"type": "cloud",
"remote": "remotename",
"root": "backup",
"groups": [
    {
        "name": "backups",
        "jobs": [
            {
                "enabled": true,
                "name": "backup home",
                "source": "$HOME/",
                "destinationRemote": "",
                // ...
            },
            {
                "enabled": true,
                "name": "backup bin",
                "source": "$HOME/bin/",
                "destinationRemote": "bin",
                // ...
            }
        ]
    },
    {
        "name": "restore",
        "jobs": [
            {
                "enabled": true,
                "name": "restore home",
                "mode": "pull",
                "sourceRemote": "",
                "destination": "$HOME",
                // ...
            },
            {
                "enabled": true,
                "name": "restore bin",
                "mode": "pull",
                "sourceRemote": "bin",
                "destination": "$HOME/bin",
                // ...
            }
        ]
    }
]
```

### Mailing

Mailing info will be read from a JSON config file pointed to by the environment
variable `$MAIL_CONFIG` (`$env:MAIL_CONFIG` in Windows).

This file is ***plaintext***.  It's *not* secure, and is not intended to be.
As such, don't store credentials for important accounts in this file, or any
other.  Use a throwaway account.

The config looks like this:

``` json
{
    "MAIL_USER": "<email login>",
    "MAIL_PASS": "<email password>",
    "MAIL_SERVER": "<smtp server>:<port>",
    "MAIL_FROM": "..."
}
```

The `MAIL_FROM` field is optional and should be a name and email address the way
they are typically displayed in email clients (`"My Name <my@email.domain>"`).
This is who the email will appear to have come from.

Note: Your email server will need to be configured to accept this "lower security"
login method.  I'm using an account configured with an "app password".

This uses the `Send-MailMessage` cmdlet, which is deprecated and should not
be used for secure email tasks.

### Filtering

Include/exclude/filter files can be used by specifying them as a job attribute:

- `"includeFrom"`: works with rclone/rsync.  A file containing files/folders
to include.
- `"excludeFrom"`: works with rclone/rsync.  A file containing files/folders
to exclude.
- `"filterFrom"`: works with rclone.  Uses rclone's filtering syntax.

You can also just include the appropriate commandline arguments directly in your
`"args"` array... `"--include-from ..."`, `"--exclude-from ..."`,
`"--filter-from ..."`, etc.

For `rclone bisync` jobs, `"filterFrom"` is converted into `"--filters-file"`,
which is the parameter bisync uses for its checksummed filters file (as of
this writing).

### Variables

Environment variables (`$USER`, `$HOST`, etc) are honored in string values
and a few variables are available for ... whatever (path substitutions, etc):

- `$machineName`: Hostname (obtained by `[Environment]::MachineName`).

- `$configName`: Name (stem only) of the config file, useful for naming log files.

- `$date`: Date the script was run in `yyyy-MM-dd` format.

- `$datetime`: Date and time the script was run in `yyyy-MM-dd-HHmmss` format.

- `$user`: User, as specified in the job or config details with the `"user"`
attribute.  If unset, will be the current user running the script.

- `$root`: Backup root, as specified in the config file with `"root"` or on the
commandline with the `-Root` argument.

- `$remote`: Remote name, as specified in the config with `"remote"` or on the
commandline with the `-Remote` argument.

- `$trunk`: Trunk, as specified in the config with `"trunk"` or on the commandline
with the `-Trunk` argument (or the default value for whatever backup type you're
running if no other value is set).

- `$remotePath`: Same as `$root` for local backups, or `$remote:$root`
for host or cloud backups.  For host backup jobs using `rsync`, `$user@` is also
prepended.

### Pre-exec and post-exec tasks

Jobs may have a `"prereq"` attribute with a list of prerequisite tasks that must
be executed before the job command can be run.  If a task is marked `"required"`,
the job will be skipped if the task fails.  Jobs may also have an `"onSuccess"`
attribute consisting of tasks to run once the job completes successfully.

``` jsonc
"prereq": [
    {
        "required": true,
        "name": "tar files",
        "command": [
            "tar",
            "czvf",
            "$HOME/my_archive.tar.gz",
            "$HOME/my_dir/*.*"
        ]
    }
]
...
"onSuccess": [
    {
        "name": "clean up",
        "command": [
            "rm",
            "$HOME/my_archive.tar.gz"
        ]
    }
]
```
