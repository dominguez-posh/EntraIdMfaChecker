#Version 1.0
#Author Lucas Dominguez

# Install-Module -Name ImportExcel 

$ErrorActionPreference = "silentlycontinue"

if (-not(Get-InstalledModule ImportExcel )) { Install-Module ImportExcel -Scope CurrentUser -AllowClobber -Force}

function ConnectTo-MgGraph {
  # Check if MS Graph module is installed
  if (-not(Get-InstalledModule Microsoft.Graph)) { 
    Write-Host "Microsoft Graph module not found" -ForegroundColor Black -BackgroundColor Yellow
    $install = Read-Host "Do you want to install the Microsoft Graph Module?"

    if ($install -match "[yY]") {
      Install-Module Microsoft.Graph -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
    }else{
      Write-Host "Microsoft Graph module is required." -ForegroundColor Black -BackgroundColor Yellow
      exit
    } 
  }

  # Connect to Graph
  Write-Host "Connecting to Microsoft Graph" -ForegroundColor Cyan


  Connect-MgGraph -Scopes "User.Read.All, UserAuthenticationMethod.Read.All, Directory.Read.All" -Environment 'Global' -ContextScope 'Process'
  
   }

function Get-Admins{
  <#
  .SYNOPSIS
    Get all user with an Admin role
  #>
  process{
    $UserRoles = @()
    $i = 1
    $Roles = Get-MgDirectoryRole | Select-Object DisplayName, Id
    foreach($Role in $Roles){
        $RoleName = $Role.DisplayName
        Write-Host ("Processing Admin Role(" + $i + "/" + $Roles.Count + "):" + $RoleName + "...")
        $RoleID = $ROle.ID
        $Members = @()

        $RoleMembers =  Get-MgDirectoryRoleMember -DirectoryRoleId  $RoleID 
        $ErrorActionPreference = "silentlycontinue"
        foreach ($RoleMember in $RoleMembers){

            try{$Members += Get-MgGroupMember -GroupId $RoleMember.Id } catch{}
            try{$Members += Get-MgUser -UserId $RoleMember.ID } catch{}
           

        }
        $ErrorActionPreference = "continue"



        foreach($Member in $Members){
            $UserRoles += [PSCustomObject]@{
                DisplayName    = $Member.DisplayName
                UserPrincipalName = $Member.UserPrincipalName
                Role = $RoleName
                UserMail = $Member.Mail
                UserID = $Member.Id
                
            }
        }
    $i++
    } 
    
    $UserROles = $UserRoles | Sort-Object -Property DisplayName

    $Users = @()
    $i = 1
    
    foreach ($User in ($UserRoles | Sort-Object -Unique -Property UserID)){
        
        $Roles = ($UserRoles | ? UserID -EQ $User.UserID).Role
        Write-Host ("Processing Admin User (" + $i + "/" + ($UserRoles | Sort-Object -Unique -Property UserID).Count  + ") " + $User.UserID)
        $Users += [PSCustomObject]@{
                DisplayName    = $User.DisplayName
                UserPrincipalName = $User.UserPrincipalName
                Role = $Roles
                UserMail = $User.UserMail
                UserID = $User.UserID
                AuthMethods = Get-MFAMethods -userId $User.UserID
                }
                $i++

    }

    return $users
  }
}

function Get-Users($Users, $OnlyEnabledAccounts = $True){


if(-Not $Users){
    Write-Host "Fetching User Infos..."

    $users = Get-MgUser -Property DisplayName, Id, UserPrincipalName, AssignedLicenses, Email, AssignedPlans, LicenseAssignmentStates, LicenseDetails, MobilePhone, BusinessPhones, Mail, OfficeLocation, JobTitle, accountenabled  -all #-filter "accountenabled eq true" 

}

$Users = $Users | Out-GridView -PassThru |? accountenabled -eq $OnlyEnabledAccounts

$UserList = @()
$TotalMiliseconds = 0
$AverageMilliseconds = 0
$i = 1
$User=$Null
foreach($User in $Users){
    cls
    $TimeStart = Get-Date
    $Persontage = [math]::Round((($i /$Users.Count) * 100 ),2)
    Write-Host ("Processing User (" + $i +"/" + $Users.Count + ") " + $Persontage + "% Finish"  ) 
    Write-Host "approximately finish in: " $FinishIn.Hours "Hours, " $FinishIn.Minutes " Minutes and " $FinishIn.Seconds "Seconds..."
    
    $UserPrincipalName = $User.UserPrincipalName
    $DisplayName = $User.DisplayName
    $IsLicensed = ($User.AssignedLicenses.count -gt 0)
    $UserMail = $User.Mail
    $AuthMethods = Get-MFAMethods -userId $User.Id   
    $MFAConfigured = ($AuthMethods.methodsconfigured -gt 1)
    $AdminRoles = $Null
    $IsExternal = ($User.UserPrincipalName -like "*#EXT#*")
    if(($admins | ? UserID -Like $User.Id) -notlike $Null){$IsAdmin = $True}
    else{$IsAdmin = $False}
    if($IsAdmin){$AdminRoles = ($admins | ? UserID -Like $User.Id).Role}

    $UserList += [PSCustomObject]@{
        UserPrincipalName = $UserPrincipalName
        DisplayName    = $DisplayName
        JobTitle = $User.JobTitle
        OfficeLocation = $User.OfficeLocation
        accountenabled = $User.accountenabled
        IsLicensed = $IsLicensed
        UserMail = $UserMail
        BusinessPhones = $User.BusinessPhones -join ', '
        MobilePhone = $User.MobilePhone
        UserID = $User.Id
        IsAdmin = $IsAdmin
        IsExternal = $IsExternal
        AdminRoles = $AdminRoles -join ', '
        MFAConfigured = $MFAConfigured
        PasswordlastSet = $AuthMethods.passwordlastset
        methodsconfigured = $AuthMethods.methodsconfigured
        authApp = $AuthMethods.authApp
        phoneAuth = $AuthMethods.phoneAuth
        fido = $AuthMethods.fido
        helloForBusinessCount = $AuthMethods.helloForBusinessCount
        emailAuth = $AuthMethods.emailAuth
        tempPass = $AuthMethods.tempPass
        passwordLess = $AuthMethods.passwordLess
        softwareAuth = $AuthMethods.softwareAuth
        authDevices = $AuthMethods.authDevice -join ', '
        authPhoneNrs = $AuthMethods.authPhoneNr -join ', '
        helloForBusiness = $AuthMethods.helloForBusiness
        SSPREmail = $AuthMethods.SSPREmail
        
    }


$TimeEnd = Get-Date
$TotalMiliseconds +=  ($TimeEnd - $TimeStart).TotalMilliseconds

$AverageMilliseconds = $TotalMiliseconds / $i

$ProcessTime = ($Users.Count - $i) * $AverageMilliseconds

$FinishAt = (Get-Date).AddMilliseconds($ProcessTime)

$FinishIn =  $FinishAt - $TimeEnd





$i++

}

return $UserList

}

function Get-MFAMethods {
  <#
    .SYNOPSIS
      Get the MFA status of the user
  #>
  param(
    [Parameter(Mandatory = $true)] $userId
  )
  process{
    # Get MFA details for each user
    [array]$mfaData = Get-MgUserAuthenticationMethod -UserId $userId

    # Create MFA details object
    $mfaMethods  = [PSCustomObject][Ordered]@{
      methodsconfigured = 0
      passwordlastset   = $Null
      authApp           = $Null
      phoneAuth         = $Null
      fido              = $Null
      helloForBusiness  = $Null
      helloForBusinessCount = 0
      emailAuth         = $Null
      tempPass          = $Null
      passwordLess      = $Null
      softwareAuth      = $Null
      authDevice        = @()
      authPhoneNr       = @()
      SSPREmail         = $Null
    }

    ForEach ($method in $mfaData) {
        Switch ($method.AdditionalProperties["@odata.type"]) {
          "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod"  { 
            # Microsoft Authenticator App
            $mfaMethods.authApp = $true
            $mfaMethods.authDevice += $method.AdditionalProperties["displayName"] -join ' '
            $mfaMethods.methodsconfigured ++
          } 
          "#microsoft.graph.phoneAuthenticationMethod"                  { 
            # Phone authentication
            $mfaMethods.phoneAuth = $true
            $mfaMethods.authPhoneNr += $method.AdditionalProperties["phoneType", "phoneNumber"] -join ' '
            $mfaMethods.methodsconfigured ++
          } 
          "#microsoft.graph.fido2AuthenticationMethod"                   { 
            # FIDO2 key
            $mfaMethods.fido = $true
            $fifoDetails = $method.AdditionalProperties["model"]
            $mfaMethods.methodsconfigured ++
          } 
          "#microsoft.graph.passwordAuthenticationMethod"                { 
            $mfaMethods.passwordlastset = [DateTime]$method.AdditionalProperties."createdDateTime"
            $mfaMethods.methodsconfigured ++
          }
          "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" { 
            # Windows Hello
            $mfaMethods.helloForBusiness = $true
            $helloForBusinessDetails = $method.AdditionalProperties["displayName"]
            $mfaMethods.helloForBusinessCount++
            if($mfaMethods.helloForBusinessCount -eq 1){$mfaMethods.methodsconfigured ++}
          } 
          "#microsoft.graph.emailAuthenticationMethod"                   { 
            # Email Authentication
            $mfaMethods.emailAuth =  $true
            $mfaMethods.SSPREmail = $method.AdditionalProperties["emailAddress"] 
            $mfaMethods.methodsconfigured ++
          }               
          "microsoft.graph.temporaryAccessPassAuthenticationMethod"    { 
            # Temporary Access pass
            $mfaMethods.tempPass = $true
            $tempPassDetails = $method.AdditionalProperties["lifetimeInMinutes"]
            $mfaMethods.methodsconfigured ++
          }
          "#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod" { 
            # Passwordless
            $mfaMethods.passwordLess = $true
            $passwordLessDetails = $method.AdditionalProperties["displayName"]
            $mfaMethods.methodsconfigured ++
          }
          "#microsoft.graph.softwareOathAuthenticationMethod" { 
            # ThirdPartyAuthenticator
            $mfaMethods.softwareAuth = $true
            $mfaMethods.methodsconfigured ++
          }
        }
    }
    Return $mfaMethods
  }
}

function Get-UsersInGroupsRecurse {

$Groupselect = Get-MgGroup -All
$Groups = $Groupselect  | Out-GridView -PassThru

$Members = @()
$Membergroups = @()

foreach($Group in $Groups){
    Write-Host "Fetching Users from Group: " $Group.DisplayName
    $Membergroups += $Groups
    (Get-MgGroupMember -GroupId $Group.Id | ? {$_.AdditionalProperties."@odata.type" -like "*user"}) | % {$Members += (Get-MgUser  -Property DisplayName, Id, UserPrincipalName, AssignedLicenses, Email, AssignedPlans, LicenseAssignmentStates, LicenseDetails, MobilePhone, BusinessPhones, Mail, OfficeLocation, JobTitle, accountenabled -UserId $_.Id)}

    do{
        $Subgroup = (Get-MgGroupMember -GroupId $Group.Id | ? {$_.AdditionalProperties."@odata.type" -like "*group"})
        $Loopdetection = $False
        if(-not ($Membergroups | ? Id -like $Subgroup.Id)){ #Prevent Loop
            if($Subgroup){

                $Membergroups += Get-MgGroup -GroupId $Subgroup.id
                $Subgroup | % {(Get-MgGroupMember -GroupId $Group.Id | ? {$_.AdditionalProperties."@odata.type" -like "*user"}) | % {$Members += (Get-MgUser  -Property DisplayName, Id, UserPrincipalName, AssignedLicenses, Email, AssignedPlans, LicenseAssignmentStates, LicenseDetails, MobilePhone, BusinessPhones, Mail, OfficeLocation, JobTitle, accountenabled -UserId $_.Id)}}
                $Group = Get-MgGroup -GroupId $Subgroup.id 

            }
            else{$Subgroup = $False}    
        }else{$Loopdetection = $True}

    }while($Subgroup)
}
if($Loopdetection){Write-Host "Loop in Group Detectet!"}
Write-Host "Members in following subGroups Found:" $Membergroups.DisplayName
$Members = $Members | Sort-Object -Property UserPrincipalName -Unique

return $Members
}

Function Get-MFAStatusUsers {
  <#
    .SYNOPSIS
      Get all AD users
  #>
  process {
    Write-Host "Collecting users" -ForegroundColor Cyan
    
    # Collect users
    $users = Get-Users
    
    Write-Host "Processing" $users.count "users" -ForegroundColor Cyan

    # Collect and loop through all users
    $users | ForEach {
      Write-Host "Processing User:" $_.id
      $mfaMethods = Get-MFAMethods -userId $_.id
      $manager = Get-Manager -userId $_.id

       $uri = "https://graph.microsoft.com/beta/users/$($_.id)/authentication/signInPreferences"
       $mfaPreferredMethod = Invoke-MgGraphRequest -uri $uri -Method GET

       if ($null -eq ($mfaPreferredMethod.userPreferredMethodForSecondaryAuthentication)) {
        # When an MFA is configured by the user, then there is alway a preferred method
        # So if the preferred method is empty, then we can assume that MFA isn't configured
        # by the user
        $mfaMethods.status = "disabled"
       }

      if ($withOutMFAOnly) {
        if ($mfaMethods.status -eq "disabled") {
          [PSCustomObject]@{
            "Name" = $_.DisplayName
            Emailaddress = $_.mail
            UserPrincipalName = $_.UserPrincipalName
            isAdmin = if ($listAdmins -and ($admins.UserPrincipalName -match $_.UserPrincipalName)) {$true} else {"-"}
            MFAEnabled        = $false
            "Phone number" = $mfaMethods.authPhoneNr
            "Email for SSPR" = $mfaMethods.SSPREmail
          }
        }
      }else{
        [pscustomobject]@{
          "Name" = $_.DisplayName
          Emailaddress = $_.mail
          UserPrincipalName = $_.UserPrincipalName
          isAdmin = if ($listAdmins -and ($admins.UserPrincipalName -match $_.UserPrincipalName)) {$true} else {"-"}
          "MFA Status" = $mfaMethods.status
          "MFA Preferred method" = $mfaPreferredMethod.userPreferredMethodForSecondaryAuthentication
          "Phone Authentication" = $mfaMethods.phoneAuth
          "Authenticator App" = $mfaMethods.authApp
          "Passwordless" = $mfaMethods.passwordLess
          "Hello for Business" = $mfaMethods.helloForBusiness
          "FIDO2 Security Key" = $mfaMethods.fido
          "Temporary Access Pass" = $mfaMethods.tempPass
          "Authenticator device" = $mfaMethods.authDevice
          "Phone number" = $mfaMethods.authPhoneNr
          "Email for SSPR" = $mfaMethods.SSPREmail
          "Manager" = $manager
        }
      }
    }
  }
}

function Get-Summary($UserList){
cls

Write-Host "MFA-STATUS-REPORT FOR TENANT" (Get-MgContext).TenantId
Write-Host

#Filter for Internal and Active Users
$UserList = $UserList | ? IsExternal -eq $False | ? accountenabled -eq $True

Write-Host "In total there are" $UserList.Count "Enabled and active Users"

#Total Users, wich has no Enabled MFA
$TotalEnabledUsers = ($UserList | ? accountenabled -eq $true).count
$TotalUsersWithEnabledMFA =  ($UserList | ? accountenabled -eq $true | ? MFAConfigured -eq $True).count
$RelativeUsersWithEnabledMFA = [math]::Round((($TotalUsersWithEnabledMFA / $TotalEnabledUsers) * 100 ),2)

Write-Host ($TotalEnabledUsers - $TotalUsersWithEnabledMFA) "Users of them has no configured MFA , or " $RelativeUsersWithEnabledMFA "%"


#Total licensed Users, wich has no Enabled MFA
$TotalLicensedEnabledUsers = ($UserList | ? accountenabled -eq $true | ? IsLicensed -eq $True).count
$TotalLicensedUsersWithEnabledMFA =  ($UserList | ? accountenabled -eq $true | ? MFAConfigured -eq $True | ? IsLicensed -eq $True).count
$RelativeLicensedUsersWithEnabledMFA = [math]::Round((($TotalLicensedUsersWithEnabledMFA / $TotalLicensedEnabledUsers) * 100 ),2)

Write-Host ""
Write-Host "In total there are" $TotalLicensedEnabledUsers "Licensed Enabled and active Users"
Write-Host ($TotalLicensedEnabledUsers - $TotalLicensedUsersWithEnabledMFA) "Users of them has no configured MFA. or"  (100 - $RelativeLicensedUsersWithEnabledMFA) "%"


#Total Admins (No Global Admins) With no MFA
$TotalAdmins = ($UserList | ? IsAdmin -eq $True | ? AdminRoles -notlike "*Global*").count
$AdminsEnabledWithNoMFA = $UserList | ? accountenabled -eq $true | ? IsAdmin -eq $True | ? MFAConfigured -eq $False | ? AdminRoles -notlike "*Global*"
$TotalAdminsEnabledWithNoMFA = $AdminsEnabledWithNoMFA.count
$RelativeAdminsEnabledWithNoMFA = [math]::Round((($TotalAdminsEnabledWithNoMFA / $TotalAdmins) * 100 ),2)


Write-Host ""
Write-Host "In total there are" $TotalAdmins "Licensed Enabled and active Admin Users, with no Global Admin Rights"
Write-Host ($TotalLicensedEnabledUsers - $TotalLicensedUsersWithEnabledMFA) "Users of them has no configured MFA. or"  (100 - $RelativeAdminsEnabledWithNoMFA) "%"



#Total Global Admins with no MFA
$TotalGlobalAdmins = ($UserList | ? AdminRoles -like "*Global*").count
$GlobalAdminsEnabledWithNoMFA = $UserList | ? accountenabled -eq $true | ? AdminRoles -like "*Global*"| ? MFAConfigured -eq $False
$TotalGlobalAdminsEnabledWithNoMFA = $GlobalAdminsEnabledWithNoMFA.count
$RelativeGlobalAdminsEnabledWithNoMFA = [math]::Round((($TotalGlobalAdminsEnabledWithNoMFA / $TotalGlobalAdmins) * 100 ),2)

Write-Host ""
Write-Host "In total there are" $TotalGlobalAdmins "Licensed Enabled and active Admin Users, with no Global Admin Rights"
Write-Host $TotalGlobalAdminsEnabledWithNoMFA "Users of them has no configured MFA. or"  (100 - $RelativeGlobalAdminsEnabledWithNoMFA) "%"

if($GlobalAdminsEnabledWithNoMFA){
    Write-Host
    Write-Host "Warning, there is a high Security risk, for your global admin accounts, wich are not configured with MFA!" -BackgroundColor RE
    Write-Host
    Write-Host "We Highly Reccomend you to activate MFA for following Global Admins first:"
    Write-Host $GlobalAdminsEnabledWithNoMFA.UserPrincipalname
    Write-Host
    Write-Host "After enabling MFA for Global Admins, you need to activate MFA for all Other Admin-Accounts"
    Write-Host $AdminsEnabledWithNoMFA.UserPrincipalname
    Write-Host
    Write-Host "Then Enable all Other User-Accounts, minimum wich are Licensed and Enabled!"
  

}

pause



}

function Save-File([string] $initialDirectory){

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "Excel| *.xlsx"
    $OpenFileDialog.ShowDialog() |  Out-Null

    return $OpenFileDialog.filename
}
cls
Write-Host "Welcome to the MFA Checker-Tool"
Write-Host "In Next Step, Please Select, if you want to get MFA Infos from selected or all users,"
Write-Host "Or Select one or more Groups from that members you want to get the MFA Infos. (The Script also looks in nested Groups)"
Pause
cls

while(-not (Get-MgContext)){ConnectTo-MgGraph}

#Getting Admin Users
$admins = Get-Admins


$Menu = @(
"Select All or specific User"
"Select All Users from Specific Groups"
) | Out-GridView -OutputMode Single -Title "What Users to Process?"

switch ($Menu){

    "Select All or specific User" {$MFAInfos = Get-Users}
    "Select All Users from Specific Groups" {
        $Users = Get-UsersInGroupsRecurse 
        if($Users){$MFAInfos = Get-Users -Users $Users}}
}

#Get-Summary $MFAInfos 

$MFAInfos = $MFAInfos | Out-GridView -PassThru -Title "Select Users to Save for Report in .xml File (STRG+A for ALL)"

#if($MFAInfos){$MFAInfos | Export-Clixml -Path (Save-File)}

if($MFAInfos){$MFAInfos | Export-Excel -Path (Save-File) -WorksheetName "MFA-Users"}

$Void = Disconnect-MgGraph
