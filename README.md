# RBackupPs

PowerShell backup script for rclone/rsync, intended for backing up individual
directories (not full system backups).  Backup jobs are defined in JSON
config files and processed in groups.  Use `-IncludeGroups group1, group2 ...`
to run only certain backup groups while excluding all others or
`-ExcludeGroups ...` to exclude only certain groups while running all others.

A backup group has one or more jobs.  Jobs run sequentially and are typically
used to back up or restore a single directory or directory tree.

You *might* be able to use it for versioned backups of a single directory by
using variables (`$rbackupRunTime`) in your destination path.  I don't do
versions so I haven't tested it.  See [variables](#environment-variables) below.

Everything is entered manually into JSON config files, there is no GUI or
config generator or anything like that.  Just a PowerShell script for backup
automation with some predefined settings for quick deployment and options for
flexibility.

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

Logging functionality uses the PowerShell logging module located
[here](https://github.com/RootITUp/Logging).  It's used for console as well as
file logging.

## Backup types and attributes

Each config needs a `"type"` attribute that applies to all groups/jobs defined
in the config and affects the default options as well as what options are
available to configure.  The three backup types available are `"local"`,
`"cloud"`, and `"host"`.

`"local"` and `"cloud"` should be self-explanatory.  `"host"` backups are
intended for replicating things like your music or video library onto other
local networked systems.

### Backup root and trunk

Backup jobs have a source and destination.  These are either specified as
absolute paths or computed as `<root>/<trunk>/<source or destination dir>`,
depending on what source and destination attributes are used.  See
[job attributes](#job-attributes) below for more details.

`"root"` should be self-explanatory and needs to be defined at the config level.
It is shared by all jobs in the config.  For local and host backups, it should
be an absolute path (or an environment variable like `$HOME` or `$env:UserProfile`
that evaluates to one).  For cloud backups (`rclone` remotes), it should be the
root directory/bucket/whatever where your backups live.

(*Side note: I only use Google Drive so I don't actually have any experience
with "bucket" based remotes.  Feel free to test this with other remotes, but I
don't have any inclination to do so at the moment.*)

`"trunk"` is what subdirectory under the root to backup/write to.  The "trunk"
for most of my local and cloud backups is the hostname of the system the backup
came from.

### Job modes - push and pull

Jobs have an optional `"mode"` attribute that can be set to either `"push"`
or `"pull"`.  This is meant only as a means of separating backup jobs from
backup restoration jobs and determining which ones run when the script is
executed.  `"push"` jobs are meant to be backup jobs, while `"pull"` jobs
restore backups, "pulling" backed up files from a remote destination.
There are no technical differences between the two modes, only semantics.
Source and destination are computed the same for both.  See below.

If a job does not specify its `"mode"`, it defaults to `"push"`.

### Source and destination

Source and destination can either be specified as absolute paths or relative
paths that depend on `"root"` and `"trunk"`.

Use `"source"` to specify an absolute path to the backup source, or
`"sourceRemote"` to specify a subdirectory or path under `<root>/<trunk>`.
If both are present, `"source"` is used.  *If neither is present, source will
be treated as an empty string ("").*

Use `"destination"` to specify an absolute path to the destination, or
`"destinationRemote"` to specify a subdirectory or path under `<root>/<trunk>`.
If both are present, `"destination"` is used.

`"sourceRemote"` is meant to be used with `"pull"` jobs (backup restoration),
while `"destinationRemote"` would more commonly be used with `"push"` backup
jobs.

Note that any of these attributes can be used in any job type.  Jobs that use
both remote-relative attributes may work entirely on the remote side and involve
no local files (this may only work with `rclone` jobs), whereas the absolute
attributes allow using any arbitrary local or remote path for source and
destination.

### Path variable subtitution and separators

All paths will have variable subsitution performed and be converted to
POSIX-style paths (backslashes converted to forward slashes).  If a path (or
final path component, ie. `"sourceRemote"`/`"destinationRemote"`) ends with
a path separator, the trailing separator is retained.

Whatever rules exist for `rsync`/`rclone` regarding trailing separators still
apply here.  If source ends with a path separator, `rsync` will always copy the
directory *contents*, not the directory itself.  `rclone` on the other hand does
not care either way, and if the source is a directory its contents are always
copied.

All paths will have all backslashes (`\\`) replaced with forward slashes (`/`)
as Windows will accept either one as a path separator, whereas backslashes do
not work as path separators on Unix-like systems.

### "Local" vs "cloud" vs "host"

Local and cloud backups are designed to be stored similarly - on a single drive
or cloud account, with each system's backup housed in a different subdirectory
(named according to hostname).  This subdirectory is what's referred to as the
"trunk" of the backup.  The default trunk for local and cloud backups is the
hostname of the system being backed up.  Change this to whatever you want with
the `-Trunk` script arg, by specifying a `"trunk"` at the config level, or even
per job by specifying a different trunk for each one.

For example, on my laptop, every folder in my home directory except `~/bin`
is backed up to:

```
<backup root>/<laptop host name>/<subdirectory name>
```

`~/bin` is backed up straight to the `bin/` subdirectory of my backup root
because I use `rclone bisync` to sync `bin/` between all of my systems.  That
way, every system has all my shell scripts.

This is accomplished by setting the `"trunk"` of the backup to `"bin"` and the
`"destinationRemote"` to an empty string.  (Or set `"destinationRemote"` to
`"bin"` and `"trunk"` to empty.  Either way, `[System.IO.Path]::Combine(...)`
evaluates to `<root>/bin`.)

Host backups are intended for duplicating file trees from one local system to
another (music libraries, etc), thus the default `"trunk"` for these is an empty
string (so your music library gets synced to `~/Music/` on the remote host instead
of `~/<local hostname>/Music/`).

If you want to change this behavior, set the trunk to whatever you want.  If you
want host backups to work the same as cloud, you can set the `"trunk"` to
`$rbackupMachineName` (see [environment variables](#environment-variables) below).

## Config attributes

- `"type"` - Type of backup config (`"local"`, `"cloud"`, or `"host"`)

- `"remote"` - Only used for `"cloud"` or `"host"` config types.  Remote name
(`rclone`), address or hostname (`rsync`).

- `"root"` - Root directory of the backup.  For local backups, ideally this is
an absolute path.  For cloud/host, it could be absolute or relative to the
remote's actual root or user home directory (it is appended to the `"remote"`
after a colon `:`, as in `"remote:root"`).

- `"trunk"` - Subdirectory of backup root to use.  Used as part of the
source/destination path for jobs that do not specify their own "trunk" to
override this.

- `"timeFormat"` - Change the time format for logging if desired.
See [date and time formats](https://learn.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings).

- `"groups"` - The array of backup groups

## Group attributes

- `"name"` - Group name

- `"skipOnFail"` - If set, jobs that exit with an error will cause subsequent
jobs in the group to be skipped.

- `"jobs"` - The array of backup jobs

## Job attributes

- `"enabled"` - Must be set to enable a job to run.

- `"name"` - Job name.

- `"description"` - Optional.  A short description.

- `"mode"` - Options are `"push"`, `"pull"`.  If not set, defaults to `"push"`.
Mostly just a way of controlling which jobs run when the script is called, but
could be used to logically separate backup restoration jobs from backup creation
ones.

- `"trunk"` - Overrides config `"trunk"` per job.  Subdirectory of backup root.

### Source

- `"source"` - The absolute path to the source.

- `"sourceRemote"` - Path to the source, relative to `"root"` and `"trunk"`
(`<root>/<trunk>/<sourceRemote>`).  Most commonly used for backup restoration.
Only used if `"source"` is unset.

### Destination

- `"destination"` - The absolute path to the destination.

- `"destinationRemote"` - Path to the destination, relative to `"root"` and
`"trunk"` (`<root>/<trunk>/<destinationRemote>`).  Most commonly used for
normal backups.  Only used if `"destination"` is unset or empty/whitespace.

### Optional/extra

- `"resyncMode"` - For `rclone bisync` jobs, resync mode to use.

- `"filterFrom"` - `rclone` filtering, see [filtering](#filtering) below.

- `"includeFrom"` - `rsync` or `rclone` filtering, see below.

- `"excludeFrom"` - `rsync` or `rclone` filtering, see below.

### Required attributes

Besides a "source" and the backup command itself, local backups require only that
`"root"` be set.  They can use `rclone` or `rsync`.  Cloud and host backups also
require a `"remote"`.  This should be a name (like an rclone remote name), IP
address, etc. -- anything that will be recognized by rclone or rsync as a remote
target.

The `"command"` attribute of a backup job has three components: `"exec"`,
`"args"`, and `"subcommand"` (for `rclone` only).  `"exec"` should *end with*
`rclone` or `rsync` (`rclone.exe` or `rsync.exe` for Windows) for script logic
to work.

`"args"` should be an array of commandline arguments to pass.  You don't need to
pass arguments like "--verbose", "--dry-run", etc as these are automatically
appended when the script is run with these arguments.  If using rclone,
`"subcommand"` is what rclone subcommand to use (`copy`, `sync`, etc).  If not
specified, it will default to `"check"`.  (This is to prevent data loss as `check`
should be nondestructive.)

Cloud backups should only use `rclone`, which should handle all the connection and
user details itself.  (Run `rclone config` to setup a new remote.)

Host backups can use `rclone` or `rsync`.  If using `rsync`, you'll need to specify
a username if different from your current username or rsync will be unable to
connect.

It is assumed you probably use the same username on both systems but if not, add
the user to the top of the config or to each individual backup job in the config
if necessary.

## Examples

Example "host" config
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

My `~/bin` backup job
``` json
{
    "name": "bin",
    "jobs": [
        {
            "enabled": true,
            "name": "bin",
            "description": "Shell scripts",
            "trunk": "bin",
            "source": "$HOME/bin/",
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
                    "local,remote",
                    "--resilient",
                    "--recover",
                    "--max-lock",
                    "5m"
                ]
            }
        }
    ]
}

```

## Script parameters

- `-ConfigName` - Name/path of config file.  If not the absolute path to the config,
RBackupPS will look for any JSON/JSONC files matching the given name in the
`$HOME/.config/rbackup/` directory.

- `-Mode` - Backup mode to run in.  One of: "push" (the default), "pull", or "any".
Affects which jobs are selected to run.  If set to `any`, all jobs of either mode
will be run, in the order they appear in the config.

- `-LocalBackupRoot` - Only for local backups, the root of the local backup.
Overrides `"root"` defined in the config file if set.  Use this for backing up
to a different drive/directory than your usual local backups (one-offs, Windows
drive letter changes, etc).

- `-Trunk` - Subdirectory of root to write backup to.  For local/cloud backups
defaults to system hostname.  For host backups, defaults to an empty string.
Only changes the config-level trunk value.  Each individual backup job can still
specify its own trunk in the config that will override this.

- `-IncludeGroups` - Backup groups to include (all others will be excluded)

- `-ExcludeGroups` - Backup groups to exclude (all others will be included)

- `-LogFile` - Path to log file, `"none"`, or `"default"`.  If `"none"` is
specified, logging to file will be temporarily disabled.  This applies even if
the user has previously enabled file logging by setting a `"logFile"` value in
the config.  If `"default"` is specified, the default logfile name is used
(`~/.local/state/rbackup-<$configName>.log`)

- `-MailTo` - Email address to send log to.  If `-MailTo` is specified but no
logfile has been is set, the default logfile is used.

- `-DryRun` - Add `--dry-run` to the commandline for all backups, for testing.

- `-Resync` - Run bisync jobs (jobs that use the `rclone bisync` subcommand) in
resync mode.  Jobs can specify a resync mode with the `"resyncMode"` attribute,
otherwise `"newer"` is used.

- `-Interactive` - Confirm before running each job.

## Other things

### Safety features

Use `-Interactive` to confirm before running each job.  The commandline should
be printed before the confirmation (sometimes it prints after due to issues
with logging to console).

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

### Environment variables

Environment variables (`$USER`, `$HOST`, etc) are honored in string values
and a few environment variables are exported and available for ... whatever
(path substitutions, etc):

- `$rbackupMachineName`: Hostname (obtained by `[Environment]::MachineName`).
- `$rbackupConfigName`: Name (stem only) of the config file, for naming log files
- `$rbackupRunTime`: Script execution time in `yyyyMMdd-HHmmss` format.

### Pre-exec and post-exec tasks

Jobs may have a `"prereq"` attribute with a list of prerequisite tasks that must
be executed before the job command can be run.  If a task is marked `"required"`,
the job will be skipped if the task fails.  Jobs may also have an `"onSuccess"`
attribute consisting of tasks to run once the job completes successfully.

``` json
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
