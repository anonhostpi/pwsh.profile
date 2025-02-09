New-Module -Name SloppyOneDrive {

    $REGISTRY= "HKCU:\Software\Microsoft\OneDrive\Accounts"
    $URL_SUFFIX = "?web=1"

    function global:Get-OneDriveNames {
        Get-ChildItem -Path $REGISTRY | Select-Object -ExpandProperty PSChildName
    }

    function global:Get-OneDriveEmails {
        $out = [ordered]@{}
        Get-ChildItem -Path $REGISTRY | ForEach-Object {
            $key = $_.PSChildName
            $email = $_ | Get-ItemProperty | Select-Object -ExpandProperty UserEmail

            $out[$key] = $email
        }
        New-Object psobject -Property $out
    }

    function global:Get-OneDriveRoots {
        $out = [ordered]@{}
        $h = (Resolve-Path "~").ToString()
        Get-ChildItem -Path $REGISTRY | ForEach-Object {
            $key = $_.PSChildName
            $path = $_.PSPath
            $root_entries = Get-ItemProperty "$path\ScopeIdToMountPointPathCache" | Select-Object -ExcludeProperty PS*
            $root_entries = ConvertTo-OrderedHashtable $root_entries


            $out[$key] = $root_entries.Values | ForEach-Object {
                $_.Replace($h,"~")
            }
        }
        $out
    }

    function global:Get-SharepointRoots {
        $out = [ordered]@{}
        $all = Get-OneDriveRoots
        $all.Keys | ForEach-Object {
            $name = $_
            $hits = $all[$name] | ForEach-Object {
                If( -not $_.StartsWith("~\OneDrive") ){
                    $out[$name] = & {
                        $out[$name]
                        $_
                    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                }
            }
        }
        $out
    }

    function global:Get-OneDrive {
        param( [string] $Key )

        $entries = Get-ChildItem -Path $REGISTRY

        $keys = $entries | Select-Object -ExpandProperty PSChildName
        $emails = @{}
        $roots = @{}

        $entries | ForEach-Object {
            $_key = $_.PSChildName
            $_props = $_ | Get-ItemProperty | Select-Object -Property UserEmail #,UserFolder
            $_path = $_.PSPath
            $root_entries = Get-ItemProperty "$_path\ScopeIdToMountPointPathCache" | Select-Object -ExcludeProperty PS*
            $root_entries = ConvertTo-OrderedHashtable $root_entries

            $root_entries.Values | ForEach-Object {
                $roots[$_] = $_key
            }

            $emails[$_props.UserEmail] = $_key
        }

        # could be plural, if $provided_path === $true
        $mapped_keys = & {
            If( $keys -contains $Key ){
                $Key
            } Elseif( -not [string]::IsNullOrWhiteSpace( $emails[$key] ) ){
                $emails[$key]
            } Else {
                If( [string]::IsNullOrWhiteSpace($Key) ){
                    $Key = "."
                }

                $path_provided = Try {
                    Test-Path $Key -ErrorAction Stop
                } Catch {
                    $false
                }

                If( $path_provided ){
                    $provided_paths = Resolve-Path $key | ForEach-Object { "$_" }

                    $roots.Keys | Where-Object {
                        $root = $_
                        $hits = $provided_path | Where-Object {
                            $path = $_
                            "$path".StartsWith("$root")
                        }

                        $hits.Count
                    } | ForEach-Object { "$_" }
                }
            }
        } | Where-Object {
            -not [string]::IsNullOrWhiteSpace( "$_" )
        }
        $mapped_keys = If( $mapped_keys.Count ){
            $mapped_keys
        } Else {
            "*"
        }
       
        $mapped_keys | ForEach-Object {
            Get-ItemProperty "$REGISTRY\$_"
        }
    }

    function global:Get-OneDriveEndpoint {
        param( [string] $Key )

        Get-OneDrive $key | Select-Object -ExpandProperty ServiceEndpointUri | ForEach-Object {
            "$_".Trim() -replace "_api$",""
        }
    }

    function global:Get-OneDriveDownloadURL {
        param(
            [string] $Path = ".",
            [string] $Sharepoint,
            [string] $Drive
        )

        Try {
            If( -not (Test-Path $Path -ErrorAction Stop) ){
                throw "Path does not exist"
            }
        } Catch {
            throw "Invalid path provided: $_"
        }

        Resolve-Path $Path | ForEach-Object {
            $resolved = "$_"
            $onedrive = Get-OneDrive $resolved
            $path = $onedrive.PSPath

            $user_folder = $onedrive.UserFolder
            $api_endpoint = $onedrive | Select-Object -ExpandProperty ServiceEndpointUri #,UserFolder
            $endpoint = $api_endpoint.Trim() -replace "[\/\\](?:_api)?$",""
           
            $root_entries = Get-ItemProperty "$path\ScopeIdToMountPointPathCache" | Select-Object -ExcludeProperty PS*
            $root_entries = ConvertTo-OrderedHashtable $root_entries

            $root_entries.Values | ForEach-Object {
                $root = $_

                If( $resolved.StartsWith( $root.TrimEnd("\") ) ){
                    $urified = $resolved.Replace($root.TrimEnd("\"),"").Replace("\","/").TrimStart("/")
                    If( $root -ne $user_folder ){
                        $sanitized_sharepoint = If( [string]::IsNullOrWhiteSpace($Sharepoint) ){
                            $root_name = $root | Split-Path -Leaf
                            $segments = $root_name -split " - "
                            If( $root_name.Trim() -match " \- (?:Shared )?Documents$" ){
                                $root_name -replace " \- (?:Shared )?Documents$",""
                            }
                        } Else {
                            $Sharepoint
                        }
                        $sanitized_sharepoint = $sanitized_sharepoint.Replace(" ","")

                        If( [string]::IsNullOrWhiteSpace($sanitized_sharepoint) ){
                            $urified
                        } ELse {
                            If( $sanitized_sharepoint.StartsWith("http") ){
                                $sanitized_drive = If( [string]::IsNullOrWhiteSpace($Drive) ){
                                    "Documents"
                                } Else {
                                    $Drive
                                }
                                "$sanitized_sharepoint/$sanitized_drive/$urified"
                            } Else {
                                $spo_uri = $onedrive.TeamSiteSPOResourceId.TrimEnd("/")
                                If( $sanitized_sharepoint.StartsWith("sites/") ){
                                    $sanitized_drive = If( [string]::IsNullOrWhiteSpace($Drive) ){
                                        "Documents"
                                    } Else {
                                        $Drive
                                    }
                                    "$spo_uri/$sanitized_sharepoint/$sanitized_drive/$urified"
                                } Else {
                                    $sanitized_drive = If( [string]::IsNullOrWhiteSpace($Drive) ){
                                        "Shared Documents"
                                    } Else {
                                        $Drive
                                    }

                                    If( $sanitized_sharepoint.StartsWith("teams/") ){
                                        "$spo_uri/$sanitized_sharepoint/$sanitized_drive/$urified"
                                    } Else {
                                        "$spo_uri/teams/$sanitized_sharepoint/$sanitized_drive/$urified"
                                    }
                                }
                            }
                        }
                    } Else {
                        "$endpoint/Documents/$urified"
                    }
                }
            }
        }
    }

    function global:Get-OneDriveURL {
        param(
            [string] $Path = ".",
            [string] $Sharepoint,
            [string] $Drive
        )

        (Get-OneDriveDownloadURL $Path $Sharepoint $Drive) | ForEach-Object { "$_" + "$URL_SUFFIX" }
    }

    function global:Get-OneDriveChildItems {
        param(
            [string] $Directory = ".",
            [string] $Sharepoint,
            [string] $Drive
        )

        $out = [ordered]@{}

        $Directory | Resolve-Path | ForEach-Object {
            $dir = $_

            Try {
                If( -not (Test-Path -PathType Container -Path $dir -ErrorAction Stop) ){
                    throw "Directory '$dir' does not exist"
                }
            } Catch {
                throw "Invalid directory ('$dir') provided: $_"
            }

            "$dir\*" | Resolve-Path | Where-Object {
                Test-Path -PathType Leaf $_
            } | ForEach-Object {
                $path = "$_"
                $name = $path | Split-Path -Leaf

                $url = Get-OneDriveURL $path

                $out[$name] = $url
            }
        }

        $out
    }

    function global:Open-SharepointDrive {
        param( $Sharepoint )
        $sanitized_sharepoint = $Sharepoint.Replace(" ","")

        $url = If( [string]::IsNullOrWhiteSpace($sanitized_sharepoint) ){
            throw "No sharepoint provided"
        } ELse {
            If( $sanitized_sharepoint.StartsWith("http") ){
                $sanitized_drive = "Documents"
                "$sanitized_sharepoint/$sanitized_drive/$urified"
            } Else {
                $onedrive = Get-OneDrive
                $spo_uri = $onedrive.TeamSiteSPOResourceId.TrimEnd("/")
                If( $sanitized_sharepoint.StartsWith("sites/") ){
                    $sanitized_drive = "Documents"
                    "$spo_uri/$sanitized_sharepoint/$sanitized_drive/$urified"
                } Else {
                    $sanitized_drive = "Shared Documents"

                    If( $sanitized_sharepoint.StartsWith("teams/") ){
                        "$spo_uri/$sanitized_sharepoint/$sanitized_drive/$urified"
                    } Else {
                        "$spo_uri/teams/$sanitized_sharepoint/$sanitized_drive/$urified"
                    }
                }
            }
        }

        Start $url
    }

    Export-ModuleMember
} | Import-Module
