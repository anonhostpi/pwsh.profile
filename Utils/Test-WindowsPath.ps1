function global:Test-WindowsPath {
    param (
        $Path
    )

    If( $Path -is [string] ){
        if ($Path -match '^(?:([a-zA-Z]:))') {
            If( -not (Test-Path $matches[1]) ){             return $false }
        }
    
        If( -not ($Path -match '[^\<\>\:"\|\?\*\n\r]') ){   return $false }
    
        $segments = $Path -split "[\\\/]+"
        foreach( $segment in $segments ){
            If( $segment.StartsWith(" ") ){                 return $false }
            If( $segment.EndsWith(" ") ){                   return $false }
            If(
                (-not ($segment -match "^\.{1,2}$")) -and
                $segment.EndsWith(".")
            ){                                              return $false }
        }
                                                            return $true
    } Else {
                                                            return $false
    }
}