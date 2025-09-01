-- By: Pico Mitchell
-- For: MacLand @ Free Geek
--
-- MIT License
--
-- Copyright (c) 2023 Free Geek
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--

-- Version: 2025.8.20-1

-- Build Flag: LSUIElement
-- Build Flag: CFBundleAlternateNames: ["FG Reset", "fgreset", "Reset"]
-- NOTE: These alternate names are set so that searching for these names in Spotlight match this app.

use AppleScript version "2.7"
use scripting additions
use framework "AppKit"

repeat -- dialogs timeout when screen is asleep or locked (just in case)
	set isAwake to true
	try
		set isAwake to ((run script "ObjC.import('CoreGraphics'); $.CGDisplayIsActive($.CGMainDisplayID())" in "JavaScript") is equal to 1)
	end try
	
	set isUnlocked to true
	try
		set isUnlocked to ((do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :IOConsoleUsers:0:CGSSessionScreenIsLocked' /dev/stdin <<< \"$(ioreg -ac IORegistryEntry -k IOConsoleUsers -d 1)\""))) is not equal to "true")
	end try
	
	if (isAwake and isUnlocked) then
		exit repeat
	else
		delay 1
	end if
end repeat

set currentBundleIdentifier to "UNKNOWN"

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set intendedAppName to "Free Geek Reset" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
	try
		do shell script ("/usr/libexec/PlistBuddy -c 'Print :FGBuiltByMacLandScriptBuilder' " & (quoted form of infoPlistPath))
		((((POSIX path of (path to me)) & "Contents/MacOS/" & intendedAppName) as POSIX file) as alias)
	on error
		try
			activate
		end try
		display alert "
“" & (name of me) & "” must be built by the “MacLand Script Builder” script." buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end try
	
	set AppleScript's text item delimiters to "-"
	set intendedBundleIdentifier to ("org.freegeek." & ((words of intendedAppName) as text))
	set currentBundleIdentifier to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & (quoted form of infoPlistPath))) as text)
	if (currentBundleIdentifier is not equal to intendedBundleIdentifier) then error "“" & (name of me) & "” does not have the correct Bundle Identifier.


Current Bundle Identifier:
	" & currentBundleIdentifier & "

Intended Bundle Identifier:
	" & intendedBundleIdentifier
on error checkInfoPlistError
	if (checkInfoPlistError does not start with "Can’t make file") then
		try
			activate
		end try
		display alert checkInfoPlistError buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end if
end try

try
	set mainScptPath to ((POSIX path of (path to me)) & "Contents/Resources/Scripts/main.scpt")
	((mainScptPath as POSIX file) as alias)
	do shell script "osadecompile " & (quoted form of mainScptPath)
	error "
“" & (name of me) & "” must be exported as a Run-Only Script."
on error checkReadOnlyErrorMessage
	if ((checkReadOnlyErrorMessage does not contain "errOSASourceNotAvailable") and (checkReadOnlyErrorMessage does not start with "Can’t make file")) then
		try
			activate
		end try
		display alert checkReadOnlyErrorMessage buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end if
end try


global adminUsername, adminPassword, lastDoShellScriptAsAdminAuthDate, hasT2chip, isAppleSilicon -- Needs to be accessible in functions.
set lastDoShellScriptAsAdminAuthDate to 0

set adminUsername to "fg-admin"
set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"

set demoUsername to "fg-demo"
set demoPassword to "freegeek"

set hasT2chip to false
try
	set hasT2chip to ((do shell script "ioreg -rc AppleUSBDevice -n 'Apple T2 Controller' -d 1") contains "Apple T2 Controller")
end try

set isAppleSilicon to false
try
	set isAppleSilicon to ((do shell script "sysctl -in hw.optional.arm64") is equal to "1")
end try


if (((short user name of (system info)) is equal to demoUsername) and ((POSIX path of (path to me)) is equal to ("/Users/" & demoUsername & "/Applications/" & (name of me) & ".app/"))) then
	set freeGeekUpdaterAppPath to ("/Users/" & demoUsername & "/Applications/Free Geek Updater.app")
	try
		((freeGeekUpdaterAppPath as POSIX file) as alias)
		
		if (application freeGeekUpdaterAppPath is running) then -- Quit if Updater is running so that this app can be updated if needed.
			quit
			delay 10
		end if
	end try
	
	try
		set fgSetupName to "Free Geek Setup"
		
		((("/Users/" & demoUsername & "/Applications/" & fgSetupName & ".app") as POSIX file) as alias)
		try
			activate
		end try
		display alert "“" & fgSetupName & "” Hasn't Finished Running" message "Please wait for “" & fgSetupName & "” to finish and then try running “" & (name of me) & "” again." buttons {"Quit"} default button 1 as critical giving up after 15
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
			do shell script "open -na " & (quoted form of ("/Users/" & demoUsername & "/Applications/" & fgSetupName & ".app"))
		end try
		quit
		delay 10
	end try
	
	try
		set cleanupAppName to "Cleanup After QA Complete"
		
		((("/Users/" & demoUsername & "/Applications/" & cleanupAppName & ".app") as POSIX file) as alias)
		try
			activate
		end try
		display alert "“" & cleanupAppName & "” Hasn't Been Run Yet" message "“" & cleanupAppName & "” must be run before this Mac can be reset." buttons {"Launch “" & cleanupAppName & "”"} default button 1 as critical giving up after 15
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
			do shell script "open -na " & (quoted form of ("/Users/" & demoUsername & "/Applications/" & cleanupAppName & ".app"))
		end try
		quit
		delay 10
	end try
	
	set designedForSnapshotReset to false
	try
		(("/Users/Shared/.fgResetSnapshotCreated" as POSIX file) as alias)
		set designedForSnapshotReset to true
	on error
		try
			(("/Users/Shared/.fgResetSnapshotLost" as POSIX file) as alias)
			set designedForSnapshotReset to true
			
			((("/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app") as POSIX file) as alias)
			
			try
				-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
				do shell script ("open -na '/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app'")
			end try
			
			quit
			delay 10
		end try
	end try
	
	if (designedForSnapshotReset) then -- If Snapshot Reset (pre-T2 Mac), just prompt with instructions and reboot into Recovery.
		try
			activate
		end try
		
		set rebootIntoRecoveryNote to "(will happen automatically after clicking the confirmation button below)"
		set snapshotResetDialogButtons to {"No, Don't Reboot Into Recovery", "Yes, Reboot Into Recovery"}
		if (isAppleSilicon) then -- CANNOT auto-reboot into Recovery using NVRAM variables on Apple Silicon (but Apple Silicon Macs should always be doing the newer "Erase Assistant" (EAC&S) reset, but keep this here while transitioning to newer processes).
			set rebootIntoRecoveryNote to "by holding the Power button when booting until “Loading startup options…” is shown and then choose “Options”"
			set snapshotResetDialogButtons to {"No, Don't Shut Down Yet", "Yes, Shut Down Now"}
		end if
		
		display dialog "Are you sure want to Snapshot Reset this Mac?


USE THE FOLLOWING STEPS TO SNAPSHOT RESET THIS MAC:

• Reboot into Recovery " & rebootIntoRecoveryNote & ".

• Choose “English” if prompted for Language in Recovery.

• Select “Restore from Time Machine”.

• Select “Macintosh HD” as “Restore Source” (there should only be one option).

• Select the Local Snapshot with time close to midnight (there should only be one option).

• Confirm restoring Snapshot." buttons snapshotResetDialogButtons cancel button 1 default button 2 with title (name of me) with icon note
		
		checkRemoteManagement()
		
		quitAllApps() -- "Free Geek Setup" will have granted AppleEvents/Automation TCC permissions for "System Events" to be able to quit all apps, but don't bother verifying the permissions since it's not a big deal if this fails.
		
		clearNVRAMandCheckStartupSecurityAndClearSIP()
		
		if (isAppleSilicon) then -- CANNOT auto-reboot into Recovery using NVRAM variables on Apple Silicon (but Apple Silicon Macs should always be doing the newer "Erase Assistant" (EAC&S) reset, but keep this here while transitioning to newer processes).
			tell application id "com.apple.systemevents" to shut down with state saving preference
		else
			try
				-- https://mrmacintosh.com/boot-to-internet-recovery-recovery-partition-or-diagnostics-from-macos/
				-- https://twocanoes.com/booting-to-macos-recovery-and-diagnostics-mode/
				-- NOTE: "internet-recovery-mode=RecoveryModeDisk" works on all pre-Apple Silicon Macs (and only boots to Recovery once), but "recovery-boot-mode=unused" only works when SIP is disabled.
				doShellScriptAsAdmin("nvram internet-recovery-mode=RecoveryModeDisk")
			end try
			
			tell application id "com.apple.systemevents" to restart with state saving preference
		end if
		
		quit
		delay 10
	end if
	
	set systemVersion to (system version of (system info))
	considering numeric strings
		set isMontereyOrNewer to (systemVersion ≥ "12.0")
		set isVenturaOrNewer to (systemVersion ≥ "13.0")
		set isTahoeOrNewer to (systemVersion ≥ "16.0")
	end considering
	
	if (not isMontereyOrNewer) then
		errorAndQuit("Only macOS 12 Monterey or newer is supported.")
	end if
	
	if ((not hasT2chip) and (not isAppleSilicon)) then
		errorAndQuit("Only T2 or Apple Silicon Macs are supported.")
	end if
	
	try
		set globalTCCdbPath to "/Library/Application Support/com.apple.TCC/TCC.db" -- For more info about the TCC.db structure, see "fg-install-os" script and https://www.rainforestqa.com/blog/macos-tcc-db-deep-dive
		set whereAllowedOrAuthValue to "auth_value = 2"
		set globalTCCallowedAppsAndServices to (paragraphs of (do shell script ("sqlite3 " & (quoted form of globalTCCdbPath) & " 'SELECT client,service FROM access WHERE (" & whereAllowedOrAuthValue & ")'"))) -- This SELECT command on the global TCC.db will error if "Free Geek Reset" doesn't have Full Disk Access.
		
		if (globalTCCallowedAppsAndServices does not contain (currentBundleIdentifier & "|kTCCServiceAccessibility")) then error ("“" & (name of me) & "” DOES NOT HAVE REQUIRED Accessibility Access")
		if (globalTCCallowedAppsAndServices does not contain (currentBundleIdentifier & "|kTCCServiceSystemPolicyAllFiles")) then error ("“" & (name of me) & "” DOES NOT HAVE REQUIRED Full Disk Access") -- This should not be possible to hit since reading the global TCC.db would have errored if this app didn't have FDA, but check anyways.
		
		set userTCCdbPath to ((POSIX path of (path to library folder from user domain)) & "Application Support/com.apple.TCC/TCC.db")
		set userTCCallowedAppsAndServices to (paragraphs of (do shell script ("sqlite3 " & (quoted form of userTCCdbPath) & " 'SELECT client,service,indirect_object_identifier FROM access WHERE (" & whereAllowedOrAuthValue & ")'"))) -- This SELECT command on the user TCC.db will error if "Free Geek Reset" doesn't have Full Disk Access (but that should never happen because we couldn't get this far without FDA).
		
		if (userTCCallowedAppsAndServices does not contain (currentBundleIdentifier & "|kTCCServiceAppleEvents|com.apple.systemevents")) then error ("“" & (name of me) & "” DOES NOT HAVE REQUIRED AppleEvents/Automation Access for “System Events”")
	on error tccErrorMessage
		if (tccErrorMessage starts with "Error: unable to open database") then set tccErrorMessage to ("“" & (name of me) & "” DOES NOT HAVE REQUIRED Full Disk Access (" & tccErrorMessage & ")")
		
		try
			try
				activate
			end try
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
			end try
			display alert ("CRITICAL “" & (name of me) & "” TCC ERROR:

" & tccErrorMessage) message "This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research if checking again does not work." buttons {"Shut Down", "Check Again"} cancel button 1 default button 2 as critical giving up after 10
			try
				do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
			end try
		on error
			tell application id "com.apple.systemevents" to shut down with state saving preference
		end try
		quit
		delay 10
	end try
	
	set eraseAssistantAppPath to "/System/Library/CoreServices/Erase Assistant.app"
	try
		((eraseAssistantAppPath as POSIX file) as alias)
	on error
		errorAndQuit("“Erase Assistant” app was not found at “" & eraseAssistantAppPath & "”.")
	end try
	
	try
		activate
	end try
	
	set demoUsernameIsChanged to false
	try
		set demoUsernameIsChanged to ((do shell script ("id -F " & (quoted form of demoUsername))) is equal to "Free Geek Reset User")
	end try
	
	if (not demoUsernameIsChanged) then -- Do not confirm if demo username was already changed which means that "Free Geek Reset" was already started but interrupted somehow.
		try
			activate
		end try
		display dialog "Are you sure want to reset this Mac?


This Mac will reset itself automatically after clicking the confirmation button below.

During the reset process this Mac will reboot into Recovery for Activation, which requires internet. So, it is best to connect an Ethernet cable now for a fully automated process, but you will also be able to manually connect to Wi-Fi in Recovery if needed.

NOTE: You may need to select a language when rebooted into Recovery before Activation can start." buttons {"No, Don't Reset This Mac Yet", "Yes, Reset This Mac"} cancel button 1 default button 2 with title (name of me) with icon note
	end if
	
	set progress total steps to -1
	set progress description to "
🚧	Preparing to Reset This Mac…"
	
	try
		repeat with thisWindow in (current application's NSApp's |windows|())
			if (thisWindow's isVisible() is true) then
				if (((thisWindow's title()) as text) is equal to (name of me)) then
					repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
						if ((((thisProgressWindowSubView's className()) as text) is equal to "NSButton") and ((thisProgressWindowSubView's title() as text) is equal to "Stop")) then
							(thisProgressWindowSubView's setEnabled:false)
							exit repeat
						end if
					end repeat
				end if
			end if
		end repeat
	end try
	
	checkRemoteManagement()
	
	set progress total steps to -1
	set progress description to "🚧	Resetting This Mac…"
	set progress additional description to "
🚫	DO NOT TOUCH THIS MAC WHILE IT IS BEING RESET"
	
	quitAllApps()
	
	clearNVRAMandCheckStartupSecurityAndClearSIP()
	
	try -- Set progress window to topmost AFTER checking Remote Management and SIP so that the progress window doesn't block any possible alert.
		repeat with thisWindow in (current application's NSApp's |windows|())
			if (thisWindow's isVisible() is true) then
				if (((thisWindow's title()) as text) is equal to (name of me)) then
					repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
						if (((thisProgressWindowSubView's className()) as text) is equal to "NSProgressIndicator") then
							-- Set Style Mask to ONLY be Titled, which make it not minimizable or resizable and hides all the titlebar buttons.
							(thisWindow's setStyleMask:(current application's NSWindowStyleMaskTitled as integer)) -- MUST be "as integer" instead of "as number" for ObjC-bridge casting to not throw an exception.
							(thisWindow's setLevel:2.147483647E+9) -- The highest defined window level is "kCGMaximumWindowLevelKey" which is equal to "2147483631" (https://michelf.ca/blog/2016/choosing-window-level/). We are setting an even higher level of "2147483647" which is the signed 32-bit interger max which seems to be the highest possible level since any higher and the value appears to roll over and no longer be topmost.
							exit repeat
						end if
					end repeat
				end if
			end if
		end repeat
	end try
	
	set demoUsernameIsAdmin to false
	try
		set demoUsernameIsAdmin to ((do shell script ("dsmemberutil checkmembership -U " & (quoted form of demoUsername) & " -G 'admin'")) is equal to "user is a member of the group")
	end try
	if (not demoUsernameIsAdmin) then -- NOTE: Erase Assistant can only be run by an Administrator that has a Secure Token.
		try
			doShellScriptAsAdmin("dseditgroup -o edit -a " & (quoted form of demoUsername) & " -t user admin")
			set demoUsernameIsAdmin to ((do shell script ("dsmemberutil checkmembership -U " & (quoted form of demoUsername) & " -G 'admin'")) is equal to "user is a member of the group")
		end try
	end if
	
	if (demoUsernameIsAdmin) then
		set demoUserHasSecureToken to false
		try
			set demoUserHasSecureToken to ((do shell script ("sysadminctl -secureTokenStatus " & (quoted form of demoUsername) & " 2>&1")) contains "is ENABLED for")
		end try
		if (not demoUserHasSecureToken) then -- Secure Token should already be granted when user was created, but double check and grant the first to itself which will only work if there are currently NO Secure Token users and the user is an admin.
			try
				set grantDemoUserFirstSecureTokenOutput to (do shell script ("sysadminctl -secureTokenOn " & (quoted form of demoUsername) & " -password " & (quoted form of demoPassword) & " -adminUser " & (quoted form of demoUsername) & " -adminPassword " & (quoted form of demoPassword) & " 2>&1"))
				set demoUserHasSecureToken to ((grantDemoUserFirstSecureTokenOutput contains "] - Done!") and ((do shell script ("sysadminctl -secureTokenStatus " & (quoted form of demoUsername) & " 2>&1")) contains "is ENABLED for"))
			end try
		end if
		
		if (demoUserHasSecureToken) then
			if (not demoUsernameIsChanged) then
				try
					doShellScriptAsAdmin("dscl . -create " & (quoted form of ("/Users/" & demoUsername)) & " RealName 'Free Geek Reset User'")
					set demoUsernameIsChanged to ((do shell script ("id -F " & (quoted form of demoUsername))) is equal to "Free Geek Reset User")
				end try
			end if
			
			if (not demoUsernameIsChanged) then
				errorAndQuit("Failed to change “" & demoUsername & "” user name to “Free Geek Reset User”.")
			end if
		else
			errorAndQuit("Failed to grant Secure Token to “" & demoUsername & "” user.")
		end if
	else
		errorAndQuit("Failed to make “" & demoUsername & "” user an administrator.")
	end if
	
	try
		doShellScriptAsAdmin("pmset repeat cancel") -- Cancel power schedule so that scheduled shut down doesn't interrupt reset (even though that timing would be increadibly rare).
	end try
	
	try
		activate
	end try
	
	-- DISABLE CAPS LOCK IF ENABLED: https://forum.latenightsw.com/t/toggle-capslock/4319/11
	-- So that passwords are not typed in caps
	try
		run script "ObjC.import(\"IOKit\");
ObjC.import(\"CoreServices\");

(() => {
    var ioConnect = Ref();
    var keystate = Ref();

    $.IOServiceOpen(
        $.IOServiceGetMatchingService(
            $.kIOMasterPortDefault,
            $.IOServiceMatching(
                $.kIOHIDSystemClass
            )
        ),
        $.mach_task_self_,
        $.kIOHIDParamConnectType,
        ioConnect
    );
    $.IOHIDSetModifierLockState(ioConnect, $.kIOHIDCapsLockState, 0);
    $.IOServiceClose(ioConnect);
	
})();" in "JavaScript"
	end try
	
	set eraseAssistantAppID to (id of application eraseAssistantAppPath)
	
	set didAttemptToAuthenticateEraseAssistant to false
	repeat 10 times -- Wait up to 10 seconds for Erase Assistant to launch and present the admin auth prompt.
		do shell script ("open -a " & (quoted form of eraseAssistantAppPath))
		delay 1
		try
			if (application eraseAssistantAppPath is running) then
				tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is eraseAssistantAppID)
					if (isVenturaOrNewer) then
						if ((number of windows) is 1) and ((number of sheets of window 1) is 1) then
							repeat with thisEraseAssistantButton in (buttons of sheet 1 of window 1)
								if ((title of thisEraseAssistantButton) is equal to "Unlock") then
									set value of (text field 2 of sheet 1 of window 1) to demoPassword
									click thisEraseAssistantButton
									set didAttemptToAuthenticateEraseAssistant to true
									exit repeat
								end if
							end repeat
							exit repeat
						end if
					else
						if ((number of windows) is 1) then
							repeat with thisEraseAssistantButton in (buttons of window 1)
								if ((title of thisEraseAssistantButton) is equal to "OK") then
									set value of (text field 1 of window 1) to demoPassword
									click thisEraseAssistantButton
									set didAttemptToAuthenticateEraseAssistant to true
									exit repeat
								end if
							end repeat
							exit repeat
						end if
					end if
				end tell
			end if
		end try
	end repeat
	
	try
		activate
	end try
	
	if (didAttemptToAuthenticateEraseAssistant and (application eraseAssistantAppPath is running)) then
		set didAuthenticateEraseAssistant to false
		
		repeat 10 times -- Wait up to 10 seconds for auth prompt to close if was successful.
			try
				tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is eraseAssistantAppID)
					set eraseAssistantWindowHeaderTextValue to ""
					if (isTahoeOrNewer) then
						set eraseAssistantWindowHeaderTextValue to (value of static text 1 of scroll area 1 of window 1)
					else
						set eraseAssistantWindowHeaderTextValue to (value of static text 1 of window 1)
					end if
					
					if (eraseAssistantWindowHeaderTextValue is equal to "Erase All Content & Settings") then
						set didAuthenticateEraseAssistant to true
						exit repeat
					end if
				end tell
			end try
			delay 1
		end repeat
		
		try
			activate
		end try
		
		if (didAuthenticateEraseAssistant and (application eraseAssistantAppPath is running)) then
			set didConfirmEraseAssistant to false
			try
				tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is eraseAssistantAppID)
					repeat with thisEraseAssistantButton in (buttons of window 1)
						if ((title of thisEraseAssistantButton) is equal to "Continue") then
							click thisEraseAssistantButton
							
							repeat 10 times -- Wait up to 10 seconds for final confirmation sheet.
								if ((number of sheets of window 1) is 1) then
									repeat with thisEraseAssistantButton in (buttons of sheet 1 of window 1)
										if ((title of thisEraseAssistantButton) is equal to "Erase All Content & Settings") then
											click thisEraseAssistantButton
											set didConfirmEraseAssistant to true
											exit repeat
										end if
									end repeat
									exit repeat
								end if
								delay 1
							end repeat
							
							exit repeat
						end if
					end repeat
				end tell
				
				if (didConfirmEraseAssistant) then
					repeat while (application eraseAssistantAppPath is running)
						try
							activate
						end try
						delay 1
					end repeat
					
					delay 10 -- If the Mac hasn't shut down within 10 seconds, assume an error since Mac should reboot while "Erase Assistant" is still running.
					
					errorAndQuit("Failed to complete “Erase Assistant” reset.")
				else
					errorAndQuit("Failed to confirm reset in “Erase Assistant” app.")
				end if
			on error
				errorAndQuit("Failed to automate “Erase Assistant” app.")
			end try
		else
			errorAndQuit("Failed to authenticate “Erase Assistant” app.")
		end if
	else
		errorAndQuit("Failed to launch or authenticate “Erase Assistant” app.")
	end if
else
	try
		activate
	end try
	display alert "Cannot Run “" & (name of me) & "”" message "“" & (name of me) & "” must be installed at
“/Users/" & demoUsername & "/Applications/” and run from the “" & demoUsername & "” user account." buttons {"Quit"} default button 1 as critical
end if

on errorAndQuit(errorMessage)
	try
		activate
	end try
	try
		do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
	end try
	display alert "CRITICAL “" & (name of me) & "” ERROR:

" & errorMessage message "This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research." buttons {"Quit"} default button 1 as critical
	quit
	delay 10
end errorAndQuit

on checkRemoteManagement()
	set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")
	
	try -- Don't check Remote Management if "TESTING" flag folder exists on desktop
		((((POSIX path of (path to desktop folder from user domain)) & "TESTING") as POSIX file) as alias)
	on error
		set serialNumber to ""
		try
			set serialNumber to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:IOPlatformSerialNumber' /dev/stdin <<< \"$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)\"")))
		end try
		
		if (serialNumber is not equal to "") then
			try
				repeat
					repeat
						try
							do shell script "ping -t 5 -c 1 www.apple.com" -- Require that internet is connected DEP status to get checked.
							exit repeat
						on error
							try
								display dialog "You must be connected to the internet to be able to check for Remote Management.

The rest of “" & (name of me) & "” cannot be run and this Mac CANNOT BE SOLD until it has been confirmed that Remote Management is not enabled on this Mac.


Make sure you're connected to either the “FG Staff” (or “Free Geek”) Wi-Fi network or plugged in with an Ethernet cable.

If this Mac does not have an Ethernet port, use a Thunderbolt or USB to Ethernet adapter.

Once you're connected to Wi-Fi or Ethernet, it may take a few moments for the internet connection to be established.

If it takes more than a few minutes, consult an instructor or inform Free Geek I.T." buttons {"Quit", "Try Again"} cancel button 1 default button 2 with title (name of me) with icon caution giving up after 30
							on error
								quit
								delay 10
							end try
						end try
					end repeat
					
					set progress total steps to -1
					set progress description to "
🔒	Checking for Remote Management"
					delay 0.5
					
					set checkRemoteManagedMacsLogCommand to ("curl --connect-timeout 5 -sfL " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED CHECK REMOTE MANAGED MACS LOG URL]") & " --data-urlencode " & (quoted form of ("serial=" & serialNumber)))
					set remoteManagedMacIsAlreadyLogged to false
					try
						set remoteManagedMacIsAlreadyLogged to ((do shell script checkRemoteManagedMacsLogCommand) is equal to "ALREADY LOGGED")
					end try
					
					set remoteManagementOutput to ""
					try
						try
							set remoteManagementOutput to doShellScriptAsAdmin("profiles renew -type enrollment; profiles show -type enrollment 2>&1; exit 0")
						on error profilesShowDefaultUserErrorMessage number profilesShowDefaultUserErrorNumber
							if (profilesShowDefaultUserErrorNumber is not equal to -60007) then error profilesShowDefaultUserErrorMessage number profilesShowDefaultUserErrorNumber
							try
								activate
							end try
							display alert "Would you like to check for
Remote Management (ADE/DEP/MDM)?" message "Remote Management check will be skipped in 10 seconds." buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 10
							if (gave up of result) then error number -128
							set remoteManagementOutput to (do shell script "profiles renew -type enrollment; profiles show -type enrollment 2>&1; exit 0" with prompt "Administrator Permission is required
to check for Remote Management (ADE/DEP/MDM)." with administrator privileges)
						end try
					end try
					
					if (remoteManagementOutput contains " - Request too soon.") then -- macOS 12.3 adds client side "profiles show" rate limiting of once every 23 hours: https://derflounder.wordpress.com/2022/03/22/profiles-command-includes-client-side-rate-limitation-for-certain-functions-on-macos-12-3/
						try
							set remoteManagementOutput to (do shell script ("cat " & (quoted form of (buildInfoPath & ".fgLastRemoteManagementCheckOutput"))))
						end try
					else if (remoteManagementOutput is not equal to "") then -- So always cache the last "profiles show" output so we can show the last valid results in case it's checked again within 23 hours.
						try
							do shell script ("mkdir " & (quoted form of buildInfoPath))
						end try
						try
							do shell script ("echo " & (quoted form of remoteManagementOutput) & " > " & (quoted form of (buildInfoPath & ".fgLastRemoteManagementCheckOutput"))) with administrator privileges -- DO NOT specify username and password in case it was prompted for. This will still work within 5 minutes of the last authenticated admin permissions run though.
						end try
					end if
					
					if (remoteManagementOutput contains " - Request too soon.") then -- Don't allow completion if rate limited and there was no previous cached output to use.
						set progress description to "
❌	UNABLE to Check for Remote Management"
						try
							activate
						end try
						try
							do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
						end try
						set nextAllowedProfilesShowTime to "23 hours after last successful check"
						try
							set nextAllowedProfilesShowTime to ("at " & (do shell script "date -jv +23H -f '%FT%TZ %z' \"$(plutil -extract lastProfilesShowFetchTime raw /private/var/db/ConfigurationProfiles/Settings/.profilesFetchTimerCheck) +0000\" '+%-I:%M:%S %p on %D'"))
						end try
						display alert ("Cannot Reset This Mac

Unable to Check Remote Management Because of Once Every 23 Hours Rate Limiting

Next check will be allowed " & nextAllowedProfilesShowTime & ".") message "This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research." buttons {"Shut Down"} as critical
						tell application id "com.apple.systemevents" to shut down with state saving preference
						
						quit
						delay 10
					else if (remoteManagementOutput is not equal to "") then
						try
							set remoteManagementOutputParts to (paragraphs of remoteManagementOutput)
							
							if ((count of remoteManagementOutputParts) > 3) then
								set progress description to "
⚠️	Remote Management IS Enabled"
								set remoteManagementOrganizationName to "Unknown Organization"
								set remoteManagementOrganizationContactInfo to {}
								
								set shortModelName to "UNKNOWN MAC"
								try
									set shortModelName to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:_items:0:machine_name' /dev/stdin <<< \"$(system_profiler -xml SPHardwareDataType)\"")))
								end try
								set modelIdentifier to "UNKNOWN MODEL ID"
								try
									set modelIdentifier to (do shell script "sysctl -n hw.model")
								end try
								
								set logRemoteManagedMacCommand to ("curl --connect-timeout 5 -sfL " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED LOG REMOTE MANAGED MAC URL]") & " --data-urlencode " & (quoted form of ("source=" & (name of me))) & " --data-urlencode " & (quoted form of ("model=" & shortModelName & " (" & modelIdentifier & ")")) & " --data-urlencode " & (quoted form of ("serial=" & serialNumber)))
								
								repeat with thisRemoteManagementOutputPart in remoteManagementOutputParts
									set organizationNameOffset to (offset of "OrganizationName = " in thisRemoteManagementOutputPart)
									set organizationDepartmentOffset to (offset of "OrganizationDepartment = " in thisRemoteManagementOutputPart)
									set organizationEmailOffset to (offset of "OrganizationEmail = " in thisRemoteManagementOutputPart)
									set organizationSupportEmailOffset to (offset of "OrganizationSupportEmail = " in thisRemoteManagementOutputPart)
									set organizationPhoneOffset to (offset of "OrganizationPhone = " in thisRemoteManagementOutputPart)
									set organizationSupportPhoneOffset to (offset of "OrganizationSupportPhone = " in thisRemoteManagementOutputPart)
									
									if (organizationNameOffset > 0) then
										set remoteManagementOrganizationName to (text (organizationNameOffset + 19) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationName starts with "\"") and (remoteManagementOrganizationName ends with "\"")) then set remoteManagementOrganizationName to (text 2 thru -2 of remoteManagementOrganizationName) -- Remove quotes if they exist, which they always should since this should always be a string value.
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("organization=" & remoteManagementOrganizationName)))
									else if (organizationDepartmentOffset > 0) then
										set remoteManagementOrganizationDepartment to (text (organizationDepartmentOffset + 25) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationDepartment starts with "\"") and (remoteManagementOrganizationDepartment ends with "\"")) then set remoteManagementOrganizationDepartment to (text 2 thru -2 of remoteManagementOrganizationDepartment) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
										if ((remoteManagementOrganizationDepartment is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationDepartment)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationDepartment
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("department=" & remoteManagementOrganizationDepartment)))
									else if (organizationEmailOffset > 0) then
										set remoteManagementOrganizationEmail to (text (organizationEmailOffset + 20) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationEmail starts with "\"") and (remoteManagementOrganizationEmail ends with "\"")) then set remoteManagementOrganizationEmail to (text 2 thru -2 of remoteManagementOrganizationEmail) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
										if ((remoteManagementOrganizationEmail is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationEmail)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationEmail
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("email=" & remoteManagementOrganizationEmail)))
									else if (organizationSupportEmailOffset > 0) then
										set remoteManagementOrganizationSupportEmail to (text (organizationSupportEmailOffset + 27) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationSupportEmail starts with "\"") and (remoteManagementOrganizationSupportEmail ends with "\"")) then set remoteManagementOrganizationSupportEmail to (text 2 thru -2 of remoteManagementOrganizationSupportEmail) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
										if ((remoteManagementOrganizationSupportEmail is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationSupportEmail)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationSupportEmail
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("support_email=" & remoteManagementOrganizationSupportEmail)))
									else if (organizationPhoneOffset > 0) then
										set remoteManagementOrganizationPhone to (text (organizationPhoneOffset + 20) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationPhone starts with "\"") and (remoteManagementOrganizationPhone ends with "\"")) then set remoteManagementOrganizationPhone to (text 2 thru -2 of remoteManagementOrganizationPhone) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
										if ((remoteManagementOrganizationPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationPhone
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("phone=" & remoteManagementOrganizationPhone)))
									else if (organizationSupportPhoneOffset > 0) then
										set remoteManagementOrganizationSupportPhone to (text (organizationSupportPhoneOffset + 27) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationSupportPhone starts with "\"") and (remoteManagementOrganizationSupportPhone ends with "\"")) then set remoteManagementOrganizationSupportPhone to (text 2 thru -2 of remoteManagementOrganizationSupportPhone) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
										if ((remoteManagementOrganizationSupportPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationSupportPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationSupportPhone
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("support_phone=" & remoteManagementOrganizationSupportPhone)))
									end if
								end repeat
								
								if (not remoteManagedMacIsAlreadyLogged) then
									set remoteManagedMacPID to ""
									repeat
										try
											activate
										end try
										try
											do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
										end try
										
										set invalidPIDnote to ""
										
										if (remoteManagedMacPID is not equal to "") then
											set invalidPIDnote to "
❌	“" & remoteManagedMacPID & "” IS NOT A VALID PID - TRY AGAIN
"
										end if
										
										set remoteManagedMacPIDreply to (display dialog "🔒	This Mac is Remote Managed by “" & remoteManagementOrganizationName & "”
" & invalidPIDnote & "
Enter the PID of this Mac below to log this Mac with the contact info for “" & remoteManagementOrganizationName & "” so that they can be contacted to remove Remote Management:" default answer remoteManagedMacPID buttons {"Log Remote Managed Mac Without PID", "Log Remote Managed Mac"} default button 2)
										
										set remoteManagedMacPID to (text returned of remoteManagedMacPIDreply)
										
										if ((button returned of remoteManagedMacPIDreply) ends with "Without PID") then
											set remoteManagedMacPID to "N/A"
										end if
										
										if ((remoteManagedMacPID is equal to "N/A") or ((do shell script "bash -c " & (quoted form of ("[[ " & (quoted form of remoteManagedMacPID) & " =~ ^[[:alpha:]]*[[:digit:]]+\\-[[:digit:]]+$ ]]; echo $?"))) is equal to "0")) then
											set remoteManagedMacPID to (do shell script "echo " & (quoted form of remoteManagedMacPID) & " | tr '[:lower:]' '[:upper:]'")
											set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("pid=" & remoteManagedMacPID)))
											exit repeat
										end if
									end repeat
									
									repeat
										set logRemoteManagedMacResult to "UNKNOWN ERROR"
										try
											set logRemoteManagedMacResult to (do shell script logRemoteManagedMacCommand)
											if (logRemoteManagedMacResult ends with "LOGGED") then exit repeat
										end try
										
										try
											activate
										end try
										try
											do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
										end try
										display alert "Failed to Log Remote Managed Mac

ERROR: " & logRemoteManagedMacResult & "

You must be connected to the internet to be able to log this Remote Managed Mac." message "Make sure you're connected to either the “FG Staff” (or “Free Geek”) Wi-Fi network or plugged in with an Ethernet cable.

If this Mac does not have an Ethernet port, use a Thunderbolt or USB to Ethernet adapter.

Once you're connected to Wi-Fi or Ethernet, it may take a few moments for the internet connection to be established.

If it takes more than a few minutes, consult an instructor or inform Free Geek I.T." buttons {"Try Again"} default button 1 as critical giving up after 10
									end repeat
								else
									try
										do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
									end try
								end if
								
								set remoteManagementOrganizationContactInfoDisplay to "NO CONTACT INFORMATION"
								if ((count of remoteManagementOrganizationContactInfo) > 0) then
									set AppleScript's text item delimiters to (linefeed & tab & tab)
									set remoteManagementOrganizationContactInfoDisplay to (remoteManagementOrganizationContactInfo as text)
								end if
								
								set remoteManagementDialogButton to "Shut Down                                                                                                              "
								
								try
									activate
								end try
								display dialog "	     ⚠️     REMOTE MANAGEMENT IS ENABLED ON THIS MAC     ⚠️

❌     MACS WITH REMOTE MANAGEMENT ENABLED CANNOT BE SOLD     ❌



🔒	THIS MAC IS MANAGED BY “" & remoteManagementOrganizationName & "”

🔑	ONLY “" & remoteManagementOrganizationName & "” CAN DISABLE REMOTE MANAGEMENT

☎️	“" & remoteManagementOrganizationName & "” MUST BE CONTACTED BY A MANAGER:
		" & remoteManagementOrganizationContactInfoDisplay & "

🆔	THE SERIAL NUMBER FOR THIS MAC IS “" & serialNumber & "”



	     📝     THIS MAC AND CONTACT INFO HAS BEEN LOGGED     ✅" buttons {remoteManagementDialogButton} with title "Remote Management Enabled"
								tell application id "com.apple.systemevents" to shut down with state saving preference
								
								quit
								delay 10
							else if ((remoteManagementOutput does not contain "Error fetching Device Enrollment configuration") or (remoteManagementOutput contains "Client is not DEP enabled.") or (remoteManagementOutput contains "Bad response from apsd: Connection interrupted")) then -- NOTE: This "Bad response from apsd" error will often be returned when the device IS NOT Remote Managed, so don't show it as an error so that technicians don't get confused.
								if (remoteManagedMacIsAlreadyLogged) then
									set markPreviouslyRemoteManagedMacAsRemovedCommand to ("curl --connect-timeout 5 -sfL " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED MARK PREVIOUSLY REMOTE MANAGED MAC AS REMOVED URL]") & " --data-urlencode " & (quoted form of ("serial=" & serialNumber)))
									
									repeat
										set markPreviouslyRemoteManagedMacAsRemovedResult to "UNKNOWN ERROR"
										try
											set markPreviouslyRemoteManagedMacAsRemovedResult to (do shell script markPreviouslyRemoteManagedMacAsRemovedCommand)
											if (markPreviouslyRemoteManagedMacAsRemovedResult ends with "REMOVED") then exit repeat
										end try
										
										try
											activate
										end try
										try
											do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
										end try
										display alert "Failed to Mark Previously Remote Managed Mac As Removed

ERROR: " & markPreviouslyRemoteManagedMacAsRemovedResult & "

You must be connected to the internet to be able to mark this previously Remote Managed Mac as removed." message "Make sure you're connected to either the “FG Staff” (or “Free Geek”) Wi-Fi network or plugged in with an Ethernet cable.

If this Mac does not have an Ethernet port, use a Thunderbolt or USB to Ethernet adapter.

Once you're connected to Wi-Fi or Ethernet, it may take a few moments for the internet connection to be established.

If it takes more than a few minutes, consult an instructor or inform Free Geek I.T." buttons {"Try Again"} default button 1 as critical giving up after 10
									end repeat
								end if
								
								set progress description to "
👍	Remote Management IS NOT Enabled"
								delay 2
								
								exit repeat
							else
								set progress description to "
❌	FAILED to Check for Remote Management"
								try
									activate
								end try
								try
									do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
								end try
								try
									display alert "Cannot Reset This Mac

Failed to Check Remote Management" message (remoteManagementOutput & "

This should not have happened, please inform Free Geek I.T.") buttons {"Shut Down", "Try Again"} cancel button 1 default button 2 as critical
								on error
									tell application id "com.apple.systemevents" to shut down with state saving preference
									
									quit
									delay 10
								end try
							end if
						end try
					else
						set progress description to "
❌	FAILED to Check for Remote Management"
						try
							activate
						end try
						try
							do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
						end try
						try
							display alert "Cannot Reset This Mac

Failed to Check Remote Management" message "An UNKNOWN ERROR occurred.

This should not have happened, please inform Free Geek I.T." buttons {"Shut Down", "Try Again"} cancel button 1 default button 2 as critical
						on error
							tell application id "com.apple.systemevents" to shut down with state saving preference
							
							quit
							delay 10
						end try
					end if
				end repeat
			end try
		end if
	end try
end checkRemoteManagement

on quitAllApps()
	try
		tell application id "com.apple.systemevents" to set listOfRunningAppIDs to (bundle identifier of every application process where ((background only is false) and (bundle identifier is not "com.apple.finder") and (bundle identifier is not (id of me))))
		if ((count of listOfRunningAppIDs) > 0) then
			try
				repeat with thisAppID in listOfRunningAppIDs
					try
						if (application id thisAppID is running) then
							with timeout of 1 second
								tell application id thisAppID to quit without saving
							end timeout
						end if
					end try
				end repeat
			end try
			delay 3
			try
				set AppleScript's text item delimiters to space
				tell application id "com.apple.systemevents" to set allRunningAppPIDs to ((unix id of every application process where ((background only is false) and (bundle identifier is not "com.apple.finder") and (bundle identifier is not (id of me)))) as text)
				if (allRunningAppPIDs is not equal to "") then
					do shell script ("kill " & allRunningAppPIDs)
				end if
			end try
		end if
	end try
end quitAllApps

on clearNVRAMandCheckStartupSecurityAndClearSIP()
	-- CLEAR NVRAM (just for house cleaning purposes, this doesn't clear SIP).
	try
		-- DO NOT clear NVRAM if TRIM has been enabled on Catalina with "trimforce enable" because clearing NVRAM will undo it. (The TRIM flag is not stored in NVRAM before Catalina.)
		doShellScriptAsAdmin("nvram EnableTRIM") -- This will error if the flag does not exist.
	on error
		try
			doShellScriptAsAdmin("nvram -c")
		end try
	end try
	
	try
		if (hasT2chip) then
			if ((do shell script "nvram '94B73556-2197-4702-82A8-3E1337DAFBFB:AppleSecureBootPolicy'") does not end with "%02") then -- https://github.com/dortania/OpenCore-Legacy-Patcher/blob/b85256d9708a299b9f7ea15cb3456248a1a666b7/resources/utilities.py#L242 & https://macadmins.slack.com/archives/CGXNNJXJ9/p1686766296067939?thread_ts=1686766055.849109&cid=CGXNNJXJ9
				errorAndQuit("Startup Security IS REDUCED on this T2 Mac.") -- "Erase Assistant" (EAC&S) reset will error and not allow running if Startup Security is reduced on a T2 Mac.
			end if
		else if (isAppleSilicon) then
			if (doShellScriptAsAdmin("bputil -d") does not contain "(smb0): absent") then
				errorAndQuit("Startup Security IS REDUCED on this Apple Silicon Mac.") -- "Erase Assistant" (EAC&S) reset will actually still work with Startup Security reduced on an Apple Silicon Mac and it will set it back to "Full", but error anyways since this shouldn't happen.
			end if
		end if
	end try
	
	try
		if ((do shell script "csrutil status") is not equal to "System Integrity Protection status: enabled.") then
			if (isAppleSilicon) then
				-- If on Apple Silicon, enabling SIP requires authentication from a Secure Token admin (which won't have ever existed) to enable or disable it,
				-- so it should be impossible to be enabled, and we wouldn't be able to disable it if it was.
				-- So, fully stop with an error if somehow SIP is NOT enabled on an Apple Silicon Mac.
				errorAndQuit("System Integrity Protection (SIP) IS NOT enabled on this Apple Silicon Mac.") -- "Erase Assistant" (EAC&S) reset will actually still work with SIP disabled on an Apple Silicon Mac and it will re-enable it, but error anyways since this shouldn't happen.
			else
				try
					doShellScriptAsAdmin("csrutil clear") -- "csrutil clear" can run from full macOS (Recovery is not required) but still needs a reboot to take affect, which will happen after Erase Assistant has been run.
				end try
			end if
		end if
	end try
end clearNVRAMandCheckStartupSecurityAndClearSIP

on doShellScriptAsAdmin(command)
	-- "do shell script with administrator privileges" caches authentication for 5 minutes: https://developer.apple.com/library/archive/technotes/tn2065/_index.html#//apple_ref/doc/uid/DTS10003093-CH1-TNTAG1-HOW_DO_I_GET_ADMINISTRATOR_PRIVILEGES_FOR_A_COMMAND_ & https://developer.apple.com/library/archive/releasenotes/AppleScript/RN-AppleScript/RN-10_4/RN-10_4.html#//apple_ref/doc/uid/TP40000982-CH104-SW10
	-- And, it takes reasonably longer to run "do shell script with administrator privileges" when credentials are passed vs without.
	-- In testing, 100 iteration with credentials took about 30 seconds while 100 interations without credentials after authenticated in advance took only 2 seconds.
	-- So, this function makes it easy to call "do shell script with administrator privileges" while only passing credentials when needed.
	-- Also, from testing, this 5 minute credential caching DOES NOT seem to be affected by any custom "sudo" timeout set in the sudoers file.
	-- And, from testing, unlike "sudo" the timeout DOES NOT keep extending from the last "do shell script with administrator privileges" without credentials but only from the last time credentials were passed.
	-- To be safe, "do shell script with administrator privileges" will be re-authenticated with the credentials every 4.5 minutes.
	-- NOTICE: "do shell script" calls are intentionally NOT in "try" blocks since detecting and catching those errors may be critical to the code calling the "doShellScriptAsAdmin" function.
	
	set currentDate to (current date)
	if ((lastDoShellScriptAsAdminAuthDate is equal to 0) or (currentDate ≥ (lastDoShellScriptAsAdminAuthDate + 270))) then -- 270 seconds = 4.5 minutes.
		set commandOutput to (do shell script command user name adminUsername password adminPassword with administrator privileges)
		set lastDoShellScriptAsAdminAuthDate to currentDate -- Set lastDoShellScriptAsAdminAuthDate to date *BEFORE* command was run since the command itself could have updated the date and the 5 minute timeout started when the command started, not when it finished.
	else
		set commandOutput to (do shell script command with prompt "This “" & (name of me) & "” password prompt should not have been displayed.

Please inform Free Geek I.T. that you saw this password prompt.

You can just press “Cancel” below to continue." with administrator privileges)
	end if
	
	return commandOutput
end doShellScriptAsAdmin
