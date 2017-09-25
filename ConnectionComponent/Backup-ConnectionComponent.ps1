function Backup-ConnectionComponent {
	<#
	.SYNOPSIS
	Extracts connection component details from a PVConfiguration.xml file.
	Allows configured connection components to be backed up to a file.

	.DESCRIPTION
	Individual CyberArk PVWA Connection Component configurations are extracted from the vault without having to
	manually manipulate the PVConfiguration.xml file.
	Reads a local PVConfiguration.xml file, or fetches a PVConfiguration.xml file from a vault (using PACLI).
	Specified connection component details are read from the document and output from the function.
	The XML data can be optionally saved to a file in a nominated directory.
	Any output files will be named "_<Connection Component Name>.xml"

	.PARAMETER ConnectionComponent
	The name, or list of names, of Connection Components for which the configuration is wanted.

	.PARAMETER InputFile
	The path to a local copy of a PVConfiguration.xml file from which to read the Connection Component configuration.

	.PARAMETER VaultAddress
	The address of the CyberArk vault from which to get the PVConfiguration.xml file.

	.PARAMETER Credential
	A credential object with which to connect to the CyberArk Vault.

	.PARAMETER PacliFolder
	The path to a local folder containing PACLI.EXE

	.PARAMETER PVWAConfigSafe
	The name of the CyberArk safe containing PVConfiguration.xml.

	.PARAMETER OutputDirectory
	The path to a local folder in which to optionally save individual  backup files containing connection component
	configurations.

	.EXAMPLE
	Backup-ConnectionComponent -ConnectionComponent SSH -InputFile C:\PVConfiguration.xml

	Extracts the SSH connection component details from a local PVConfiguration.xml file.

	.EXAMPLE
	Backup-ConnectionComponent -ConnectionComponent SSH -VaultAddress EPV01 -Credential $cred -PacliFolder C:\PACLI

	Extracts the SSH connection component details from PVConfiguration.xml file for the CyberArk vault EPV01.

	.EXAMPLE
	Backup-ConnectionComponent -ConnectionComponent SSH,RDP -VaultAddress 10.10.10.20 -Credential $cred `
	-PacliFolder C:\PACLI -OutputDirectory .\

	Extracts the SSH connection component details from PVConfiguration.xml file for the CyberArk vault EPV01.
	Saves connection component configurations to local files.

	.NOTES
	PoShPACLI Module is required to be available on the local machine
	https://github.com/pspete/PoShPACLI

	#>

	#Requires -Module PoShPACLI
	[CmdletBinding()]
	Param(

		# Connection Component Name
		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "The name of the connection component"
		)]
		[ValidateNotNullOrEmpty()]
		[string[]]
		$ConnectionComponent,

		# Specifies the path to a PVWAConfiguration.XML file.
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "FromFile",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Path to local PVConfiguration.xml file"
		)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( {Select-XML -Path $_ -XPath "//ConnectionComponents"} )]
		[string]
		$InputFile,

		# IP or DNS address of CyberArk Vault Server
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Default",
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
		[ValidateNotNullOrEmpty()]
		[pscredential]
		$Credential,

		# Folder containing PACLI.EXE
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Default",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Path to folder containing PACLI.EXE."
		)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( {Test-Path $_} )]
		[string]
		$PacliFolder,

		# PVWAConfig Safe Name
		[Parameter(
			Mandatory = $false,
			ParameterSetName = "Default",
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Name of the safe containing PVConfiguration.xml"
		)]
		[ValidateNotNullOrEmpty()]
		[string]
		$PVWAConfigSafe = "PVWAConfig",

		# Specifies a file path to output connection component data to.
		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $false,
			HelpMessage = "Path to folder in which to save output files."
		)]
		[ValidateNotNullOrEmpty()]
		[string]
		$OutputDirectory

	)

	Begin {

		if($PsCmdlet.ParameterSetName -eq "Default") {

			#tasks for PACLI operation
			Try {

				#Initialise
				Initialize-PoShPACLI -pacliFolder $PacliFolder -ErrorAction Stop | Out-Null

				if(-not (Get-Process PACLI -ErrorAction SilentlyContinue)) {

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
				$token = New-PVVaultDefinition -address $VaultAddress -vault Source |
					Connect-PVVault -user $($Credential.UserName) -password $($Credential.Password) -ErrorAction Stop |
					Open-PVSafe -safe $PVWAConfigSafe -ErrorAction Stop

				Write-Verbose "Downloading Input File: PVConfiguration.xml"

				#Save PVConfiguration.xml to Local Temp folder
				$token |
					Get-PVFile -folder Root -file PVConfiguration.xml `
					-localFolder $env:TEMP -localFile _bak_PVConfiguration.xml -ErrorAction Stop | Out-Null

				#Set inputfile path to local copy of PVConfiguration.xml
				$InputFile = Join-Path $env:TEMP "_bak_PVConfiguration.xml"

			}

			Catch {

				#Attempt Logoff & Stop
				$token | Disconnect-PVVault -ErrorAction SilentlyContinue |
					Stop-PVPacli | Out-Null

				#Terminate on any error - cannot continue if PACLI process does not succeed
				Throw $_

			}

			Finally {

				#Close Safe, Logoff
				$token |
					Close-PVSafe -safe $PVWAConfigSafe -ErrorAction SilentlyContinue |
					Disconnect-PVVault | Out-Null

			}

		}

		Write-Verbose "Importing Input File: $InputFile"

		#Import PVConfiguration.xml file
		$Config = Select-Xml -Path $InputFile -XPath /

	}

	Process {

		foreach($ComponentName in $ConnectionComponent) {

			If($Component = (($Config | Select-Xml -XPath "//ConnectionComponent[@Id='$ComponentName']").Node)) {

				Write-Verbose "Connection Component Found: $ComponentName"

				#if output directory specified
				If($OutputDirectory) {

					#Write XML to file in directory
					$Component.OuterXML | Out-File -FilePath (
						Join-Path $OutputDirectory "_$($Component.Id).xml") -Encoding utf8

					Write-Verbose "Saving '_$($Component.Id).xml' to $(Get-Item $OutputDirectory)"

				}

				#output collection
				Write-Output $Component

			}

			#connection component not found
			Else {

				#output error
				Write-Error "Connection Component Not Found: $ComponentName"

			}

		}

	}

	End {

		#If file fetched from vault, and retrieved file exists locally
		if(($PsCmdlet.ParameterSetName -eq "Default") -and (Test-Path $InputFile)) {

			if(Get-Process PACLI -ErrorAction SilentlyContinue) {

				Write-Verbose "Stopping Pacli"

				Stop-PVPACLI -ErrorAction SilentlyContinue | Out-Null

			}

			Write-Verbose "Deleting $InputFile"

			#Clean Up
			Remove-Item $InputFile

		}

	}

}