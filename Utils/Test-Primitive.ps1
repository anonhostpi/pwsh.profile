function global:Test-Primitive {
    param( $Value )

    return (& {
        $null -eq $Value
        
        $Value -is [bool]
        $Value -is [switch]

        $Value -is [byte]
        $Value -is [sbyte]
        
        $Value -is [char]
        $Value -is [string]

        $Value -is [int16]
        $Value -is [int32]
        $Value -is [int64]
        $Value -is [uint16]
        $Value -is [uint32]
        $Value -is [uint64]

        $Value -is [single]
        $Value -is [double]

        Try {
            $Value -is [int128]
            $Value -is [uint128]

            $Value -is [decimal]
        } Catch {}
    }) -contains $true
}