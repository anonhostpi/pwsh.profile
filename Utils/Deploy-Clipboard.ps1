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
        } While( ($Contents.Trim() -eq $out.Trim()) -or [string]::IsNullOrWhiteSpace($out) )
        
        Try {
            $out | ConvertFrom-Json
            Write-Host "Clipboard parsed!"
        } Catch {
            Write-Host "Clipboard received!"
            return $out
        }
    } Else {
        Pause
    }
}
