function global:Loop-Clipboard {
    $clips = @{
        prev = Get-Clipboard
        curr = $null
        store = @()
    }

    Write-Host "Collecting unique clipboard entries..."
    While ($true) {
        Write-Host "Waiting on Clipboard Update..."
        Do {
            Sleep -Milliseconds 1000
            $clips.curr = Get-Clipboard -Raw
        } While( ("$($clips.prev)" -eq "$($clips.curr)") -or [string]::IsNullOrWhiteSpace($clips.curr) )
        $clips.prev = $clips.curr
        If( $clips.store -contains $clips.curr ){
            break;
        }
        $clips.store += $clips.curr
    } 

    $clips.store
}
