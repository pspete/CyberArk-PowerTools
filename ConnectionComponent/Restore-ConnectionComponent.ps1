function Restore-ConnectionComponent {
	<#
	.SYNOPSIS
	Restores (adds or replaces) a "ConnectionComponent" in a CyberArk PVConfiguration.xml file.

	.DESCRIPTION
	When passed xml objects, or xml files, containing data for a connection component configuration, the data will be used
	to update a PVConfiguration.xml file.

	The PVConfiguration.xml file can either be a local copy, or be automatically  retrieved from, updated & saved, and
	then stored back in a CyberArk Vault using PACLI (and relevant vault credentials).

	If the Connection Component being restored does not currently exist in the PVConfiguration.xml file, it will be
	added as an additional connection component. If a connection component with the same Id already exists in the
	PVConfiguration.xml file, the existing connection component will be replaced.

	Restore-ConnectionComponent is a companion function to Backup-ConnectionComponent; It can consume pipeline output
	or backup files created by Backup-ConnectionComponent, ideal for transferring connection components developed in
	one environment to other environments for testing or deployment, or reverting to known good configurations.

	.PARAMETER ConnectionComponent
	XML object containing a Connection Component Element from PVConfiguration.xml.
	The Output of Backup-ConnectionComponent is expected.

	.PARAMETER BackupFile
	An xml file containing Connection Component configuration element.
	A file should contain only data for a single connection component.
	Backup file from Backup-ConnectionComponent is expected.

	.PARAMETER LocalConfig
	A local PVConfiguration.xml file to update.

	.PARAMETER VaultAddress
	The address of a CyberArk vault containing a PVConfiguration.xml file to update.

	.PARAMETER Credential
	Username/password to authenticate to the CyberArk vault.

	.PARAMETER PacliPath
	Path to PACLI.exe.

	.PARAMETER PVWAConfigSafe
	The name of the safe in the CyberArk vault containing the PVConfiguration.xml file.
	Defaults to PVWAConfig.

	.EXAMPLE
	Restore-ConnectionComponent -ConnectionComponent $SSH -LocalConfig C:\PVConfiguration.xml

	Restores Connection Component (stored in $SSH) to Local PVConfiguration file.

	.EXAMPLE
	Restore-ConnectionComponent -ConnectionComponent $RDP -VaultAddress QAEPV -Credential $QACred -PacliFolder C:\PACLI

	Restores Connection Component (stored in $RDP) to PVConfiguration file in PVWAConfig safe in Vault QAEPV.

	.EXAMPLE
	Restore-ConnectionComponent -BackupFile C:\_PSM-RDP.xml -LocalConfig C:\PVConfiguration.xml

	Restores connection component from local backup file _PSM-RDP.xml to local PVConfiguration file.

	.EXAMPLE
	Restore-ConnectionComponent -BackupFile C:\_Web.xml -VaultAddress Prod-EPV -Credential $Creds -PacliFolder C:\PACLI

	Restores connection component from local backup file _Web.xml to Vault Prod-EPV.

	.EXAMPLE
	Backup-ConnectionComponent -ConnectionComponent SSH -VaultAddress EPV01 -Credential $cred -PacliFolder C:\PACLI |
	Restore-ConnectionComponent -LocalConfig C:\PVConfiguration.xml

	Restores SSH Connection Component output by Backup-ConnectionComponent to local PVConfiguration file.

	.EXAMPLE
	Backup-ConnectionComponent -ConnectionComponent RDP -VaultAddress EPV01 -Credential $cred1 -PacliFolder C:\PACLI |
	Restore-ConnectionComponent -VaultAddress EPV02 -Credential $cred2 -PacliFolder C:\PACLI

	Restores RDP Connection Component from Vault EPV01, to PVConfiguration.xml in vault EPV02.

	.NOTES
	PoShPACLI Module is required to be available on the local machine
	https://github.com/pspete/PoShPACLI

	#>

	#Requires -Module PoShPACLI
	[CmdletBinding()]
	param(
		# Connection Component Name
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Default",
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "XML object containing Connection Component configuration"
		)]
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "LocalFile",
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "XML object containing Connection Component configuration"
		)]
		[ValidateNotNullOrEmpty()]
		[System.Xml.XmlElement[]]
		$ConnectionComponent,

		# Connection Component Backup XML file(s).
		[Parameter(
			Mandatory = $false,
			ParameterSetName = "FileToRemote",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Connection Component Backup XML file path"
		)]
		[Parameter(
			Mandatory = $false,
			ParameterSetName = "FileToLocal",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Connection Component Backup XML file path"
		)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( { Select-XML -Path $_ -XPath "//ConnectionComponent" } )]
		[string[]]
		$BackupFile,

		# Local PVConfiguration.xml file.
		[Parameter(
			Mandatory = $false,
			ParameterSetName = "LocalFile",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Local PVConfiguration.xml file to update"
		)]
		[Parameter(
			Mandatory = $false,
			ParameterSetName = "FileToLocal",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Path to local PVConfiguration.xml file to update"
		)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( { Select-XML -Path $_ -XPath "//ConnectionComponents" } )]
		[string[]]
		$LocalConfig,

		# IP or DNS address of CyberArk Vault Server
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Default",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "IP or DNS address of CyberArk Vault Server"
		)]
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "FileToRemote",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "IP or DNS address of CyberArk Vault Server"
		)]
		[ValidateNotNullOrEmpty()]
		[string]
		$VaultAddress,

		# Credentials used to logon to the CyberArkVault
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Default",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Vault Credentials"
		)]
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "FileToRemote",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Vault Credentials"
		)]
		[ValidateNotNullOrEmpty()]
		[pscredential]
		$Credential,

		# PACLI.EXE Path
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Default",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Path to PACLI.EXE."
		)]
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "FileToRemote",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Path to PACLI.EXE."
		)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( { Test-Path $_ } )]
		[string]
		$PacliPath,

		# PVWAConfig Safe Name
		[Parameter(
			Mandatory = $false,
			ParameterSetName = "Default",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Name of the safe containing PVConfiguration.xml"
		)]
		[Parameter(
			Mandatory = $false,
			ParameterSetName = "FileToRemote",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Name of the safe containing PVConfiguration.xml"
		)]
		[ValidateNotNullOrEmpty()]
		[string]
		$PVWAConfigSafe = "PVWAConfig"
	)

	Begin {

		#If PACLI is required (for Retrieve or Store of remote PVConfiguration.xml)
		if (($PsCmdlet.ParameterSetName -eq "Default") -or ($PsCmdlet.ParameterSetName -eq "FileToRemote")) {

			Try {

				#Initialise
				Set-PVConfiguration -ClientPath $PacliPath -ErrorAction Stop | Out-Null

				#If Pacli not already running
				if (-not (Get-Process PACLI -ErrorAction SilentlyContinue)) {

					#Start Pacli
					Start-PVPACLI -ErrorAction Stop | Out-Null

				}

			}

			Catch {

				#Terminate on any error - cannot continue if PACLI process not available
				Throw $_

			}

			Try {

				Write-Verbose "Connecting to Vault: $VaultAddress"

				#Logon to Vault, to get token, open target safe
				$token = New-PVVaultDefinition -address $VaultAddress -vault Destination -ErrorAction SilentlyContinue |
				Connect-PVVault -user $($Credential.UserName) -password $($Credential.Password) -ErrorAction Stop |
				Open-PVSafe -safe $PVWAConfigSafe -ErrorAction Stop

				Write-Verbose "Downloading Target File: PVConfiguration.xml"

				#Save PVConfiguration.xml to Local Temp folder
				$token |
				Get-PVFile -folder Root -file PVConfiguration.xml `
					-localFolder $env:TEMP -localFile _dst_PVConfiguration.xml -ErrorAction Stop | Out-Null


				#Set inputfile path to local copy of PVConfiguration.xml
				$PVConfiguration = Join-Path $env:TEMP "_dst_PVConfiguration.xml"

			}

			Catch {

				#Attempt Logoff & Stop
				$token | Disconnect-PVVault -ErrorAction SilentlyContinue |
				Stop-PVPacli  -ErrorAction SilentlyContinue | Out-Null

				#Terminate on any error - cannot continue if PACLI process does not succeed
				Throw $_

			}

		}

		if (($PsCmdlet.ParameterSetName -eq "FileToLocal") -or ($PsCmdlet.ParameterSetName -eq "LocalFile")) {

			#Set inputfile path to local PVConfiguration.xml
			$PVConfiguration = $LocalConfig

		}

		Write-Verbose "Importing Target File: $PVConfiguration"

		#Import PVConfiguration.xml data
		$Config = (Select-Xml -Path $PVConfiguration -XPath / ).Node

	}

	Process {

		#If Restoring from Backup Files
		if (($PsCmdlet.ParameterSetName -eq "FileToLocal") -or ($PsCmdlet.ParameterSetName -eq "FileToRemote")) {

			#Enumerate files
			foreach ($File in $BackupFile) {

				Write-Verbose "Importing Backup File: $File"

				#Add ConnectionComponent XML data to array
				$ConnectionComponent += ((Select-Xml -Path $File -XPath / ).node).ConnectionComponent

			}

		}

		#Process each Component to Restore
		foreach ($Component in $ConnectionComponent) {

			#Current Connection Components
			$ConnectionComponents = $Config.PasswordVaultConfiguration.ConnectionComponents

			Write-Verbose "Restoring Connection Component: $($Component.Id)"

			Try {

				#Import Component as node of config to update
				$NewNode = $Config.PasswordVaultConfiguration.OwnerDocument.ImportNode($Component, $true)

				#If Component already exists
				if ($OldNode = $ConnectionComponents.SelectSingleNode("//ConnectionComponent[@Id='$($Component.Id)']")) {

					Write-Verbose "Replacing Connection Component Node: $($Component.Id)"

					#Replace Node
					$Config.PasswordVaultConfiguration.ConnectionComponents.ReplaceChild($NewNode, $OldNode) | Out-Null

				}

				#Connection Component does not exist
				Else {

					Write-Verbose "Adding Connection Component Node: $($Component.Id)"

					#Append Connection Component Node
					$Config.PasswordVaultConfiguration.ConnectionComponents.AppendChild($NewNode) | Out-Null

				}

			}

			Catch {

				Write-Error $_

			}

			Finally {

				Write-Verbose "Saving File: $($PVConfiguration | Get-Item).FullName"

				#Normalize XML
				$Config.Normalize()

				#Update local PVConfiguration.xml
				$Config.Save(($PVConfiguration | Get-Item).FullName)

			}

		}

		#If Storing file back in a vault
		if (($PsCmdlet.ParameterSetName -eq "Default") -or ($PsCmdlet.ParameterSetName -eq "FileToRemote")) {

			#upload file
			Try {

				Write-Verbose "Uploading PVConfiguration.xml to $PVWAConfigSafe"

				#Store Updated local PVConfiguration.xml to PVConfig Safe.
				$token |
				Add-PVFile -folder Root -file PVConfiguration.xml `
					-localFolder $env:TEMP -localFile _dst_PVConfiguration.xml -ErrorAction Stop | Out-Null

			}

			Catch {

				#Try Close Safe, Logoff, Stop Pacli
				$token | Close-PVSafe -ErrorAction SilentlyContinue |
				Disconnect-PVVault | Stop-PVPacli | Out-Null

				#Terminate on any error - cannot continue if PACLI process does not succeed
				Throw $_

			}

		}

	}

	End {

		#If PACLI has been required
		if (($PsCmdlet.ParameterSetName -eq "Default") -or ($PsCmdlet.ParameterSetName -eq "FileToRemote")) {

			#Check for PACLI process
			if (Get-Process PACLI -ErrorAction SilentlyContinue) {

				Write-Verbose "Stopping Pacli"

				#Close Safe, Logoff, Always (try to) Stop Pacli
				$token | Close-PVSafe -safe $PVWAConfigSafe -ErrorAction SilentlyContinue |
				Disconnect-PVVault -ErrorAction SilentlyContinue |
				Stop-PVPacli -ErrorAction SilentlyContinue | Out-Null

			}

			Write-Verbose "Deleting $PVConfiguration"

			#Clean Up - Delete Retrieved File
			Remove-Item $PVConfiguration

		}

	}

}