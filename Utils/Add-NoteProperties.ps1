function global:Add-NoteProperties {
    param(
        [psobject] $target,
        [System.Collections.IDictionary] $Members
    )

    $keys = $Members.Keys | ForEach-Object { $_ }

    If( $keys.Count ){
        $keys | ForEach-Object {
            $target | Add-Member -MemberType NoteProperty -Name $_ -Value $Members[$_] -Force
        }
    }
}
