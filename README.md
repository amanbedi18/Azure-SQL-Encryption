# Azure SQL Encryption Wiki

Automation script for implementing Azure SQL Always encrypted feature on SQL Table Columns.

## Prerequisits

1. Azure key vault for storing column master key.
2. Azure SQL Server hosting Azure SQL Database with multiple tables.
3. Azure PowerShell with SqlServer module installed.
4. Azure AD Native application for service principal authentication. Make sure the application has create / modify azure resources for service principal auth and the application has keys create / modify permissions to key vault.

## Executing the PowerShell script

### 1. Modify configuration file json

* The **SqlDbs** object is an array of each object having **Name** and **Tables** array.
* Add as many objects to the array as the number of databases.
* Each object has the name property for the name of the database and tables array having name of the object representing the table column to be encrypted.

### 2. Configure PowerShell script arguments 

* SubscriptionId =  subscription id of the azure subscription.
* akvName = azure key vault name.
* TenantId = tenant Id of azure AD.
* akvKeyName = Azure key vault key name, same as that of the column master key.
* clientId = client Id of azure AD application.
* clientSecret = client secret of azure AD application.
* Configure the following function arguments of SetUpKeyVaulAndDBtEncryptionKeys function call in the script:
1. databaseName = name of the database to create the column encryption and master keys.
2. cekName = column encryption key name
3. cmkName = column encryption master key name

### 3. Execute the PowerShell script

* On executing the PowerShell script, azure column master key metadata is created in the SQL database and stored azure key vault keys.
* Generates a column encryption key, encrypt it with the column master key and create column encryption key metadata in the database.
* Parses the configuration json to get list of columns in respective tables belonging to the databases where encryption has to be enabled for.
* Applies encryption changes on each database object as per the configuration json. 
* If the data in the column already exist then the data is encrypted else the script simply changes the schema to only allow encrypted values to be stored and retrieved from the database.

**_In order to enter / retrieve the data from the database, use the SqlColumnEncryptionAzureKeyVaultProvider in the client application so that the data can be encrypted and decrypted by the client application._**

