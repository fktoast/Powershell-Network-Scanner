# Powershell-Network-Scanner
A SQL database driven IP and port scanner written in powershell

Tested on:
Windows Server 2019
SQL 2019
Confluence 7.4.6
PocketQuery (Confluence Add-On)

SQL Server Configuration Manager > SQL Server Network Configuration > TCP/IP > IP Addresses Tab > Enable 127.0.0.1

Copy and paste the following to set up your pocketquery datasource.

URL
jdbc:sqlserver://127.0.0.1:1433;databaseName=Automation;useLOBs=false

Driver
com.microsoft.sqlserver.jdbc.SQLServerDriver
