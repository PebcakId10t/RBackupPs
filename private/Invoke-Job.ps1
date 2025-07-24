<# Run a job, including its prerequisites and onSuccess tasks #>
function Invoke-Job {
    [CmdletBinding()]
    param(
        [object] $job
    )

    if ($job.prereq) {
        foreach ($task in $job.prereq) {
            Write-Log "Running prerequisite task: '$($task.name)'"
            try {
                Invoke-Task $task
            }
            catch {
                Write-Log -Level WARNING "Prerequisite task '$($task.name)' failed."
                if ($task.required) {
                    throw "Skipping job due to failed required task."
                }
            }
        }
    }

    if ($IsWindows) {
        cmd /c $job.commandline
    } else {
        sh -c $job.commandline
    }
    $exitCode = $LASTEXITCODE

    # "--error-on-no-transfer" exit code
    if ($($job.command.exec) -match "rclone(\.exe)?$" -and $exitCode -eq 9) {
        Write-Log "Nothing to sync."
    }
    elseif ($exitCode -ne 0) {
        throw "Non-zero exit code. Check log for potential errors."
    }
    elseif ($exitCode -eq 0) {
        Write-Log "Operation appears to have been successful."
    }

    if ($job.onSuccess) {
        foreach ($task in $job.onSuccess) {
            Write-Log "Running onSuccess task: '$($task.name)'"
            Invoke-Task $task
        }
    }
}
