1..254 | % {
    Request-SQL.Automation.Record -Table IP_Addresses -Payload @{
        IP_Address = "192.168.7.$_";
        IP_Type="";
    }
}