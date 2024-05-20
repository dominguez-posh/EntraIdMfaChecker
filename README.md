# EntraIdMfaChecker
a little tool to fetch all configured MFA Methods and Admin-Users

Microsoft has no built in feature to show the MFA-Status of the users

##Requirements

- To do a Export with excel, you need to import the export-excel CMDlet with admin privileges.
  <Install-Module -Name ImportExcel>

- A Previleged User for Accessing the data. In my case I use a global admin.


##How to Use

Eesy start the script and logon with yout Entra-ID User.

In first menu, you are able to select, if you want to show all or selected users, or users from specific group.

The Groups are recursive. So for your rollout plans you can put groups in groups in groups. (Loop Detection is included)

When the Scrip is done, you can select the User Objects, after filtering in Grid-View for exporting to excel.
