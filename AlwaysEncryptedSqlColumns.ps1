Param
(
    [Parameter(ParameterSetName='Customize')]	
	[String]
	$SubscriptionId = "",

    [Parameter(ParameterSetName='Customize')]
	[String]
    $akvName = "",

    [Parameter(ParameterSetName='Customize')]
	[String]
    $TenantId = "",
    
    [Parameter(ParameterSetName='Customize')]
	[String]
    $akvKeyName = "",

    [Parameter(ParameterSetName='Customize')]
	[String]
    $clientId = "",

    [Parameter(ParameterSetName='Customize')]
	[String]
    $clientSecret = ""
)

Function SetUpKeyVaulAndDBtEncryptionKeys($databaseName, $cekName, $cmkName, $clientId, $clientSecret)
{

Import-Module Azure -ErrorAction SilentlyContinue

Set-StrictMode -Version 3

$secpasswd = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($clientId, $secpasswd)
Login-AzureRmAccount -TenantId $TenantId -Credential $mycreds -SubscriptionId $SubscriptionId -ServicePrincipal 

$azureCtx = Set-AzureRMConteXt -SubscriptionId $SubscriptionId -TenantId $TenantId 

# Create a column master key in Azure Key Vault.
$akvKey = Add-AzureKeyVaultKey -VaultName $akvName -Name $akvKeyName -Destination "Software"

# Import the SqlServer module.
Import-Module "SqlServer" -ErrorAction SilentlyContinue

$currentDb = "{db name to connect to}"
# Connect to your database (Azure SQL database).
$serverName = "{azure sql server name}.database.windows.net,1433"
$connStr = "Server = tcp:" + $serverName + "; Initial Catalog = " + $currentDb + "; Persist Security Info=False;User ID={user Id};Password={user password};Pooling=False; MultipleActiveResultSets=False;Connection Timeout=60;Encrypt=False;TrustServerCertificate=True"
$connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
$connection.ConnectionString = $connStr
$connection.Connect()
$server = New-Object Microsoft.SqlServer.Management.Smo.Server($connection)
$database = $server.Databases[$databaseName] 


# Create a SqlColumnMasterKeySettings object for your column master key. #>
$cmkSettings = New-SqlAzureKeyVaultColumnMasterKeySettings -KeyURL $akvKey.ID

# Create column master key metadata in the database.
New-SqlColumnMasterKey -Name $cmkName -InputObject $database -ColumnMasterKeySettings $cmkSettings

# Authenticate to Azure
Add-SqlAzureAuthenticationContext -ClientID $clientId -Secret $clientSecret -Tenant $TenantId

# Generate a column encryption key, encrypt it with the column master key and create column encryption key metadata in the database. 
New-SqlColumnEncryptionKey -Name $cekName -InputObject $database -ColumnMasterKey $cmkName

$ScriptPath = $MyInvocation.MyCommand.Path

$ScriptDir  = Split-Path -Parent $ScriptPath

$json = Get-Content $ScriptDir\databaseWithTableNames.json | Out-String | ConvertFrom-Json

$json.SqlDbs | ForEach {

echo "database $($_.name) "

$currentDb = $_.name
$serverName = "{azure sql server name}.database.windows.net,1433"
$connStr = "Server = tcp:" + $serverName + "; Initial Catalog = " + $currentDb + "; Persist Security Info=False;User ID={user Id};Password={user password};Pooling=False; MultipleActiveResultSets=False;Connection Timeout=60;Encrypt=False;TrustServerCertificate=True"
$connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
$connection.ConnectionString = $connStr
$connection.Connect()
$server = New-Object Microsoft.SqlServer.Management.Smo.Server($connection)
$database = $server.Databases[$databaseName] 

$_.tables | Foreach {

echo "database $($currentDb) tables $($_.name)"

# Change encryption schema

$encryptionChanges = @()

# Add changes for table
<#$encryptionChanges += New-SqlColumnEncryptionSettings -ColumnName dbo.EncryptionTest.NotEncryptedColumn -EncryptionType Deterministic -EncryptionKey CEK10#>
$encryptionChanges += New-SqlColumnEncryptionSettings -ColumnName $_.name -EncryptionType Deterministic -EncryptionKey $cekName

Set-SqlColumnEncryption -ColumnEncryptionSettings $encryptionChanges -InputObject $database

        }
     }
}

SetUpKeyVaulAndDBtEncryptionKeys "{db name}" "{CEK name}" "{CMK name}" $clientId $clientSecret