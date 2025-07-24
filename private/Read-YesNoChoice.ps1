<# Prompt until yes/no is received and return $true/$false #>
function Read-YesNoChoice {
    param(
        [Parameter(Position=0)]
        [string]$Question,
        
        [Parameter()]
        [ValidateSet('Yes', 'No')]
        [string]$Default = 'Yes'
    )
    $answer = ''
    $affirmative = @('y', 'yes')
    $negative = @('n', 'no')
    $Question += ($Default -eq 'Yes' ? ' (Y/n)' : ' (y/N)')
    while (-not $answer -or ($answer -notin $affirmative -and $answer -notin $negative))
    {
        $answer = Read-Host "$Question"
        if (-not $answer) {
            $answer = $Default
        }
    }
    if ($answer -in $affirmative) {
        return $true
    } else {
        return $false
    }
}
