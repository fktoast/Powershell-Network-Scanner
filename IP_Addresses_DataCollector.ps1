Import-Module C:\Powershell-Network-Scanner-main\SQL.Automation.psm1
$Teams_Webhook = "https://outlook.office.com/webhook/xxxxxxxxx/IncomingWebhook/xxxxxxxxx"
$Confluence_URI = "http://192.168.1.8:8090/x/AAAAA"
$IP_Network = "192.168.7"

$IP_Subnet = $null
$IP_Subnet = @(Get-SQL.Automation.Records -Query "
SELECT
    IP_Address
FROM
    [Automation].[dbo].[IP_Addresses]
WHERE
    IP_Address LIKE '$IP_Network.%'
")

If ($IP_Subnet.Count -gt 0)
{
    For ($i=0;$i -lt $IP_Subnet.Count;$i++)
    {
        $IP_Address = $null
        $IP_Address = $IP_Subnet[$i].IP_Address
        
        If ($IP_Address)
        {
            $New_Response = New-Object PSObject -Property @{
                IP_Address = $IP_Address;
            }

            $PingResult = $null

            Try
            {
                $PingResult = ping -a -n 1 -w 2000 $IP_Address
            }
            Catch
            {
                Write-Host $_.Exception.Message
            }

            If (($PingResult | Select-String Pinging) -imatch '^Pinging (.*?) \[\d{1,3}')
            {
                $New_Response | Add-Member -MemberType NoteProperty -Name IP_Hostname -Value ($Matches[1] -split '\.')[0]

            } $Matches.Clear()

            If (($PingResult | Select-String TTL) -imatch 'TTL=(\d+)')
            {
                $New_Response | Add-Member -MemberType NoteProperty -Name IP_TTL -Value $Matches[1]
                $New_Response | Add-Member -Force -MemberType NoteProperty -Name IP_Activity_Last -Value (get-date)
            }
            Else
            {
                $New_Response | Add-Member -MemberType NoteProperty -Name IP_TTL -Value -1
            } $Matches.Clear()

            If (($PingResult | Select-String TTL) -imatch 'time.(\d+)ms')
            {
                $New_Response | Add-Member -MemberType NoteProperty -Name IP_Latency -Value $Matches[1]
            }
            Else
            {
                $New_Response | Add-Member -MemberType NoteProperty -Name IP_Latency -Value -1
            } $Matches.Clear()

            $ArpResult = $null

            Try
            {
                $ArpResult = ARP -A $IP_Address
            }
            Catch
            {
                Write-Host $_.Exception.Message
            }

            If ($ArpResult[3] -imatch '([0-9.]+)[ ]+([a-zA-Z0-9\-]+)[ ]+([a-zA-Z]+)')
            {
                $New_Response | Add-Member -MemberType NoteProperty -Name IP_Physical -Value $Matches[2]
                $New_Response | Add-Member -MemberType NoteProperty -Name IP_Type -Value $Matches[3]
            } $Matches.Clear()

            $Last_Response = $null
            $Last_Response = @(Get-SQL.Automation.Records -Query "
            SELECT
                PrimaryKey,IP_Latency,IP_Hostname,IP_Physical,IP_Type,IP_Activity_First,IP_Activity_Last
            FROM
                [Automation].[dbo].[IP_Addresses]
            WHERE
                IP_Address = '$IP_Address'
            ")

            $IP_Activity_Message = $null

            If ($New_Response.IP_Latency -and $New_Response.IP_Latency -ne -1 -and $Last_Response[0].IP_Latency -eq -1)
            {
                [array]$IP_Activity_Message += "New $($New_Response.IP_Latency)ms response from $($New_Response.IP_Physical).  Previous new event was on $(($Last_Response[0].IP_Activity_Last).GetDateTimeFormats()[93]) by $($Last_Response[0].IP_Physical)"
            }
            ElseIf ($New_Response.IP_Latency -and $New_Response.IP_Latency -eq -1 -and $Last_Response[0].IP_Latency -ne -1)
            {
                [array]$IP_Activity_Message += "Stopped responding.  Last response was $(($Last_Response[0].IP_Activity_Last).GetDateTimeFormats()[93]) by $($Last_Response[0].IP_Physical)"
            }

            If ($New_Response.IP_Latency -and [int]($New_Response.IP_Latency) -gt 500 -and [int]($Last_Response[0].IP_Latency) -le 500)
            {
                [array]$IP_Activity_Message += "High latency response of $($New_Response.IP_Latency)ms from $($New_Response.IP_Physical)."
            }

            If ($New_Response.IP_Physical -and ($Last_Response[0].IP_Physical | Measure-Object -Character).Characters -gt 0 -and $New_Response.IP_Physical -ine $Last_Response[0].IP_Physical)
            {
                [array]$IP_Activity_Message += "Physical Address changed from $($Last_Response[0].IP_Physical) >>> $($New_Response.IP_Physical)"
            }

            If ($New_Response.IP_Hostname -and $New_Response.IP_Hostname -ine $Last_Response[0].IP_Hostname)
            {
                [array]$IP_Activity_Message += "Hostname changed from $($Last_Response[0].IP_Hostname) >>> $($New_Response.IP_Hostname)"
            }

            If ($New_Response.IP_Type -and $New_Response.IP_Type -ine $Last_Response[0].IP_Type)
            {
                [array]$IP_Activity_Message += "Configuration type changed from $($Last_Response[0].IP_Type) >>> $($New_Response.IP_Type)"
            }

            If ($IP_Activity_Message.Count -gt 0)
            {
                $New_Response | Add-Member -Force -MemberType NoteProperty -Name IP_Activity_First -Value (get-date)
                $New_Response | Add-Member -Force -MemberType NoteProperty -Name IP_Activity_Message -Value ($IP_Activity_Message | Out-String)
################
$JSON = @"
{
    "@context": "https://schema.org/extensions",
    "@type": "MessageCard",
    "themeColor": "0072C6",
    "title": "$($IP_Address) $($New_Response.IP_Physical) $($New_Response.IP_Hostname)",
    "text": "$($IP_Activity_Message | Out-String)",
    "potentialAction": [
    {
        "@type": "OpenUri",
        "name": "View Dashboard",
        "targets": [
        { "os": "default", "uri": "$($Confluence_URI)" }
        ]
    }
    ]
}
"@
################
                Invoke-RestMethod -uri $Teams_Webhook -Method Post -body $JSON -ContentType 'application/json'
            }
            
            Write-Host ($New_Response | Out-String)

            Try
            {
                Set-SQL.Automation.Record -Table IP_Addresses -Payload $New_Response -PrimaryKey $Last_Response.PrimaryKey
            }
            Catch
            {
                Write-Host $_.Exception.Message
            }
        }
    }

    $Stats = $null
    $Stats = @(Get-SQL.Automation.Records -Query "
    SELECT
	    COUNT(CASE 
			    WHEN IP_Latency > -1 THEN 'Used'
		    END) AS Used
	    ,COUNT(CASE 
			    WHEN IP_Latency = -1 THEN 'Free'
		    END) AS Free
      FROM
        [Automation].[dbo].[IP_Addresses]
      WHERE
        IP_Address LIKE '$IP_Network.%'
    ")

    If ($Stats.count -eq 1)
    {
        Request-SQL.Automation.Record -Table IP_Addresses_Stats -Payload @{
            Used = $Stats[0].Used;
            Free = $Stats[0].Free;
        }
    }
}

