function global:ForEach-Leaf {
    param(
        $KeyChain,
        $InputObject,
        [scriptblock] $Process,
        [switch] $Flat,
        [switch] $Tree,
        [switch] $JsonMode
    )

    If( $Process -and (-not $Tree) ){
        $Flat = $true
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        # Convert dictionaries to ordered hashtable
        $orderedHashtable = [ordered]@{}
        $keys = $InputObject.Keys | ForEach-Object { $_ }
        $array = foreach ($_key in $keys) {
            $chain = & { $KeyChain; $_key } | Where-Object { $null -ne $_ }
            $out = ForEach-Leaf -KeyChain $chain -InputObject $InputObject."$_key" -Process $Process -JsonMode:$JsonMode -Flat:$Flat -Tree:$Tree
            If( $Flat ){
                $out
            } Else {
                $orderedHashtable[$_key] = $out
            }
        }
        If( $Flat ){
            return $array | Where-Object { $null -ne $_ }
        } Else {
            return $orderedHashtable
        }
    }
    elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        # Convert arrays/lists recursively
        $out = foreach( $in in $InputObject ){
            ForEach-Leaf -KeyChain $KeyChain -InputObject $in -Process $Process -JsonMode:$JsonMode -Flat:$Flat -Tree:$Tree
        }
        return @($out)
    }
    elseif ( -not (Test-Primitive $InputObject) ) {
        # Convert PSObject to ordered hashtable
        $orderedHashtable = [ordered]@{}
        $props = $InputObject.PSObject.Properties | ForEach-Object { $_ }
        $array = foreach ($property in $props) {
            $value = $property.Value
            $chain = & { $KeyChain; $property.Name } | Where-Object { $null -ne $_ }
            $out = ForEach-Leaf -KeyChain $chain -InputObject $value -Process $Process -JsonMode:$JsonMode -Flat:$Flat -Tree:$Tree
            
            If( $Flat ){
                $out
            } Else {
                $orderedHashtable[$property.Name] = $out
            }
        }
        If( $Flat ){
            return $array | Where-Object { $null -ne $_ }
        } Else {
            return $orderedHashtable
        }
    }
    else {
        $out = If( $JsonMode ){
            Try {
                If( Test-Path $InputObject -ErrorAction Stop ){
                    If( Test-Path -PathType Container $InputObject -ErrorAction Stop ){
                        $parsed = Build-PathTree -Path $InputObject
                        return ForEach-Leaf -KeyChain $KeyChain -InputObject $parsed -Process $Process -JsonMode:$JsonMode -Flat:$Flat -Tree:$Tree
                    } Else {
                        $parsed = Get-Content $InputObject -Raw | ConvertFrom-Json
                        return ForEach-Leaf -KeyChain $KeyChain -InputObject $parsed -Process $Process -JsonMode:$JsonMode -Flat:$Flat -Tree:$Tree
                    }
                } Else {
                    $InputObject
                }
            } Catch {
                $InputObject
            }
        } Else {
            $InputObject
        }

        If( $Process ){
            & $Process $KeyChain $out
        } Else {
            $out
        }
    }
}