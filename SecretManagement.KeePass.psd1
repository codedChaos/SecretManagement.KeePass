#
# Module manifest for module 'SecretsManagement.KeePass'
#
# Generated by: jgrote
#
# Generated on: 2/10/2020
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'SecretManagement.KeePass.psm1'

# Version number of this module.
ModuleVersion = '0.9.1.1'

# Supported PSEditions
CompatiblePSEditions = @('Desktop','Core')

# ID used to uniquely identify this module
GUID = '14f945da-777e-4f2b-9c79-b59287d19478'

# Author of this module
Author = 'Justin Grote'

# Copyright statement for this module
Copyright = '(c) 2020 Justin Grote. All rights reserved.'

# Description of the functionality provided by this module
Description = 'A cross-platform Keepass Secret Management vault extension. See the README.MD in the module for more details.'

# Modules that must be imported into the global environment prior to importing this module
NestedModules = @(
    './SecretManagement.KeePass.Extension/SecretManagement.KeePass.Extension.psd1'
)
RequiredModules = @(
    @{
        ModuleName = 'Microsoft.Powershell.SecretManagement'
        ModuleVersion = '0.9.1'    
    }
)
PowershellVersion = '5.1'
FunctionsToExport = @('Register-KeePassSecretVault')
CmdletsToExport   = @()
VariablesToExport = @()
AliasesToExport   = @()
PrivateData = @{
    PSData = @{
        Tags       = 'SecretManagement', 'KeePass', 'SecretVault', 'Vault', 'Secret'
        ProjectUri = 'https://www.github.com/JustinGrote/SecretManagement.KeePass'
        IconUri    = 'https://raw.githubusercontent.com/JustinGrote/SecretManagement.KeePass/main/images/Logo.png'
    }
}
}

