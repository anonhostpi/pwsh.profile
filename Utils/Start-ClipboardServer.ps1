function global:Start-ClipboardServer {
    param( $file = "~/clipboard/mem.csv" )
    Start-Job {
        param( $file )
        $max = 100

        $root = ($file | Split-Path -Parent).ToString()

        $mem = @{
            cache = @()
        }

        function Add-Entry {
            param( $encrypted )
            $mem.cache += $encrypted
            If( $mem.cache -gt $max ){
                $mem.cache = $mem.cache[-$max..-1]
                $idx_file = Try {
                    Get-Item "$root\*.idx"
                } Catch {
                    "" | Out-File "$root\0.idx"
                    Get-Item "$root\0.idx"
                }
                $idx = [int]$idx_file.BaseName
                $old = $idx
                $idx -= 1
                If( $idx -lt 0 ){
                    $idx = $max - 1
                }
                Rename-Item -Path "$root\$old.idx" -NewName "$idx.idx" | Out-Null
            }
            ($mem.cache) -join "`n" | Out-File $file
        }

        while($true){
            $curr = Get-Clipboard
            $curr = ConvertTo-SecureString $curr -AsPlainText -Force
            If( -not ($mem.cache -contains $curr) ){
                Add-Entry $curr
            }
        }
    } -ArgumentList $file

    $mem = @{
        index = 0
    }
    $root = ($file | Split-Path -Parent).ToString()

    while($true){
        $idx_file = Try {
            Get-Item "$root\*.idx"
        } Catch {
            "" | Out-File "$root\0.idx"
            Get-Item "$root\0.idx"
        }
        $idx = [int] $idx_file.BaseName

        If( $idx -ne $mem.index ){
            $mem.index = $idx
            $entry = Get-Content $file -split "\n" | Select-Object -Index $idx
            $entry = (New-Object PSCredential 0, $entry).GetNetworkCredential().Password
            Write-Host "[$idx]:" 
            Write-Host $entry
            $entry | Set-Clipboard
            $entry = $null
        }
    }
}
