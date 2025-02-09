function global:Add-ScriptProperties {
    param(
        [psobject] $Target,
        [System.Collections.IDictionary] $GetterSetters
    )

    $keys = $GetterSetters.Keys | ForEach-Object { $_ }

    If( $keys.Count ){
        $keys | ForEach-Object {
            $target | Add-Member -MemberType ScriptProperty -Name $_ -Value $GetterSetters[$_].Getter -SecondValue $GetterSetters[$_].Setter -Force
        }
    }
}
