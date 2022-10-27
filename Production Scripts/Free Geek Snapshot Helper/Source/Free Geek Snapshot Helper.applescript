-- By: Pico Mitchell
-- For: MacLand @ Free Geek
--
-- MIT License
--
-- Copyright (c) 2021 Free Geek
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

-- Version: 2022.10.12-1

-- Build Flag: LSUIElement

use AppleScript version "2.7"
use scripting additions

set currentBundleIdentifier to "UNKNOWN"

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set intendedAppName to "Free Geek Snapshot Helper" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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
	set intendedBundleIdentifier to ("org.freegeek." & ((words of intendedAppName) as string))
	set currentBundleIdentifier to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & (quoted form of infoPlistPath))) as string)
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


global adminUsername, adminPassword, lastDoShellScriptAsAdminAuthDate -- Needs to be accessible in doShellScriptAsAdmin function.
set lastDoShellScriptAsAdminAuthDate to 0

set adminUsername to "fg-admin"
set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"

set demoUsername to "fg-demo"


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
		(("/Users/Shared/.fg-snapshot-preserver" as POSIX file) as alias)
		
		set shouldShutDownAfterError to false
		try
			(("/Users/Shared/.fgResetSnapshotCreated" as POSIX file) as alias)
			
			set systemVersion to (system version of (system info))
			considering numeric strings
				set isBigSurOrNewer to (systemVersion ≥ "11.0")
			end considering
			
			if (isBigSurOrNewer) then
				try
					-- Do not bother try re-mounting if it's already mounted.
					(("/Users/Shared/.fg-snapshot-preserver/mount/Users/Shared/fg-snapshot-reset" as POSIX file) as alias)
					try
						doShellScriptAsAdmin("echo \"$(date '+%D %T')	Snapshot Helper: Reset Snapshot Already Mounted\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'")
					end try
				on error
					set resetSnapshotName to (do shell script "head -1 /Users/Shared/.fgResetSnapshotCreated")
					
					try
						if (resetSnapshotName starts with "com.apple.TimeMachine") then
							try
								(("/Users/Shared/.fg-snapshot-preserver/mount" as POSIX file) as alias)
							on error
								try
									-- Needs admin privileges since root owns ".fg-snapshot-preserver" folder.
									doShellScriptAsAdmin("mkdir '/Users/Shared/.fg-snapshot-preserver/mount'")
								end try
							end try
							
							try
								-- But the mount folder needs to be writeable by demoUsername or mounting the snapshot will fail (even when using administrator privileges).
								doShellScriptAsAdmin("chown " & demoUsername & " '/Users/Shared/.fg-snapshot-preserver/mount'")
							end try
							
							try
								-- Mounting the reset Snapshot will prevent macOS from deleting it after 24 hours: https://eclecticlight.co/2021/03/28/last-week-on-my-mac-macos-at-20-apfs-at-4/#comment-59001
								do shell script ("bash -c " & (quoted form of ("mount_apfs -o rdonly,nobrowse -s " & (quoted form of resetSnapshotName) & " \"$(/usr/libexec/PlistBuddy -c 'Print :DeviceNode' /dev/stdin <<< \"$(diskutil info -plist '/System/Volumes/Data')\")\" '/Users/Shared/.fg-snapshot-preserver/mount'")))
								try
									doShellScriptAsAdmin("echo \"$(date '+%D %T')	Snapshot Helper: Successfully Mounted Reset Snapshot\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'")
								end try
							on error mountErrorMessage number mountErrorNumber
								set snapshotMountError to ("FAILED to Mount Reset Snapshot (Error Code " & (mountErrorNumber as string) & ": " & mountErrorMessage & ")")
								try
									doShellScriptAsAdmin("echo \"$(date '+%D %T')	Snapshot Helper: " & snapshotMountError & "\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'")
								end try
								
								error snapshotMountError
							end try
						else
							set snapshotNameError to ("Invalid Reset Snapshot Name (" & resetSnapshotName & ")")
							try
								doShellScriptAsAdmin("echo \"$(date '+%D %T')	Snapshot Helper: " & snapshotNameError & "\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'")
							end try
							
							error snapshotNameError
						end if
					on error snapshotErrorMessage
						try
							activate
						end try
						try
							do shell script "afplay /System/Library/Sounds/Basso.aiff"
						end try
						display alert ("CRITICAL “" & (name of me) & "” ERROR:
					
" & snapshotErrorMessage) message "This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research." buttons {"Shut Down"} default button 1 as critical
						
						set shouldShutDownAfterError to true
					end try
				end try
			else
				try
					doShellScriptAsAdmin("echo \"$(date '+%D %T')	Snapshot Helper: Not Mounting Reset Snapshot on Catalina\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'")
				end try
			end if
		on error
			set resetSnapshotName to "UNKNOWN SNAPSHOT NAME"
			set resetSnapshotLostReason to "UNKNOWN LOST REASON"
			try
				(("/Users/Shared/.fgResetSnapshotLost" as POSIX file) as alias)
				try
					set resetSnapshotName to (do shell script "head -1 /Users/Shared/.fgResetSnapshotLost")
				end try
				try
					set resetSnapshotLostReason to (do shell script "tail -1 /Users/Shared/.fgResetSnapshotLost")
				end try
			end try
			
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
			
			try
				activate
			end try
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff"
			end try
			display alert ("CRITICAL “" & (name of me) & "” ERROR:

Reset Snapshot Has Been Lost

" & resetSnapshotLostReason & "

This Mac CANNOT BE SOLD since it cannot be reset.") message ("
Reset Snapshot Name: " & resetSnapshotName & "

This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research.") buttons {"Shut Down"} default button 1 as critical
			
			set shouldShutDownAfterError to true
		end try
		
		try
			doShellScriptAsAdmin("rm -rf '/Users/Shared/.fg-snapshot-preserver/.launchedSnapshotHelper'")
		end try
		
		if (shouldShutDownAfterError) then
			tell application "System Events" to shut down with state saving preference
			quit
			delay 10
		end if
	end try
else
	try
		(("/Users/Shared/.fg-snapshot-preserver" as POSIX file) as alias)
		
		try
			doShellScriptAsAdmin("echo \"$(date '+%D %T')	Snapshot Helper: NOT RUNNING Because Not Logged In or Not Installed in Correct Location\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'")
		end try
	on error
		try
			activate
		end try
		display alert "Cannot Run “" & (name of me) & "”" message "“" & (name of me) & "” must be installed at
“/Users/" & demoUsername & "/Applications/” and run from the “" & demoUsername & "” user account." buttons {"Quit"} default button 1 as critical
	end try
end if

on doShellScriptAsAdmin(command)
	-- "do shell script with administrator privileges" caches authentication for 5 minutes: https://developer.apple.com/library/archive/technotes/tn2065/_index.html#//apple_ref/doc/uid/DTS10003093-CH1-TNTAG1-HOW_DO_I_GET_ADMINISTRATOR_PRIVILEGES_FOR_A_COMMAND_
	-- And, it takes reasonably longer to run "do shell script with administrator privileges" when credentials are passed vs without.
	-- In testing, 100 iteration with credentials took about 30 seconds while 100 interations without credentials after authenticated in advance took only 2 seconds.
	-- So, this function makes it easy to call "do shell script with administrator privileges" while only passing credentials when needed.
	-- Also, from testing, this 5 minute credential caching DOES NOT seem to be affected by any custom "sudo" timeout set in the sudoers file.
	-- And, from testing, unlike "sudo" the timeout DOES NOT keep extending from the last "do shell script with administrator privileges" without credentials but only from the last time credentials were passed.
	-- To be safe, "do shell script with administrator privileges" will be re-authenticated with the credentials every 4.5 minutes.
	-- NOTICE: "do shell script" calls are intentionally NOT in "try" blocks since detecting and catching those errors may be critical to the code calling the "doShellScriptAsAdmin" function.
	
	if ((lastDoShellScriptAsAdminAuthDate is equal to 0) or ((current date) ≥ (lastDoShellScriptAsAdminAuthDate + 270))) then -- 270 seconds = 4.5 minutes.
		set commandOutput to (do shell script command user name adminUsername password adminPassword with administrator privileges)
		set lastDoShellScriptAsAdminAuthDate to (current date)
	else
		set commandOutput to (do shell script command with administrator privileges)
	end if
	
	return commandOutput
end doShellScriptAsAdmin
