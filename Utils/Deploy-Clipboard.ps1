function global:Deploy-Clipboard {
    param(
        $Contents,
        [switch] $Communicate
    )

    $Contents | Set-Clipboard
    Write-Host "Clipboard is set."
    If( $Communicate ){
        Write-Host "Waiting on Clipboard Update..."
        Do {
            Sleep -Milliseconds 1000
            $out = Get-Clipboard
        } While( $Contents.Trim() -eq ($out -join "`r`n" -replace "(?<!\r)\n","`r`n").Trim() )
        Write-Host "Clipboard received!"
        Try {
            $out | ConvertFrom-Json
        } Catch {
            $out
        }
    } Else {
        Pause
    }
}
