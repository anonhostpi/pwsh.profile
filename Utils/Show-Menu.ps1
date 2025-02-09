function global:Show-Menu {
    param(
        [switch] $Multi,
        [string[]] $Options,
        [string[]] $Defaults = (& {
            If( $Multi ){
                @()
            } Else {
                $Options | Select-Object -Index 0
            }
        }),
        [string] $Title = "Select an Option:",
        [switch] $ArrowsSelect,
        [switch] $ShowSelected
    )

    Write-Host

    $sanitized = $Options | Select-Object -unique

    $selected = @{
        index = 0
        drawn = $false
        options = $sanitized | Where-Object {
            $Defaults -contains $_
        }
    }

    function Draw-Menu {
        $height = $host.UI.RawUI.BufferSize.Height

        If( $sanitized.Count -gt $height - 3 ){
            throw "Viewport too small"
        }

        If( $selected.drawn ){
            $host.UI.RawUI.CursorPosition = New-Object Management.Automation.Host.Coordinates(0, 0)
        }

        $width = $host.UI.RawUI.BufferSize.Width
        for( $i=0; $i -lt $height - 1; $i++ ){
            Write-Host (" "*$Width)
        }
        $host.UI.RawUI.CursorPosition = New-Object Management.Automation.Host.Coordinates(0, 0)

        for( $i=0; $i -lt $sanitized.Length + 1; $i++ ){
            If( $i -eq 0 ){
                Write-Host $Title
            } Else {
                $is_selected = ($i - 1) -eq $selected.index
                $is_checked = $selected.options -contains $sanitized[($i - 1)]

                $indicator = If($is_checked) { "[x]" } Else { "[ ]" }
                $highlight = If($is_selected) { "> " } Else { "  " }

                Write-Host "$highlight$indicator $($sanitized[($i - 1)])"
            }
        }
        $host.UI.RawUI.CursorPosition = New-Object Management.Automation.Host.Coordinates(0, ($height - 1))
        Write-Host -NoNewLine (" "*$Width)
        If( $ShowSelected ){
            $host.UI.RawUI.CursorPosition = New-Object Management.Automation.Host.Coordinates(0, ($height - 1))
            $end = "Select an Option. Selected: $($Selected.Options -join ", ")"
            If( $end.Length -gt $width - 3 ){
                $end = $end.SubString(0, $width - 3) + "..."
            }
            Write-Host -NoNewLine $end
        }

        $selected.drawn = $true
    }

    # Handle user input for selection
    function Handle-Input {
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($key.VirtualKeyCode) {
            # Arrow Down
            40 {
                $selected.index = ($selected.index + 1) % $sanitized.Length
                If( -not $Multi ){
                    $current_option = $sanitized[$selected.index]
                    if ($selected.options -contains $current_option) {
                        $selected.options = $selected.options | Where-Object { $_ -ne $current_option }
                    } else {
                        $selected.options = & {
                            If( $Multi ){ $selected.options }
                            $current_option
                        } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    }
                }
            }
            # Arrow Up
            38 {
                $selected.index = ($selected.index - 1 + $sanitized.Length) % $sanitized.Length
                If( -not $Multi ){
                    $current_option = $sanitized[$selected.index]
                    if ($selected.options -contains $current_option) {
                        $selected.options = $selected.options | Where-Object { $_ -ne $current_option }
                    } else {
                        $selected.options = & {
                            If( $Multi ){ $selected.options }
                            $current_option
                        } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    }
                }
            }
            # Spacebar (toggle selection)
            32 {
                If( $Multi ){
                    $current_option = $sanitized[$selected.index]
                    if ($selected.options -contains $current_option) {
                        $selected.options = $selected.options | Where-Object { $_ -ne $current_option }
                    } else {
                        $selected.options = & {
                            If( $Multi ){ $selected.options }
                            $current_option
                        } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    }
                }
            }
            # Enter key to finalize selection
            13 {
                return $true
            }
        }
    }

    # Main loop to show the menu and handle input
    while ($true) {
        Draw-Menu
        if (Handle-Input) {
            break
        }
    }
    $height = $host.UI.RawUI.BufferSize.Height
    $width = $host.UI.RawUI.BufferSize.Width

    $host.UI.RawUI.CursorPosition = New-Object Management.Automation.Host.Coordinates(0, ($height - 1))
    Write-Host -NoNewLine (" "*$Width)

    $y = If( ($sanitized.Count + 1) -ge $height ){
        $height
    } Else {
        ($sanitized.Count + 1)
    }
    $host.UI.RawUI.CursorPosition = New-Object Management.Automation.Host.Coordinates(0, $y)
    Write-Host

    return $selected.options
}
