# EntraIdMfaChecker
a little tool to fetch all configured MFA Methods and Admin-Users

Microsoft has no built in feature to show the MFA-Status of the users

## Requirements

- To do a Export with excel, you need to import the export-excel CMDlet with admin privileges.
  <Install-Module -Name ImportExcel>

- A Previleged User for Accessing the data. In my case I use a global admin.


## How to Use

Eesy start the script and logon with yout Entra-ID User.

First, the script is checking all Admin-Roles in Tenant.
In first menu, you are able to select, if you want to show all or selected users, or users from specific group.
![image](https://github.com/dominguez-posh/EntraIdMfaChecker/assets/9081611/e1a37758-a6c2-4aa1-ad8d-0622686ae249)

If you select all, or specific user, in next menu you can select users by using the gridview, or press STRG-A for using all Users.
![image](https://github.com/dominguez-posh/EntraIdMfaChecker/assets/9081611/0fa5a43c-ef57-4d35-b5ce-a60319d70e60)


The Groups are recursive. So for your rollout plans you can put groups in groups in groups. (Loop Detection is included)

When the Scrip is done, you can select the User Objects, after filtering in Grid-View for exporting to excel.
![image](https://github.com/dominguez-posh/EntraIdMfaChecker/assets/9081611/7c653df0-c4b4-4d45-bf3e-6ef984c59c65)

Here you find all configured Methods.


## After Words
Importand: You only see the configured Methods and not, if MFA is enabled, or a conditional Access Rule is set.

For me, the script is a perfect tool for checking, if all users has set up their 2nd factor befor enabling Conditional Access.

Also you see imidiatly, if you have admin-users with no configured 2nd factor

