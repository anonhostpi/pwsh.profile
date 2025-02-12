$DEFAULTS = @{
    Directory = $null
    MainName = "main"
    Extension = "md"
    VariablePattern = "\$\{(?!\$)(.*?)\}"
    Components = $null
}

New-ValidatingFactory -Options @{
    # Invalidators = @{}
    # Cleaners = @{}
    Base = $DEFAULTS
    # Postscripts = @({},{})
    Methods = @{
        Load = {
            param(
                $Directory = $this.Directory,
                $Extension = $this.Extension,
                $MainName = $this.MainName
            )

            $this.Directory = $Directory
            $this.Extension = $Extension
            $this.MainName = $MainName

            Resolve-Path "$Directory\*.$Extension" | ForEach-Object {
                $file = $_
                $properties = Get-Item $file
                $this.Components[$properties.BaseName.ToUpper()] = @{
                    "Contents" = Get-Content $file
                }
            }

            $this.Resolve() | Out-Null
        }
        Resolve = {
            $unmodified = $true

            $variable_pattern = $this.VariablePattern
            $line_ending = "\r{0,1}\n"

            $components = $this.Components
            $keys = $components.Keys | ForEach-Object { $_ }

            $keys | ForEach-Object {
                $key = $_
                $component = $components[$_]
               
                If( -not $component.UsedIn.Count ){
                    If( -not ($component.UsedIn -is [System.Collections.IEnumerable]) ){
                        $component.UsedIn = @()
                        $unmodified = $false
                    }
                }
                If( -not $component.DependsOn.Count ){
                    If( -not ($component.DependsOn -is [System.Collections.IEnumerable]) ){
                        $component.DependsOn = @()
                        $unmodified = $false
                    }
                }

                $contents = $component.Contents

                $contents -split $line_ending | ForEach-Object {
                    $line = $_.Trim()
                    $m = [regex]::Matches($line,$variable_pattern)

                    $m | ForEach-Object {
                        $dependency = $_.Groups[1].Value

                        If( $Component.DependsOn -contains $dependency ){
                            # no-op
                        } Else {
                            $unmodified = $false
                            $component.DependsOn = & {
                                $component.DependsOn
                                $dependency
                            } | Select-Object -Unique

                            If( -not $components[$dependency.ToUpper()] ){
                                $components[$dependency.ToUpper()] = @{}
                            }

                            $dep_component = $components[$dependency.ToUpper()]

                            If( -not $dep_component.UsedIn.Count ){
                                $dep_component.UsedIn = @()
                            }
                            If( -not $dep_component.DependsOn.Count ){
                                $dep_component.DependsOn = @()
                            }

                            $dep_component.UsedIn = & {
                                $dep_component.UsedIn
                                $key
                            } | Select-Object -Unique
                        }
                    }
                }
            }

            return $unmodified
        }
        Set = {
            param(
                $Key, $Value, $NoResolve
            )

            If( -not $this.Components[$key.ToUpper()] ){
                $this.Components[$key.ToUpper()] = @{}
            }

            $this.Components[$key.ToUpper()].Contents = $Value

            If( -not $NoResolve ){
                $this.Resolve() | Out-Null
            }
        }
        Apply = {
            param(
                $Values
            )

            If( $Values -is [System.Collections.IDictionary] ){
                $Values.Keys | ForEach-Object {
                    $this.Set( $_, $Value[$_], $true )
                }
            } Else {
                $Values.PSObject.Properties.Name | ForEach-Object {
                    $this.Set( $_, $Value."$_", $true )
                }
            }

            $this.Resolve() | Out-Null
        }
        Build = {
            $this.Resolve() | Out-Null

            $components = $this.Components
            $keys = $components.Keys | ForEach-Object { $_ }

            $line_ending = "`n"

            $no_deps = foreach( $key in $keys ){
                If( $components[$key].DependsOn.Count -eq 0 ){
                    "$key"
                }
            }
            $unmet = foreach( $key in $keys ){
                If( -not $components[$key].Contains("Contents") ){
                    "$key"
                }
            }

            If( $unmet.Count ){
                $e_title = "Unmet dependencies detected."
                $e_msg = "The following template components could not be fully resolved:"
               
                $e_details = @()
               
                foreach( $key in $keys ){
                    $component = $components[$key]

                    $overlap = foreach( $d in $unmet ){
                        If( $component.DependsOn -contains $d ){
                            $d
                        }
                    }

                    If( $overlap.Count ){
                        $details = @{
                            "$key is missing" = $overlap
                        }
                        $e_details += $details
                    }
                }

                $e_details = ConvertTo-Yaml $e_details 1 -Short

                $msg = @(
                    ""
                    ""
                    $e_title
                    ("  " + $e_msg)
                    $e_details
                ) -join "`n"

                throw $msg
            }

            for( $i=0; $no_deps.Count -ne $keys.Count; $i++ ){
                $key = $no_deps | Select-Object -Index $i

                If( $null -eq $key ){

                    $e_title = "Circular template components or unmet dependencies detected."
                    $e_msg = "The following template components could not be fully resolved:"
                   
                    $e_details = @()

                    foreach( $_key in $keys ){
                        $component = $components[$_key]

                        If( $component.DependsOn.Count ){
                            $details = @{
                                "$key depends on" = $components[$_key].DependsOn
                            }
                            $e_details += $details
                        }
                    }

                    $e_details = ConvertTo-Yaml $e_details 1 -Short

                    $msg = @(
                        ""
                        ""
                        $e_title
                        ("  " + $e_msg)
                        $e_details
                    ) -join "`n"

                    throw $msg
                }

                $component = $components[$key]
                $used_in = $component.UsedIn
                $contents = $component.Contents -join $line_ending

                $used_in | ForEach-Object {
                    $target_key = $_
                    $target_component = $components[$target_key]

                    $target_component.Contents = $target_component.Contents -join $line_ending -ireplace "\$\{$key\}", "$contents"
                    $target_component.DependsOn = $target_component.DependsOn | Where-Object {
                        $_ -ne $key
                    }

                    If( $target_component.DependsOn.Count -eq 0 ){
                        $no_deps = & {
                            $no_deps
                            $target_key
                        }
                    }
                }
            }

            If( -not $this.Resolve() ){
                return $this.Build()
            }

            If( $components.Contains( $this.MainName ) ){
                $components[ $this.MainName ].Contents.Trim()
            }
        }
    }
} -Name "TextTemplate"
