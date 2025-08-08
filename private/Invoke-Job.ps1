<# Run a job, including its prerequisites and onSuccess tasks #>
function Invoke-Job {
    [CmdletBinding()]
    param(
        [object] $job
    )

    if ($job.prereq) {
        foreach ($task in $job.prereq) {
            Script:Write-Logger "Running prerequisite task: '$($task.name)'"
            try {
                Invoke-Task $task
            }
            catch {
                Script:Write-Logger -Level WARNING "Prerequisite task '$($task.name)' failed."
                if ($task.required) {
                    throw "Skipping job because failed prerequisite task was marked essential."
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
        Script:Write-Logger "Nothing to sync."
    }
    elseif ($exitCode -ne 0) {
        throw "Non-zero exit code. Check log for potential errors."
    }
    elseif ($exitCode -eq 0) {
        Script:Write-Logger "Operation appears to have been successful."
    }

    if ($job.onSuccess) {
        foreach ($task in $job.onSuccess) {
            Script:Write-Logger "Running onSuccess task: '$($task.name)'"
            try {
                Invoke-Task $task
            }
            catch {
                Script:Write-Logger -Level WARNING "onSuccess task '$($task.name)' failed."
                if ($task.required) {
                    # Will cause groups with "skipOnFail" to stop processing further jobs
                    throw "Last warning raised from WARNING to ERROR due to task being marked essential."
                }
            }
        }
    }
}
