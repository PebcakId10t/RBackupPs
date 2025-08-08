<# Execute a job task (prereq/onSuccess) #>
function Invoke-Task {
    [CmdletBinding()]
    param(
        [object] $task
    )

    # Execute "command" arrays using the system shell...
    if ($task.command -is [Array]) {
        # Evaluate any variables
        $task.command = $task.command | ForEach-Object {
            $str = $ExecutionContext.InvokeCommand.ExpandString($_)
            $str
        }
        $cmd = $task.command -join " "
        Script:Write-Logger "shell> $cmd"

        if ($IsWindows) {
            cmd /c $cmd 2>&1
        } else {
            sh -c $cmd 2>&1
        }
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            throw "Task '$($task.name)' failed."
        }

    }
    # ...and "ps" strings using powershell
    elseif ($task.ps -is [String]) {
        Script:Write-Logger "   PS> $($task.ps)"
        Invoke-Expression -Command $task.ps
    }
}
