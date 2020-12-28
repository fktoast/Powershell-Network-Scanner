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
        If ($Table -eq "IP_Addresses")
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
        ElseIf ($Table -eq "IP_Addresses_Stats")
        {
            If ($Payload.Used -and $Payload.Free)
            {
                $Query = "SELECT * FROM $Table WHERE CONVERT(VARCHAR(13), [Created], 127) = '$(get-date -Format yyyy-MM-ddThh)';"
                Write-Verbose -Message ($Query | Out-String)
            }
        }
        ElseIf ($Table -eq "IP_Addresses_Ports_Stats")
        {
            If ($Payload.Port -and $Payload.OpenCount)
            {
                $Query = "SELECT * FROM $Table WHERE [Port] = '$($Payload.Port)' AND CONVERT(VARCHAR(13), [Created], 127) = '$(get-date -Format yyyy-MM-ddThh)';"
                Write-Verbose -Message ($Query | Out-String)
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
