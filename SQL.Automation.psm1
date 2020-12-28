Try
{
	$Global:SQL_Automation_Username = 'sa'
	$Global:SQL_Automation_Password = '12345678'
    $Global:SQL_Automation = "127.0.0.1"
    $Global:SQL_Automation_Tables = Invoke-Sqlcmd -ServerInstance $Global:SQL_Automation -Database Automation -Username $Global:SQL_Automation_Username -Password $Global:SQL_Automation_Password -Query "
        select t.name
        from Automation.sys.tables as T
        where t.type = 'U'
    "
}
Catch
{
    Write-Host -ForegroundColor Red $_.Exception.Message
}

Function Get-SQL.SQLString
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
            Else
            {
                Throw "$($Dataset.GetType().Name) has not been defined in Get-USPI.SQLString and thus cannot be processed"
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
    Else
    {
        #Break
    }
}

Function Remove-SQL.BlankValuesFromObject
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

Function Get-SQL.Automation.Records
{
    Param
    (
        [Parameter()][string]$Query
    )

    Write-Verbose -Message "Searching for existing record using: $Query"

    Try
    {
        $Result = [array](Invoke-Sqlcmd -ServerInstance $Global:SQL_Automation -Database Automation -Username $Global:SQL_Automation_Username -Password $Global:SQL_Automation_Password -Query $Query -ErrorAction Stop)

        Return $Result
    }
    Catch
    {
        THROW
    }
}

Function Set-SQL.Automation.Record
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
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($Global:SQL_Automation_Tables.Name)
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
                Invoke-Sqlcmd -ServerInstance $Global:SQL_Automation -Database Automation -Username $Global:SQL_Automation_Username -Password $Global:SQL_Automation_Password -ErrorAction Stop -Query "$(Get-SQL.SQLString -Dataset $Payload -SQLTable $Table -SQLStatement UPDATE) WHERE PrimaryKey='$PrimaryKey';"

                Return (Get-SQL.Automation.Records -Query "SELECT * FROM $Table WHERE PrimaryKey='$PrimaryKey';")
            }
            Catch
            {
                THROW
            }
        }
    }
}

Function New-SQL.Automation.Record
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
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($Global:SQL_Automation_Tables.Name)
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
                $Query = "$(Get-SQL.SQLString -Dataset $Payload -SQLTable $Table -SQLStatement INSERT);"
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
                    Invoke-Sqlcmd -ServerInstance $Global:SQL_Automation -Database Automation -Username $Global:SQL_Automation_Username -Password $Global:SQL_Automation_Password -ErrorAction Stop -Query $Query
                    Write-Verbose -Message "Record created successfully"
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

Function Request-SQL.Automation.Record
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
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($Global:SQL_Automation_Tables.Name)
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
                    $Payload = Remove-SQL.BlankValuesFromObject -Object $Payload
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
                        $Payload | Add-Member -MemberType NoteProperty -Name Updated -Value (Get-Date) -Force
                    }
                    ElseIf ($Payload.GetType().Name -ieq "Hashtable")
                    {
                        $Payload.Add("Updated",(GET-DATE))
                    }
                    Else
                    {
                        Throw "$($Payload.GetType().Name) has not been defined in Get-SQL.SQLString and thus cannot be processed"
                    }
                }
                ElseIf ($Payload.GetType().IsArray -eq $true)
                {
                    $Payload | Add-Member -MemberType NoteProperty -Name Updated -Value (Get-Date) -Force
                }
            }
            Catch
            {
                Write-Error -Message $_.Exception.Message
            }

            Try
            {
                $GetRecords = [array](Get-SQL.Automation.Records -Query $Query)

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
                    $SetRecord = Set-SQL.Automation.Record -Table $Table -PrimaryKey $GetRecords[0].PrimaryKey -Payload $Payload
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
                    New-SQL.Automation.Record -Table $Table -Payload $Payload

                    Return ([array](Get-SQL.Automation.Records -Query $Query))
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