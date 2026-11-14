-1. Before running the script, run the following command to change the PowerShell execution policy:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

0. OPTIONAL: Create a config.txt file (or any other text file) and add your configuration.
1. Run the following command in PowerShell: 
.\Install.ps1 -ConfigFile config.txt

1.1 To run the script without a config, use:
 .\Install.ps1

1.2 If the following error appears while the archive is being downloaded:

`Invoke-WebRequest: C:\Users\edsuy\Desktop\autoinstall-v2rayN\Install.ps1:92
Line |
  92 |  Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsin …
     |  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Unable to read data from the transport connection: An existing connection was forcibly closed by the remote host.'

1.2.1 Run the command again until the download starts successfully.

1.3 If the script stops with "SHA-256 mismatch", the downloaded archive was corrupted
or altered. It is deleted automatically — just run the script again.

1.4 To update v2rayN, close it (tray icon -> Exit) and run the script again.
Your settings and servers are kept; a backup of the guiConfigs folder is saved
to v2rayN-backups\<date-time> next to the script.

2. Once the installation is complete, v2rayN will launch automatically. 
Note: A shortcut to v2rayN will also be created on the desktop.

3. Sometimes configs from clipboard isn't pasted into the table automatically.
In this case manually paste press Ctrl+V (or Configuration -> Import Share Links from clipboard).
