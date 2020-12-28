Import-Module C:\Automation\SQL.Automation.psm1


[array]$Records = Get-SQL.Automation.Records -Query "
    SELECT PrimaryKey, IP_Address, IP_Latency
    FROM Automation.dbo.IP_Addresses
    WHERE IP_Latency <> -1
"

$ListofPorts = "22,80,443" -split ','

If ($Records)
{
    $Report = @()

    For ($i=0;$i -lt $Records.Count;$i++)
    {
        Write-Host $i -NoNewline
        Write-Host " $($Records[$i].IP_Address)" -NoNewline

        For ($j=0;$j -lt $ListofPorts.Count;$j++)
        {
            Write-Host " $($ListofPorts[$j])" -NoNewline

            $ProcessObj = $null
            $ProcessObj = New-Object PSObject -Property @{
                IP_Address = $Records[$i].IP_Address;
                Port = $ListofPorts[$j];
                IP_Address_PrimaryKey = $Records[$i].PrimaryKey;
                Status = "Unknown";
            }

            $NetSockets = $null
            $NetSockets = New-Object Net.Sockets.TcpClient

            Try
            {
                $NetSockets.Connect("$($Records[$i].IP_Address)",$ListofPorts[$j]) | Out-Null
            }
            Catch
            {
                $ProcessObj.Status = "Closed"
                Write-Host $_.Exception.Message
            }

            If ($NetSockets.Connected -eq $true)
            {
                $ProcessObj.Status = "Open"
                Write-Host "*" -NoNewline
            }
            ElseIf ($NetSockets.Connected -eq $false)
            {
                $ProcessObj.Status = "Closed"
            }

            $Report += $ProcessObj
            Write-Host -Message $ProcessObj | Out-String
            $SQLRecord = Request-SQL.Automation.Record -Table IP_Addresses_Ports -Payload $ProcessObj
        }

        Write-Host ""
    }

    $Stats = $null
    $Stats = @(Get-SQL.Automation.Records -Query "
    SELECT 
	    iap.port as [Port],
	    Count(iap.Port) as Total
	    FROM
		    Automation.dbo.IP_Addresses_Ports iap
	    WHERE
		    iap.[Status] = 'Open'
    Group By iap.port
    Order By Total DESC
    ")

    If ($Stats.Count -gt 0)
    {
        $Stats | % {
            Request-SQL.Automation.Record -Table IP_Addresses_Ports_Stats -Payload @{
                Port = $_.Port
                OpenCount = $_.Total
            }
        }
    }
}

