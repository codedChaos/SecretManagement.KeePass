using namespace KeePassLib
using namespace KeePassLib.Keys
using namespace KeePassLib.Serialization
using namespace KeePassLib.Interfaces
using namespace System.Runtime.InteropServices

function Connect-KeePassDatabase {
    <#
    .SYNOPSIS
    Open a connection to a keepass database
    #>
    param (
        #Path to the Keepass database
        [Parameter(Mandatory)][String]$Path,
        #Prompt for a master password
        [Switch]$UseMasterPassword,
        #The master password to unlock the database
        [SecureString]$MasterPassword,
        #The path to the key file for the database
        [String]$KeyPath,
        #Whether to use a secure key stored via DPAPI in your windows profile
        [Switch]$UseWindowsAccount,
        #Create a new database at the specified path. Will error if a database does not exist at the specified path
        [Switch]$Create,
        #Allow clobbering an existing database
        [Switch]$AllowClobber
    )

    $DBCompositeKey = [CompositeKey]::new()

    if (-not $MasterPassword -and -not $KeyPath -and -not $UseWindowsAccount) {
        Write-Verbose "No vault authentication mechanisms specified. Assuming you wanted to prompt for the Master Password"
        $UseMasterPassword = $true
    }

    if ($UseMasterPassword) {
        $CredentialParams = @{
            Username = 'Keepass Master Password'
            Message = "Enter the Keepass Master password for: $Path"
        }
        #PS7+ Only
        if ($PSEdition -ne 'Desktop') {
            $CredentialParams.Title = 'Keepass Master Password'
        }
        $MasterPassword = (Get-Credential @CredentialParams).Password
    }

    #NOTE: Order in which the CompositeKey is created is important and must follow the order of : MasterKey, KeyFile, Windows Account
    if ($MasterPassword) {
        $DBCompositeKey.AddUserKey(
            [KcpPassword]::new(
                #Decode SecureString
                [Marshal]::PtrToStringUni([Marshal]::SecureStringToBSTR($MasterPassword))
            )
        )
    }

    if ($KeyPath) {
        
        if (-not (Test-Path $KeyPath)) {
            if ($Create) {
                #Create a new key
                [KcpKeyFile]::Create(
                    $KeyPath, 
                    $null
                )
            } else {
                #Will emit a path not found error
                Resolve-Path $KeyPath
            }
        } else {
            Write-Verbose "A keepass key file was already found at $KeyPath. Reusing this key for safety. Please manually delete this key if you wish to use a new one"
        }

        $dbCompositeKey.AddUserKey(
            [KcpKeyFile]::new(
                (Resolve-Path $KeyPath), #Path to keyfile
                $true #Error if it is a database file
            )
        )
    }

    if ($UseWindowsAccount) {
        if ($PSVersionTable.PSVersion -gt '5.99.99' -and -not $IsWindows) {
            throw [NotSupportedException]'The -UseWindowsAccount parameter is only supported on a Windows Platform'
        }
        $DBCompositeKey.AddUserKey([KcpUserAccount]::new())
    }

    $DBConnection = [PWDatabase]::new()
    $DBConnectionInfo = [IOConnectionInfo]::FromPath($Path)

    if ($Create) {
        if (-not $AllowClobber -and (Test-Path $Path)) {
            throw "-Create was specified but a database already exists at $Path. Please specify -AllowClobber to overwrite the database."
        }
        $DBConnection.New(
            $DBConnectionInfo,
            $DBCompositeKey
        )
        $DBConnection.Save($null)
    }

    #Establish the connection

    $DBConnection.Open(
        $DBConnectionInfo,
        $DBCompositeKey,
        $null #No status logger
    )
    if (-not $DBConnection.IsOpen) {throw "Unable to connect to the database at $Path. Please check you supplied proper credentials"}
    $DBConnection
}