1. Create a config.txt file (or any other text file) and add your configuration to it.
2. Run the following command in PowerShell: .\Install.ps1 config.txt

2.1 If the following error appears while the archive is being downloaded:

`Invoke-WebRequest: C:\Users\edsuy\Desktop\autoinstall-v2rayN\Install.ps1:90
Line |
  90 |  Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsin …
     |  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Unable to read data from the transport connection: An existing connection was forcibly closed by the remote host.'

Run the command again until the download starts successfully.

3. Once the installation is complete, a shortcut to 'v2rayN' will be created on desktop.