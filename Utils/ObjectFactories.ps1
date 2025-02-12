New-Module -Name "ObjectFactories" -Scriptblock {
    function global:New-ValidatingFactory {
        param(
            $Options,
                # - Invalidators
                # - Cleaners
                # - Base
                # - Postscripts
                    # - Arguments:
                        # - $Object: equivalent to $this, but cleaned up
                        # - $Source: equivalent to $this, without sanitation and after conversion to hashtable/psobject
                        # - $Original: equivalent to $this, but as the user provided it (can be a path, JSON string, hashtable, or psobject)
                        # - $Trees: the Objects used for Resolve-Options and Resolve-Parameters
                # - Methods
            $PostscriptOptions,
            [string] $Name,
            [switch] $Scriptblock
        )

        $output = @{}

        $p = @{
            ArgumentList = @($Options, $output, $PostscriptOptions)
        }

        If( -not [string]::IsNullOrWhitespace( $Name ) ){
            $p.Name = $Name
        }

        New-Module @p -Scriptblock {
            param(
                $Options,
                    # - Invalidators
                    # - Cleaners
                    # - Base
                    # - Postscripts
                        # - Arguments:
                            # - $Object: equivalent to $this, but cleaned up
                            # - $Source: equivalent to $this, without sanitation and after conversion to hashtable/psobject
                            # - $Original: equivalent to $this, but as the user provided it (can be a path, JSON string, hashtable, or psobject)
                            # - $Trees: the Objects used for Resolve-Options and Resolve-Parameters
                    # - Methods
                $Output,
                    # - Import
                $PostscriptOptions
            )

            $trees = @{
                Invalidators = (& { If( $Options.Invalidators ){ ConvertTo-OrderedHashtable $Options.Invalidators [scriptblock] } Else { @{} } })
                Cleaners = (& { If( $Options.Cleaners ){ ConvertTo-OrderedHashtable $Options.Cleaners [scriptblock] } Else { @{} } })
                Base = (& { If( $Options.Base ){ ConvertTo-OrderedHashtable $Options.Base [scriptblock] } Else { @{} } })
            }

            $imports = @{
                Post = $Options.Postscripts
                Methods = $Options.Methods
            }

            $imports.Methods.Clone = {
                & $Output.Import $this
            }

            $Output.Import = {
                param(
                    $Source,
                    $Original = $Source
                )

                If( $Source -eq $null ){
                    $Source = @{}
                }

                $props = $Source

                if ($Source -is [System.Collections.IDictionary]) {
                    # no-op
                }
                elseif ($Source -is [string]){
                    $props = Try {
                        If( Test-Path $Source -ErrorAction Stop ){
                            Get-Content -Raw $Source
                        } Elseif( $Source.Trim().EndsWith(".json") ){
                            "{}"
                        } Else {
                            $props
                        }
                    } Catch {
                        $props
                    }

                    Try {
                        $props = $props | ConvertFrom-Json
                    } Catch {
                        throw "Provided string is not an acceptable path nor acceptable JSON: $Source"
                    }

                    return & $Output.Import $props $Original
                }
                elseif ($Source -is [System.Collections.IEnumerable]) {
                    return @($Source | ForEach-Object { & $Output.Import $Source $Original })
                }
                elseif ( -not ($Source -is [PSObject])) {
                    throw "Provided argument is not an importable type (JSON-string, IDictionary, PSObject, or enumerable of the prior 3)"
                }

                $props = ConvertTo-OrderedHashtable $props
                $props = Resolve-Options $trees.Invalidators $trees.Cleaners $trees.Base $props

                $keys = $props.Keys | ForEach-Object { $_ }

                $shared = @{
                    Object = New-Object psobject
                }

                If( $Keys.Count ){
                    New-Module {
                        param(
                            $Store,
                            $Output,
                            $Trees
                        )

                        $cache = @{}
                        $cache.Store = $Store
                        $cache.ScriptProperties = [ordered]@{}
                        $proxy = @{
                            Set = {
                                param(
                                    $Key,
                                    $Value
                                )

                                $invalidator = $Trees.Invalidators[$Key]
                                $cleaner = $Trees.Cleaners[$Key]
                                $base = $cache.Store[$Key]

                                # important for allowing hashtables:
                                $recurse = $Trees.Base[$Key] -is [System.Collections.IDictionary]

                                $_invalidator = If( $Trees.Invalidators[$Key] ){
                                    $Trees.Invalidators[$Key]
                                } Elseif( $recurse ){
                                    @{}
                                } Else {
                                    { $false } # PassThrough
                                }
                                $_cleaner = If( $Trees.Cleaners[$Key] ){
                                    $Trees.Cleaners[$Key]
                                } Elseif( $recurse ) {
                                    @{}
                                } Else {
                                    { param( $o ); $o } # PassThrough
                                }

                                $_option = $value
                                $_store = $cache.Store[$Key]
                               
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

                                    $cache.Store[$key] = Resolve-Options $_invalidator $_cleaner $_store $_option
                                } Else {
                                    $cache.Store[$key] = Resolve-Parameter $_invalidator $_cleaner $_store $_option
                                }
                            }
                            Get = {
                                param(
                                    $Key
                                )

                                $cache.Store[$key]
                            }
                        }

                        $cache.Store.Keys | ForEach-Object {
                            $key = "$_"

                            $setter = "{ param( `$Value ); & `$proxy.Set `"$key`" `$Value }"
                            $setter = Invoke-Expression "( & { $setter } )"
                            $getter = "{ & `$proxy.Get `"$key`" }"
                            $getter = Invoke-Expression "( & { $getter } )"

                            $cache.ScriptProperties[$key] = @{
                                Setter = $setter
                                Getter = $getter
                            }
                        }

                        Add-ScriptProperties $Output.Object $cache.ScriptProperties

                        Export-ModuleMember
                    } -ArgumentList $props,$shared,$trees | Import-Module
                }

                $out = $shared.Object
               
                Add-ScriptMethods $out $imports.Methods

                If( $null -ne $imports.Post ){
                    $imports.Post | Where-Object { $_ } | ForEach-Object {
                        [scriptblock] $sb = $_

                        & $sb $out $Source $Original $trees $PostscriptOptions | Out-Null
                    }
                }

                $out
            }
            Export-ModuleMember
        } | Import-Module

        If( $Scriptblock -or [string]::IsNullOrWhitespace( $Name ) ){
            $Output.Import
        } Else {
            Set-Item -Path "Function:\global:New-$Name" -Value $Output.Import
            Set-Alias -Scope "Global" -Name "Import-$Name" -Value "New-$Name"
        }
    }

    function global:New-ValidatingPersistableFactory {
        param(
            $Options,
                # - Invalidators
                # - Cleaners
                # - Base
                # - Postscripts
                    # - Arguments:
                        # - $Object: equivalent to $this, but cleaned up
                        # - $Source: equivalent to $this, without sanitation and after conversion to hashtable/psobject
                        # - $Original: equivalent to $this, but as the user provided it (can be a path, JSON string, hashtable, or psobject)
                        # - $Trees: the Objects used for Resolve-Options and Resolve-Parameters
                # - Methods

                # - LiveProperties
            [string] $Name,
            [switch] $Scriptblock
        )

        $Output = @{}

        $ordered = ConvertTo-OrderedHashtable $Options -Shallow

        New-Module -ArgumentList $ordered,$Name,$Scriptblock,$Output -Scriptblock {
            param(
                $Options,
                    # - Invalidators
                    # - Cleaners
                    # - Base
                    # - Postscripts
                        # - Arguments:
                            # - $Object: equivalent to $this, but cleaned up
                            # - $Source: equivalent to $this, without sanitation and after conversion to hashtable/psobject
                            # - $Original: equivalent to $this, but as the user provided it (can be a path, JSON string, hashtable, or psobject)
                            # - $Trees: the Objects used for Resolve-Options and Resolve-Parameters
                    # - Methods

                    # - LiveProperties
                [string] $Name,
                $Scriptblock,
                $Output
                    # - Result
            )

            [string[]] $live_properties = & {
                $Options.LiveProperties
                "Path"
            } | Where-Object { $_ } | Select-Object -Unique

            $initial_live_props = [ordered]@{}
            $live_properties | ForEach-Object {
                $initial_live_props[$_] = $null
            }

            If( $null -eq $Options.Methods ){
                $Options.Methods = @{}
            }

            $Options.Postscripts = & {
                {
                    param(
                        $Object,
                        $Source,
                        $Original,
                        $Trees
                    )

                    Add-NoteProperties $Object $initial_live_props

                    If( Test-WindowsPath $Original ) {
                        $Object.Path = $Original
                    }
                }
                $Options.Postscripts
            } | Where-Object { $_ } | Select-Object -Unique
           
            $Options.Methods.Save = {
                param( $Path = $this.Path )
                If( $this.Onsave ){
                    $this.Onsave( $Path )
                }
                $this.Path = $Path
                $dir = $Path | Split-Path -Parent

                If( -not [string]::IsNullOrWhiteSpace( $dir ) ){
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                }

                $this | Select-Object -ExcludeProperty $live_properties | ConvertTo-Json -Depth 100 | Out-File $Path
            }

            $p = @{
                Options = $Options
                Name = $Name
                Scriptblock = [bool] $Scriptblock
            }

            $Output.Results = New-ValidatingFactory @p

            Export-ModuleMember
        } | Import-Module

        return $Output.Results
    }

    function global:New-SimpleFactory {
        param(
            $Options,
                # - NoteProperties
                # - ScriptMethods
                # - ScriptProperties
                # - Postscripts
            [string] $Name,
            [switch] $Scriptblock
        )

        $output = @{}

        $p = @{
            ArgumentList = @($Options, $output)
        }

        If( -not [string]::IsNullOrWhitespace( $Name ) ){
            $p.Name = $Name
        }

        New-Module @p -Scriptblock {
            param(
                $Options,
                    # - NoteProperties
                    # - ScriptMethods
                    # - ScriptProperties
                    # - Postscripts
                $Output
                    # - New
            )

            $descriptor = ConvertTo-OrderedHashtable $Options -Shallow

            $Output.New = {
                param( $Values )

                $object = New-Object psobject -Property $descriptor.NoteProperties

                Add-ScriptMethods $object $descriptor.ScriptMethods
                Add-ScriptProperties $object $descriptor.ScriptProperties
               
                If( $descriptor.Postscripts -ne $null ){
                    $descriptor.Postscripts | Where-Object { $_ } | ForEach-Object {
                        [scriptblock] $sb = $_

                        & $sb $object $descriptor $Values | Out-Null
                    }
                }

                $object
            }
        } | Import-Module

        If( $Scriptblock -or [string]::IsNullOrWhitespace( $Name ) ){
            $output.New
        } Else {
            Set-Item -Path "Function:\global:New-$Name" -Value $Output.New
        }
    }

    Export-ModuleMember
} | Import-Module
