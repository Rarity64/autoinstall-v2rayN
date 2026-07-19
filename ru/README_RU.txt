-1. Перед запуском скрипта выполни эту команду, чтобы разрешить исполнять скрипты без подписи и для данного пользователя:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

0. ОПЦИОНАЛЬНО: Создай файл config.txt (или с другим названием) и добавь свои конфигурации.
1. Выполни эту команду в PowerShell:
.\Install.ps1 -ConfigFile config.txt

1.1 Чтобы запустить скрипт без конфига, используй:
 .\Install.ps1

1.2 Если данная ошибка появляется, пока архив скачивается:

`Invoke-WebRequest: C:\Users\edsuy\Desktop\autoinstall-v2rayN\Install.ps1:90
Line |
  90 |  Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsin …
     |  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Unable to read data from the transport connection: An existing connection was forcibly closed by the remote host.'

Выполни команду запуска скрипта ещё раз, пока не получится:

2. Когда установка выполнится, v2rayN запустится автоматически.
Примечание: ярлык v2rayN появится на рабочем столе.

3. Иногда конфиги из буфера обмена не вставляются в таблицу проксей автоматически.
В этом случае вручную добавьте их посредством Ctrl+V (или Configuration -> Import Share Links from clipboard).
