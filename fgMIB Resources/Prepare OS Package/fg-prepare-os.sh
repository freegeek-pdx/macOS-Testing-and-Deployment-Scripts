#!/bin/bash

#
# Created by Pico Mitchell on 2/15/21.
# For MacLand @ Free Geek
#
# MIT License
#
# Copyright (c) 2021 Free Geek
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# ARGUMENTS FROM PACKAGE INSTALLATION:
# $0 = path to this script
# $1 = path to the parent package
# $2 = path to the installed resources folder
# $3 = path to root of selected install disk
# $4 = "/" on startup disk

# Only run if running as root on first boot after OS installation, or on a clean installation prepared by fg-install-os.
# IMPORTANT: If on a clean installation prepared by fg-install-os, AppleSetupDone will have been created to not show Setup Assistant while the package installations run via LaunchDaemon.

readonly SCRIPT_VERSION='2022.4.8-1'

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy.

DARWIN_MAJOR_VERSION="$(uname -r | cut -d '.' -f 1)" # 17 = 10.13, 18 = 10.14, 19 = 10.15, 20 = 11.0, etc.
readonly DARWIN_MAJOR_VERSION

critical_error_occurred=false

if (( DARWIN_MAJOR_VERSION >= 17 )) && [[ ! -f '/private/var/db/.AppleSetupDone' || -f '/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist' ]] && \
   [[ "$3" == '/' && "${EUID:-$(id -u)}" == '0' && -z "$(dscl . -list /Users Password 2> /dev/null | awk '($NF != "*" && $1 != "_mbsetupuser") { print $1 }')" ]]; then # "_mbsetupuser" may have a password if customizing a clean install that presented Setup Assistant.
	
	log_path='/Users/Shared/Build Info/Prepare OS Log.txt'
	if [[ ! -f '/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist' ]]; then # The log file will have already been started when run on boot via LaunchDaemon, so we do not want to delete it.
		rm -rf '/Users/Shared/Build Info' # "Build Info" folder should not exist yet, but delete it to be sure.
		mkdir -p '/Users/Shared/Build Info'
		chown -R 502:20 '/Users/Shared/Build Info' # Want standard auto-login user to own the "Build Info" folder, but keep log owned by root.
	fi

	write_to_log() {
		echo -e "$(date '+%D %T')\t$1" >> "${log_path}"
	}

	write_to_log "Starting Prepare OS (version ${SCRIPT_VERSION})"

	error_occurred_resources_install_path='/Users/Shared/fg-error-occurred'

	if [[ ! -f '/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist' ]]; then

		# ANNOUNCE STARTING CUSTOMIZATION (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)
		# Audio drivers (or something) need a few seconds before audio will be able to play when run early on boot via LaunchDaemon. So try for up to 60 seconds before continuing.
		# Do not announce if started via LaunchDaemon since that would have already announced this same thing earlier.
		
		for (( wait_to_play_seconds = 0; wait_to_play_seconds < 60; wait_to_play_seconds ++ )); do
			osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
			if afplay "$2/Announcements/fg-starting-customizations.aiff" &> /dev/null; then
				afplay "$2/Announcements/fg-do-not-disturb.aiff" & # Continue before this is done being said.
				break
			else
				sleep 1
			fi
		done


		# PREPARE fg-error-occurred LAUNCH DAEMON (which will be deleted after successfully finishing customizations but could run when rebooting after an error occurred)
		# Do not need to set this up if fg-install-packages LaunchDaemon exists since it will do this same error display on its own when rebooting after an error occurred.
		# The fg-install-packages LaunchDaemon needs to do its own identical error handling like this in case an error occurrs before or after this was created or deleted by fg-prepare-os package.

		write_to_log 'Setting Up Error Display LaunchDaemon'

		rm -rf "${error_occurred_resources_install_path}"
		ditto "$2/fg-error-occurred" "${error_occurred_resources_install_path}"
		chmod +x "${error_occurred_resources_install_path}/fg-error-occurred.sh"
		
		PlistBuddy \
			-c 'Add :Label string org.freegeek.fg-error-occurred' \
			-c "Add :Program string ${error_occurred_resources_install_path}/fg-error-occurred.sh" \
			-c 'Add :RunAtLoad bool true' \
			-c 'Add :StandardOutPath string /dev/null' \
			-c 'Add :StandardErrorPath string /dev/null' \
			'/Library/LaunchDaemons/org.freegeek.fg-error-occurred.plist' &> /dev/null
	fi


	if [[ ! -f '/private/var/db/.AppleSetupDone' ]]; then

		# SKIP SETUP ASSISTANT (users will be created by this script)
		# Do this before creating reset Snapshot since we also do not want Setup Assistant during Snapshot reset.

		write_to_log 'Skipping Setup Assistant'

		touch '/private/var/db/.AppleSetupDone'
		chown 0:0 '/private/var/db/.AppleSetupDone' # Make sure this file is properly owned by root:wheel.

		if [[ ! -f '/private/var/db/.AppleSetupDone' ]]; then
			write_to_log 'ERROR: Failed to Skip Setup Assistant'
			critical_error_occurred=true
		fi
	fi


	if [[ -n "$1" && -f "$1" ]]; then

		# DELETE PACKAGE PARENT FOLDER IF IN "startosinstall --installpackage" LOCATION
		# Do this before creating reset Snapshot so it does not have to be dealt with in fg-snapshot-reset.

		if [[ "$1" == '/System/Volumes/Data/.com.apple.templatemigration.boot-install/'* ]]; then
			# This is where macOS 11 Big Sur will store the package when included via "installpackage". MAKE SURE TO CHECK THIS IS THE SAME LOCATION FOR FUTURE VERSIONS.
			
			write_to_log 'Deleting Package Parent Folder (com.apple.templatemigration.boot-install)'

			rm -rf '/System/Volumes/Data/.com.apple.templatemigration.boot-install/'
		elif [[ "$1" == '/Library/Application Support/com.apple.installer/'* ]]; then
			# This is where macOS 10.13 High Sierra through macOS 10.15 Catalina will store the package when included via "installpackage".

			write_to_log 'Deleting Package Parent Folder (com.apple.installer)'

			rm -rf '/Library/Application Support/com.apple.installer/'
		elif [[ "$1" != '/Users/Shared/fg-install-packages/'* ]]; then
			# Log a note if installed via "startosinstall --installpackage" and package is in a different location.

			write_to_log 'NOTE: New Location for Package Parent Folder'
		fi
	fi


	if ! $critical_error_occurred; then
		
		# INSTALL GLOBAL APPS
		# Do this before creating reset Snapshot since we want the customer to have these Apps pre-installed.
		
		for this_global_app_installer in "$2/Global/Apps/all-versions/"*'.'* "$2/Global/Apps/darwin-${DARWIN_MAJOR_VERSION}/"*'.'*; do
			if [[ -f "${this_global_app_installer}" ]]; then
				if [[ "${this_global_app_installer}" == *'.zip' ]]; then
					this_global_app_name="$(basename "${this_global_app_installer}" '.zip')"

					write_to_log "Installing Global App \"${this_global_app_name}\""

					rm -rf "/Applications/${this_global_app_name}.app" # Delete app if it already exist from previous customization before reset.
					ditto -x -k --noqtn "${this_global_app_installer}" '/Applications' &> /dev/null

					if [[ -d "/Applications/${this_global_app_name}.app" ]]; then
						touch "/Applications/${this_global_app_name}.app"
						chown -R 501:20 "/Applications/${this_global_app_name}.app" # Make sure the customer user account ends up owning the pre-installed apps.
					fi
				elif [[ "${this_global_app_installer}" == *'.dmg' ]]; then
					#write_to_log "Mounting \"$(basename "${this_global_app_installer}" '.dmg')\" Disk Image for Global Apps"

					dmg_mount_path="$(hdiutil attach "${this_global_app_installer}" -nobrowse -readonly -plist 2> /dev/null | awk -F '<string>|</string>' '/<string>\/Volumes\// { print $2; exit }')"

					if [[ -d "${dmg_mount_path}" ]]; then
						for this_dmg_app in "${dmg_mount_path}/"*'.app'; do
							if [[ -d "${this_dmg_app}" ]]; then
								this_global_app_name="$(basename "${this_dmg_app}" '.app')"

								write_to_log "Installing Global App \"${this_global_app_name}\""

								rm -rf "/Applications/${this_global_app_name}.app" # Delete app if it already exist from previous customization before reset.
								ditto "${this_dmg_app}" "/Applications/${this_global_app_name}.app" &> /dev/null

								if [[ -d "/Applications/${this_global_app_name}.app" ]]; then
									xattr -drs com.apple.quarantine "/Applications/${this_global_app_name}.app"
									touch "/Applications/${this_global_app_name}.app"
									chown -R 501:20 "/Applications/${this_global_app_name}.app" # Make sure the customer user account ends up owning the pre-installed apps.
								fi
							fi
						done

						#write_to_log "Unmounting \"$(basename "${this_global_app_installer}" '.dmg')\" Disk Image for Global Apps"
						hdiutil detach "${dmg_mount_path}" &> /dev/null
					fi
				else
					write_to_log "Skipping Unrecognized Global App Installer (${this_user_app_installer})"
				fi
			fi
		done


		if (( DARWIN_MAJOR_VERSION >= 19 )); then

			# PREPARE fg-snapshot-reset RESOURCES AND LAUNCH DAEMON AND PROGRESS LAUNCH AGENT AND SNAPSHOT FOR FULL RESET *BEFORE* DOING *ANYTHING* ELSE

			# Only prepare reset Snapshot on macOS 10.15 Catalina and newer since:
				# macOS 10.14 Mojave and older do not store "trimforce" setting in NVRAM (it is stored in the filesystem, so it would get undone with the reset Snapshot).
				# macOS 10.13 High Sierra is not guaranteed to be APFS so the Snapshot could not always be created and it would be confusing to have multiple reset options for the same version of macOS.
				# Also, we can do full resets with fgreset on macOS 10.14 Mojave and older (and we do not even install macOS 10.14 Mojave anymore, but we do still install macOS 10.13 High Sierra).
				# So, fgreset will continue to be used on older versions of macOS.

			write_to_log 'Setting Up Snapshot Reset LaunchDaemon'

			snapshot_reset_resources_install_path='/Users/Shared/fg-snapshot-reset'
			rm -rf "${snapshot_reset_resources_install_path}"
			ditto "$2/fg-snapshot-reset" "${snapshot_reset_resources_install_path}"
			chmod +x "${snapshot_reset_resources_install_path}/fg-snapshot-reset.sh"
			
			PlistBuddy \
				-c 'Add :Label string org.freegeek.fg-snapshot-reset' \
				-c "Add :Program string ${snapshot_reset_resources_install_path}/fg-snapshot-reset.sh" \
				-c 'Add :RunAtLoad bool true' \
				-c 'Add :StandardOutPath string /dev/null' \
				-c 'Add :StandardErrorPath string /dev/null' \
				'/Library/LaunchDaemons/org.freegeek.fg-snapshot-reset.plist' &> /dev/null
			
			if [[ ! -f "${snapshot_reset_resources_install_path}/fg-snapshot-reset.sh" || ! -f '/Library/LaunchDaemons/org.freegeek.fg-snapshot-reset.plist' ]]; then
				write_to_log 'ERROR: Failed to Setup Reset Snapshot LaunchDaemon'
				critical_error_occurred=true
			fi

			if ! $critical_error_occurred; then
			
				if [[ "$(tmutil listlocalsnapshots /)" == *'com.apple.TimeMachine'* ]]; then
					# Make sure there are not previous Snapshots (which should not happen since this is a clean install, just being thorough).
					write_to_log 'Deleting Previous Snapshots'

					tmutil deletelocalsnapshots / &> /dev/null
				fi

				if [[ ! -f '/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist' && "$(sudo systemsetup -getusingnetworktime)" == *': Off' ]]; then # "sudo" is needed for "systemsetup" within subshell.
					# Network Time will already have been synced and turned off if started via LaunchDaemon since drastic time manipulation during the install can cause an indefinite hang.
					# So, only make sure time is synced here if running via "startosinstall --installpackage" which does not have an issue with drastic time manipulation during this package installation.
					
					write_to_log 'Turning On Network Time Before Creating Reset Snapshot'

					systemsetup -setusingnetworktime on &> /dev/null
					sleep 5 # Give system 5 seconds to sync to correct time before turning off network time and setting to midnight for reset Snapshot.
				fi

				actual_snapshot_time="$(date '+%T')"

				if [[ "${actual_snapshot_time}" != '00:0'* ]]; then # Do not set time all the way back to midnight it was already set back by "fg-install-packages". See "SET TIME BACK TO MIDNIGHT FOR RESET SNAPSHOT" in "fg-install-packages" for more info.

					write_to_log 'Setting Time to Midnight for Reset Snapshot'

					systemsetup -setusingnetworktime off &> /dev/null
					systemsetup -settime '00:00:00' &> /dev/null
					
					# Once, the time did not get set to midnight properly, so keep setting it in a loop for 10 seconds and confirm it was set to be sure.
					for (( set_time_to_midnight_attempt = 0; set_time_to_midnight_attempt < 10; set_time_to_midnight_attempt ++ )); do
						if [[ "$(date '+%T')" != '00:0'* ]]; then
							write_to_log 'Setting Time to Midnight for Reset Snapshot (Again)'
							systemsetup -settime '00:00:00' &> /dev/null
							sleep 1
						fi
					done

					# ABOUT RESET SNAPSHOT TIME MANIPULATION
					# Since macOS will automatically delete Snapshot 24 hours after they are created, I've created the "fg-snapshot-preserver" LaunchDaemon
					# which will be run on boot and at regular intervals to manipulate the date and time to make macOS think that 24 hours has never passed.
					# Since macOS will also delete any Snapshots that are in the future, setting the time to midnight makes it so that no matter what time
					# it happens to be, the reset Snapshot will not be in the future when the date is set back to the reset Snapshot date.
					# Creating the reset Snapshot at midnight is also a way to "tag" the reset Snapshot so that it is clear that this is a valid reset Snapshot,
					# this can be useful to validate the reset Snapshot code as well as visually when restoring the reset Snapshot (even though the reset Snapshot should be the only available Snapshot).
					# See comments at the top of "fg-snapshot-preserver" for more information about this and another solution that is used to prevent the reset Snapshot from being deleted by macOS.
				fi

				if [[ -f '/Users/Shared/fg-install-packages/actual-snapshot-time.txt' ]]; then
					# If time was already set back by fg-install-packages, then save that actual time for Snapshot reset, and set back to it after reset Snapshot is created.
					actual_snapshot_time="$(cat /Users/Shared/fg-install-packages/actual-snapshot-time.txt)"
				fi
				
				echo "${actual_snapshot_time}" > "${snapshot_reset_resources_install_path}/actual-snapshot-time.txt" # Save actual_snapshot_time to be used during Snapshot reset.

				actual_snapshot_date="$(date '+%F')" # Must load this "date" command (used to validate the reset Snapshot) before turning back on Network Time in case the date is not synced when creating the Snapshot.
				
				write_to_log 'Creating Reset Snapshot'

				tmutil localsnapshot &> /dev/null # Create the reset Snapshot.
				# Automatic Snapshots are not enabled by default, so this should be the only Snapshot available to restore.
				# BUT! macOS will automatically delete Snapshots after 24 hours, SO WE ARE MANIPULATING TIME SO macOS THINKS ITS ALWAYS WITHIN 24 HOURS!

				if [[ "$(sudo systemsetup -getusingnetworktime)" == *': Off' ]]; then # "sudo" is needed for "systemsetup" within subshell.
					write_to_log 'Turning On Network Time After Creating Reset Snapshot'

					systemsetup -settime "${actual_snapshot_time}" &> /dev/null
					systemsetup -setusingnetworktime on &> /dev/null
				fi

				reset_snapshot_name="$(tmutil listlocalsnapshots / | grep 'com.apple.TimeMachine' | head -1)"

				# Create flags that reset Snapshot has been created (or not) for other Apps and Scripts to check for (and can use the contents to confirm the Snapshot still exists).

				if [[ "${reset_snapshot_name}" == "com.apple.TimeMachine.${actual_snapshot_date}-00"* ]]; then
					echo "${reset_snapshot_name}" > '/Users/Shared/.fgResetSnapshotCreated'
				else
					echo "${reset_snapshot_name}" > '/Users/Shared/.fgResetSnapshotLost'
					echo "LOST REASON: Snapshot Name != com.apple.TimeMachine.${actual_snapshot_date}-00*" >> '/Users/Shared/.fgResetSnapshotLost'
					
					tmutil deletelocalsnapshots / &> /dev/null
					
					# Still setup fg-snapshot-preserver even if the Snapshot creation failed so that it can be used to display an error instead of preserving the Snapshot.
				fi

				if [[ ! -f '/Users/Shared/.fgResetSnapshotCreated' ]]; then
					write_to_log 'ERROR: Failed to Create Reset Snapshot'
					critical_error_occurred=true
				fi

				if ! $critical_error_occurred; then

					write_to_log 'Setting Up Snapshot Preserver LaunchDaemon'

					# Copy fg-snapshot-preserver out of fg-snapshot-reset resources to keep it around and start is running with a LaunchDaemon.
					snapshot_preserver_resources_install_path='/Users/Shared/.fg-snapshot-preserver' # NOTICE: INVISIBLE folder.
					mkdir -p "${snapshot_preserver_resources_install_path}"
					mv "${snapshot_reset_resources_install_path}/fg-snapshot-preserver.sh" "${snapshot_preserver_resources_install_path}/fg-snapshot-preserver.sh"
					mv "${snapshot_reset_resources_install_path}/Resources" "${snapshot_preserver_resources_install_path}/Resources"
					chmod +x "${snapshot_preserver_resources_install_path}/fg-snapshot-preserver.sh"

					# Setting StartCalendarInterval to run ever 5th minute instead of setting a StartInterval of 300 because want to be sure that fg-snapshot-preserver is always run at the top of every hour,
					# since 00:00:00 is the most important and StartInterval cannot guarantee that run time. Also want to run at the top of every other hour in case a network time sync changed the time resulting in the date needing to be updated at some time other than midnight.
					# And want to run every 5 minutes just to be extra safe and to allow for prompt manual time syncs if a previous manual sync failed or was blocked. Also want to have a more promptly logged record of when a reset Snapshot is lost, if that happens.
					# Also, if the reset Snapshot does somehow get lost, this will be used to launch "Snapshot Helper" which will display an alert about this critical error, which we want to be opened promptly and re-opened often if closed.
					# I tried using both StartCalendarInterval and StartInterval which seemed to work well at first (the StartCalendarInterval would actually reset the interval that StartInterval would run on which would make it pretty precise after the first hour had passed),
					# but extended testing showed that the StartInterval would eventually take precedence over StartCalendarInterval and it would not run right at 00:00:00 and the reset Snapshot could get deleted by macOS.
					# So, I switched to only using StartCalendarInterval which then made the actual issue apparent. The actual issue was that when the date was set to the past, the StartCalendarInterval would stop being processed until
					# the date and time caught back up to the next scheduled run before the date was set to the past, and that would only leave the StartInterval running since it was not dependent on a specifically scheduled run time.
					# To workaround this issue, the LaunchDaemon will now reboot the computer whenever the date is manipulated to make sure macOS runs the LaunchDaemon on the intended StartCalendarInterval.
					# See REBOOT AFTER DATE IS SET BACK IN TIME comments in fg-snapshot-preserver for more information about this.
					# This means that StartCalendarInterval and StartInterval could actually be used together, but now there is no real benefit to switching back to that over the existing StartCalendarInterval setup.
					echo "
Add :Label string org.freegeek.fg-snapshot-preserver
Add :Program string ${snapshot_preserver_resources_install_path}/fg-snapshot-preserver.sh
Add :RunAtLoad bool true
Add :StandardOutPath string /dev/null
Add :StandardErrorPath string /dev/null
Add :StartCalendarInterval array
$(for (( start_calendar_interval_minute = 55; start_calendar_interval_minute >= 0; start_calendar_interval_minute -= 5 )); do echo "Add :StartCalendarInterval:0 dict
Add :StartCalendarInterval:0:Minute integer ${start_calendar_interval_minute}"; done)
Save
" | PlistBuddy '/Library/LaunchDaemons/org.freegeek.fg-snapshot-preserver.plist' &> /dev/null

					if [[ ! -f '/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist' ]]; then
						# Do not need to load right away if started via LaunchDaemon since we will restart.
						launchctl load -w '/Library/LaunchDaemons/org.freegeek.fg-snapshot-preserver.plist'
					fi
					
					rm -f '/Library/LaunchDaemons/org.freegeek.fg-snapshot-reset.plist' # Only want this to launch on first boot after restoring from the reset Snapshot, never another time.
					rm -rf "${snapshot_reset_resources_install_path}" # Delete remaining fg-snapshot-reset resources since they are only needed on first boot after restoring from the reset Snapshot.

					if [[ ! -f "${snapshot_preserver_resources_install_path}/fg-snapshot-preserver.sh" || ! -f '/Library/LaunchDaemons/org.freegeek.fg-snapshot-preserver.plist' || -f '/Library/LaunchDaemons/org.freegeek.fg-snapshot-reset.plist' || -d "${snapshot_reset_resources_install_path}" ]]; then
						write_to_log 'ERROR: Failed to Setup Snapshot Preserver LaunchDaemon'
						critical_error_occurred=true
					fi
				fi
			fi
		else
		
			# FIX EXPIRED LET'S ENCRYPT CERTFICATE FOR MOJAVE AND OLDER
			# This removes the expired Let's Encrypt certificate based on these instructions: https://docs.hedge.video/remove-dst-root-ca-x3-certificate
			# If the expired certificate exists, using curl with sites using Let's Encrypt will fail, but just removing the certificate allows curl to work.
			# But, I'm not exactly sure what certificate is getting used to authenticate the connection after the expired on is removed. Kinda weird.

			# Newer versions of macOS do not need this fix and the versions that do need it don't use a the Snapshot reset technique,
			# so it's fine for this to be in this "else" statement only when a Snapshot is NOT being made.
			
			mv -f '/private/etc/ssl/cert.pem' '/private/etc/ssl/cert-orig.pem'
			
			awk '
(!remove_cert) {
    if (is_cert_body) {
        print
    } else if ($0 == "-----BEGIN CERTIFICATE-----") {
        print cert_header $0
        cert_header = ""
        is_cert_body = 1
    } else if (!is_cert_body) {
        if ($1 == "44:af:b0:80:d6:a3:27:ba:89:30:39:86:2e:f8:40:6b") {
            remove_cert = 1
            cert_header = ""
        } else {
            cert_header = cert_header $0 "\n"
        }
    }
}
($0 == "-----END CERTIFICATE-----") {
    is_cert_body = 0
    remove_cert = 0
}
' '/private/etc/ssl/cert-orig.pem' > '/private/etc/ssl/cert.pem'


			if [[ ! -f '/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist' && "$(sudo systemsetup -getusingnetworktime)" == *': Off' ]]; then # "sudo" is needed for "systemsetup" within subshell.
				
				# MAKE SURE TIME IS SYNCED
				# This will already have been done if launched via LaunchDaemon or will be done in this script after reset Snapshot is created if on macOS 10.15 Catalina and newer.

				write_to_log 'Turning On Network Time'

				systemsetup -setusingnetworktime on &> /dev/null
			fi
		fi
	fi


	hidden_admin_user_account_name='fg-admin'
	hidden_admin_user_full_name='Free Geek Administrator'
	hidden_admin_user_password='[BUILD PACKAGE SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]'

	standard_autologin_user_account_name='fg-demo'
	standard_autologin_user_full_name='Free Geek Demo User'
	standard_autologin_user_password='freegeek'


	if ! $critical_error_occurred; then
	
		# DISABLE SLEEP

		write_to_log 'Disabling System Sleep'

		pmset -a sleep 0 displaysleep 0


		# SET COMPUTER NAME
		
		write_to_log 'Setting Computer Name'

		sp_hardware_plist_path="${TMPDIR:-/private/tmp/}fg-prepare-os-sp-hardware.plist"
		for (( get_model_id_attempt = 0; get_model_id_attempt < 60; get_model_id_attempt ++ )); do
			rm -rf "${sp_hardware_plist_path}"
			system_profiler -xml SPHardwareDataType > "${sp_hardware_plist_path}"

			model_id="$(PlistBuddy -c 'Print :0:_items:0:machine_model' "${sp_hardware_plist_path}" 2> /dev/null)"
			
			if [[ "${model_id}" == *'Mac'* ]]; then
				serial_number="$(PlistBuddy -c 'Print :0:_items:0:serial_number' "${sp_hardware_plist_path}" 2> /dev/null)"
				
				if [[ -z "${serial_number}" || "${serial_number}" == 'Not Available' ]]; then
					serial_number="$(PlistBuddy -c 'Print :0:_items:0:riser_serial_number' "${sp_hardware_plist_path}" 2> /dev/null)"

					if [[ -z "${serial_number}" || "${serial_number}" == 'Not Available' ]]; then
						serial_number="UNKNOWNSERIAL-$(jot -r 1 100 999)"
					fi
				fi
				rm -f "${sp_hardware_plist_path}"

				serial_number="${serial_number//[[:space:]]/}"

				computer_name="Free Geek - ${model_id} - ${serial_number}"

				for (( set_computer_name_attempt = 0; set_computer_name_attempt < 60; set_computer_name_attempt ++ )); do
					scutil --set ComputerName "${computer_name}"

					if [[ "$(scutil --get ComputerName)" == "${computer_name}" ]]; then
						break
					else
						sleep 1
					fi
				done

				local_host_name="FreeGeek-${model_id//,/}-${serial_number}"

				for (( set_local_host_name_attempt = 0; set_local_host_name_attempt < 60; set_local_host_name_attempt ++ )); do
					scutil --set LocalHostName "${local_host_name}"

					if [[ "$(scutil --get LocalHostName)" == "${local_host_name}" ]]; then
						break
					else
						sleep 1
					fi
				done

				break
			else
				sleep 1
			fi
		done
		rm -f "${sp_hardware_plist_path}"


		write_to_log 'Setting Custom Global Preferences'


		# SET GLOBAL LANGUAGE AND LOCALE

		defaults write '/Library/Preferences/.GlobalPreferences' AppleLanguages -array 'en-US'
		defaults write '/Library/Preferences/.GlobalPreferences' AppleLocale -string 'en_US'
		defaults write '/Library/Preferences/.GlobalPreferences' AppleMeasurementUnits -string 'Inches'
		defaults write '/Library/Preferences/.GlobalPreferences' AppleMetricUnits -bool false
		defaults write '/Library/Preferences/.GlobalPreferences' AppleTemperatureUnit -string 'Fahrenheit'
		defaults write '/Library/Preferences/.GlobalPreferences' AppleTextDirection -bool false
		defaults delete '/Library/Preferences/.GlobalPreferences' AppleICUForce24HourTime &> /dev/null
		defaults delete '/Library/Preferences/.GlobalPreferences' AppleFirstWeekday &> /dev/null


		# DISABLE AUTOMATIC OS & APP STORE UPDATES
		# Keeping AutomaticCheckEnabled and AutomaticDownload enabled is required for EFIAllowListAll to be able to be updated when EFIcheck is run by our scripts, the rest should be disabled.

		defaults write '/Library/Preferences/com.apple.SoftwareUpdate' AutomaticCheckEnabled -bool true
		defaults write '/Library/Preferences/com.apple.SoftwareUpdate' AutomaticDownload -bool true
		defaults write '/Library/Preferences/com.apple.SoftwareUpdate' ConfigDataInstall -bool false
		defaults write '/Library/Preferences/com.apple.SoftwareUpdate' CriticalUpdateInstall -bool false
		defaults write '/Library/Preferences/com.apple.commerce' AutoUpdate -bool false
		if (( DARWIN_MAJOR_VERSION >= 18 )); then
			defaults write '/Library/Preferences/com.apple.SoftwareUpdate' AutomaticallyInstallMacOSUpdates -bool false
		else
			defaults write '/Library/Preferences/com.apple.commerce' AutoUpdateRestartRequired -bool false
		fi


		# CONNECTING TO WI-FI

		wifi_ssid='FG Reuse'
		wifi_password='[BUILD PACKAGE SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]'

		network_interfaces="$(networksetup -listallhardwareports 2> /dev/null | awk -F ': ' '($1 == "Device") { print $NF }')"
		IFS=$'\n'
		for this_network_interface in $network_interfaces; do
			if getairportnetwork_output="$(networksetup -getairportnetwork "${this_network_interface}" 2> /dev/null)" && [[ "${getairportnetwork_output}" != *'disabled.' ]]; then
				write_to_log "Connecting \"${this_network_interface}\" to \"${wifi_ssid}\" Wi-Fi"

				if networksetup -getairportpower "${this_network_interface}" 2> /dev/null | grep -q '): Off$'; then
					networksetup -setairportpower "${this_network_interface}" on &> /dev/null
				fi
				
				networksetup -setairportnetwork "${this_network_interface}" "${wifi_ssid}" "${wifi_password}" &> /dev/null
			fi
		done
		unset IFS


		# INSTALL GLOBAL SCRIPTS

		for this_global_script_zip in "$2/Global/Scripts/"*'.zip'; do
			if [[ -f "${this_global_script_zip}" ]]; then
				this_global_script_name="$(basename "${this_global_script_zip}" '.zip')"
				
				write_to_log "Installing Global Script \"${this_global_script_name}\""

				ditto -x -k --noqtn "${this_global_script_zip}" '/Applications' &> /dev/null

				if [[ -f "/Applications/${this_global_script_name}.sh" ]]; then
					mv -f "/Applications/${this_global_script_name}.sh" "/Applications/${this_global_script_name}"

					xattr -c "/Applications/${this_global_script_name}"
					chmod +x "/Applications/${this_global_script_name}"
					chflags hidden "/Applications/${this_global_script_name}"

					if [[ ! -d '/usr/local/bin' ]]; then
						mkdir -p '/usr/local/bin'
					fi

					ln -s "/Applications/${this_global_script_name}" '/usr/local/bin'
				fi
			fi
		done

		if [[ ! -f '/Applications/fgreset' ]]; then
			write_to_log 'ERROR: Failed to Install "fgreset" Global Script'
			critical_error_occurred=true
		fi

		
		fg_user_picture_path="$2/Global/Users/Free Geek User Picture.png"


		if ! $critical_error_occurred; then

			# CREATE HIDDEN ADMIN USER

			write_to_log "Creating Hidden Admin User \"${hidden_admin_user_full_name}\" (${hidden_admin_user_account_name})"
			
			create_hidden_admin_user_options=( '--account-name' "${hidden_admin_user_account_name}" )
			create_hidden_admin_user_options+=( '--full-name' "${hidden_admin_user_full_name}" )
			create_hidden_admin_user_options+=( '--generated-uid' '0CAA0000-0A00-0000-BA00-0B000C00B00A' ) # This GUID is from the "johnappleseed" user shown on https://support.apple.com/en-us/HT208050
			create_hidden_admin_user_options+=( '--stdin-password' )
			create_hidden_admin_user_options+=( '--password-hint' 'If you do not know this password, then you should not be logging in as this user.' )
			create_hidden_admin_user_options+=( '--picture' "${fg_user_picture_path}" )
			create_hidden_admin_user_options+=( '--administrator' )
			create_hidden_admin_user_options+=( '--hidden' )
			create_hidden_admin_user_options+=( '--skip-setup-assistant' )
			create_hidden_admin_user_options+=( '--prohibit-user-password-changes' )
			create_hidden_admin_user_options+=( '--prohibit-user-picture-changes' )
			create_hidden_admin_user_options+=( '--prevent-secure-token-on-big-sur-and-newer' )
			create_hidden_admin_user_options+=( '--suppress-status-messages' ) # Don't output stdout messages, but we will still get stderr to save to variable.

			# PREVENT SECURE TOKEN ON BIG SUR AND NEWER
			# See comments in "mkuser.sh" for more information about preventing Secure Tokens on macOS 11 Big Sur.
			# This is nice for being able to use Snapshot reset and having the customer user account get a Secure Token on macOS 11 Big Sur:
			# Although, this DOES NOT work on macOS 10.15 Catalina. BUT, I found that I can remove the crypto user references after the users no longer exist (on non-SEP Macs)
			# after restoring the reset Snapshot, so this isn't the only way to be able to do a Snapshot reset (on non-SEP Macs) and have the customer user account be able to get a Secure Token.
			# But, since Secure Tokens cannot be removed on SEP Macs (T2/Apple Silicon), this is still a very critical thing to do to be able to do a Snapshot reset on those newer Macs.
			# See comments in fg-snapshot-reset for more info about deleting crypto user references on macOS 10.15 Catalina.

			chmod +x "$2/Tools/mkuser.sh"
			create_hidden_admin_user_error="$(echo "${hidden_admin_user_password}" | "$2/Tools/mkuser.sh" "${create_hidden_admin_user_options[@]}" 2>&1)" # Redirect stderr to save to variable.
			create_hidden_admin_user_exit_code="$?" # Do not check "create_user" exit code directly by putting the function within an "if" since we want to print it as well when an error occurs.

			if (( create_hidden_admin_user_exit_code != 0 )) || [[ "$(id -u "${hidden_admin_user_account_name}" 2> /dev/null)" != '501' ]]; then # Confirm hidden_admin_user_account_name was assigned UID 501 to be sure all is as expected.
				if [[ -z "${create_hidden_admin_user_error}" ]]; then create_hidden_admin_user_error="$(id -u "${hidden_admin_user_account_name}" 2>&1)"; fi
				write_to_log "ERROR: \"${hidden_admin_user_account_name}\" User Not Created (${create_hidden_admin_user_error})"
				critical_error_occurred=true
			fi
		fi


		if ! $critical_error_occurred; then
			
			# CREATE STANDARD AUTO-LOGIN USER

			write_to_log "Creating Standard Auto-Login User \"${standard_autologin_user_full_name}\" (${standard_autologin_user_account_name})"
			
			create_standard_autologin_user_options=( '--account-name' "${standard_autologin_user_account_name}" )
			create_standard_autologin_user_options+=( '--full-name' "${standard_autologin_user_full_name}" )
			create_standard_autologin_user_options+=( '--generated-uid' 'B0ABCAB0-D000-00C0-A0D0-00000CA000C0' ) # This GUID is from the "johnappleseed" user shown on https://support.apple.com/en-us/HT201548 (which is different from the one above)
			create_standard_autologin_user_options+=( '--stdin-password' )
			create_standard_autologin_user_options+=( '--password-hint' "The password is \"${standard_autologin_user_password}\"." )
			create_standard_autologin_user_options+=( '--picture' "${fg_user_picture_path}" )
			create_standard_autologin_user_options+=( '--skip-setup-assistant' )
			create_standard_autologin_user_options+=( '--automatic-login' )
			create_standard_autologin_user_options+=( '--do-not-share-public-folder' )
			create_standard_autologin_user_options+=( '--prohibit-user-password-changes' )
			create_standard_autologin_user_options+=( '--prohibit-user-picture-changes' )
			create_standard_autologin_user_options+=( '--prevent-secure-token-on-big-sur-and-newer' )
			create_standard_autologin_user_options+=( '--suppress-status-messages' ) # Don't output stdout messages, but we will still get stderr to save to variable.

			chmod +x "$2/Tools/mkuser.sh"
			create_standard_autologin_user_error="$(echo "${standard_autologin_user_password}" | "$2/Tools/mkuser.sh" "${create_standard_autologin_user_options[@]}" 2>&1)" # Redirect stderr to save to variable.
			create_standard_autologin_user_exit_code="$?" # Do not check "create_user" exit code directly by putting the function within an "if" since we want to print it as well when an error occurs.

			if (( create_standard_autologin_user_exit_code != 0 )) || [[ "$(id -u "${standard_autologin_user_account_name}" 2> /dev/null)" != '502' ]]; then # Confirm standard_autologin_user_account_name was assigned UID 502 to be sure all is as expected.
				if [[ -z "${create_standard_autologin_user_error}" ]]; then create_standard_autologin_user_error="$(id -u "${standard_autologin_user_account_name}" 2>&1)"; fi
				write_to_log "ERROR: \"${standard_autologin_user_account_name}\" User Not Created (${create_standard_autologin_user_error})"
				critical_error_occurred=true
			fi
		fi


		if ! $critical_error_occurred; then

			# USER SPECIFIC TASKS (based on home folders)
			# About running "defaults" commands as another user: https://scriptingosx.com/2020/08/running-a-command-as-another-user/

			for this_home_folder in '/Users/'*; do
				if [[ -d "${this_home_folder}" && "${this_home_folder}" != '/Users/Shared' && "${this_home_folder}" != '/Users/Guest' ]]; then
					this_username="$(dscl . -search /Users NFSHomeDirectory "${this_home_folder}" | awk '{ print $1; exit }')"
					this_uid="$(dscl -plist . -read "/Users/${this_username}" UniqueID 2> /dev/null | xmllint --xpath '//string[1]/text()' - 2> /dev/null)"

					if [[ -n "${this_uid}" && -d "${this_home_folder}/Library" ]]; then

						write_to_log "Setting Custom User Preferences for \"${this_username}\" User"


						# SET USER LANGUAGE AND LOCALE

						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'NSGlobalDomain' AppleLanguages -array 'en-US'
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'NSGlobalDomain' AppleLocale -string 'en_US'
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'NSGlobalDomain' AppleMeasurementUnits -string 'Inches'
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'NSGlobalDomain' AppleMetricUnits -bool false
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'NSGlobalDomain' AppleTemperatureUnit -string 'Fahrenheit'
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'NSGlobalDomain' AppleTextDirection -bool false
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults delete 'NSGlobalDomain' AppleICUForce24HourTime &> /dev/null
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults delete 'NSGlobalDomain' AppleFirstWeekday &> /dev/null


						# DISABLE REOPEN WINDOWS ON LOGIN

						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.loginwindow' TALLogoutSavesState -bool false


						# ADD SECONDS TO CLOCK FORMAT

						if (( DARWIN_MAJOR_VERSION >= 20 )); then
							# Need to set pref keys AND format on macOS 11 Big Sur, but older versions of macOS only use the format.
							# Must still set format after setting this pref (and seconds won't get updated if we ONLY set the format).
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.menuextra.clock' ShowSeconds -bool true
						fi

						# All of the other prefs specified by this format are already default in macOS 11 Big Sur.
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.menuextra.clock' DateFormat -string 'EEE MMM d  h:mm:ss a'


						# DO NOT SHOW INTERNAL/BOOT DRIVE ON DESKTOP AND SET NEW FINDER WINDOWS TO COMPUTER

						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.finder' ShowHardDrivesOnDesktop -bool false
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.finder' ShowExternalHardDrivesOnDesktop -bool true
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.finder' ShowMountedServersOnDesktop -bool true
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.finder' ShowRemovableMediaOnDesktop -bool true
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.finder' NewWindowTarget -string 'PfCm'
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults delete 'com.apple.finder' NewWindowTargetPath &> /dev/null


						# DISABLE DICTATION (Don't want to alert to turn on dictation when clicking Fn multiple times)
						
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.HIToolbox' AppleDictationAutoEnable -bool false


						if (( DARWIN_MAJOR_VERSION == 17 )); then

							# SET SCREEN ZOOM TO USE SCROLL GESTURE WITH MODIFIER KEY, ZOOM FULL SCREEN, AND MOVE CONTINUOUSLY WITH POINTER
							# This can only work on macOS 10.13 High Sierra since this plist is protected on macOS 10.14 Mojave and newer: https://eclecticlight.co/2020/03/04/how-macos-10-14-and-later-overrides-write-permission-on-some-files/

							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.universalaccess' closeViewScrollWheelToggle -bool true
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.universalaccess' closeViewZoomMode -int 0
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.universalaccess' closeViewPanningMode -int 0
						fi


						# SET MOUSE BUTTON SETTINGS

						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.driver.AppleHIDMouse' Button1 -int 1
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.driver.AppleHIDMouse' Button2 -int 2
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.driver.AppleHIDMouse' Button3 -int 3


						# DISABLE SCREEN SAVER

						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.screensaver' idleTime -int 0


						# DISABLE NOTIFICATIONS

						if (( DARWIN_MAJOR_VERSION >= 20 )); then
							# In macOS 11 Big Sur, the Do Not Distrub data is stored as binary of a plist within the "dnd_prefs" of "com.apple.ncprefs": 
							# https://www.reddit.com/r/osx/comments/ksbmay/big_sur_how_to_test_do_not_disturb_status_in/gjb72av/
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.ncprefs' dnd_prefs -data "$(echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>dndDisplayLock</key>
	<true/>
	<key>dndDisplaySleep</key>
	<true/>
	<key>dndMirrored</key>
	<true/>
	<key>facetimeCanBreakDND</key>
	<false/>
	<key>repeatedFacetimeCallsBreaksDND</key>
	<false/>
	<key>scheduledTime</key>
	<dict>
		<key>enabled</key>
		<true/>
		<key>end</key>
		<real>1439</real>
		<key>start</key>
		<real>0.0</real>
	</dict>
</dict>
</plist>' | plutil -convert binary1 - -o - | xxd -p | tr -d '[:space:]')" # "xxd" converts the binary data into hex, which is what "defaults" needs.
						else
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' dndEnabledDisplayLock -bool true
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' dndEnabledDisplaySleep -bool true
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' dndMirroring -bool true
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' dndEnd -float 1439
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' dndStart -float 0
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' doNotDisturb -bool false
						fi


						# DISABLE SAFARI AUTO-FILL AND AUTO-OPENING DOWNLOADS
						# Safari 13 and newer are now Sandboxed and store their preferences at "~/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.plist"
						# This Safari Container location is also protected: https://lapcatsoftware.com/articles/containers.html
						# That article says the Safari Container is protected by SIP, but I think it's actually TCC since drag-and-dropping the location onto a Terminal window or granting Full Disk Access makes it accessible as well as manually trashing the folder in Finder. SIP wouldn't allow any of that.
						# But, since Safari hasn't been launched at this point, we can set the preferences in the old unprotected location and Safari will migrate them when launched for the first time.
						# This approach is also nice in that it supports any older versions of Safari which may be pre-installed on macOS 10.13 High Sierra through macOS 10.15 Catalina.

						# BUT: This no longer works in macOS 12 Monterey because the Safari Container is created upon login instead of first Safari launch.
						# The preferences within the Safari Container don't exist until launch, but the preferences from the old location DO NOT get migrated like they do on older versions of macOS because the Safari Container already exists.
						# Modifying the preferences within the Safari Container requires Full Disk Access TCC privileges, and the only applet that gets FDA is the "Free Geek Snapshot Helper".
						# Therefore, "Free Geek Snapshot Helper" has a Safari preferences check added to it to set these prefernences value within the Safari Container location AFTER it has been granted FDA.
						# I don't love the idea of overloading "Free Geek Snapshot Helper" with this functionality, but it is the simplest option instead of making a new dedicated applet and granting that FDA as well for such a simple task.

						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.Safari' AutoFillPasswords -bool false
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.Safari' AutoFillFromAddressBook -bool false
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.Safari' AutoFillCreditCardData -bool false
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.Safari' AutoFillMiscellaneousForms -bool false
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.Safari' AutoOpenSafeDownloads -bool false
						

						# USER SPECIFIC TASKS IF USER RESOURCES EXIST

						this_user_resources_folder="$2/User/${this_username}"
						this_user_apps_folder="${this_home_folder}/Applications"

						if [[ -d "${this_user_resources_folder}" ]]; then
							if [[ -d "${this_user_resources_folder}/Pics" ]]; then
								
								# UNZIP FREE GEEK PROMO PICS TO USER PICTURES FOLDER (FOR SCREENSAVER AUTOMATION DURING DEMO MODE)

								this_user_pictures_folder="${this_home_folder}/Pictures"

								for this_pics_zip in "${this_user_resources_folder}/Pics/"*'.zip'; do
									if [[ -f "${this_pics_zip}" ]]; then
										write_to_log "Installing Screen Saver Promo Pics for \"${this_username}\" User"

										ditto -x -k --noqtn "${this_pics_zip}" "${this_user_pictures_folder}" &> /dev/null
									fi
								done

								chown -R "${this_username}" "${this_user_pictures_folder}"
							fi


							if [[ -d "${this_user_resources_folder}/Apps" ]]; then
								
								# INSTALL USER APPS

								mkdir -p "${this_user_apps_folder}"

								for this_user_app_installer in "${this_user_resources_folder}/Apps/"*'.'*; do
									if [[ -f "${this_user_app_installer}" ]]; then
										if [[ "${this_user_app_installer}" == *'.zip' ]]; then
											this_user_app_name="$(basename "${this_user_app_installer}" '.zip' | tr '-' ' ')"
											if [[ "${this_user_app_name}" == 'QAHelper'* ]]; then this_user_app_name='QA Helper'; fi

											write_to_log "Installing User App \"${this_user_app_name}\" for \"${this_username}\" User"

											ditto -x -k --noqtn "${this_user_app_installer}" "${this_user_apps_folder}" &> /dev/null
										elif [[ "${this_user_app_installer}" == *'.dmg' ]]; then
											#write_to_log "Mounting \"$(basename "${this_user_app_installer}" .'dmg')\" Disk Image for \"${this_username}\" User Apps"

											dmg_mount_path="$(hdiutil attach "${this_user_app_installer}" -nobrowse -readonly -plist 2> /dev/null | awk -F '<string>|</string>' '/<string>\/Volumes\// { print $2; exit }')"

											if [[ -d "${dmg_mount_path}" ]]; then
												for this_dmg_app in "${dmg_mount_path}/"*'.app'; do
													if [[ -d "${this_dmg_app}" ]]; then
														this_user_app_name="$(basename "${this_dmg_app}" '.app')"

														write_to_log "Installing User App \"${this_user_app_name}\" for \"${this_username}\" User"

														ditto "${this_dmg_app}" "/Applications/${this_user_app_name}.app" &> /dev/null
													fi
												done

												#write_to_log "Unmounting \"$(basename "${this_global_app_installer}" '.dmg')\" Disk Image for \"${this_username}\" User Apps"
												hdiutil detach "${dmg_mount_path}" &> /dev/null
											fi
										else
											write_to_log "Skipping Unrecognized \"${this_username}\" User App Installer (${this_user_app_installer})"
										fi
									fi
								done

								xattr -drs com.apple.quarantine "${this_user_apps_folder}/"*'.app' &> /dev/null # Still remove all Quarantine flags in case app came from DMG instead of unzipped with "ditto -x -k --noqtn".
								touch "${this_user_apps_folder}/"*'.app' &> /dev/null

								chown -R "${this_username}" "${this_user_apps_folder}"
								

								if [[ -d "${this_user_apps_folder}/QA Helper.app" ]]; then

									# DISABLE NOTIFICATIONS FOR QA HELPER
									# Disable notifications so that notification approval is not prompted for the technician to have to dismiss (even though QA Helper does not send any notifications).
									# Doing this because the notification approval prompt is not hidden with Do Not Disturb enabled on macOS 11 Big Sur like it is on macOS 10.15 Catalina and older (but went ahead and disabled notifications for all versions of macOS anyway).

									write_to_log "Disabling \"QA Helper\" Notifications for \"${this_username}\" User"

									notification_center_disable_all_flags='8401217' # macOS 11 Big Sur: "Allow Notifications" disabled, alert style "None", and every checkbox option disabled.
									if (( DARWIN_MAJOR_VERSION == 18 || DARWIN_MAJOR_VERSION == 19 )); then
										notification_center_disable_all_flags='8409409' # macOS 10.14 Mojave & macOS 10.15 Catalina: "Allow Notifications" disabled, alert style "None", notification previews "when unlocked", and every checkbox option disabled.
									elif (( DARWIN_MAJOR_VERSION == 17 )); then
										notification_center_disable_all_flags='4417' # macOS 10.13 High Sierra: Alert style "None", and every checkbox option disabled.
									fi

									launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.ncprefs' apps -array-add "<dict><key>bundle-id</key><string>org.freegeek.QA-Helper</string><key>flags</key><integer>${notification_center_disable_all_flags}</integer><key>path</key><string>${this_user_apps_folder}/QA Helper.app</string></dict>"
								fi


								if [[ -d "${this_user_apps_folder}/Automation Guide.app" ]]; then
									
									write_to_log "Preparing \"Automation Guide\" for \"${this_username}\" User"


									# SYMLINK AUTOMATION GUIDE ON DESKTOP

									this_user_desktop_folder="${this_home_folder}/Desktop"

									ln -s "${this_user_apps_folder}/Automation Guide.app" "${this_user_desktop_folder}"
									chown -R "${this_username}" "${this_user_desktop_folder}"


									# SETUP AUTOMATION GUIDE AUTO-LAUNCH

									this_user_launch_agents_folder="${this_home_folder}/Library/LaunchAgents"

									mkdir -p "${this_user_launch_agents_folder}"

									PlistBuddy \
										-c 'Add :Label string org.freegeek.Automation-Guide' \
										-c 'Add :ProgramArguments array' \
										-c 'Add :ProgramArguments: string /usr/bin/open' \
										-c 'Add :ProgramArguments: string -n' \
										-c 'Add :ProgramArguments: string -a' \
										-c "Add :ProgramArguments: string '${this_user_apps_folder}/Automation Guide.app'" \
										-c 'Add :RunAtLoad bool true' \
										-c 'Add :StartInterval integer 300' \
										-c 'Add :StandardOutPath string /dev/null' \
										-c 'Add :StandardErrorPath string /dev/null' \
										"${this_user_launch_agents_folder}/org.freegeek.Automation-Guide.plist" &> /dev/null

									chown -R "${this_username}" "${this_user_launch_agents_folder}"
								fi
							fi
						fi


						# SETUP DOCK
						# Add QA Helper to the front (if installed), add LibreOffice after Reminders,
						# replace Safari with Firefox (if installed, which it will be on macOS 10.13 High Sierra),
						# lock contents size and position, and hide recents (on macOS 10.14 Mojave and newer).
						
						# NOTE: The user Dock prefs will not exist yet, so we need start with the "persistent-apps" from the default source plist within the Dock app.
						# Do this AFTER user specific tasks so that we can check if QA Helper was installed for this user.

						write_to_log "Customizing Dock for \"${this_username}\" User"

						default_dock_plist='/System/Library/CoreServices/Dock.app/Contents/Resources/default.plist' # This is location on macOS 10.15 Catalina and newer.
						if [[ ! -f "${default_dock_plist}" ]]; then
							default_dock_plist='/System/Library/CoreServices/Dock.app/Contents/Resources/en.lproj/default.plist' # This is location on macOS 10.14 Mojave and older.
						fi

						if [[ -f "${default_dock_plist}" ]]; then # Do not try to customize the Dock contents if the default Dock plist is moved in a future version of macOS.
							default_dock_persistent_apps="$(plutil -extract persistent-apps xml1 -o - "${default_dock_plist}")"

							if [[ "${default_dock_persistent_apps}" == *'<key>tile-data</key>'* ]]; then # Do not try to customize the Dock contents if extracting "persistent-apps" failed for some reason.
								dock_app_dict_for_path() {
									if [[ -n "$1" && -d "$1" ]]; then
										echo "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$1</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
									fi
								}

								custom_dock_persistent_apps=()

								if [[ -d "${this_user_apps_folder}/QA Helper.app" ]]; then
									custom_dock_persistent_apps+=( "$(dock_app_dict_for_path "${this_user_apps_folder}/QA Helper.app")" )
								fi

								did_add_libreoffice_to_dock=false

								IFS=$'\n'
								this_dock_persistent_app=''
								this_dock_persistent_app_exists=false
								for this_dock_persistent_apps_line in $default_dock_persistent_apps; do
									if [[ "${this_dock_persistent_apps_line}" == $'\t'* ]]; then
										this_dock_persistent_app+="${this_dock_persistent_apps_line}"

										if [[ "${this_dock_persistent_apps_line}" == *'.app</string>' ]]; then
											# The default Dock contents will include Pages, Numbers, and Keynote which will not be installed, so make sure to only include existing apps to our Dock.
											# If the Dock were allowed to initialize on it's own, these app would be removed from the Dock by macOS when they are not installed.
											this_dock_persistent_app_exists="$([[ -d "$(echo "${this_dock_persistent_apps_line}" | awk -F '<string>|</string>' '{ print $2; exit }')" ]] && echo 'true' || echo 'false')"
										elif [[ "${this_dock_persistent_apps_line}" == $'\t</dict>'* ]]; then
											if [[ "${this_dock_persistent_app}" == *'/Applications/Safari.app'* && -d '/Applications/Firefox.app' ]]; then
												custom_dock_persistent_apps+=( "$(dock_app_dict_for_path '/Applications/Firefox.app')" )
											elif $this_dock_persistent_app_exists; then
												custom_dock_persistent_apps+=( "${this_dock_persistent_app}" )

												if [[ "${this_dock_persistent_app}" == *'/Applications/Reminders.app'* && -d '/Applications/LibreOffice.app' ]]; then
													custom_dock_persistent_apps+=( "$(dock_app_dict_for_path '/Applications/LibreOffice.app')" )
													did_add_libreoffice_to_dock=true
												fi
											fi

											this_dock_persistent_app=''
											this_dock_persistent_app_exists=false
										fi
									fi
								done
								unset IFS

								if ! $did_add_libreoffice_to_dock && [[ -d '/Applications/LibreOffice.app' ]]; then
									# This should never happen, but in case Reminders was not in the Dock then add LibreOffice to the end.
									custom_dock_persistent_apps+=( "$(dock_app_dict_for_path '/Applications/LibreOffice.app')" )
								fi

								launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.dock' persistent-apps -array "${custom_dock_persistent_apps[@]}"

								# VERY IMPORTANT: If this "version" key is not set, the Dock contents will get reset when Dock runs.
								# I've confirmed it to get set to "1" by Dock on macOS 10.13 High Sierra through macOS 11 Big Sur.
								launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.dock' version -int 1
							fi
						fi

						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.dock' contents-immutable -bool true
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.dock' size-immutable -bool true
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.dock' position-immutable -bool true
						if (( DARWIN_MAJOR_VERSION >= 18 )); then
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.dock' show-recents -bool false
						fi
					fi
				fi
			done


			if [[ ! -d "/Users/${standard_autologin_user_account_name}/Applications/Automation Guide.app" || ! -f "/Users/${standard_autologin_user_account_name}/Library/LaunchAgents/org.freegeek.Automation-Guide.plist" ]]; then
				write_to_log 'ERROR: Automation Guide Not Installed or LaunchAgent Not Configured'
				critical_error_occurred=true
			fi

			if ! launchctl asuser '502' sudo -u "${standard_autologin_user_account_name}" defaults read 'com.apple.dock' persistent-apps | grep -q 'QA Helper'; then
				write_to_log 'ERROR: QA Helper Not Installed or Dock Not Configured'
				critical_error_occurred=true
			fi
		fi
	fi
	

	if $critical_error_occurred; then
		
		if id "${standard_autologin_user_account_name}"; then

			# HIDE STANDARD AUTO-LOGIN USER (in case it got created before the critical error)

			dscl . -create "/Users/${standard_autologin_user_account_name}" IsHidden 1
		fi

		if [[ -f '/private/etc/kcpassword' ]]; then

			# DISABLE AUTO-LOGIN (in case it got enabled before the critical error)

			rm -f '/private/etc/kcpassword'
			defaults delete '/Library/Preferences/com.apple.loginwindow' autoLoginUser &> /dev/null
		fi

		if [[ -f '/Library/LaunchDaemons/org.freegeek.fg-error-occurred.plist' ]]; then
			
			# LOAD fg-error-occurred LAUNCH DAEMON (so error is announced and shown next at Login Window if was not run on boot via LaunchDaemon)

			launchctl load -w '/Library/LaunchDaemons/org.freegeek.fg-error-occurred.plist'
		fi
	else

		# DELETE fg-error-occurred LAUNCH DAEMON

		rm -f '/Library/LaunchDaemons/org.freegeek.fg-error-occurred.plist'
		rm -rf "${error_occurred_resources_install_path}"


		# ANNOUNCE COMPLETED CUSTOMIZATIONS (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)

		write_to_log 'Successfully Prepared OS'

		osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
		afplay "$2/Announcements/fg-completed-customizations.aiff"
	fi
else

	critical_error_occurred=true


	# ANNOUNCE ERROR (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)
	# Audio drivers (or something) need a few seconds before audio will be able to play when run early on boot via LaunchDaemon. So try for up to 60 seconds before continuing.
	
	for (( wait_to_play_seconds = 0; wait_to_play_seconds < 60; wait_to_play_seconds ++ )); do
		osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
		if afplay "$2/Announcements/fg-error-occurred.aiff" &> /dev/null; then
			afplay "$2/Announcements/fg-deliver-to-it.aiff"
			break
		else
			sleep 1
		fi
	done
fi


# DELETE INSTALLED RESOURCES FOLDER

if [[ -n "$2" && -d "$2" && "$2" == *'fg-prepare-os'* ]]; then
	rm -rf "$2"
fi


# NOTE: Do not need to worry about deleting this script itself since macOS seems to take care of that right after it's done running.


if $critical_error_occurred; then
	exit 1
fi

exit 0
