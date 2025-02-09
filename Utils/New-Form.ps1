function global:New-Form {
    param( $Name, $Questions )

    $Options = @{
        NoteProperties = $Questions
        Postscripts = {
            param(
                $Object,
                $Descriptor,
                $Values
            )

            $sanitized = If( $Values -eq $null ){ @{} } Else { $Values }

            $Object.Apply( $sanitized )
        }
        ScriptMethods = @{
            Apply = {
                param( $Values )
                $ordered = ConvertTo-OrderedHashtable $Values

                $ordered.Keys | ForEach-Object {
                    $q = $_
                    $a = $ordered[$q]
                    Try {
                        $this."$q" = $a
                    } Catch {}
                }
            }
            Ask = {
                $ordered = ConvertTo-OrderedHashtable $this

                $ordered.Keys | ForEach-Object {
                    $q = $_
                    $a = $ordered[$q]

                    If( [string]::IsNullOrWhiteSpace( $a ) ){
                        $this."$q" = Read-Host "$q`?"
                    }
                }
            }
        }
    }

    New-SimpleFactory -Name $Name -Options $Options
}
