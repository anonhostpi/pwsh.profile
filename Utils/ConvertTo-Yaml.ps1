function global:ConvertTo-Yaml {
    param(
        $InputObject,
        [int] $IndentLevel,
        [switch] $Short
    )

    $yaml = ""
    $indent = "  " * $IndentLevel

    $is_array = $InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [System.Collections.IDictionary]) -and -not ($InputObject -is [string])

    $ordered = If( $null -ne $InputObject ){
        ConvertTo-OrderedHashtable $InputObject
    } Else {
        $null
    }

    $escaper = {
        param( $out )

        $has_special = @(
            $out.Contains("'")
            $out.Contains('"')
            $out.Contains("[")
            $out.Contains("]")
            $out.Contains("-")
            $out.Contains(":")
            $out.Contains("`r")
            $out.Contains("`n")
        ) -contains $true

        If( $out -is [string] -and $has_special ){
            $inner = $out.Replace('"','\"').Replace("`n","\n").Replace("`r","\r")
            "`"$inner`""
        } else {
            $out
        }
    }

    If( $ordered -is [System.Collections.IDictionary] -and -not ($is_array)){
        foreach( $key in $ordered.Keys ){
            $value = $ordered[$key]

            If( $value -is [System.Collections.IDictionary]){
                $yaml += $indent + (& $escaper "$key") + ":`n"
                $p = @{
                    IndentLevel = $IndentLevel + 1
                }
                If( $null -ne $value ){
                    $p.InputObject = $value
                }
                $yaml += ConvertTo-Yaml @p
            } Elseif( $value -is [System.Collections.IEnumerable] -and -not ($value -is [string]) ){
                $yaml += $indent + (& $escaper "$key") + ":`n"
                foreach( $item in $value ){
                    if( $item -is [System.Collections.IEnumerable] -and -not ($item -is [string])){
                        $yaml += "$indent  - `n"
                        $p = @{
                            IndentLevel = $IndentLevel + 2
                        }
                        If( $null -ne $item ){
                            $p.InputObject = $item
                        }
                        $yaml += ConvertTo-Yaml @p
                    } else {
                        If( $null -eq $item ){
                            $item = "~"
                        }
                        $yaml += "$indent  - $(& $escaper $item)`n"
                    }
                }
            } else {
                If( $null -eq $value ){
                    $value = "~"
                }
                $yaml += $indent + (& $escaper "$key") + ": $(& $escaper $value)`n"
            }
        }
    } Elseif( $InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string]) ) {
        foreach( $item in $InputObject ){
            If( $item -is [System.Collections.IEnumerable] -and -not ($item -is [string]) ){
                $yaml += "$indent- `n"
                $p = @{
                    IndentLevel = $IndentLevel + 1
                }
                If( $null -ne $item ){
                    $p.InputObject = $item
                }
                $yaml += ConvertTo-Yaml @p
            } else {
                If( $null -eq $item ){
                    $item = "~"
                }
                $yaml += "$indent- $(& $escaper $item)`n"
            }
        }
    } Else {
        $out = If( $null -eq $InputObject ){
            "~"
        } Else {
            "$InputObject"
        }

        $yaml = (& $escaper $out)
    }

    If( $short ){
        $lines = $yaml -split "`n"
        $condensed = for( $i = 0; $i -lt $lines.Count; $i++ ){
            $line = $lines[$i]
            If( $line.Trim() -eq "-" ){
                $i++
                $next_line = $lines[$i]
                $tacks = 0
                while( $next_line.Trim() -eq "-" ){
                    $i++
                    $next_line = $lines[$i]
                    $tacks++
                }
                
                $line.TrimEnd() + (" -" * $tacks) + " " + $next_line.TrimStart()
            } Else {
                $line
            }
        }

        $yaml = $condensed -join "`n"
    }

    $yaml
}
