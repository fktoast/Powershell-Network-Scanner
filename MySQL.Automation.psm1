[void][system.reflection.Assembly]::LoadWithPartialName("MySql.Data")
$Global:MySQL_Automation_Server = "1234.mysqlhosting.fake"
$Global:MySQL_Automation_Database = "Automation"
$Global:MySQL_Automation_Username = 'root'
$Global:MySQL_Automation_Password = '12345678'
$Connection_String = "server=$MySQL_Automation_Server;database=$MySQL_Automation_Database;Persist Security Info=false;user id=$MySQL_Automation_Username;pwd=$MySQL_Automation_Password;"

Try
{
    $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection($Connection_String)
    $Connection.Open()
}
Catch
{
    Write-Host -ForegroundColor Red $_.Exception.Message
}

Try
{   
    $Global:MySQL_Automation_Tables_Query = "
        SELECT TABLE_NAME, TABLE_SCHEMA FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
    "
    $Global:MySQL_Automation_Command = New-Object MySql.Data.MySqlClient.MySqlCommand($MySQL_Automation_Tables_Query, $Connection)
    $Global:MySQL_Automation_DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($MySQL_Automation_Command)

    $Global:MySQL_Automation_DataSet = New-Object System.Data.DataSet
    $Global:MySQL_Automation_RecordCount = $Global:MySQL_Automation_DataAdapter.Fill($Global:MySQL_Automation_DataSet, "data")
    $Global:MySQL_Automation_Tables = @($Global:MySQL_Automation_DataSet.Tables[0] | Where-Object {$_.TABLE_SCHEMA -eq "Automation"}).TABLE_NAME

}
Catch
{
    Write-Host -ForegroundColor Red $_.Exception.Message
}

Try
{

}
Catch
{
    Write-Host -ForegroundColor Red $_.Exception.Message
}

Function ConvertTo-MySQL.Automation.DATETIME {
    Param
    (
        [Parameter(Mandatory=$true)]$DateTime
    )

    Return (Get-Date -Date $DateTime -Format 'yyyy-MM-dd hh:mm:ss')
}

Function ConvertTo-MySQL.Automation.Statement
{
    Param
    (
        [Parameter(Mandatory=$true)]$Dataset,
        [Parameter(Mandatory=$true)]$SQLTable,
        [Parameter()][ValidateSet("INSERT", "UPDATE")][string]$SQLStatement
    )

    If ($SQLTable)
    {
        If ($Dataset.GetType().IsArray -eq $false)
        {
            If ($Dataset.GetType().Name -ieq "PSCustomObject")
            {
                [array]$Columns = ($Dataset | Get-Member -MemberType NoteProperty).Name
                [array]$Values = $Columns |% {$Dataset.$_}
            }
            ElseIf ($Dataset.GetType().Name -ieq "Hashtable")
            {
                [array]$Columns = $Dataset.Keys
                [array]$Values = $Dataset.Values
            }
            ElseIf ($Dataset.GetType().Name -ieq "Process")
            {
                $Dataset = @($Dataset)
                [array]$Columns = ($Dataset | Get-Member -MemberType Property).Name
                [array]$Values = $Columns |% {$Dataset.$_}
            }
            Else
            {
                Throw "$($Dataset.GetType().Name) has not been defined in ConvertTo-MySQL.Automation.Statement and thus cannot be processed"
            }
        }
        ElseIf ($Dataset.GetType().IsArray -eq $true)
        {
            [array]$Columns = ($Dataset | Get-Member -MemberType NoteProperty).Name
            [array]$Values = $Columns |% {$Dataset.$_}
        }

        If ($Columns.Count -eq $Values.Count)
        {
            $ColumnCount = $Columns.Count
        }
        Else
        {
            TRAP {"Keys and Values dont match"}
        }
        
        If ($ColumnCount)
        {
            If ($SQLStatement -ieq "UPDATE")
            {
                $SQLQueryString = "UPDATE $SQLTable SET "

                For ($i=0;$i -lt $ColumnCount;$i++)
                {
                    If ($i -lt ($ColumnCount -1))
                    {
                        $SQLQueryString = $SQLQueryString + "$($Columns[$i])='$($Values[$i])',"
                    }
                    ElseIf ($i -eq ($ColumnCount -1))
                    {
                        $SQLQueryString = $SQLQueryString + "$($Columns[$i])='$($Values[$i])'"
                    }
                }
            }
            ElseIf ($SQLStatement -ieq "INSERT")
            {
                $SQLQueryString = "INSERT INTO $SQLTable ("

                For ($i=0; $i -lt $ColumnCount; $i++)
                {
                    If ($i -lt ($ColumnCount -1))
                    {
                        $SQLQueryString = $SQLQueryString + "$($Columns[$i]),"
                    }
                    ElseIf ($i -eq ($ColumnCount -1))
                    {
                        $SQLQueryString = $SQLQueryString + "$($Columns[$i])) "
                    }
                }

                $SQLQueryString = $SQLQueryString + "VALUES ("

                For ($i=0; $i -lt $ColumnCount; $i++)
                {
                    If ($i -lt ($ColumnCount -1))
                    {
                        $SQLQueryString = $SQLQueryString + "'$($values[$i])',"
                    }
                    ElseIf ($i -eq ($ColumnCount -1))
                    {
                        $SQLQueryString = $SQLQueryString + "'$($values[$i])')"
                    }
                }
            }

            Write-Verbose -Message $SQLQueryString

            Return $SQLQueryString
        }
        Else
        {
            TRAP {"Error"}
        }
    }
}

Function Remove-BlankValuesFromObject
{
    Param($Object)

    If ($Object)
    {
        $Dataset = @{}

        If ($Object.GetType().IsArray -eq $false)
        {
            If ($Object.GetType().Name -ieq "PSCustomObject")
            {
                Try
                {
                    $Object | Get-Member -MemberType NoteProperty |% {If (($Object.($_.Name) | Measure-Object -Character).Characters -gt 0){$Dataset.($_.Name) = $Object.($_.Name)}}
                }
                Catch
                {
                    Throw $_.Exception.Message
                }
            }
            ElseIf ($Object.GetType().Name -ieq "Hashtable")
            {
                Try
                {
                    $Object.Keys | Where {($Object.$_ | Measure-Object -Character).Characters -gt 0} |% {
                        $Dataset.Add($_,$Object.$_)
                    }
                }
                Catch
                {
                    Throw $_.Exception.Message
                }
            }
            Else
            {
                Throw "$($Dataset.GetType().Name) has not been defined and thus cannot be processed"
            }
        }
        ElseIf ($Dataset.GetType().IsArray -eq $true)
        {
            Try
            {
                $Object | Get-Member -MemberType NoteProperty |% {
                    If (($Object.($_.Name) | Measure-Object -Character).Characters -gt 0)
                    {
                        $Dataset.($_.Name) = $Object.($_.Name)
                    }
                }
            }
            Catch
            {
                Throw $_.Exception.Message
            }
        }

        Return $Dataset
    }
    Else
    {
        Throw "Payload was empty"
    }
}

Function Get-MySQL.Automation.Records
{
    Param
    (
        [Parameter()][string]$Query
    )

    Write-Verbose -Message "Searching for existing record using: $Query"

    Try
    {
        $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
        $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
    
        $DataSet = New-Object System.Data.DataSet
        $RecordCount = $DataAdapter.Fill($DataSet, "data")
        $Result = @($DataSet.Tables[0])
        Return $Result
    }
    Catch
    {
        THROW
    }
}

Function Set-MySQL.Automation.Record
{
    Param
    (
        [Parameter()][int]$PrimaryKey,
        [Parameter()]$Payload
    )

    DynamicParam
    {
        $ParameterName = "Table"
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 0
        $AttributeCollection.Add($ParameterAttribute)
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($Global:MySQL_Automation_Tables)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    Begin
    {
        $Table = $PsBoundParameters["Table"]
        Write-Verbose -Message "Using $Table"
    }

    Process
    {
        If ($Payload)
        {
            Try
            {
                $cmd = New-Object MySql.Data.MySqlClient.MySqlCommand
                $cmd.Connection = $Connection
                $cmd.CommandText = "$(ConvertTo-MySQL.Automation.Statement -Dataset $Payload -SQLTable $Table -SQLStatement UPDATE) WHERE PrimaryKey='$PrimaryKey';"
                $cmd.ExecuteNonQuery() 
                $Result = Get-MySQL.Automation.Records -Query "SELECT * FROM $Table WHERE PrimaryKey='$PrimaryKey';"
                Return ($Result)
            }
            Catch
            {
                THROW
            }
        }
    }
}

Function Remove-MySQL.Automation.Records
{
    Param ($PrimaryKey,$Table)
    <#
    DynamicParam
    {
        $ParameterName = "Table"
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 0
        $AttributeCollection.Add($ParameterAttribute)
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($Global:MySQL_Automation_Tables)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    Begin
    {
        $Table = $PsBoundParameters["Table"]
        Write-Verbose -Message "Using $Table"        
    }#>

    Process
    {
        $cmd = New-Object MySql.Data.MySqlClient.MySqlCommand
        $cmd.Connection = $Connection
        $cmd.CommandText = "DELETE FROM $Table WHERE PrimaryKey='$PrimaryKey'"
        $cmd.ExecuteNonQuery() 
    }
}

Function New-MySQL.Automation.Record
{
    Param
    (
        [Parameter()]$Payload
    )

    DynamicParam
    {
        $ParameterName = "Table"
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 0
        $AttributeCollection.Add($ParameterAttribute)
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($Global:MySQL_Automation_Tables)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    Begin
    {
        $Table = $PsBoundParameters["Table"]
        Write-Verbose -Message "Using $Table"        
    }

    Process
    {
        If ($Payload)
        {
            Try
            {
                $Query = "$(ConvertTo-MySQL.Automation.Statement -Dataset $Payload -SQLTable $Table -SQLStatement INSERT);"
            }
            Catch
            {
                THROW
            }

            If ($Query)
            {
                Write-Verbose -Message "Creating a new record"

                Try
                {
                    $cmd = New-Object MySql.Data.MySqlClient.MySqlCommand
                    $cmd.Connection = $Connection
                    $cmd.CommandText = $Query
                    $cmd.ExecuteNonQuery()
                }
                Catch
                {
                    Throw
                }
            }
            Else
            {
                Write-Error -Message "Query must contain a value"
            }
        }
    }
}

Function Request-MySQL.Automation.Record
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Position = 1,Mandatory=$true)]$Payload,
        [Parameter()][switch]$KeepBlankValues
    )

    DynamicParam
    {
        $ParameterName = "Table"
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 0
        $AttributeCollection.Add($ParameterAttribute)
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($Global:MySQL_Automation_Tables)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    Begin
    {
        $Table = $PsBoundParameters["Table"]
        Write-Verbose -Message "Using $Table"
    }

    Process
    {
        If ($Table -eq "Accounts")
        {
            If ($Payload.Employee_ID -and $Payload.SiteCode)
            {
                $Query = "SELECT * FROM $Table WHERE Employee_ID = '$($Payload.Employee_ID)' AND SiteCode ='$($Payload.SiteCode)';"
            }
            Else
            {
                If (!$Employee_ID -or !$SiteCode)
                {
                    THROW {"Missing requirements."}
                }
            }
        }
        ElseIf ($Table -eq "Tasks")
        {
            If ($Payload.Number -and $Payload.FormData)
            {
                $Query = "SELECT * FROM $Table WHERE Number = '$($Payload.Number)' AND FormData = '$($Payload.FormData)';"
                Write-Verbose -Message ($Query | Out-String)
            }
        }
        ElseIf ($Table -eq "Applications_Folders")
        {
            If ($Payload.Folder -and $Payload.Parent_ID)
            {
                $Query = "SELECT * FROM $Table WHERE Folder = '$($Payload.Folder)' AND Parent_ID ='$($Payload.Parent_ID)';"
            }
            Else
            {
                If (!$Payload.Folder)
                {
                    THROW {"Missing folder name."}
                }
            
                If (!$Payload.Parent_ID)
                {
                    THROW {"Missing Parent_ID."}
                }
            }
        }
        ElseIf ($Table -eq "Servers")
        {
            If ($Payload.Hostname)
            {
                $Query = "SELECT * FROM $Table WHERE Hostname = '$(($Payload.Hostname).ToUpper())';"
            }
        }
        ElseIf ($Table -eq "Servers_Services")
        {
            If ($Payload.Name -and $Payload.Path -and $Payload.HostName)
            {
                $Query = "SELECT * FROM $Table WHERE Name = '$($Payload.Name)' AND Path = '$($Payload.Path)' AND Hostname = '$($Payload.HostName)';"
            }
        }
        ElseIf ($Table -eq "ActiveDirectory_SPNs")
        {
            If ($Payload.Name)
            {
                $Query = "SELECT * FROM $Table WHERE Name = '$($Payload.Name)';"
            }
        }
        ElseIf ($Table -eq "DHCP_Scopes")
        {
            If ($Payload.NetworkID -and $Payload.Subnet_Mask)
            {
                $Query = "SELECT * FROM $Table WHERE NetworkID = '$($Payload.NetworkID)' AND Subnet_Mask = '$($Payload.Subnet_Mask)';"
            }
        }
        ElseIf ($Table -eq "DHCP_Scopes_Reservations")
        {
            If ($Payload.IP_Address)
            {
                $Query = "SELECT * FROM $Table WHERE IP_Address = '$($Payload.IP_Address)';"
            }
        }
        ElseIf ($Table -eq "DHCP_Scopes_Exclusions")
        {
            If ($Payload.Scope_ID -and $Payload.Start_Range -and $Payload.End_Range)
            {
                $Query = "SELECT * FROM $Table WHERE Scope_ID = '$($Payload.Scope_ID)' AND Start_Range = '$($Payload.Start_Range)' And End_Range = '$($Payload.End_Range)';"
            }
        }
        ElseIf ($Table -eq "MappedDrives")
        {
            If ($Payload.Drive_Path -and $Payload.Drive_Type -and $Payload.Object_Source_Type -and $Payload.SiteCode)
            {
                $Query = "SELECT * FROM $Table WHERE Drive_Path = '$($Payload.Drive_Path)' AND Drive_Type = '$($Payload.Drive_Type)' AND Object_Source_Type = '$($Payload.Object_Source_Type)' AND SiteCode = '$($Payload.SiteCode)';"
            }
            Else
            {
                If (!$Drive_Path)
                {
                    Write-Error -Message "Drive_Path is empty`r`n$($Payload | Out-String)"
                }

                If (!$Drive_Type)
                {
                    Write-Error -Message "Drive_Type is empty`r`n$($Payload | Out-String)"
                }

                If (!$SiteCode)
                {
                    Write-Error -Message "SiteCode is empty`r`n$($Payload | Out-String)"
                }
            }
        }
        ElseIf ($Table -eq "DHCP_Servers")
        {
            If ($Payload.HostName -and $Payload.IP_Address)
            {
                $Query = "SELECT * FROM $Table WHERE Hostname = '$(($Payload.HostName).ToUpper())' AND IP_Address = '$($Payload.IP_Address)';"
            }
        }
        ElseIf ($Table -eq "SQL_Instances")
        {
            If ($Payload.Instance_Name -and $Payload.HostName)
            {
                $Query = "SELECT * FROM $Table WHERE Instance_Name = '$($Payload.Instance_Name)' AND Hostname = '$(($Payload.HostName).ToUpper())';"
            }
        }
        ElseIf ($Table -eq "Applications")
        {
            If ($Payload.Name -and $Payload.Label)
            {
                $Query = "SELECT * FROM $Table WHERE Name = '$($Payload.Name)' AND Label = '$($Payload.Label)';"
            }
        }
        ElseIf ($Table -eq "Applications_Services")
        {
            If ($Payload.Name)
            {
                $Query = "SELECT * FROM $Table WHERE Name = '$($Payload.Name)';"
            }
        }
        ElseIf ($Table -eq "ActiveDirectory_DomainControllers")
        {
            If ($Payload.Hostname)
            {
                $Query = "SELECT * FROM $Table WHERE Hostname = '$($Payload.Hostname)';"
            }
        }
        ElseIf ($Table -eq "Evault_JobSources")
        {
            If ($Payload.startLocation)
            {
                $Query = "SELECT * FROM $Table WHERE startLocation = '$($Payload.startLocation)';"
            }
        }
        ElseIf ($Table -eq "Exchange_Servers")
        {
            If ($Payload.Hostname)
            {
                $Query = "SELECT * FROM $Table WHERE Hostname = '$($Payload.Hostname)';"
            }
        }
        ElseIf ($Table -eq "Exchange_Databases")
        {
            If ($Payload.Name)
            {
                $Query = "SELECT * FROM $Table WHERE Name = '$($Payload.Name)';"
            }
        }
        ElseIf ($Table -eq "Sites")
        {
            If ($Payload.SiteCode)
            {
                $Query = "SELECT * FROM $Table WHERE SiteCode = '$($Payload.SiteCode)';"
            }
        }
        ElseIf ($Table -eq "Workstations")
        {
            If ($Payload.Hostname)
            {
                $Query = "SELECT * FROM $Table WHERE Hostname = '$($Payload.Hostname)';"
            }
        }
        ElseIf ($Table -eq "ServiceNow_SysAdmin_TicketCounts")
        {
            If ($Payload.UserName -and $Payload.Week)
            {
                $Query = "SELECT * FROM $Table WHERE UserName = '$($Payload.UserName)' AND Week = '$($Payload.Week)';"
            }
            Else
            {
                Write-Error "Missing UserName or Week or both"
            }
        }
        ElseIf ($Table -eq "ServiceNow_SysAdmin_Tasks")
        {
            If ($Payload.Number)
            {
                $Query = "SELECT * FROM $Table WHERE Number = '$($Payload.Number)';"
            }
        }
        ElseIf ($Table -eq "ServiceNow_Tasks")
        {
            If ($Payload.sys_id)
            {
                $Query = "SELECT * FROM $Table WHERE sys_id = '$($Payload.sys_id)';"
            }
        }
        ElseIf ($Table -eq "ServiceNow_SysAdmin_Rotation")
        {
            If ($Payload.sys_id)
            {
                $Query = "SELECT * FROM $Table WHERE sys_id = '$($Payload.sys_id)';"
            }
        }
        ElseIf ($Table -eq "Altiris_PackageServers")
        {
            If ($Payload.Hostname)
            {
                $Query = "SELECT * FROM $Table WHERE Hostname = '$($Payload.Hostname)';"
            }
        }
        ElseIf ($Table -eq "Solarwinds_GroupNodes")
        {
            If ($Payload.GroupID)
            {
                $Query = "SELECT * FROM $Table WHERE GroupID = '$($Payload.GroupID)';"
            }
        }
        ElseIf ($Table -eq "Solarwinds_Exchange_Top5MailboxesPerDB")
        {
            If ($Payload.MailboxID)
            {
                $Query = "SELECT * FROM $Table WHERE MailboxID = '$($Payload.MailboxID)';"
            }
        }
        ElseIf ($Table -eq "Exchange_ActiveSync_Devices")
        {
            If ($Payload.DeviceID)
            {
                $Query = "SELECT * FROM $Table WHERE DeviceID = '$($Payload.DeviceID)';"
            }
        }
        ElseIf ($Table -eq "VMWare_Guests")
        {
            If ($Payload.InstanceUuid)
            {
                $Query = "SELECT * FROM $Table WHERE InstanceUuid = '$($Payload.InstanceUuid)';"
            }
        }
        ElseIf ($Table -eq "VMWare_Guests_HardDisks")
        {
            If ($Payload.Filename)
            {
                $Query = "SELECT * FROM $Table WHERE Filename = '$($Payload.Filename)';"
            }
        }
        ElseIf ($Table -eq "VMWare_Hosts")
        {
            If ($Payload.ID)
            {
                $Query = "SELECT * FROM $Table WHERE ID = '$($Payload.ID)';"
            }
        }
        ElseIf ($Table -eq "VMWare_VirtualPortGroups")
        {
            If ($Payload.ID)
            {
                $Query = "SELECT * FROM $Table WHERE ID = '$($Payload.ID)';"
            }
        }
        ElseIf ($Table -eq "VMWare_Guests_HardDisks_StorageFormat")
        {
            If ($Payload.StorageFormat)
            {
                $Query = "SELECT * FROM $Table WHERE StorageFormat = '$($Payload.StorageFormat)';"
            }
        }
        ElseIf ($Table -eq "VMWare_Guests_NetworkAdapters")
        {
            If ($Payload.ID)
            {
                $Query = "SELECT * FROM $Table WHERE ID = '$($Payload.ID)';"
            }
        }
        ElseIf ($Table -eq "Solarwinds_Nodes")
        {
            If ($Payload.NodeID)
            {
                $Query = "SELECT * FROM $Table WHERE NodeID = '$($Payload.NodeID)';"
            }
        }
        ElseIf ($Table -eq "Evault_TaskPools")
        {
            If ($Payload.PoolGUID)
            {
                $Query = "SELECT * FROM $Table WHERE PoolGUID = '$($Payload.PoolGUID)';"
            }
        }
        ElseIf ($Table -eq "ActiveDirectory_Users")
        {
            If ($Payload.samAccountName)
            {
                $Query = "SELECT * FROM $Table WHERE samAccountName = '$($Payload.samAccountName)';"
            }
        }
        ElseIf ($Table -eq "Servers_Services_BlackList")
        {
            If ($Payload.Process)
            {
                $Query = "SELECT * FROM $Table WHERE Process = '$($Payload.Process)';"
            }
        }
        ElseIf ($Table -eq "ServiceNow_SI_Tasks")
        {
            If ($Payload.Number)
            {
                $Query = "SELECT * FROM $Table WHERE Number = '$($Payload.Number)';"
            }
        }
        ElseIf ($Table -eq "Storage_Report")
        {
            If ($Payload.Name -and $Payload.Collected)
            {
                $Query = "SELECT * FROM $Table WHERE Name = '$($Payload.Name)' AND CONVERT(VARCHAR(10), Collected, 127) = '$($Payload.Collected | Get-date -Format yyyy-MM-dd)';"
            }
        }
        ElseIf ($Table -eq "LiveVault_DailyStatus")
        {
            If ($Payload.BackupPolicyId -and $Payload.Collected)
            {
                $Query = "SELECT * FROM $Table WHERE BackupPolicyId = '$($Payload.BackupPolicyId)';"
            }
        }
        ElseIf ($Table -eq "ActiveDirectory_Subnets")
        {
            If ($Payload.ObjectGUID)
            {
                $Query = "SELECT * FROM $Table WHERE ObjectGUID = '$($Payload.ObjectGUID)';"
            }
        }
        ElseIf ($Table -eq "Azure_Users")
        {
            If ($Payload.ObjectID)
            {
                $Query = "SELECT * FROM $Table WHERE ObjectID = '$($Payload.ObjectID)';"
            }
        }
        ElseIf ($Table -eq "WSUS")
        {
            If ($Payload.HostName)
            {
                $Query = "SELECT * FROM $Table WHERE HostName = '$($Payload.HostName)';"
            }
        }
        ElseIf ($Table -eq "LiveVault_Billing")
        {
            If ($Payload.BackupPolicyID)
            {
                $Query = "SELECT * FROM $Table WHERE BackupPolicyID = '$($Payload.BackupPolicyID)';"
            }
        }
        ElseIf ($Table -eq "Servers_ScheduledTasks")
        {
            If ($Payload.Hostname -and $Payload.Name -and $Payload.Path)
            {
                $Query = "SELECT * FROM $Table WHERE Hostname = '$($Payload.Hostname)' AND Name = '$($Payload.Name)' AND Path = '$($Payload.Path)';"
            }
        }
        ElseIf ($Table -eq "Azure_Licenses")
        {
            If ($Payload.AccountSkuId)
            {
                $Query = "SELECT * FROM $Table WHERE AccountSkuId = '$($Payload.AccountSkuId)';"
            }
        }
        ElseIf ($Table -eq "UNC_Folders")
        {
            If ($Payload.Drive_Path)
            {
                $Query = "SELECT * FROM $Table WHERE Drive_Path = '$($Payload.Drive_Path)';"
            }
        }
        ElseIf ($Table -eq "Geographic_States")
        {
            If ($Payload.Name)
            {
                $Query = "SELECT * FROM $Table WHERE Name = '$($Payload.Name)';"
            }
        }
        ElseIf ($Table -eq "SystemsHealth")
        {
            If ($Payload.Name)
            {
                $Query = "SELECT * FROM $Table WHERE Name = '$($Payload.Name)';"
            }
        }
        ElseIf ($Table -eq "ActiveDirectory_Health")
        {
            If ($Payload.FQDN)
            {
                $Query = "SELECT * FROM $Table WHERE FQDN = '$($Payload.FQDN)';"
            }
        }
        ElseIf ($Table -eq "ActiveDirectory_Users_Events")
        {
            If ($Payload.UserName -and $Payload.TimeCreated -and $Payload.ID)
            {
                $Query = "SELECT * FROM $Table WHERE UserName = '$($Payload.Hostname)' AND TimeCreated = '$($Payload.TimeCreated)' AND ID = '$($Payload.ID)';"
            }
        }
        ElseIf ($Table -eq "NPS_accounting")
        {
            If ($Payload.Timestamp -and $Payload.Client_Friendly_Name)
            {
                $Query = "SELECT * FROM $Table WHERE Timestamp = '$($Payload.Timestamp)' AND Client_Friendly_Name = '$($Payload.Client_Friendly_Name)';"
            }
        }
        ElseIf ($Table -eq "MAC_Vendors")
        {
            If ($Payload.Vendor -and $Payload.Address )
            {
                $Query = "SELECT * FROM $Table WHERE Vendor = '$($Payload.Vendor)' AND Address = '$($Payload.Address)';"
            }
        }
        ElseIf ($Table -eq "ActiveDirectory_Users_PasswordPolicyStats")
        {
            If ($Payload.Category)
            {
                $Query = "SELECT * FROM $Table WHERE Category = '$($Payload.Category)' AND CONVERT(VARCHAR(10), [Created], 127) = '$(get-date -Format yyyy-MM-dd)';"
            }
        }
        ElseIf ($Table -eq "ActiveDirectory_GPOs")
        {
            If ($Payload.ID)
            {
                $Query = "SELECT * FROM $Table WHERE ID = '$($Payload.ID)';"
            }
        }
        ElseIf ($Table -eq "ActiveDirectory_GPOs_Backups")
        {
            If ($Payload.ID)
            {
                $Query = "SELECT * FROM $Table WHERE ID = '$($Payload.ID)';"
            }
        }
        ElseIf ($Table -eq "Cybereason_Machines")
        {
            If ($Payload.pylumId)
            {
                $Query = "SELECT * FROM $Table WHERE pylumId = '$($Payload.pylumId)';"
            }
        }
        ElseIf ($Table -eq "Altiris_Computers")
        {
            If ($Payload.Guid)
            {
                $Query = "SELECT * FROM $Table WHERE Guid = '$($Payload.Guid)';"
            }
        }
        ElseIf ($Table -eq "Servers_NetAdapters")
        {
            If ($Payload.Hostname -and $Payload.Name -and $Payload.MacAddress)
            {
                $Query = "
                    SELECT
                        *
                    FROM
                        $Table
                    WHERE
                        Hostname = '$($Payload.Hostname)'
                        AND Name = '$($Payload.Name)'
                        AND MacAddress = '$($Payload.MacAddress)'
                "
            }
        }
        ElseIf ($Table -eq "IP_Addresses")
        {
            If ($Payload.IP_Address)
            {
                $Query = "
                    SELECT
                        *
                    FROM
                        $Table
                    WHERE
                        IP_Address = '$($Payload.IP_Address)'
                "
            }
        }
        ElseIf ($Table -eq "IP_Addresses_Ports")
        {
            If ($Payload.IP_Address -and $Payload.Port)
            {
                $Query = "
                    SELECT
                        *
                    FROM
                        $Table
                    WHERE
                        IP_Address = '$($Payload.IP_Address)'
                        AND Port = '$($Payload.Port)'
                "
            }
        }
        Else
        {
            Write-Error -Message "Unknown table selected"
        }

        Write-Verbose -Message "Query = $($Query | Out-String)"
        Write-Verbose -Message ($Payload | Out-String)

        If ($Query)
        {
            Try
            {
                If (!$KeepBlankValues)
                {
                    Write-Verbose -Message "Removing Blank Values"
                    $Payload = Remove-BlankValuesFromObject -Object $Payload
                    Write-Verbose -Message ($Payload | Out-String)
                }
                Else
                {
                    Write-Verbose -Message ($Payload | Out-String)
                }
            }
            Catch
            {
                THROW
            }

            Try
            {
                If ($Payload.GetType().IsArray -eq $false)
                {
                    If ($Payload.GetType().Name -ieq "PSCustomObject")
                    {
                        $Payload | Add-Member -MemberType NoteProperty -Name Updated -Value (ConvertTo-MySQL.Automation.DATETIME -DateTime (Get-Date)) -Force
                    }
                    ElseIf ($Payload.GetType().Name -ieq "Hashtable")
                    {
                        $Payload.Add("Updated",(ConvertTo-MySQL.Automation.DATETIME -DateTime (Get-Date)))
                    }
                    Else
                    {
                        Throw "$($Payload.GetType().Name) has not been defined in ConvertTo-MySQL.Automation.Statement and thus cannot be processed"
                    }
                }
                ElseIf ($Payload.GetType().IsArray -eq $true)
                {
                    $Payload | Add-Member -MemberType NoteProperty -Name Updated -Value (ConvertTo-MySQL.Automation.DATETIME -DateTime (Get-Date)) -Force
                }
            }
            Catch
            {
                Write-Error -Message $_.Exception.Message
            }

            Try
            {
                $GetRecords = [array](Get-MySQL.Automation.Records -Query $Query)

                Write-Verbose -Message "Found $($GetRecords.Count) record(s)"
            }
            Catch
            {
                THROW
            }

            If ($GetRecords.Count -eq 1)
            {
                Write-Verbose -Message "Updating record with Payload"

                Try
                {
                    $SetRecord = Set-MySQL.Automation.Record -Table $Table -PrimaryKey $GetRecords[0].PrimaryKey -Payload $Payload
                    Return $SetRecord
                }
                Catch
                {
                    Throw
                }
            }
            ElseIf ($GetRecords.Count -gt 1)
            {
                Write-Error -Message "Duplicate records found.  This should not happen and is very very bad."
            }
            Else
            {
                Write-Verbose -Message "Creating a new record using Payload"
                    
                Try
                {
                    $NewRecord = New-MySQL.Automation.Record -Table $Table -Payload $Payload

                    Return ([array](Get-MySQL.Automation.Records -Query $Query))
                }
                Catch
                {
                    Throw
                }
            }
        }
        Else
        {
            Write-Error -Message "Unable to establish query for $($Table)`r`n$($Payload | Out-String)"
        }
    }
}