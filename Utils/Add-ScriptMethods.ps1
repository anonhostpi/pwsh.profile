function global:Add-ScriptMethods {
    param(
        [psobject] $Target,
        [System.Collections.IDictionary] $Members
    )

    $keys = $Members.Keys | ForEach-Object { $_ }

    If( $keys.Count ){
        $keys | ForEach-Object {
            $target | Add-Member -MemberType ScriptMethod -Name $_ -Value $Members[$_] -Force
        }
    }
}
