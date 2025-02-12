function global:New-Form {
    param(
        $Name,
        $Questions,
        $Defaults = @{}
    )

    $tabled = If( $Questions -is [System.Collections.IDictionary] ){
        $Questions
    } Elseif( $Questions -is [string] ){
        @{ $Questions = $null }
    } Elseif( $Questions -is [System.Collections.IEnumerable] ){
        $keys = $Questions | ForEach-Object { $_ }
        $table = @{}
        foreach( $key in $keys ){
            $table[$key] = $null
        }
        $table   
    } Else {
        throw "Invalid type for Questions"
    }

    $Defaults = ConvertTo-OrderedHashtable $Defaults [scriptblock]

    New-Module -ArgumentList $Name,$tabled,$Defaults -ScriptBlock {
        param( $Name, $Questions, $Defaults )
        
        $Options = @{
            Base = $Questions
            Methods = @{
                Apply = {
                    param( $Values )

                    ForEach-Leaf -InputObject $Values -Process {
                        param(
                            $KeyChain,
                            $Value
                        )

                        $obj = $this
                        $root = $KeyChain | Select-Object -SkipLast 1
                        $leaf = $KeyChain | Select-Object -Last 1

                        ForEach( $key in $root ){
                            $obj = $obj."$key"
                        }

                        $obj."$leaf" = $Value
                    }
                }
                Ask = {

                    $form = $this | Select-Object -ExcludeProperty Path

                    ForEach-Leaf -InputObject $form -Process {
                        param(
                            $KeyChain,
                            $Value
                        )

                        $obj = $this
                        $def = $Defaults
                        $leaf = $KeyChain | Select-Object -Last 1

                        for( $i=0; $i -lt $KeyChain.Count; $i++ ){
                            $key = $KeyChain[$i]
                            $obj = If( $i -eq $KeyChain.Count-1 ){
                                $obj # no change
                            } Else {
                                $obj."$key"
                            }
                                
                            If( $def -is [System.Collections.IDictionary] ){
                                $def = $def."$key"
                            } Else {
                                $def = $null
                            }
                        }

                        If( $def -is [scriptblock] ){
                            $def = & $def $this
                        }

                        $q = $KeyChain -join "."
                        If( -not [string]::IsNullOrWhiteSpace( $def ) ){
                            $q += " (default: $def)"
                        }
                        If( @(
                            $null -eq $obj."$leaf"
                            [string]::IsNullOrWhiteSpace( $obj."$leaf" )
                        ) -contains $true ){
                            $obj."$leaf" = Read-Host "$q`?"
                        } Else {
                            return
                        }

                        If( [string]::IsNullOrWhiteSpace( $obj."$leaf" ) ){
                            $obj."$leaf" = $def
                        }
                    }
                }
            }
        }

        New-ValidatingPersistableFactory -Name $Name -Options $Options
    } | Import-Module
}
