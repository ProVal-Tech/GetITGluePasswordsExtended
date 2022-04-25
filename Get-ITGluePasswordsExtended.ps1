<#
.SYNOPSIS
    Gets ITGlue passwords with one time password secrets!
.EXAMPLE
    $passwords = .\Get-ITGluePasswordsExtended.ps1
    $passwords.attributes | Export-CSV -Path 'C:\temp\mypasswords.csv' -NoTypeInformation
.PARAMETER APIKey
    An API key for ITGlue with password access.
.PARAMETER BearerToken
    The bearer token to use for parsing individual passwords. Review the README for instructions on getting this string.
.PARAMETER Authority
    The authority to use for parsing individual passwords. Review the README for instructions on getting this string.
.OUTPUTS
    System.Object
    Will return the same objects that the ITGlueAPIv2 module does with an additional attribute: 'otp-secret'
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)][string]$APIKey,
    [Parameter(Mandatory = $true)][string]$BearerToken,
    [Parameter(Mandatory = $true)][string]$Authority
)

### Process ###
if ($Authority -notmatch '^https:\/\/') {
    $Authority = "https://$Authority"
}
if (!(Import-Module ITGlueAPI -PassThru)) {
    Install-Module -Name ITGlueAPI
}
Add-ITGlueAPIKey -Api_Key $APIKey
$APIKey = $null
$pageSize = -1
$apiPasswords = for ($i = 1; ($i -le $pageSize) -or ($pageSize -eq -1); $i++) {
    $passwordAPIReturn = Get-ITGluePasswords -page_number $i -page_size 1000
    Write-Progress -Activity 'Gathering ITGlue passwords.' -Status "Processing page $i" -PercentComplete ($i / $passwordAPIReturn.meta.'total-pages')
    if ($pageSize -eq -1) {
        $pageSize = $passwordAPIReturn.meta.'total-pages'
    }
    $passwordAPIReturn.data
}
$passwordIndex = 0
foreach ($password in $apiPasswords) {
    $passwordIndex++
    Write-Progress -Activity 'Gathering one-time password secrets.' -Status "Processing password ID $($password.id) - ($passwordIndex/$($apiPasswords.Count))" -PercentComplete ($passwordIndex / $apiPasswords.Count * 100)
    $otpSecret = [string]::Empty
    if ($password.attributes.'otp-enabled') {
        $pathUri = "/api/passwords/$($password.id)?show_password=true"
        $passwordWithOTP = Invoke-RestMethod -Method GET -Uri "$Authority$pathUri" -Headers @{ 'authorization' = $BearerToken }
        $otpSecret = $passwordWithOTP.data.attributes.'otp-secret'
    }
    $password.attributes | Add-Member -MemberType NoteProperty -Name 'otp-secret' -Value $otpSecret
}
Write-Progress -Activity 'Gathering one-time password secrets.' -Completed
return $apiPasswords