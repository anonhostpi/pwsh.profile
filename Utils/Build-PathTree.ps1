
function global:Build-PathTree {
    param ( [string] $Path )

    $tree = [ordered]@{}

    if (Test-Path $Path -PathType Container) {
        Get-ChildItem -Path $Path | ForEach-Object {
            if ($_.PSIsContainer) {
                $tree[$_.Name] = Build-Tree -CurrentPath $_.FullName
            } else {
                $tree[$_.Name] = $_.FullName
            }
        }
    } else {
        return $Path
    }

    return $tree
}