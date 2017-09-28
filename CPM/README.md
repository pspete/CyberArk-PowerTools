# CPM

## Parameter Files

A method to capture the short lived temporary file containing account configuration parameters which is created on a CyberArk CPM server prior to a password management operation taking place.

- `Get-CPMParameterFile`
  - Watches the CPM `tmp` directory for a parameter file relating a specific account.
  - Requires the CyberArk password object name as input.
  - Can optionally restart the Password Manager service.
  - Found parameter file is copied to an output folder for subsequent use in CPM Plugin development or debugging.