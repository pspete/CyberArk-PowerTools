$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-CCPPassword" {

	BeforeEach {
		Mock Invoke-RestMethod {}
		$InputObj = [pscustomobject]@{
			"AppID" = "SomeApplication"
			"URL"   = "https://SomeURL"
		}
	}

	It "sends request" {
		$InputObj | Get-CCPPassword
		Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly -Scope It
	}

	It "sends request with expected method" {
		$InputObj | Get-CCPPassword
		Assert-MockCalled Invoke-RestMethod -ParameterFilter {
			$Method -eq "GET"

		} -Times 1 -Exactly -Scope It
	}

	It "sends request with expected content-type" {
		$InputObj | Get-CCPPassword
		Assert-MockCalled Invoke-RestMethod -ParameterFilter {
			$ContentType -eq "application/json"

		} -Times 1 -Exactly -Scope It
	}

	It "sends request to expected URL" {
		$InputObj | Get-CCPPassword
		Assert-MockCalled Invoke-RestMethod -ParameterFilter {

			$URI -eq "https://SomeURL/AIMWebService/api/Accounts?AppID=SomeApplication"

		} -Times 1 -Exactly -Scope It
	}

}
