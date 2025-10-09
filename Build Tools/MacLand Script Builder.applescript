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

use AppleScript version "2.7"
use scripting additions

set bundleIdentifierPrefix to "org.freegeek."

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set AppleScript's text item delimiters to "-"
	set correctBundleIdentifier to bundleIdentifierPrefix & ((words of (name of me)) as text)
	try
		set currentBundleIdentifier to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & (quoted form of infoPlistPath)) as text)
		if (currentBundleIdentifier is not equal to correctBundleIdentifier) then error "INCORRECT Bundle Identifier"
	on error
		do shell script "plutil -replace CFBundleIdentifier -string " & (quoted form of correctBundleIdentifier) & " " & (quoted form of infoPlistPath)
		
		try
			set currentCopyright to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :NSHumanReadableCopyright' " & (quoted form of infoPlistPath)) as text)
			if (currentCopyright does not contain "Twemoji") then error "INCORRECT Copyright"
		on error
			do shell script "plutil -replace NSHumanReadableCopyright -string " & (quoted form of ("Copyright © " & (year of (current date)) & " Free Geek
Designed and Developed by Pico Mitchell")) & " " & (quoted form of infoPlistPath)
		end try
		
		try
			set minSystemVersion to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' " & (quoted form of infoPlistPath)) as text)
			if (minSystemVersion is not equal to "10.13") then error "INCORRECT Minimum System Version"
		on error
			do shell script "plutil -remove LSMinimumSystemVersionByArchitecture " & (quoted form of infoPlistPath) & "; plutil -replace LSMinimumSystemVersion -string '10.13' " & (quoted form of infoPlistPath)
		end try
		
		try
			set prohibitMultipleInstances to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :LSMultipleInstancesProhibited' " & (quoted form of infoPlistPath)) as number)
			if (prohibitMultipleInstances is equal to 0) then error "INCORRECT Multiple Instances Prohibited"
		on error
			do shell script "plutil -replace LSMultipleInstancesProhibited -bool true " & (quoted form of infoPlistPath)
		end try
		
		try
			set allowMixedLocalizations to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleAllowMixedLocalizations' " & (quoted form of infoPlistPath)) as number)
			if (allowMixedLocalizations is equal to 1) then error "INCORRECT Localization"
		on error
			do shell script "plutil -replace CFBundleAllowMixedLocalizations -bool false " & (quoted form of infoPlistPath) & "; plutil -replace CFBundleDevelopmentRegion -string 'en_US' " & (quoted form of infoPlistPath)
		end try
		
		try
			set currentAppleEventsUsageDescription to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :NSAppleEventsUsageDescription' " & (quoted form of infoPlistPath)) as text)
			if (currentAppleEventsUsageDescription does not contain (name of me)) then error "INCORRECT AppleEvents Usage Description"
		on error
			do shell script "plutil -replace NSAppleEventsUsageDescription -string " & (quoted form of ("You MUST click the “OK” button for “" & (name of me) & "” to be able to function.")) & " " & (quoted form of infoPlistPath)
		end try
		
		try
			set currentVersion to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' " & (quoted form of infoPlistPath)) as text)
			if (currentVersion is equal to "1.0") then error "INCORRECT Version"
		on error
			set shortCreationDateString to (short date string of (creation date of (info for (path to me))))
			set AppleScript's text item delimiters to "/"
			set correctVersion to ((text item 3 of shortCreationDateString) & "." & (text item 1 of shortCreationDateString) & "." & (text item 2 of shortCreationDateString))
			do shell script "plutil -remove CFBundleVersion " & (quoted form of infoPlistPath) & "; plutil -replace CFBundleShortVersionString -string " & (quoted form of correctVersion) & " " & (quoted form of infoPlistPath)
		end try
		
		-- The "main.scpt" must NOT be writable to prevent the code signature from being invalidated: https://developer.apple.com/library/archive/releasenotes/AppleScript/RN-AppleScript/RN-10_8/RN-10_8.html#//apple_ref/doc/uid/TP40000982-CH108-SW8
		do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'try' -e 'do shell script \"chmod a-w \\\"" & ((POSIX path of (path to me)) & "Contents/Resources/Scripts/main.scpt") & "\\\"\"' -e 'do shell script \"codesign -fs \\\"Developer ID Application\\\" --strict \\\"" & (POSIX path of (path to me)) & "\\\"\"' -e 'on error codeSignError' -e 'activate' -e 'display alert \"Code Sign Error\" message codeSignError' -e 'end try' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
		quit
		delay 10
	end try
end try

global obfuscateCharactersShiftCount

set currentYear to ((year of (current date)) as text)
set shortCurrentDateString to (short date string of (current date))

repeat
	set buildResultsOutput to {}
	
	tell application id "com.apple.finder"
		set parentFolder to (container of (path to me))
		
		set fgPrivateStringsPlistPath to ((POSIX path of (parentFolder as alias)) & "Free Geek Private Strings.plist")
		
		set adminPassword to ""
		try
			set adminPassword to (do shell script ("/usr/libexec/PlistBuddy -c 'Print :admin_password' " & (quoted form of fgPrivateStringsPlistPath)) as text)
		end try
		
		set previousAdminPassword to ""
		try
			set previousAdminPassword to (do shell script ("/usr/libexec/PlistBuddy -c 'Print :previous_admin_password' " & (quoted form of fgPrivateStringsPlistPath)) as text)
		end try
		
		set wiFiPassword to ""
		try
			set wiFiPassword to (do shell script ("/usr/libexec/PlistBuddy -c 'Print :wifi_password' " & (quoted form of fgPrivateStringsPlistPath)) as text)
		end try
		
		set checkRemoteManagedMacsLogURL to ""
		try
			set checkRemoteManagedMacsLogURL to (do shell script ("/usr/libexec/PlistBuddy -c 'Print :check_remote_managed_macs_log_url' " & (quoted form of fgPrivateStringsPlistPath)) as text)
		end try
		
		set logRemoteManagedMacURL to ""
		try
			set logRemoteManagedMacURL to (do shell script ("/usr/libexec/PlistBuddy -c 'Print :log_remote_managed_mac_url' " & (quoted form of fgPrivateStringsPlistPath)) as text)
		end try
		
		set markPreviouslyRemoteManagedMacAsRemovedURL to ""
		try
			set markPreviouslyRemoteManagedMacAsRemovedURL to (do shell script ("/usr/libexec/PlistBuddy -c 'Print :mark_previously_remote_managed_mac_as_removed_url' " & (quoted form of fgPrivateStringsPlistPath)) as text)
		end try
		
		if (adminPassword is equal to "") then
			set (end of buildResultsOutput) to "⚠️		FAILED TO RETRIEVE adminPassword"
			set (end of buildResultsOutput) to ""
		else if (wiFiPassword is equal to "") then
			set (end of buildResultsOutput) to "⚠️		FAILED TO RETRIEVE wiFiPassword"
			set (end of buildResultsOutput) to ""
		else if (checkRemoteManagedMacsLogURL is equal to "") then
			set (end of buildResultsOutput) to "⚠️		FAILED TO RETRIEVE checkRemoteManagedMacsLogURL"
			set (end of buildResultsOutput) to ""
		else if (logRemoteManagedMacURL is equal to "") then
			set (end of buildResultsOutput) to "⚠️		FAILED TO RETRIEVE logRemoteManagedMacURL"
			set (end of buildResultsOutput) to ""
		else if (markPreviouslyRemoteManagedMacAsRemovedURL is equal to "") then
			set (end of buildResultsOutput) to "⚠️		FAILED TO RETRIEVE markPreviouslyRemoteManagedMacAsRemovedURL"
			set (end of buildResultsOutput) to ""
		else if ((name of parentFolder) is equal to "Build Tools") then
			set macLandFolder to (container of parentFolder)
			set zipsForAutoUpdateFolderPath to ((POSIX path of (macLandFolder as alias)) & "ZIPs for Auto-Update/")
			try
				do shell script "mkdir -p " & (quoted form of zipsForAutoUpdateFolderPath)
			end try
			set scriptTypeFolders to (get folders of macLandFolder)
			repeat with thisScriptTypeFolder in scriptTypeFolders
				if (((name of thisScriptTypeFolder) as text) is equal to "ZIPs for Auto-Update") then
					set latestVersionsFilePath to ((POSIX path of (thisScriptTypeFolder as alias)) & "latest-versions.txt")
					do shell script "rm -f " & (quoted form of latestVersionsFilePath) & "; touch " & (quoted form of latestVersionsFilePath)
					
					set zipFilesForAutoUpdate to (every file of thisScriptTypeFolder whose name extension is "zip")
					repeat with thisScriptZip in zipFilesForAutoUpdate
						-- NOTE: The "fgreset" script is no longer installed since we are no longer installing older than macOS 10.15 Catalina.
						-- So, this code to include it for auto-updating is now commented out, but it is being left in place in case it is useful in the future.
						(*
						if (((name of thisScriptZip) as text) is equal to "fgreset.zip") then
							do shell script ("ditto -xk --noqtn " & (quoted form of (POSIX path of (thisScriptZip as alias))) & " ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-Versions/")
													
							set thisScriptVersionLine to (do shell script "grep -m 1 '# Version: ' ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-Versions/*.sh")
													
							if (thisScriptVersionLine contains "# Version: ") then
								do shell script "echo '" & (text 1 thru -5 of ((name of thisScriptZip) as text)) & ": " & ((text 12 thru -1 of thisScriptVersionLine) as text) & "' >> " & (quoted form of latestVersionsFilePath)
							end if
													
							do shell script "rm -f ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-Versions/*.sh"
						else
						*)
						do shell script "unzip -jo " & (quoted form of (POSIX path of (thisScriptZip as alias))) & " '*/Contents/Info.plist' -d ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-Versions/"
						set thisAppName to (do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleName' ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-Versions/Info.plist")
						set thisAppVersion to (do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-Versions/Info.plist")
						do shell script "echo '" & thisAppName & ": " & thisAppVersion & "' >> " & (quoted form of latestVersionsFilePath)
						--end if
					end repeat
					do shell script "rm -rf ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-Versions/"
				else if ((((name of thisScriptTypeFolder) as text) is not equal to "Build Tools") and (((name of thisScriptTypeFolder) as text) is not equal to "fgMIB Resources") and (((name of thisScriptTypeFolder) as text) is not equal to "Other Scripts")) then
					set scriptFoldersForThisScriptType to (get folders of thisScriptTypeFolder)
					repeat with thisScriptFolder in scriptFoldersForThisScriptType
						set thisScriptName to ((name of thisScriptFolder) as text)
						set thisScriptFolderPath to (POSIX path of (thisScriptFolder as alias))
						
						set AppleScript's text item delimiters to "-"
						set thisScriptHyphenatedName to ((words of thisScriptName) as text)
						
						-- Only build if .app doesn't exit and Source folder does exist
						set thisScriptAppPath to (thisScriptFolderPath & thisScriptName & ".app")
						
						try
							((thisScriptAppPath as POSIX file) as alias)
							set (end of buildResultsOutput) to "⏭️		" & (name of thisScriptTypeFolder) & " > " & thisScriptName & " ALREADY BUILT"
						on error
							try
								set thisScriptSourcePath to (thisScriptFolderPath & "Source/" & thisScriptName & ".applescript")
								((thisScriptSourcePath as POSIX file) as alias)
								
								do shell script "rm -f " & (quoted form of (thisScriptFolderPath & thisScriptHyphenatedName & ".zip")) & " " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip"))
								
								set thisScriptSource to (do shell script "cat " & (quoted form of thisScriptSourcePath) without altering line endings) -- VERY IMPORTANT to preserve "LF" line endings for multi-line "do shell script" commands within scripts to be able to work properly.
								
								set obfuscatedAdminPasswordPlaceholder to "\"[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]\""
								set obfuscatedWiFiPasswordPlaceholder to "\"[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]\""
								set obfuscatedCheckRemoteManagedMacsLogURLPlaceholder to "\"[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED CHECK REMOTE MANAGED MACS LOG URL]\""
								set obfuscatedLogRemoteManagedMacURLPlaceholder to "\"[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED LOG REMOTE MANAGED MAC URL]\""
								set obfuscatedMarkPreviouslyRemoteManagedMacAsRemovedURLPlaceholder to "\"[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED MARK PREVIOUSLY REMOTE MANAGED MAC AS REMOVED URL]\""
								
								set addBuildRunOnlyArg to ""
								if (thisScriptSource contains "-- Build Flag: Run-Only" or (thisScriptSource contains obfuscatedAdminPasswordPlaceholder) or (thisScriptSource contains obfuscatedWiFiPasswordPlaceholder) or (thisScriptSource contains obfuscatedCheckRemoteManagedMacsLogURLPlaceholder) or (thisScriptSource contains obfuscatedLogRemoteManagedMacURLPlaceholder) or (thisScriptSource contains obfuscatedMarkPreviouslyRemoteManagedMacAsRemovedURLPlaceholder)) then
									set addBuildRunOnlyArg to " -x"
									
									if ((thisScriptSource contains obfuscatedAdminPasswordPlaceholder) or (thisScriptSource contains obfuscatedWiFiPasswordPlaceholder) or (thisScriptSource contains obfuscatedCheckRemoteManagedMacsLogURLPlaceholder) or (thisScriptSource contains obfuscatedLogRemoteManagedMacURLPlaceholder) or (thisScriptSource contains obfuscatedMarkPreviouslyRemoteManagedMacAsRemovedURLPlaceholder)) then
										set obfuscateCharactersShiftCount to (random number from 100000 to 999999)
										
										if (thisScriptSource contains obfuscatedAdminPasswordPlaceholder) then
											tell me to set obfuscatedAdminPassword to shiftString(adminPassword)
											
											set AppleScript's text item delimiters to obfuscatedAdminPasswordPlaceholder
											set thisScriptSourcePartsSplitAtObfuscatedAdminPasswordPlaceholder to (every text item of thisScriptSource)
											
											set AppleScript's text item delimiters to "x(\"" & obfuscatedAdminPassword & "\")
try
	do shell script (\"id \" & (quoted form of adminUsername))
	set verifiedAdminPassword to false
	try
		set verifiedAdminPassword to (\"VERIFIED ADMIN PASSWORD\" is equal to (do shell script \"echo 'VERIFIED ADMIN PASSWORD'\" user name adminUsername password adminPassword with administrator privileges))
	end try"
											
											if (previousAdminPassword is not equal to "") then
												tell me to set obfuscatedPreviousAdminPassword to shiftString(previousAdminPassword)
												set AppleScript's text item delimiters to (AppleScript's text item delimiters & "
	if (not verifiedAdminPassword) then
		set adminPassword to x(\"" & obfuscatedPreviousAdminPassword & "\")
		try
			set verifiedAdminPassword to (\"VERIFIED ADMIN PASSWORD\" is equal to (do shell script \"echo 'VERIFIED ADMIN PASSWORD'\" user name adminUsername password adminPassword with administrator privileges))
		end try
	end if")
											end if
											
											set AppleScript's text item delimiters to (AppleScript's text item delimiters & "
	if (not verifiedAdminPassword) then
		try
			activate
		end try
		try
			do shell script \"afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &\"
		end try
		display alert \"CRITICAL “\" & (name of me) & \"” ERROR:

Failed to Verify “\" & adminUsername & \"” Admin Password\" message \"This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research.\" buttons {\"Shut Down\"} default button 1 as critical
		tell application id \"com.apple.systemevents\" to shut down with state saving preference
		quit
		delay 10
	end if
on error
	try
		activate
	end try
	try
		do shell script \"afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &\"
	end try
	display alert \"CRITICAL “\" & (name of me) & \"” ERROR:

“\" & adminUsername & \"” Admin User Not Found\" message \"This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research.\" buttons {\"Quit\"} default button 1 as critical
	quit
	delay 10
end try")
											set thisScriptSource to (thisScriptSourcePartsSplitAtObfuscatedAdminPasswordPlaceholder as text)
										end if
										
										if (thisScriptSource contains obfuscatedWiFiPasswordPlaceholder) then
											tell me to set obfuscatedWiFiPassword to shiftString(wiFiPassword)
											
											set AppleScript's text item delimiters to obfuscatedWiFiPasswordPlaceholder
											set thisScriptSourcePartsSplitAtObfuscatedWiFiPasswordPlaceholder to (every text item of thisScriptSource)
											
											set AppleScript's text item delimiters to "x(\"" & obfuscatedWiFiPassword & "\")"
											set thisScriptSource to (thisScriptSourcePartsSplitAtObfuscatedWiFiPasswordPlaceholder as text)
										end if
										
										if (thisScriptSource contains obfuscatedCheckRemoteManagedMacsLogURLPlaceholder) then
											tell me to set obfuscatedCheckRemoteManagedMacsLogURL to shiftString(checkRemoteManagedMacsLogURL)
											
											set AppleScript's text item delimiters to obfuscatedCheckRemoteManagedMacsLogURLPlaceholder
											set thisScriptSourcePartsSplitAtObfuscatedCheckRemoteManagedMacsLogURLPlaceholder to (every text item of thisScriptSource)
											
											set AppleScript's text item delimiters to "x(\"" & obfuscatedCheckRemoteManagedMacsLogURL & "\")"
											set thisScriptSource to (thisScriptSourcePartsSplitAtObfuscatedCheckRemoteManagedMacsLogURLPlaceholder as text)
										end if
										
										if (thisScriptSource contains obfuscatedLogRemoteManagedMacURLPlaceholder) then
											tell me to set obfuscatedLogRemoteManagedMacURL to shiftString(logRemoteManagedMacURL)
											
											set AppleScript's text item delimiters to obfuscatedLogRemoteManagedMacURLPlaceholder
											set thisScriptSourcePartsSplitAtObfuscatedLogRemoteManagedMacURLPlaceholder to (every text item of thisScriptSource)
											
											set AppleScript's text item delimiters to "x(\"" & obfuscatedLogRemoteManagedMacURL & "\")"
											set thisScriptSource to (thisScriptSourcePartsSplitAtObfuscatedLogRemoteManagedMacURLPlaceholder as text)
										end if
										
										if (thisScriptSource contains obfuscatedMarkPreviouslyRemoteManagedMacAsRemovedURLPlaceholder) then
											tell me to set obfuscatedMarkPreviouslyRemoteManagedMacAsRemovedURL to shiftString(markPreviouslyRemoteManagedMacAsRemovedURL)
											
											set AppleScript's text item delimiters to obfuscatedMarkPreviouslyRemoteManagedMacAsRemovedURLPlaceholder
											set thisScriptSourcePartsSplitAtObfuscatedMarkPreviouslyRemoteManagedMacAsRemovedURLPlaceholder to (every text item of thisScriptSource)
											
											set AppleScript's text item delimiters to "x(\"" & obfuscatedMarkPreviouslyRemoteManagedMacAsRemovedURL & "\")"
											set thisScriptSource to (thisScriptSourcePartsSplitAtObfuscatedMarkPreviouslyRemoteManagedMacAsRemovedURLPlaceholder as text)
										end if
										
										set thisScriptSource to thisScriptSource & "

on x(s)
	set y to ((id of s) as list)
	repeat with c in y
		set (contents of c) to (c - " & obfuscateCharactersShiftCount & ")
	end repeat
	return (string id y)
end x"
									end if
								end if
								
								set thisScriptAppBundleIdentifier to (bundleIdentifierPrefix & thisScriptHyphenatedName)
								set thisScriptAppVersion to "UNKOWN VERSION"
								
								try
									do shell script "osacompile" & addBuildRunOnlyArg & " -o " & (quoted form of thisScriptAppPath) & " -e " & (quoted form of thisScriptSource)
									
									try
										do shell script ("tccutil reset All " & (quoted form of ("com.apple.ScriptEditor.id" & thisScriptHyphenatedName))) -- If it was previously built with Script Editor
									end try
									
									set thisScriptAppInfoPlistPath to (thisScriptAppPath & "/Contents/Info.plist")
									
									try
										((thisScriptAppInfoPlistPath as POSIX file) as alias)
										
										if (thisScriptSource contains "-- Build Flag: LSUIElement") then
											do shell script "plutil -replace LSUIElement -bool true " & (quoted form of thisScriptAppInfoPlistPath)
										end if
										
										if (thisScriptSource contains "-- Build Flag: CFBundleAlternateNames: [") then
											set AppleScript's text item delimiters to "-- Build Flag: CFBundleAlternateNames: "
											set thisScriptAppAlternateNamesPart to ((text item 2 of thisScriptSource) as text)
											set thisScriptAppAlternateNamesJSON to ((first paragraph of thisScriptAppAlternateNamesPart) as text)
											do shell script "plutil -replace CFBundleAlternateNames -json " & (quoted form of thisScriptAppAlternateNamesJSON) & " " & (quoted form of thisScriptAppInfoPlistPath)
										end if
										
										do shell script ("
plutil -remove LSMinimumSystemVersionByArchitecture " & (quoted form of thisScriptAppInfoPlistPath) & "
plutil -replace LSMinimumSystemVersion -string '10.13' " & (quoted form of thisScriptAppInfoPlistPath) & "

plutil -replace LSMultipleInstancesProhibited -bool true " & (quoted form of thisScriptAppInfoPlistPath) & "

# These two are so that error text is always in English, so that I can trust and conditions which check errors.
plutil -replace CFBundleAllowMixedLocalizations -bool false " & (quoted form of thisScriptAppInfoPlistPath) & "
plutil -replace CFBundleDevelopmentRegion -string 'en_US' " & (quoted form of thisScriptAppInfoPlistPath) & "

plutil -replace NSAppleEventsUsageDescription -string " & (quoted form of ("You MUST click the “OK” button for “" & thisScriptName & "” to be able to function.")) & " " & (quoted form of thisScriptAppInfoPlistPath))
										
										set thisScriptAppVersion to (currentYear & "." & (word 1 of shortCurrentDateString) & "." & (word 2 of shortCurrentDateString))
										if (thisScriptSource contains "-- Version: ") then
											set AppleScript's text item delimiters to "-- Version: "
											set thisScriptAppVersionPart to ((text item 2 of thisScriptSource) as text)
											set thisScriptAppVersion to ((first paragraph of thisScriptAppVersionPart) as text)
										end if
										do shell script "plutil -replace CFBundleShortVersionString -string " & (quoted form of thisScriptAppVersion) & " " & (quoted form of thisScriptAppInfoPlistPath)
										
										do shell script ("
mv " & (quoted form of (thisScriptAppPath & "/Contents/MacOS/applet")) & " " & (quoted form of (thisScriptAppPath & "/Contents/MacOS/" & thisScriptName)) & "
plutil -replace CFBundleExecutable -string " & (quoted form of thisScriptName) & " " & (quoted form of thisScriptAppInfoPlistPath) & "

mv " & (quoted form of (thisScriptAppPath & "/Contents/Resources/applet.rsrc")) & " " & (quoted form of (thisScriptAppPath & "/Contents/Resources/" & thisScriptName & ".rsrc")) & "

rm -f " & (quoted form of (thisScriptAppPath & "/Contents/Resources/applet.icns")) & "
ditto " & (quoted form of (thisScriptFolderPath & "Source/" & thisScriptName & " Icon/applet.icns")) & " " & (quoted form of (thisScriptAppPath & "/Contents/Resources/" & thisScriptName & ".icns")) & "
plutil -replace CFBundleIconFile -string " & (quoted form of thisScriptName) & " " & (quoted form of thisScriptAppInfoPlistPath) & "
if [[ -f " & (quoted form of (thisScriptFolderPath & "Source/" & thisScriptName & " Icon/Assets.car")) & " ]]; then
	ditto " & (quoted form of (thisScriptFolderPath & "Source/" & thisScriptName & " Icon/Assets.car")) & " " & (quoted form of (thisScriptAppPath & "/Contents/Resources/Assets.car")) & "
	plutil -replace CFBundleIconName -string 'AppIcon' " & (quoted form of thisScriptAppInfoPlistPath) & "
fi
")
										
										set thisScriptAppIconTwemojiAttribution to ""
										if (thisScriptSource contains "App Icon is “") then
											set AppleScript's text item delimiters to {"App Icon is “", "” from Twemoji"}
											set thisScriptAppIconEmojiName to ((text item 2 of thisScriptSource) as text)
											set thisScriptAppIconTwemojiAttribution to "

App Icon is “" & thisScriptAppIconEmojiName & "” from Twemoji by Twitter licensed under CC-BY 4.0"
										end if
										
										do shell script ("
plutil -replace NSHumanReadableCopyright -string " & (quoted form of ("Copyright © " & currentYear & " Free Geek
Designed and Developed by Pico Mitchell" & thisScriptAppIconTwemojiAttribution)) & " " & (quoted form of thisScriptAppInfoPlistPath) & "

# Do CFBundleIdentifier SECOND TO LAST because each script checks that it was set properly or alerts that not built correctly.
plutil -replace CFBundleIdentifier -string " & (quoted form of thisScriptAppBundleIdentifier) & " " & (quoted form of thisScriptAppInfoPlistPath) & "

# Add custom FGBuiltByMacLandScriptBuilder key VERY LAST for scripts to check to alert if not built correctly.
plutil -replace FGBuiltByMacLandScriptBuilder -bool true " & (quoted form of thisScriptAppInfoPlistPath) & "

chmod a-w " & (quoted form of (thisScriptAppPath & "/Contents/Resources/Scripts/main.scpt"))) -- The "main.scpt" must NOT be writable to prevent the code signature from being invalidated: https://developer.apple.com/library/archive/releasenotes/AppleScript/RN-AppleScript/RN-10_8/RN-10_8.html#//apple_ref/doc/uid/TP40000982-CH108-SW8
										
										try
											(((thisScriptFolderPath & "Source/Resources/") as POSIX file) as alias)
											do shell script ("
ditto " & (quoted form of (thisScriptFolderPath & "Source/Resources/")) & " " & (quoted form of (thisScriptAppPath & "/Contents/Resources/")) & "
rm -f " & (quoted form of (thisScriptAppPath & "/Contents/Resources/.DS_Store")))
										end try
										
										try
											do shell script ("xattr -crs " & (quoted form of thisScriptAppPath)) -- Any xattrs MUST be cleared for 'codesign' to not error (this MUST be done BEFORE code signing the following Launcher script, if created, since signing shell scripts stores the code signature in the xattrs, and those specific xattrs do not prevent code signing of the app itself).
										end try
										
										try
											if (thisScriptSource contains "-- Build Flag: IncludeSignedLauncher") then
												-- The following "Launch [APP NAME]" script is created and SIGNED so that it can be used for the LaunchAgents and/or LaunchDaemons, and it MUST be signed so that the "AssociatedBundleIdentifier" key can be used in macOS 13 Ventura so that the LA/LD is properly displayed as being for the specified app.
												-- This is because the executable in the LA/LD MUST have a Code Signing Team ID that matches the Team ID of the app Bundle ID specified in the "AssociatedBundleIdentifiers" key (as described in https://developer.apple.com/documentation/servicemanagement/updating_helper_executables_from_earlier_versions_of_macos?language=objc#4065210).
												-- We DO NOT want to have the LAs/LDs just run the app binary directly because if the app is launched that way via the LA/LD and then the LA/LD is removed during that execution the app will be terminated immediately when "launchctl bootout" is run.
												-- That issue has always been avoided by using the "/usr/bin/open" binary to launch the app instead. But using "/usr/bin/open" directly in the LA/LD on macOS 13 Ventura makes it show as just running "open" from an unidentified developer in the new Login Items list, which may seem suspicious or confusing.
												-- Making this simple SIGNED script that just runs "/usr/bin/open" and then using the "AssociatedBundleIdentifiers" allows the LA/LD to be properly displayed as being for the specified app.
												-- When on macOS 12 Monterey and older, the "AssociatedBundleIdentifiers" will just be ignored and the "Launch [APP NAME]" will function the same as if we directly specified "/usr/bin/open" with the path to the app in the LA/LD.
												-- Search for "AssociatedBundleIdentifiers" throughout other scripts to see the LA/LD creation code.
												do shell script ("echo '#!/bin/sh
/usr/bin/open -na \"${0%/Contents/*}\"' > " & (quoted form of (thisScriptAppPath & "/Contents/Resources/Launch " & thisScriptName)) & "
chmod +x " & (quoted form of (thisScriptAppPath & "/Contents/Resources/Launch " & thisScriptName)) & "
codesign -s 'Developer ID Application' --identifier " & (quoted form of (bundleIdentifierPrefix & "Launch-" & thisScriptHyphenatedName)) & " --strict " & (quoted form of (thisScriptAppPath & "/Contents/Resources/Launch " & thisScriptName)))
											end if
										end try
										
										try
											do shell script ("
codesign -fs 'Developer ID Application' --strict " & (quoted form of thisScriptAppPath) & " || exit 1

touch " & (quoted form of thisScriptAppPath) & "
	
ditto -ck --keepParent --sequesterRsrc --zlibCompressionLevel 9 " & (quoted form of thisScriptAppPath) & " " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip")))
										on error codeSignError
											do shell script "rm -rf " & (quoted form of thisScriptAppPath)
											tell me
												activate
												display alert "Code Sign & ZIP “" & thisScriptName & "” Error" message codeSignError as critical
											end tell
										end try
									on error infoPlistError
										do shell script "rm -rf " & (quoted form of thisScriptAppPath)
										tell me
											activate
											display alert "“" & thisScriptName & "” Info Plist Error" message infoPlistError as critical
										end tell
									end try
								on error osaCompileError
									do shell script "rm -rf " & (quoted form of thisScriptAppPath)
									tell me
										activate
										display alert "Compile “" & thisScriptName & "” Error" message osaCompileError as critical
									end tell
								end try
								
								try
									do shell script ("
tccutil reset All " & (quoted form of thisScriptAppBundleIdentifier) & "

# If it was previously built with default Script Debugger
tccutil reset All " & (quoted form of ("com.mycompany." & thisScriptHyphenatedName)) & "

# If it was previously built with my Script Debugger
tccutil reset All " & (quoted form of ("com.randomapplications." & thisScriptHyphenatedName)))
								end try
								
								try
									(((zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip") as POSIX file) as alias)
									
									if (addBuildRunOnlyArg is not equal to "") then
										set (end of buildResultsOutput) to "✅🔒	" & (name of thisScriptTypeFolder) & " > BUILT (AS RUN-ONLY) " & thisScriptName & " " & thisScriptAppVersion
									else
										set (end of buildResultsOutput) to "✅🛠	" & (name of thisScriptTypeFolder) & " > BUILT " & thisScriptName & " " & thisScriptAppVersion
									end if
								on error
									set (end of buildResultsOutput) to "⚠️		" & (name of thisScriptTypeFolder) & " > FAILED TO BUILD " & thisScriptName
								end try
							on error
								-- NOTE: The "fgreset" script is no longer installed since we are no longer installing older than macOS 10.15 Catalina.
								-- So, this code to include it for installation and auto-updating is now commented out, but it is being left in place in case it is useful in the future.
								(*
								try
									set thisFGresetSourcePath to (thisScriptFolderPath & "fgreset.sh")
									((thisFGresetSourcePath as POSIX file) as alias)
									
									set thisScriptVersion to "UNKNOWN VERSION"
									try
										set thisScriptVersionLine to (do shell script ("grep -m 1 '# Version: ' " & (quoted form of thisFGresetSourcePath)))
										if (thisScriptVersionLine contains "# Version: ") then set thisScriptVersion to ((text 12 thru -1 of thisScriptVersionLine) as text)
									end try
									
									do shell script ("
rm -rf ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-fgreset
mkdir -p ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-fgreset

# CANNOT directly edit shell script source strings in AppleScript (like we do with AppleScript source) since it messes up escaped characters for ANSI styles. So, we'll use 'sed' instead.
# DO NOT pass the base64 string to 'base64 -D' using a here-string since that requires writing a temp file to the filesystem which will NOT be writable when the password is decoded. Use echo and pipe instead since piping does not write to the filesystem.
sed \"s/'\\[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD\\]'/\\\"\\$(echo '$(/bin/echo -n " & (quoted form of adminPassword) & " | base64)' | base64 -D)\\\"/\" " & (quoted form of thisFGresetSourcePath) & " > ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-fgreset/fgreset.sh

chmod +x ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-fgreset/fgreset.sh
codesign -s 'Developer ID Application' --identifier " & (quoted form of (bundleIdentifierPrefix & "fgreset")) & " --strict ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-fgreset/fgreset.sh

# DO NOT '--keepParent' WHEN DITTO ZIPPING A SINGLE FILE!
ditto -ck --sequesterRsrc --zlibCompressionLevel 9 ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-fgreset/fgreset.sh " & (quoted form of (zipsForAutoUpdateFolderPath & "fgreset.zip")) & "
									
rm -rf ${TMPDIR:-/private/tmp/}MacLand-Script-Builder-fgreset
									
mkdir -p " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/Global/Scripts/")) & "
rm -f " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/Global/Scripts/fgreset.zip")) & "
ditto " & (quoted form of (zipsForAutoUpdateFolderPath & "fgreset.zip")) & " " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/Global/Scripts/")))
									
									try
										(((zipsForAutoUpdateFolderPath & "fgreset.zip") as POSIX file) as alias)
										set (end of buildResultsOutput) to "📄		" & (name of thisScriptTypeFolder) & " > ZIPPED " & thisScriptName & " " & thisScriptVersion
									on error
										set (end of buildResultsOutput) to "⚠️		" & (name of thisScriptTypeFolder) & " > FAILED TO ZIP " & thisScriptName & " " & thisScriptVersion
									end try
								on error
								*)
								set (end of buildResultsOutput) to "❌		" & (name of thisScriptTypeFolder) & " > " & thisScriptName & " NOT APPLESCRIPT APP"
								--end try
							end try
						end try
						
						if ((((name of thisScriptTypeFolder) as text) is equal to "Production Scripts") or (thisScriptName is equal to "Free Geek Updater")) then
							try
								(((zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip") as POSIX file) as alias)
								
								if (thisScriptName is equal to "Free Geek Login Progress") then
									do shell script ("
mkdir -p " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Install Packages Script/Tools/")) & "
rm -f " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Install Packages Script/Tools/" & thisScriptHyphenatedName & ".zip")) & "
ditto " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip")) & " " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Install Packages Script/Tools/")) & "

mkdir -p " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-error-occurred/Tools/")) & "
rm -f " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-error-occurred/Tools/" & thisScriptHyphenatedName & ".zip")) & "
ditto " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip")) & " " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-error-occurred/Tools/")) & "

mkdir -p " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-snapshot-reset/Tools/")) & "
rm -f " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-snapshot-reset/Tools/" & thisScriptHyphenatedName & ".zip")) & "
ditto " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip")) & " " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-snapshot-reset/Tools/")))
								else
									set userAppsDarwinVersionFolder to "darwin-all-versions"
									if ((thisScriptName is equal to "Free Geek Snapshot Helper") or (thisScriptName is equal to "Free Geek Reset")) then
										set userAppsDarwinVersionFolder to "darwin-ge-19"
									end if
									do shell script ("
mkdir -p " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/User/fg-demo/Apps/" & userAppsDarwinVersionFolder & "/")) & "
rm -f " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/User/fg-demo/Apps/" & userAppsDarwinVersionFolder & "/" & thisScriptHyphenatedName & ".zip")) & "
ditto " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip")) & " " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/User/fg-demo/Apps/" & userAppsDarwinVersionFolder & "/")))
								end if
							end try
						end if
						
					end repeat
					
					set (end of buildResultsOutput) to ""
				end if
			end repeat
		end if
	end tell
	
	activate
	set buildResultsOutputReply to (choose from list (items 1 thru -2 of buildResultsOutput) with prompt "MacLand Script Builder Results" OK button name "Quit" cancel button name "Build Again" with title "MacLand Script Builder" with empty selection allowed)
	
	if (buildResultsOutputReply is not equal to false) then
		exit repeat
	end if
end repeat

-- From: https://stackoverflow.com/questions/14612235/protecting-an-applescript-script/14616010#14616010
on shiftString(sourceString)
	set stringIDs to ((id of sourceString) as list)
	repeat with thisCharacterID in stringIDs
		set (contents of thisCharacterID) to (thisCharacterID + obfuscateCharactersShiftCount)
	end repeat
	return (string id stringIDs)
end shiftString
