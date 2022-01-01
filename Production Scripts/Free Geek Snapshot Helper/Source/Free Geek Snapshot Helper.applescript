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

-- Version: 2021.12.30-1

-- Build Flag: LSUIElement

use AppleScript version "2.4"
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

set adminUsername to "fg-admin"
set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"

set demoUsername to "fg-demo"

if (((short user name of (system info)) is equal to demoUsername) and ((POSIX path of (path to me)) is equal to ("/Users/" & demoUsername & "/Applications/" & (name of me) & ".app/"))) then
	try
		(("/Users/Shared/.fg-snapshot-preserver" as POSIX file) as alias)
		
		try
			(("/Users/Shared/.fgResetSnapshotCreated" as POSIX file) as alias)
			
			set systemVersion to (system version of (system info))
			considering numeric strings
				set isBigSurOrNewer to (systemVersion ≥ "11.0")
				set isMontereyOrNewer to (systemVersion ≥ "12.0")
			end considering
			
			if (isBigSurOrNewer) then
				try
					-- Do not bother try re-mounting if it's already mounted.
					(("/Users/Shared/.fg-snapshot-preserver/mount/Users/Shared/fg-snapshot-reset" as POSIX file) as alias)
					try
						do shell script "echo \"$(date '+%D %T')	Snapshot Helper: Reset Snapshot Already Mounted\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'" user name adminUsername password adminPassword with administrator privileges
					end try
				on error
					set resetSnapshotName to (do shell script "head -1 /Users/Shared/.fgResetSnapshotCreated")
					
					if (resetSnapshotName starts with "com.apple.TimeMachine") then
						try
							(("/Users/Shared/.fg-snapshot-preserver/mount" as POSIX file) as alias)
						on error
							try
								-- Needs admin privileges since root owns ".fg-snapshot-preserver" folder.
								do shell script "mkdir '/Users/Shared/.fg-snapshot-preserver/mount'" user name adminUsername password adminPassword with administrator privileges
							end try
						end try
						
						try
							-- But the mount folder needs to be writeable by demoUsername or mounting the snapshot will fail (even when using administrator privileges).
							do shell script "chown " & demoUsername & " '/Users/Shared/.fg-snapshot-preserver/mount'" user name adminUsername password adminPassword with administrator privileges
						end try
						
						try
							-- Mounting the reset Snapshot will prevent macOS from deleting it after 24 hours: https://eclecticlight.co/2021/03/28/last-week-on-my-mac-macos-at-20-apfs-at-4/#comment-59001
							do shell script "mount_apfs -o rdonly,nobrowse -s " & (quoted form of resetSnapshotName) & " \"$(/usr/libexec/PlistBuddy -c 'Print :DeviceNode' /dev/stdin <<< \"$(diskutil info -plist '/System/Volumes/Data')\")\" '/Users/Shared/.fg-snapshot-preserver/mount'"
							try
								do shell script "echo \"$(date '+%D %T')	Snapshot Helper: Successfully Mounted Reset Snapshot\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'" user name adminUsername password adminPassword with administrator privileges
							end try
							
							if (isMontereyOrNewer) then
								-- In macOS 12 Monterey, the Safari Container is created upon login instead of first Safari launch.
								-- The preferences within the Safari Container don't exist until launch, but the preferences from the old location (set by "fg-prepare-o.sh") DO NOT getting migrated as they do on older versions of macOS because the Safari Container already exists.
								-- Modifying the preferences within the Safari Container requires Full Disk Access TCC privileges, so it must be done in this script since it's the only one with FDA.
								
								-- SINCE THIS CHECK IS ONLY DONE AFTER A SUCCESSFULLY MOUNTING THE RESET SNAPSHOT,
								-- that means it will only be run right after FDA has been granted, or on each boot which is fine since it should only need to be run once.
								
								set currentSafariAutoFillPasswords to "UNKNOWN"
								try
									set currentSafariAutoFillPasswords to (do shell script "defaults read '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoFillPasswords")
								end try
								
								if (currentSafariAutoFillPasswords is not equal to "0") then
									try
										do shell script "killall Safari"
									end try
									try
										do shell script "defaults write '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoFillPasswords -bool false"
									end try
									try
										do shell script "defaults write '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoFillFromAddressBook -bool false"
									end try
									try
										do shell script "defaults write '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoFillCreditCardData -bool false"
									end try
									try
										do shell script "defaults write '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoFillMiscellaneousForms -bool false"
									end try
									try
										do shell script "defaults write '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoOpenSafeDownloads -bool false"
									end try
								end if
							end if
						on error mountErrorMessage number mountErrorNumber
							try
								do shell script "echo \"$(date '+%D %T')	Snapshot Helper: FAILED to Mount Reset Snapshot (Error Code " & (mountErrorNumber as string) & ": " & mountErrorMessage & ")\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'" user name adminUsername password adminPassword with administrator privileges
							end try
						end try
					else
						try
							do shell script "echo \"$(date '+%D %T')	Snapshot Helper: Invalid Reset Snapshot Name\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'" user name adminUsername password adminPassword with administrator privileges
						end try
					end if
				end try
			else
				try
					do shell script "echo \"$(date '+%D %T')	Snapshot Helper: Not Mounting Reset Snapshot on Catalina\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'" user name adminUsername password adminPassword with administrator privileges
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
					set isAwake to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :0:IOPowerManagement:CurrentPowerState' /dev/stdin <<< \"$(ioreg -arc IODisplayWrangler -k IOPowerManagement -d 1)\"") is equal to "4")
				end try
				
				set isUnlocked to true
				try
					set isUnlocked to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :IOConsoleUsers:0:CGSSessionScreenIsLocked' /dev/stdin <<< \"$(ioreg -ac IORegistryEntry -k IOConsoleUsers -d 1)\"") is not equal to "true")
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
			display alert "Reset Snapshot Has Been Lost

" & resetSnapshotLostReason & "

This Mac CANNOT BE SOLD since it cannot be reset." message "
Reset Snapshot Name: " & resetSnapshotName & "

THIS SHOULD NOT HAVE HAPPENED!

Please inform and deliver this Mac to Free Geek I.T." as critical
		end try
		
		try
			do shell script "rm -rf '/Users/Shared/.fg-snapshot-preserver/.launchedSnapshotHelper'" user name adminUsername password adminPassword with administrator privileges
		end try
	end try
else
	try
		(("/Users/Shared/.fg-snapshot-preserver" as POSIX file) as alias)
		
		try
			do shell script "echo \"$(date '+%D %T')	Snapshot Helper: NOT RUNNING Because Not Logged In or Not Installed in Correct Location\" >> '/Users/Shared/.fg-snapshot-preserver/log.txt'" user name adminUsername password adminPassword with administrator privileges
		end try
	on error
		try
			activate
		end try
		display alert "Cannot Run “" & (name of me) & "”" message "“" & (name of me) & "” must be installed at
“/Users/" & demoUsername & "/Applications/” and run from the “" & demoUsername & "” user account." buttons {"Quit"} default button 1 as critical
	end try
end if
