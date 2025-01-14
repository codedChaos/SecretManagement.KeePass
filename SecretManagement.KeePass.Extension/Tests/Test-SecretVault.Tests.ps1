Import-Module -Name 'Microsoft.PowerShell.SecretManagement'
Import-Module -Name "$($PSScriptRoot)/../../SecretManagement.KeePass.psd1" -Force -Verbose

InModuleScope -ModuleName 'SecretManagement.KeePass.Extension' {
    Describe 'Test-SecretVault' {
        BeforeAll {
            $ModuleName = 'SecretManagement.KeePass'
            $ModulePath = (Get-Module $ModuleName).Path
            $BaseKeepassDatabaseName = 'Testdb'
            $KeePassCompositeError = '*The composite key is invalid!*Make sure the composite key is correct and try again.*'
            $KeePassMasterKeyError = '*The master key is invalid!*'
            $SCRIPT:Mocks = Join-Path $PSScriptRoot 'Mocks'
        }
        AfterAll {
            try {
                Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
            } catch [system.Exception] { }
        }
        Context 'Function Parameter Validation' {
            BeforeAll {
                $ExtModuleName = 'SecretManagement.KeePass.Extension'
                $FunctionName = 'Test-SecretVault'
                $ParameterCount = 2
            }
            It 'has a parameter "<Name>"' -TestCases @(
                @{Name = 'VaultName' }
                @{Name = 'AdditionalParameters' }
            ) {
                $AllParameterNames = (Get-Command -Module $ExtModuleName -Name $FunctionName).Parameters.Keys
                $Name | Should -BeIn $AllParameterNames
            }
            It 'has the mandatory value of parameter "<Name>" set to "<Mandatory>"' -TestCases @(
                @{Name = 'VaultName'; Mandatory = $True }
                @{Name = 'AdditionalParameters'; Mandatory = $False }
            ) {
                ((Get-Command -Module $ExtModuleName -Name $FunctionName).Parameters[$Name].Attributes | Where-Object { $_.GetType().FullName -eq 'System.Management.Automation.ParameterAttribute' }).Mandatory | Should -Be $Mandatory
            }
            It 'has parameter <Name> of type <Type>' -TestCases @(
                @{Name = 'VaultName'; Type = 'string' }
                @{Name = 'AdditionalParameters'; Type = 'hashtable' }
            ) {
                ((Get-Command -Module $ExtModuleName -Name $FunctionName).Parameters[$Name].ParameterType) | Should -BeExactly $Type
            }
            It 'has one parameter set' {
                (Get-Command -Module $ExtModuleName -Name $FunctionName).ParameterSets.Count | Should -BeExactly 1
            }
        }
        Context 'Validating with correct MasterPassword' {
            BeforeAll {
                $MasterKey = '"1}`.2R{LX1`Jm8%XX2/'
                $VaultMasterKey = [PSCredential]::new('vaultkey', (ConvertTo-SecureString -AsPlainText -Force $MasterKey))

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'PathOnly'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path = $VaultPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction Stop } | 
                    Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'should request a credential on the first pass' {
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Exactly 1 -Scope Context
            }
            It 'Should not request a credential on the second pass' {
                Test-SecretVault -VaultName $VaultName
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Exactly 1 -Scope Context
            }
            It "should have a variable 'Vault_$($VaultName)' upon unlock" {
                Test-SecretVault -VaultName $VaultName | Should -BeTrue
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value } | Should -Not -Throw
            }
            It 'should return true' { 
                Test-SecretVault -VaultName $VaultName | Should -BeTrue
            }
        }
        Context 'Validating with incorrect MasterPassword' {
            BeforeAll {
                $MasterKey = 'You can not enter with this masterkey'
                $VaultMasterKey = [PSCredential]::new('vaultkey', (ConvertTo-SecureString -AsPlainText -Force $MasterKey))

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'PathOnly'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path = $VaultPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -ErrorAction Stop -Name "Vault_$VaultName" -Scope Script 2>$null).Value } | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Detects Invalid Composite Key and does not set a vault variable' {
                #ICM Used to capture forced nonterminating error, EA stop will not work
                Invoke-Command -ErrorVariable err {
                    Test-SecretVault -VaultName $VaultName 2>$null 
                } 2>$null | Should -Be $False
                $err[-1] | Should -BeLike $KeePassMasterKeyError
                
                { Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction Stop } | 
                    Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
        }
        Context 'Validating with Path and correct UseMasterPassword' {
            BeforeAll {
                $MasterKey = '"1}`.2R{LX1`Jm8%XX2/'
                $VaultMasterKey = [PSCredential]::new('vaultkey', (ConvertTo-SecureString -AsPlainText -Force $MasterKey))

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'PathAndUseMasterPassword'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path              = $VaultPath
                        UseMasterPassword = $true
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction Stop).Value 2>$null} | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'should request a credential on the first pass' {
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Exactly 1 -Scope Context
            }
            It 'Should not request a credential on the second pass' {
                Test-SecretVault -VaultName $VaultName
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Exactly 1 -Scope Context
            }
            It "should have a variable 'Vault_$($VaultName)' after unlock" {
                Test-SecretVault -VaultName $VaultName
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value } | Should -Not -Throw
            }
        }
        Context 'Validating with Path and incorrect UseMasterPassword' {
            BeforeAll {
                $MasterKey = 'You can not enter with this masterkey'
                $VaultMasterKey = [PSCredential]::new('vaultkey', (ConvertTo-SecureString -AsPlainText -Force $MasterKey))

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'PathOnly'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path = $VaultPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop 2>$null} | 
                    Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Detects keepass composite key issue and does not set Vault connection variable' {
                Test-SecretVault -VaultName $VaultName 2>$null | Should -Be $false
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null} | 
                    Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
        }
        Context 'Validating with correct Keyfile' {
            BeforeAll {
                $KeyFileName = 'TestdbKeyFile.key'

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'KeyFile'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                $KeyPath = Join-Path -Path $TestDrive -ChildPath $KeyFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath
                Copy-Item -Path (Join-Path $Mocks $KeyFileName) -Destination $KeyPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path    = $VaultPath
                        KeyPath = $KeyPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null} | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Should not request a credential' {
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Exactly 0 -Scope Context
            }
            It "should have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null} | Should -Not -Throw
            }
            It 'should return true' {
                Test-SecretVault -VaultName $VaultName | Should -BeTrue
            }
        }

        Context 'Validating with correct Keyfile V2' {
            BeforeAll {
                $KeyFileName = 'TestdbKeyFileV2.keyx'
                $KeePassDatabaseSuffix = 'KeyFileV2'

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                $KeyPath = Join-Path -Path $TestDrive -ChildPath $KeyFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath
                Copy-Item -Path (Join-Path $Mocks $KeyFileName) -Destination $KeyPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path    = $VaultPath
                        KeyPath = $KeyPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null} | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Should not request a credential' {
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Exactly 0 -Scope Context
            }
            It "should have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null} | Should -Not -Throw
            }
            It 'should return true' {
                Test-SecretVault -VaultName $VaultName | Should -BeTrue
            }
        }


        Context 'Validating with incorrect Keyfile' {
            BeforeAll {
                $KeyFileName = 'TestdbKeyFileAndMasterPassword.key'

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'KeyFile'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                $KeyPath = Join-Path -Path $TestDrive -ChildPath $KeyFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath
                Copy-Item -Path (Join-Path $Mocks $KeyFileName) -Destination $KeyPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path    = $VaultPath
                        KeyPath = $KeyPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null} | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Should not request a credential' {
                #ICM Used to capture forced nonterminating error, EA stop will not work
                Invoke-Command -ErrorVariable err {
                    Test-SecretVault -VaultName $VaultName 2>$null 
                } 2>$null | Should -Be $False
                $err[-1] | Should -BeLike $KeePassMasterKeyError
            }
            It "should still not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null} | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
        }
        Context 'Validating with correct Keyfile and correct master password' {
            BeforeAll {
                $KeyFileName = 'TestdbKeyFileAndMasterPassword.key'
                $MasterKey = '"1}`.2R{LX1`Jm8%XX2/'
                $VaultMasterKey = [PSCredential]::new('vaultkey', (ConvertTo-SecureString -AsPlainText -Force $MasterKey))

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'KeyFileAndMasterPassword'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                $KeyPath = Join-Path -Path $TestDrive -ChildPath $KeyFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath
                Copy-Item -Path (Join-Path $Mocks $KeyFileName) -Destination $KeyPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path              = $VaultPath
                        UseMasterPassword = $true
                        KeyPath           = $KeyPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null } | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Should request a credential on the first pass' {
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Times 1 -Exactly -Scope Context
            }
            It 'Should not request a credential on the second pass' {
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Times 1 -Exactly -Scope Context
            }
            It "should have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value } | Should -Not -Throw
            }
            It 'should return true' {
                Test-SecretVault -VaultName $VaultName | Should -BeTrue
            }
        }
        Context 'Validating with correct Keyfile and incorrect master password' {
            BeforeAll {
                $KeyFileName = 'TestdbKeyFileAndMasterPassword.key'
                $MasterKey = 'You can not enter with this password!'
                $VaultMasterKey = [PSCredential]::new('vaultkey', (ConvertTo-SecureString -AsPlainText -Force $MasterKey))

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'KeyFileAndMasterPassword'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                $KeyPath = Join-Path -Path $TestDrive -ChildPath $KeyFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath
                Copy-Item -Path (Join-Path $Mocks $KeyFileName) -Destination $KeyPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path              = $VaultPath
                        UseMasterPassword = $true
                        KeyPath           = $KeyPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null } | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Detects Invalid Composite Key and does not set a vault variable' {
                #ICM Used to capture forced nonterminating error, EA stop will not work
                Invoke-Command -ErrorVariable err {
                    Test-SecretVault -VaultName $VaultName 2>$null 
                } 2>$null | Should -Be $False
                $err[-1] | Should -BeLike $KeePassMasterKeyError
                
                { Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction Stop } | 
                    Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
        }
        Context 'Validating with incorrect Keyfile and correct master password' {
            BeforeAll {
                $KeyFileName = 'TestdbKeyFile.key'
                $MasterKey = '"1}`.2R{LX1`Jm8%XX2/'
                $VaultMasterKey = [PSCredential]::new('vaultkey', (ConvertTo-SecureString -AsPlainText -Force $MasterKey))

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'KeyFileAndMasterPassword'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                $KeyPath = Join-Path -Path $TestDrive -ChildPath $KeyFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath
                Copy-Item -Path (Join-Path $Mocks $KeyFileName) -Destination $KeyPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path              = $VaultPath
                        UseMasterPassword = $true
                        KeyPath           = $KeyPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null } | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Detects Invalid Composite Key and does not set a vault variable' {
                #ICM Used to capture forced nonterminating error, EA stop will not work
                Invoke-Command -ErrorVariable err {
                    Test-SecretVault -VaultName $VaultName 2>$null 
                } 2>$null | Should -Be $False
                $err[-1] | Should -BeLike $KeePassMasterKeyError
                
                { Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction Stop } | 
                    Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
        }
        Context 'Validating with incorrect Keyfile and incorrect master password' {
            BeforeAll {
                $KeyFileName = 'TestdbKeyFile.key'
                $MasterKey = 'You can not enter with this password!'
                $VaultMasterKey = [PSCredential]::new('vaultkey', (ConvertTo-SecureString -AsPlainText -Force $MasterKey))

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'KeyFileAndMasterPassword'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                $KeyPath = Join-Path -Path $TestDrive -ChildPath $KeyFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath
                Copy-Item -Path (Join-Path $Mocks $KeyFileName) -Destination $KeyPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path              = $VaultPath
                        UseMasterPassword = $true
                        KeyPath           = $KeyPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null } | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Detects Invalid Composite Key and does not set a vault variable' {
                #ICM Used to capture forced nonterminating error, EA stop will not work
                Invoke-Command -ErrorVariable err {
                    Test-SecretVault -VaultName $VaultName 2>$null 
                } 2>$null | Should -Be $False
                $err[-1] | Should -BeLike $KeePassMasterKeyError
                
                { Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction Stop } | 
                    Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
        }
        Context 'Validating Keyfile' {
            BeforeAll {
                $KeyFileName = 'TestdbKeyFile.key'

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'KeyFile'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                $KeyPath = Join-Path -Path $TestDrive -ChildPath $KeyFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath
                Copy-Item -Path (Join-Path $Mocks $KeyFileName) -Destination $KeyPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path    = $VaultPath
                        KeyPath = $KeyPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null } | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Should not request a credential' {
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Exactly 0 -Scope Context
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null } | Should -Not -Throw
            }
        }
        Context 'Validating Keyfile with master password' {
            BeforeAll {
                $KeyFileName = 'TestdbKeyFileAndMasterPassword.key'
                $MasterKey = '"1}`.2R{LX1`Jm8%XX2/'
                $VaultMasterKey = [PSCredential]::new('vaultkey', (ConvertTo-SecureString -AsPlainText -Force $MasterKey))

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'KeyFileAndMasterPassword'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                $KeyPath = Join-Path -Path $TestDrive -ChildPath $KeyFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath
                Copy-Item -Path (Join-Path $Mocks $KeyFileName) -Destination $KeyPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path              = $VaultPath
                        UseMasterPassword = $true
                        KeyPath           = $KeyPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null } | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Should request a credential on the first pass' {
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Times 1 -Exactly -Scope Context
            }
            It 'Should not request a credential on the second pass' {
                Test-SecretVault -VaultName $VaultName
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Times 1 -Exactly -Scope Context
            }
            It "should have a variable 'Vault_$($VaultName)'" {
                Test-SecretVault -VaultName $VaultName
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value } | Should -Not -Throw
            }
        }
        Context 'Validating Keyfile' {
            BeforeAll {
                $KeyFileName = 'TestdbKeyFile.key'

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'KeyFile'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                $KeyPath = Join-Path -Path $TestDrive -ChildPath $KeyFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath
                Copy-Item -Path (Join-Path $Mocks $KeyFileName) -Destination $KeyPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path    = $VaultPath
                        KeyPath = $KeyPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value 2>$null } | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Should not request a credential' {
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Exactly 0 -Scope Context
            }
            It "should have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value} | Should -Not -Throw
            }
        }
        Context 'Validating Keyfile with master password' {
            BeforeAll {
                $KeyFileName = 'TestdbKeyFileAndMasterPassword.key'
                $MasterKey = '"1}`.2R{LX1`Jm8%XX2/'
                $VaultMasterKey = [PSCredential]::new('vaultkey', (ConvertTo-SecureString -AsPlainText -Force $MasterKey))

                $VaultName = "KeepassPesterTest_$([guid]::NewGuid())"
                $KeePassDatabaseSuffix = 'KeyFileAndMasterPassword'
                $KeePassDatabaseFileName = "$($BaseKeepassDatabaseName)$($KeePassDatabaseSuffix).kdbx"
                $VaultPath = Join-Path -Path $TestDrive -ChildPath $KeePassDatabaseFileName
                $KeyPath = Join-Path -Path $TestDrive -ChildPath $KeyFileName
                Copy-Item -Path (Join-Path $Mocks $KeePassDatabaseFileName) -Destination $VaultPath
                Copy-Item -Path (Join-Path $Mocks $KeyFileName) -Destination $KeyPath

                $RegisterSecretVaultPathOnlyParams = @{
                    Name            = $VaultName
                    ModuleName      = $ModulePath
                    PassThru        = $true
                    VaultParameters = @{
                        Path              = $VaultPath
                        UseMasterPassword = $true
                        KeyPath           = $KeyPath
                    }
                }
                Microsoft.PowerShell.SecretManagement\Register-SecretVault @RegisterSecretVaultPathOnlyParams | Out-Null

                Mock -Verifiable -CommandName 'Get-Credential' -MockWith { $VaultMasterKey }
            }
            AfterAll {
                try {
                    Microsoft.PowerShell.SecretManagement\Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue | Microsoft.PowerShell.SecretManagement\Unregister-SecretVault -ErrorAction SilentlyContinue
                } catch [system.Exception] { }
            }
            It "should not have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value } | Should -Throw -ExpectedMessage "Cannot find a variable with the name 'Vault_$($VaultName)'."
            }
            It 'Should request a credential on the first pass' {
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Times 1 -Exactly -Scope Context
            }
            It 'Should not request a credential on the second pass' {
                Test-SecretVault -VaultName $VaultName
                Should -Invoke -CommandName 'Get-Credential' -Times 1 -Exactly -Scope Context
            }
            It "should have a variable 'Vault_$($VaultName)'" {
                { (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction stop).Value } | Should -Not -Throw
            }
        }
    }
}