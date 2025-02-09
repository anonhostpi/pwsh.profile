function global:Invoke-WildcardScriptfiles {
    [CmdletBinding()]
    param(
        [string[]] $Paths
    )


    $Paths | Resolve-Path | ForEach-Object {
        $_.ToString()
    } | Sort-Object | ForEach-Object {
        Write-Verbose "Running $_"
        & $_
    }
}

Set-Alias -Scope Global -Name "run" -Value "Invoke-WildcardScriptfiles"
Set-Alias -Scope Global -Name "resolve" -Value "Resolve-Path"
Set-Alias -Scope Global -Name "answer" -Value "Read-Host"

run "$PSScriptRoot\Utils\*.ps1"
