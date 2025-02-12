core.register_action("modsec_check", { "http-req" }, function(txn)
    core.Info("ModSecurity WAF check triggered")
    -- Tutaj można dokonać wywołania odpowiednich funkcji z biblioteki ModSecurity,
    -- sprawdzić reguły lub modyfikować request.
    -- W tym przykładzie jedynie logujemy wywołanie akcji.
end)
