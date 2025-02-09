function global:Resolve-Parameter {
    param(
        [scriptblock] $Invalidator,
        [scriptblock] $Cleaner = { param($o); $o },
        $Defaulter = { param($o); $o },
        $Value,
        $Original,
        $Resolving
    )

    $sanitized_invalidator = If( $Invalidator -eq $null ){
        If( $Defaulter -is [string] ){
            { param($s); [string]::IsNullOrWhiteSpace($s) }
        } Else {
            { param($o); $null -eq $o }
        }
    } Else {
        $Invalidator
    }

    $used_value = If( & $sanitized_invalidator $Value ){
        If( $Defaulter -is [scriptblock] ){
            & $Defaulter $Value $Original $Resolving
        } Else {
            $Defaulter
        }
    } else {
        $Value
    }

    & $Cleaner $used_value
}

function global:Resolve-Options {
    param(
        [System.Collections.IDictionary] $Invalidators = @{},
        [System.Collections.IDictionary] $Cleaners = @{},
        [System.Collections.IDictionary] $Base = @{}, # Defaulters
        [System.Collections.IDictionary] $Options = @{},
        [System.Collections.IDictionary] $Original = $Options,
        [System.Collections.IDictionary] $Resolving
    )

    $Invalidators = If( $Invalidators ){ $Invalidators } Else { @{} }
    $Cleaners = If( $Cleaners ){ $Cleaners } Else { @{} }
    $Base = If( $Base ){ $Base } Else { @{} }
    $Options = If( $Options ){ $Options } Else { @{} }

    $resolved = [ordered]@{}

    If( $Resolving -eq $Null ){
        $Resolving = $resolved
    }

    $acceptable_keys = $Base.Keys | ForEach-Object { "$_" }
    If( $acceptable_keys.Count ){
        $acceptable_keys | ForEach-Object {
            $recurse = $Base[$_] -is [System.Collections.IDictionary]

            $_invalidator = If( $Invalidators[$_] ){
                $Invalidators[$_]
            } Elseif( $recurse ){
                @{}
            } Else {
                { param($o); $null -eq $o } # Non-Null (so that defaulting works)
            }
            $_cleaner = If( $Cleaners[$_] ){
                $Cleaners[$_]
            } Elseif( $recurse ) {
                @{}
            } Else {
                { param( $o ); $o } # PassThrough
            }

            $_option = $Options[$_]
            $_base = $Base[$_]
           
            If( $recurse ){
                If( -not ($_invalidator -is [System.Collections.IDictionary]) ){
                    throw "Mismatched types between Base Options and Invalidator (Bad) Trees"
                }
                If( -not ($_cleaner -is [System.Collections.IDictionary]) ){
                    throw "Mismatched types between Base Options and Cleaner/Sanitizer Trees"
                }
                If( $null -ne $_option ){
                    If( -not ($_option -is [System.Collections.IDictionary]) ){
                        throw "Mismatched types between Base Options and Provided Options Trees"
                    }
                }

                $resolved[$_] = Resolve-Options $_invalidator $_cleaner $_base $_option $Original $Resolving
            } Else {
                $resolved[$_] = Resolve-Parameter $_invalidator $_cleaner $_base $_option $Original $Resolving
            }
        }
    }

    $resolved
}
