function global:ConvertTo-OrderedHashtable {
    param (
        [Parameter(Mandatory)]
        $InputObject,
        $TypeException,
        [switch] $Shallow
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        # Convert dictionaries to ordered hashtable
        $orderedHashtable = [ordered]@{}
        foreach ($key in $InputObject.Keys) {
            $orderedHashtable[$key] = If( $Shallow ) {
                $InputObject[$key]
            } ElseIf( $null -ne $InputObject[$key] ){
                ConvertTo-OrderedHashtable -InputObject $InputObject[$key] -TypeException $TypeException
            } Else {
                $null
            }
        }
        return $orderedHashtable
    }
    elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        # Convert arrays/lists recursively
        $out = foreach( $in in $InputObject ){
            If( $null -ne $in ){
                $p = @{
                    InputObject = $in
                    TypeException = $TypeException
                }
                If( $Shallow ){ $p.Shallow = $true }
                ConvertTo-OrderedHashtable @p
            } Else {
                $null
            }
        }
        return @($out)
    }
    elseif ($InputObject -is [psobject] -and -not ($TypeException -and $InputObject -is $TypeException)) {
        # Convert PSObject to ordered hashtable
        $orderedHashtable = [ordered]@{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $value = If( [string]::IsNullOrWhiteSpace( $property.Value.PSObject.BaseObject ) ){
                If( $property.Value.PSObject.BaseObject -eq $null ){
                    $null
                } Else {
                    $value
                }
            } Else {
                $property.Value.PSObject.BaseObject
            }
            $orderedHashtable[$property.Name] = If( $Shallow ) {
                $value
            } ElseIf( $null -ne $value ){
                ConvertTo-OrderedHashtable -InputObject $value -TypeException $TypeException
            } Else {
                $null
            }
        }
        return $orderedHashtable
    }
    else {
        # Return primitive values directly
        return $InputObject
    }
}
