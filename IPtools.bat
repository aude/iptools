@echo off

title IP-change

REM ----------- Information -----------
REM -----------------------------------

REM Core based on Saman Sadeghi's IP change batch file. http://samanathon.com/set-your-ip-address-via-batch-file/
REM Heavily modified by aude.
REM Developed 2011-2012

REM This script requires to be run elevated.

REM Usage: IP-change.bat[ --help][ --source=[static|dhcp]][ --wireless-toggle=[enable|disable]][ --ip=<IP>][ --subnet-mask=<IP>][ --standard-gateway=<IP>][ --dns=<IP>[,<IP>]]
REM Description: .bat "Set DHCP or static?" "Enable or disable wireless adapter?"

REM ------------ Copyright ------------
REM -----------------------------------
REM Copyright (C) 2011-toyear  aude
REM
REM This program is free software: you can redistribute it and/or modify
REM it under the terms of the GNU General Public License as published by
REM the Free Software Foundation, either version 3 of the License, or
REM (at your option) any later version.
REM
REM This program is distributed in the hope that it will be useful,
REM but WITHOUT ANY WARRANTY; without even the implied warranty of
REM MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
REM GNU General Public License for more details.
REM
REM You should have received a copy of the GNU General Public License
REM along with this program.  If not, see <http://www.gnu.org/licenses/>.

REM ------ Userdefined variables ------
REM -----------------------------------

REM set ip=192.168.1.19
set ip=
set subnetmask=255.255.255.0
REM set standardgateway=192.168.1.1
set standardgateway=
REM Use OpenDNS.
set dns1=208.67.222.222
set dns2=208.67.220.220

REM ------ File call parameters -------
REM -----------------------------------

REM Forced DHCP or static IP, determined by passed parameter. ("static" or "dhcp")
set forcedipsourceset=
REM Forced wireless adapter enable or disable, determined by passed parameter. ("true" for enable or "false" for disable)
set forcedwirelesstoggleway=

REM --------- Other variables ---------
REM -----------------------------------

REM Set "/m" switch for choice command for non-x86 systems
REM if not %processor_architecture%==x86 set choiceparam=/m
REM ver | find "Microsoft Windows [Version 5.1.2600]" &&set choiceparam=||set choiceparam=/m

REM Path to "elevate_<x86>|<AMD64>.exe".
set elevateexe="%~dp0Resources\elevate_%processor_architecture%.exe"

REM Hold path to appropriate devcon version (x86, AMD64 or IA64). Is located under \Resources.
set devconexe="%~dp0Resources\devcon_%processor_architecture%.exe"

REM Hold configuration to set to. ("static" or "dhcp")
set ipsourceset=

REM Hold if wireless adapter is enabled. ("y" or "n")
set wirelessadapterenabled=
REM Hold way to toggle the wireless adapter. ("enable" or "disable")
set wirelesstoggleway=

REM Hold name of ethernet interface name in netsh. ('netsh int show int')
set netshinterface=

REM If the ethernet adapter has DHCP enabled. ("y" or "n")
set dhcpethernetenabled=

REM Initiate variables.
set ipinput=

REM ------- Variable declaring --------
REM ------------ finished -------------



REM -------- Script execution ---------
REM ------------- begins --------------

echo ----------
echo -- INFO --
echo ----------
echo This batch file will set your IP, subnet mask, standard gateway, DNS servers,
echo and, if wanted, toggle your wireless network card.
echo.
echo Made by Aspi {2011-2012}
echo ----------
echo -- INFO --
echo ----------

echo.
echo.

REM Check for elevation.
echo Checking for elevation ^(administrative privileges^)...
REM Try initiate app that requires elevation. Will fail if not admin, will display available commands if admin (but do not display these).
REM ~https://stackoverflow.com/a/21295806
fsutil dirty query %systemdrive% >NUL
REM If app did not return successfully, batch must be elevated.
if %errorlevel% neq 0 (
	echo.
	goto noadmin
)

echo.
echo.

REM Parse command line switches.
REM First, parse a quoted string of the command line switches to exclude the equal sign as a delimiter. Thus, space will be the only delimiter.
for /f "tokens=1-7 delims= " %%a in ("%*") do (
	REM Pass the separated parameters to a new FOR loop, to loop through each one. Quote again to "escape" equal mark.
	for %%i in ("%%a" "%%b" "%%c" "%%d" "%%e" "%%f" "%%g") do (
		REM Split the string in two by the equal mark, making the FOR /F loop output the switch name as first variable, and it's property as second.
		for /f "tokens=1-2 delims==" %%l in (%%i) do (
			if "%%l" equ "--help" (
				REM Show information and exit.
				call :showusageinformation
				pause
				REM Evacuate.
				goto theend
			)
			if "%%l" equ "--source" (
				set forcedipsourceset=%%m
			)
			if "%%l" equ "--wireless-toggle" (
				set forcedwirelesstoggleway=%%m
				set wirelesstoggleway=%%m
			)
			if "%%l" equ "--ip" (
				set ip=%%m
			)
			if "%%l" equ "--subnet-mask" (
				set subnetmask=%%m
			)
			if "%%l" equ "--standard-gateway" (
				set standardgateway=%%m
			)
			if "%%l" equ "--dns" (
				REM Loop through passed DNS IPs, separated by commas. Only two DNS server IPs are allowed.
				for /f "tokens=1-2 delims=," %%o in ("%%m") do (
					set dns1=%%o
					set dns2=%%p
				)
			)
		)
	)
)

REM Get (localized) interface name (eg. "Lokal tilkobling") of netsh (Netw. Serv. shell))
for /f "tokens=3*" %%a in ('netsh int show int ^| find "Lo"') do (
	set netshinterface=%%b

	REM Quit the loop.
	goto netshinterfaceretrievalreturn
)
:netshinterfaceretrievalreturn

REM Change IP.
REM Determine if currently static or DHCP.
REM List "Ethernet adapters" and their line number.
for /f "tokens=1* delims=" %%a in ('ipconfig /all ^| find /n /i "%netshinterface%"') do (
	REM Check every line between the first and the second adapter if it contains a DHCP string.
	for /f "tokens=1* delims=[]" %%c in ("%%a") do (
		for /f "tokens=1* delims=" %%e in ('ipconfig /all ^| more +%%c ^| find /n "DHCP Enabled"') do (
			REM If the string contains "Yes", DHCP is enabled.
			for /f "tokens=1* delims=" %%g in ('echo %%e ^| find /i "Yes"') do (
				REM If the returned string from the "find" command equals the string tested, it does contain "Yes", and DHCP is enabled.
				REM The line contains a trailing space, thus correct the returning line from the first search.
				if "%%g" equ "%%e " (
					set dhcpethernetenabled=y
					REM Quit the loop.
					goto DHCPcheckreturn
				)
				if "%%g" equ "" (
				REM Else, it is disabled.
					set dhcpethernetenabled=n
					REM Quit the loop.
					goto DHCPcheckreturn
				)
			)
			REM If the string contains "No", DHCP is disabled. 
			for /f "tokens=1* delims=" %%g in ('echo %%e ^| find /i "No"') do (
				REM If the returned string from the "find" command equals the string tested, it does contain "No", and DHCP is enabled.
				REM The line contains a trailing space, thus correct the returning line from the first search.
				if "%%g" equ "%%e " (
					set dhcpethernetenabled=n
					REM Quit the loop.
					goto DHCPcheckreturn
				)
				if "%%g" equ "" (
				REM Else, it is disabled.
					set dhcpethernetenabled=y
					REM Quit the loop.
					goto DHCPcheckreturn
				)
			)
		)
	)
)
:DHCPcheckreturn
REM Expects "dhcpethernetenabled" variable to be set.
REM If not, prompt the user.
if defined dhcpethernetenabled (
	goto skipmodequery
)
REM If execution reaches current destination, user must be asked what operation is wanted.
choice /c sr /n /m "Do you want to [s]et custom IP or [r]eset to automatic IP?"
if %errorlevel% equ 2 set ipsourceset=dhcp
if %errorlevel% equ 1 set ipsourceset=static
echo.
:skipmodequery

REM Determine if wireless adapter is enabled or disabled.
call :determinewirelessadapterstate

REM If forced configuration is preset, set way to toggle configuration.
if "%forcedipsourceset%" equ "static" (
	set ipsourceset=static
)
if "%forcedipsourceset%" equ "dhcp" (
	set ipsourceset=dhcp
)

REM If source to configure IP address is not preset, toggle. Thus, check which way to toggle.
if not defined ipsourceset (
	REM If the current config is DHCP, set to static.
	if "%dhcpethernetenabled%" equ "y" (
		set ipsourceset=static
	) else (
		REM If static, set to DHCP.
		if "%dhcpethernetenabled%" equ "n" (
			set ipsourceset=dhcp
		)
	)
)

REM Set them addresses.
REM Skip if chosen to only set wireless adapters.
if "%forcedwirelesstoggleway%" neq "" (
	if "%forcedipsourceset%" equ "" (
		goto skipipsourceset
	)
)
REM If set to static...
if "%ipsourceset%" equ "static" (
	REM ...update the address in any condition.
	call :setstatic
) else (
	REM If set to DHCP...
	if "%ipsourceset%" equ "dhcp" (
		REM ...and DHCP is not already enabled...
		if "%dhcpethernetenabled%" neq "y" (
			REM ...set to DHCP.
			call :setdhcp
		)
	REM If not set to static or DHCP, undefined error has occurred.
	) else (
		goto undefinederror
	)
)
:skipipsourceset

REM Toggle them wireless adapters.
REM Will not be toggled if not set to.
if defined wirelesstoggleway (
	call :togglewirelessadapter
	echo.
)

REM Display configuration if no command line switches are present.
if "%*" equ "" (
	goto endmsg
REM Else, get'ya arse outta here.
) else (
	goto theend
)



REM ----------- Subroutines -----------
REM -----------------------------------

:echoheadline
echo -------- %~1 --------
echo.

goto :eof

:noadmin
echo -----------
echo -- ERROR --
echo -----------
echo You are not running this with an elevated command prompt.
echo Will now initiate an elevated instance of this batch file.
echo -----------
echo -- ERROR --
echo -----------
echo.

REM If "elevate.exe" is not found...
if not exist %elevateexe% (
	REM ...inform and ask user to run the batch file with administrative privileges manually.
	echo Did not find %elevateexe%.
	echo Please check whether the path is valid, and correct the "elevateexe" variable in the top of this batch file if necessary.
	echo.
	echo Alternatively, you can run this batch file as adminisrator manually by:
	echo Right click the batch file -> "Run as administrator"
	echo.
	pause
	echo.
) else (
	REM Inform.
	echo Elevating %0 with %elevateexe%...
	REM Initiate an elevated process of this batch, with appended current command line switches.
	%elevateexe% %0 %*
)

goto theend

:truncatetrailingspaces
REM Expect passed strings: [name of variable] [contents of variable].
REM Quit if either is missing.
if "%%1" equ "" (
	goto :eof
)
if "%%2" equ "" (
	goto :eof
)

REM Source: http://www.dostips.com/DtTipsStringManipulation.php#Snippets.TrimRightSubst
set str=%%2
set str=%str%##
set str=%str:                ##=##%
set str=%str:        ##=##%
set str=%str:    ##=##%
set str=%str:  ##=##%
set str=%str: ##=##%
set str=%str:##=%
set %%1=%str%

goto :eof

:showusageinformation
REM Usage information syntax based on rsync.
echo Usage: IP-tools.bat [OPTION]...
echo.
echo Options
echo  --help                             show this help
echo  --source=[static^|dhcp]             set to static or DHCP
echo  --wireless-toggle=[enable^|disable] sorce enable or disable wireless adapter
echo  --ip=^<IP^>                          static IP address to set
echo  --subnet-mask=^<IP^>                 static subnet mask to set
echo                                       defaults to 255.255.255.0 if not set
echo  --standard-gateway=^<IP^>            static standard gateway to set
echo                                       defaults to x.y.z.1, where x, y and z are
echo                                       retreived from the --ip switch
echo  --dns=^<IP^>[,^<IP^>]                  static DNS address to set. 2nd is optional
echo.

goto :eof

:determinewirelessadapterstate
REM Determine if wireless adapter is enabled or disabled.
for /f "tokens=1*" %%a in ('netsh int show int ^| find /i "Wireless"') do (
	if "%%a" equ "Enabled" (
		set wirelessadapterenabled=y
	)
	if "%%a" equ "Disabled" (
		set wirelessadapterenabled=n
	)
)

goto :eof

:togglewirelessadapter
REM Update "wirelessadapterenabled".
call :determinewirelessadapterstate

REM Expect "wirelessadapterenabled" variable to be set.
REM Check if way to toggle wireless adapter is pre-configured.
REM If pre-configured, enable or disable only if the adapter is in the opposite state.
if "%wirelesstoggleway%" equ "enable" (
	if "%wirelessadapterenabled%" equ "y" (
		REM Run to the hills!
		goto :eof
	)
)
if "%wirelesstoggleway%" equ "disable" (
	if "%wirelessadapterenabled%" equ "n" (
		REM Escape towards the mountains!
		goto :eof
	)
)

REM If not pre-configured, determine way to toggle by the state of the wireless adapter.
if "%wirelessadapterenabled%" equ "y" (
	set wirelesstoggleway=disable
) else (
	if "%wirelessadapterenabled%" equ "n" (
		set wirelesstoggleway=enable
	) else (
		echo Could not determine whether to enable or disable the Wireless Network Adapter.
		echo Thus, you will have to do this manually.
		ncpa.cpl
		goto :eof
	)
)

REM Check for devcon existance.
if not exist %devconexe% (
	echo Did not find "devcon.exe".
	echo Thus, skip %wirelesstoggleway:~0,-1%ing wireless adapter.
	goto :eof
)

REM Search for lines containing relevant keywords: "Wireless", "WLAN", "WiFi".
REM First, loop through each PCI device.
for /f "tokens=* delims=" %%a in ('%devconexe% findall PCI\*') do (
	REM Then check each device for keyword match.
	for %%c in (Wireless,WLAN,WiFi) do (
		REM Extract the DEV_ID of each matched PCI Wireless Adapter.
		for /f "tokens=2* delims=&" %%e in ('echo "%%a" ^| find "%%c"') do (
			REM Inform.
			for /f "tokens=2* delims=:" %%g in ("%%a") do (
				if "%wirelesstoggleway%" equ "enable" (
					echo Enabling "%%g"...
				)
				if "%wirelesstoggleway%" equ "disable" (
					echo Disabling "%%g"...
				)
			)
			REM And <en>|<dis>able it!
			%devconexe% %wirelesstoggleway% *%%e*
			echo.
		)
	)
)

goto :eof

:setstatic
echo Will now set static IP:
REM Skip query if forced way to configure is preset.
if "%forcedipsourceset%" equ "static" (
	goto skipstaticsetconfirmation
)
choice /c yn /n /m "Are you sure you want to continue [Y,N]?"
if %errorlevel% equ 2 (
	echo.
	echo.
	goto :eof
)
:skipstaticsetconfirmation

echo.

REM Set IP address if not preset.
if not defined ip (
	echo Input what your IP should be set to ^(192.168.x.x^):
	set /p ipinput=192.168.
)
REM This will only run if "ipinput" variable is set, which only occurs if the IP address is not preset.
if defined ipinput (
	set ip=192.168.%ipinput%
	echo.
)

REM Generate standard gateway (192.168.'the one used in desired IP'.1) if not preset.
if not defined standardgateway (
	for /f "tokens=1-4 delims=." %%a in ("%ip%") do (
		set standardgateway=192.168.%%c.1
	)
)
echo Setting IP address ^(to "%ip%"^), subnet mask ^(to "%subnetmask%"^) and standard gateway ^(to "%standardgateway%"^)...
netsh int ip set address name="%netshinterface%" source=static addr=%ip% mask=%subnetmask% gateway=%standardgateway% gwmetric=1
if %errorlevel% neq 0 goto incorrectstaticip

echo Setting primary DNS ^(to "%dns1%"^)...
REM netsh int ip set dns name="%netshinterface%" source=static addr=%dns1% validate=no & REM Previous version, did not successfully update the changed interface ip source to "static".
netsh int ip add dns name="%netshinterface%" addr=%dns1% validate=no index=1

REM Set secondary DNS if present.
if defined dns2 (
	echo Setting secondary DNS ^(to "%dns2%"^)...
	netsh int ip add dns name="%netshinterface%" addr=%dns2% validate=no index=2
)

echo.

REM Skip prompt for disabling the wireless adapter if the way to configure is preset (only valid values passes).
for %%a in (enable disable) do (
	if "%%a" equ "%wirelesstoggleway%" (
		goto skipstaticsubwirelessadapterdisablequery
	)
)
REM Else, prompt for disabling Wireless Network (PCI(e)) card if it is not currently disabled.
REM Reset errorlevel.
ver > nul
if "%wirelessadapterenabled%" neq "n" (
	choice /c yn /n /m "Disable Wireless Network card [Y,N]?"
	echo.
) else (
	REM If it is currently disabled, store this information.
	if "%wirelessadapterenabled%" equ "n" (
		set wirelesstoggleway=disable
	)
)
REM Store answer of query.
if %errorlevel% equ 1 (
	set wirelesstoggleway=disable
)
if %errorlevel% equ 2 (
	set wirelesstoggleway=enable
)
:skipstaticsubwirelessadapterdisablequery

goto :eof

:incorrectstaticip
echo -----------
echo -- ERROR --
echo -----------
echo You most likely entered an incorrect IP address.
echo To fix this, restart this file ^(as Administrator^) and input a correct IP.
echo.
echo Currently used IP addresses:
echo IP:               %ip%
echo Subnet mask:      %subnetmask%
echo Standard gateway: %standardgateway%
echo -----------
echo -- ERROR --
echo -----------
echo.
pause
echo.
goto setstatic

:setdhcp
echo Will now reset IP to DHCP ^(automatic IP^):
REM Skip query if forced way to configure is preset.
if "%forcedipsourceset%" equ "dhcp" (
	goto skipdhcpsetconfirmation
)
choice /c yn /n /m "Are you sure you want to continue [Y,N]?"
if %errorlevel% equ 2 (
	echo.
	echo.
	goto :eof
)
echo.
:skipdhcpsetconfirmation

echo Resetting IP Address and Subnet Mask to DHCP...
netsh int ip set address name="%netshinterface%" source=dhcp
REM If an error occurs, it it most likely because DHCP is already enabled. Thus, skip setting the rest of the DNS info.
if %errorlevel% neq 0 call :setdhcperror && goto :eof

echo Resetting DNS to DHCP...
netsh int ip set dns name="%netshinterface%" source=dhcp

echo Resetting Windows Internet Name Service ^(WINS^) to DHCP...
netsh int ip set wins name="%netshinterface%" source=dhcp

echo.

REM Skip prompt for enabling the wireless adapter if the way to configure is preset (only valid values passes).
for %%a in (enable disable) do (
	if "%%a" equ "%wirelesstoggleway%" (
		goto skiphdcpsubwirelessadapterdisablequery
	)
)
REM Else, prompt for enabling Wireless Network (PCI(e)) card if it is not currently disabled.
REM Reset errorlevel.
ver > nul
if "%wirelessadapterenabled%" neq "y" (
		choice /c yn /n /m "Enable Wireless Network card [Y,N]?"
		echo.
	)
) else (
	REM If it is currently enabled, store this information.
	if "%wirelessadapterenabled%" equ "y" (
		set wirelesstoggleway=enable
	)
)
REM Store answer of query.
if %errorlevel% equ 1 (
	set wirelesstoggleway=enable
)
if %errorlevel% equ 2 (
	set wirelesstoggleway=disable
)
:skiphdcpsubwirelessadapterdisablequery

goto :eof

:undefinederror
echo -----------
echo -- ERROR --
echo -----------
echo An undefined error occurred. ^(Errorlevel: %errorlevel%^)
echo -----------
echo -- ERROR --
echo -----------
echo.
pause
echo.

goto :eof

:setdhcperror
echo -----------
echo -- ERROR --
echo -----------
echo You most likely already have DNS enabled.
echo There is nothing to fix, as this why you ran this script.
echo -----------
echo -- ERROR --
echo -----------
echo.
pause
echo.

goto :eof

:endmsg
echo Here is the current network configuration for %computername%:
netsh int ip show config

pause

goto theend

:theend
