function Get-CCPPassword {
	<#
	.SYNOPSIS
	Use the GetPassword REST Web Service to retrieve passwords from the Central Credential Provider.

	.DESCRIPTION
	When the Central Credential Provider for Windows is published via an IIS and the Central
	Credential Provider Web Service, this function can be used to retrieve credentials.
	Passwords stored in the CyberArk Vault are retrieved to the Central Credential Provider, where
	they can be accessed by authorized remote applications/scripts using a web service call.

	.PARAMETER AppID
	Specifies the unique ID of the application issuing the password request.

	.PARAMETER Safe
	Specifies the name of the Safe where the password is stored.

	.PARAMETER Folder
	Specifies the name of the folder where the password is stored.

	.PARAMETER Object
	Specifies the name of the password object to retrieve.

	.PARAMETER UserName
	Defines search criteria according to the UserName account property.

	.PARAMETER Address
	Defines search criteria according to the Address account property.

	.PARAMETER Database
	Defines search criteria according to the Database account property.

	.PARAMETER PolicyID
	Defines the format that will be used in the set PolicyID method.

	.PARAMETER Reason
	The reason for retrieving the password. This reason will be audited in the Credential Provider audit log

	.PARAMETER ConnectionTimeout
	The number of seconds that the Central Credential Provider will try to retrieve the password.
	The timeout is calculated when the request is sent from the web service to the Vault and returned back
	to the web service.

	.PARAMETER WebServiceName
	The name the CCP WebService is configured under in IIS.
	Defaults to AIMWebService

	.PARAMETER URL
	The URL for the CCP Host

	.EXAMPLE
	Get-CCPPassword -AppID PSScript -Safe PSAccounts -Object PSPlatform-AccountName `
		-URL https://cyberark.yourcompany.com

	Uses the PSScript App ID to retrieve password for the PSPlatform-AccountName object in the PSAccounts safe from the
	https://cyberark.yourcompany.com/AIMWebService CCP Web Service.

	.EXAMPLE
	Get-CCPPassword -AppID PowerShell -Safe PSAccounts -UserName svc-psProvision -WebServiceName DevAIM `
		-URL https://cyberark-dev.yourcompany.com

	Uses the PowerShell App ID to search for and retrieve the password for the svc-psProvision account in the PSAccounts safe
	from the https://cyberark-dev.yourcompany.com/DevAIM CCP Web Service.

	#>
	[CmdletBinding()]
	Param(
		# Unique ID of the application
		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]
		$AppID,

		# Safe name
		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]
		$Safe,

		# Folder name
		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]
		$Folder,

		# Object name
		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]
		$Object,

		# Search username
		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]
		$UserName,

		# Search address
		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]
		$Address,

		# Search database
		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]
		$Database,

		# SetPolicyID format
		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]
		$PolicyID,

		# Reason to record in audit log
		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]
		$Reason,

		# Number of seconds to try
		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[int]
		$ConnectionTimeout,

		# Unique ID of the CCP webservice in IIS
		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]
		$WebServiceName = "AIMWebService",

		# CCP URL
		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]
		$URL
	)
	Begin {
		[array]$CommonParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
		[array]$CommonParameters += [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
		[array]$CommonParameters += "URL", "WebServiceName"

		#If Tls12 Security Protocol is available
		if(([Net.SecurityProtocolType].GetEnumNames() -contains "Tls12") -and

			#And Tls12 is not already in use
			(-not ([System.Net.ServicePointManager]::SecurityProtocol -match "Tls12"))) {

			Write-Verbose "Setting Security Protocol to TLS12"
			[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

		}

	}

	Process {

		$PSBoundParameters.keys | Where-Object {$CommonParameters -notcontains $_} | ForEach-Object {

			[array]$QueryArgs += "$_=$([System.Uri]::EscapeDataString($PSBoundParameters[$_]))"

		}

		$Query = $QueryArgs -join '&'

		$URI = "$URL/$WebServiceName/api/Accounts?$Query"

		Try {

			$result = Invoke-RestMethod -Method GET -ContentType "application/json" -Uri $URI -ErrorAction Stop

		} Catch {

			try {

				$err = $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
				Write-Error -Message $err.ErrorMsg -ErrorId $err.ErrorCode

			} catch {throw $error[-1]}

		} Finally {$result}

	}

	End {}

}
