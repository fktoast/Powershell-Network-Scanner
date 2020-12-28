Import-Module C:\Powershell-Network-Scanner-main\SQL.Automation.psm1

$Network = "192.168.7"

1..254 | % {
    Request-SQL.Automation.Record -Table IP_Addresses -Payload @{
        IP_Address = "$Network.$_";
        IP_Type="";
    }
}
