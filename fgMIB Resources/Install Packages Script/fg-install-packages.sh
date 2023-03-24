#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell on 3/11/21.
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

# NOTICE: This script will only be installed and run via LaunchDaemon when customizing an existing clean install, such as on Apple Silicon Macs.

readonly SCRIPT_VERSION='2023.3.1-1'

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy.

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"
readonly SCRIPT_DIR

DARWIN_MAJOR_VERSION="$(uname -r | cut -d '.' -f 1)" # 17 = 10.13, 18 = 10.14, 19 = 10.15, 20 = 11.0, etc.
readonly DARWIN_MAJOR_VERSION

launch_daemon_path='/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist'

launch_login_progress_app() {
	if [[ -f "${SCRIPT_DIR}/Tools/Free-Geek-Login-Progress.zip" && ! -d "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app" ]]; then
		ditto -xk --noqtn "${SCRIPT_DIR}/Tools/Free-Geek-Login-Progress.zip" "${SCRIPT_DIR}/Tools" &> /dev/null
		touch "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app"
	fi

	if [[ -d "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app" ]]; then
		# Cannot open "Free Geek Login Progress" directly when at Login Window, but a LaunchAgent with LimitLoadToSessionType=LoginWindow and "launchctl load -S LoginWindow" can open it.
		# In my testing I haven't been able to figure out how to do this with any of the modern "launchctl bootstrap" options, but maybe there is some way that I haven't found.

		login_progress_launch_agent_path='/Library/LaunchAgents/org.freegeek.Free-Geek-Login-Progress.plist'

		# NOTE: The following LaunchAgent is setup to run a signed script with launches the app and has "AssociatedBundleIdentifiers" specified to be properly displayed in the "Login Items" list in "System Settings" on macOS 13 Ventura and newer.
		# BUT, this is just done for consistency with other code since this particular script will never run when a user is logged in to even be able to see that list in macOS 13 Ventura.
		# On macOS 12 Monterey and older, the "AssociatedBundleIdentifiers" will just be ignored and the signed launcher script will behave just as if we ran "/usr/bin/open" directly via the LaunchAgent.
		PlistBuddy \
			-c 'Add :Label string org.freegeek.Free-Geek-Login-Progress' \
			-c 'Add :LimitLoadToSessionType string LoginWindow' \
			-c "Add :Program string '${SCRIPT_DIR}/Tools/Free Geek Login Progress.app/Contents/Resources/Launch Free Geek Login Progress'" \
			-c 'Add :AssociatedBundleIdentifiers string org.freegeek.Free-Geek-Login-Progress' \
			-c 'Add :RunAtLoad bool true' \
			-c 'Add :StandardOutPath string /dev/null' \
			-c 'Add :StandardErrorPath string /dev/null' \
			"${login_progress_launch_agent_path}" &> /dev/null

		launchctl load -S LoginWindow "${login_progress_launch_agent_path}"

		for (( wait_for_progress_app_seconds = 0; wait_for_progress_app_seconds < 15; wait_for_progress_app_seconds ++ )); do
			if pgrep -qax 'Free Geek Login Progress'; then
				break
			else
				sleep 1
			fi
		done

		launchctl unload -S LoginWindow "${login_progress_launch_agent_path}"
		rm -f "${login_progress_launch_agent_path}"
	fi
}

if (( DARWIN_MAJOR_VERSION >= 17 )) && [[ "${SCRIPT_DIR}" == '/Users/Shared/fg-customization-resources' && -f "${launch_daemon_path}" ]]; then
	if [[ -f '/Users/Shared/Build Info/Prepare OS Log.txt' ]] && grep -qF $'\tERROR:' '/Users/Shared/Build Info/Prepare OS Log.txt'; then
		# If rebooted after previous error, just re-display error and do not proceed.


		# ANNOUNCE ERROR (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)
		# Audio drivers (or something) need a few seconds before audio will be able to play when run early on boot via LaunchDaemon. So try for up to 60 seconds before continuing.	
		
		for (( wait_to_play_seconds = 0; wait_to_play_seconds < 60; wait_to_play_seconds ++ )); do
			osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
			if afplay "${SCRIPT_DIR}/Announcements/fg-error-occurred.aiff" &> /dev/null; then
				break
			else
				sleep 1
			fi
		done


		# WAIT FOR FULL BOOT
		# Since LaunchDaemons start so early on boot, always wait for full boot before continuing so that everything is run in a consistent state and all system services have been started.
		# Through investigation, I found that "coreauthd" is consistently the last, or nearly the last, root process to be started before the login window is displayed.

		until pgrep -qax 'coreauthd'; do
			sleep 2
		done
		

		# DO NOT ALLOW SLEEP

		caffeinate -dimsuw "$$" &


		# LAUNCH LOGIN PROGRESS APP

		launch_login_progress_app
		

		# ANNOUNCE DELIVER TO I.T. *AFTER* LOGIN WINDOW IS DISPLAYED

		osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
		afplay "${SCRIPT_DIR}/Announcements/fg-deliver-to-it.aiff"

	elif [[ -f '/Library/LaunchDaemons/org.freegeek.fg-snapshot-reset.plist' ]]; then
		# JUST DELETE launch_daemon_path AND SCRIPT_DIR IF THIS IS A BOOT AFTER RESTORING RESET SNAPSHOT (WHICH IS THE *ONLY* SITUATION THAT THE fg-snapshot-reset LAUNCH DAEMON COULD EXIST *BEFORE* THIS SCRIPT RUNS):
		# THE fg-snapshot-reset LAUNCH DAEMON SCRIPT WILL TAKE CARE OF THE REST OF CLEANUP AND SHUT DOWN FOR THE RESET PROCESS.

		rm -f "${launch_daemon_path}"
		rm -rf "${SCRIPT_DIR}"
	elif [[ -f '/private/var/db/.AppleSetupDone' && "${EUID:-$(id -u)}" == '0' && -z "$(dscl . -list /Users ShadowHashData 2> /dev/null | awk '($1 != "_mbsetupuser") { print $1 }')" ]]; then # "_mbsetupuser" may have a password if customizing a clean install that presented Setup Assistant. 
		# Only run if running as root on a clean installation prepared by fg-install-os.
		# IMPORTANT: fg-install-os will create AppleSetupDone to not show Setup Assistant while this script runs.

		log_path='/Users/Shared/Build Info/Prepare OS Log.txt'
		if [[ ! -d '/Users/Shared/Build Info' ]]; then # "Build Info" folder should already exist from the install log, but double-check and create it if needed.
			mkdir -p '/Users/Shared/Build Info'
			chown -R 502:20 '/Users/Shared/Build Info' # Want fg-demo to own the "Build Info" folder, but keep log owned by root.
		fi

		write_to_log() {
			echo -e "$(date '+%D %T')\t$1" >> "${log_path}"
		}

		# ANNOUNCE PREPARING (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)
		# Audio drivers (or something) need a few seconds before audio will be able to play when run early on boot via LaunchDaemon. So try for up to 60 seconds before continuing.

		write_to_log "Starting Customizations (version ${SCRIPT_VERSION})"

		for (( wait_to_play_seconds = 0; wait_to_play_seconds < 60; wait_to_play_seconds ++ )); do
			osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
			if afplay "${SCRIPT_DIR}/Announcements/fg-starting-customizations.aiff" &> /dev/null; then
				break
			else
				sleep 1
			fi
		done
		
		
		# WAIT FOR FULL BOOT TO FINISH BEFORE STARTING CUSTOMIZATIONS
		# Since LaunchDaemons start so early on boot, always wait for full boot before continuing so that everything is run in a consistent state and all system services have been started.
		# Through investigation, I found that "coreauthd" is consistently the last, or nearly the last, root process to be started before the login window is displayed.

		write_to_log 'Waiting for Full Boot'

		until pgrep -qax 'coreauthd'; do
			sleep 2
		done
		

		# DO NOT ALLOW SLEEP WHILE CUSTOMIZING

		write_to_log 'Preventing Sleep During Process'

		caffeinate -dimsuw "$$" &
		caffeinate_pid="$!"


		# ANNOUNCE DO NOT DISTURB *AFTER* LOGIN WINDOW IS DISPLAYED (where it may be tempting to click things)

		osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
		afplay "${SCRIPT_DIR}/Announcements/fg-do-not-disturb.aiff" & # Continue before this is done being said.


		if [[ "$(dsmemberutil checkmembership -U '_mbsetupuser' -G 'admin')" == 'user is a member of the group' ]]; then
			# REMOVE _mbsetupuser FROM ADMIN GROUP
			# If any of the Setup Assistant screens were clicked through, the "_mbsetupuser" may have been added to the admin group.
			# After Setup Assistant is normally completed, macOS would have removed "_mbsetupuser" from the admin group,
			# but since Setup Assistant will not be run "_mbsetupuser" would be left in the admin group and we don't want that to happen.

			write_to_log 'Removing Setup Assistant User from Administrators'

			declare -a admin_groups=( 'admin' '_appserverusr' '_appserveradm' )
			for this_admin_group in "${admin_groups[@]}"; do
				dseditgroup -o edit -d '_mbsetupuser' -t user "${this_admin_group}"
			done
		fi


		if [[ "$(sudo systemsetup -getusingnetworktime)" == *': Off' ]]; then # "sudo" is needed for "systemsetup" within subshell.
			
			# MAKE SURE DATE IS SYNCED
			# Do this BEFORE launching "Free Geek Login Progress" since going back in time after launch can make "delay" in AppleScript hang forever on macOS 11 Big Sur.

			write_to_log 'Turning On Network Time'

			systemsetup -setusingnetworktime on &> /dev/null
			if (( DARWIN_MAJOR_VERSION >= 19 )); then sleep 5; fi # Give system 5 seconds to sync to correct time before turning off network time and setting to midnight for reset Snapshot.
		fi
		

		if (( DARWIN_MAJOR_VERSION >= 19 )); then

			# SET TIME BACK TO MIDNIGHT FOR RESET SNAPSHOT
			# Do this BEFORE starting the "fg-prepare-os" installation since going back in time during installation (within "fg-prepare-os") was making "installer" to hang forever.
			# "fg-prepare-os" will not set the time back to midnight itself during the installation if it was already set back to midnight here.
			# Interestingly, setting the time back to midnight within "fg-prepare-os" when it is run via "startosinstall --installpackage" does not cause any hanging issues.
			# For more information about why this this time manipulation is done in the first place, see the "ABOUT RESET SNAPSHOT TIME MANIPULATION" comments in "fg-prepare-os".
			# ALSO, do this BEFORE launching "Free Geek Login Progress" since going back in time after launch can make "delay" in AppleScript hang forever on macOS 11 Big Sur.

			write_to_log 'Setting Time to Midnight for Reset Snapshot'

			date '+%T' > "${SCRIPT_DIR}/actual-snapshot-time.txt" # Save actual_snapshot_time to be used during Snapshot reset.

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
		fi


		# LAUNCH LOGIN PROGRESS APP

		write_to_log 'Launching Login Progress App'
		launch_login_progress_app

		if ! pgrep -qax 'Free Geek Login Progress'; then
			write_to_log 'Failed to Launch Login Progress App'
		fi


		# INSTALL PACKAGES

		error_installing_package=false

		for this_install_package_path in "${SCRIPT_DIR}/"*'.pkg'; do
			if [[ -f "${this_install_package_path}" ]]; then
				this_install_package_name="${this_install_package_path##*/}"
				this_install_package_name="${this_install_package_name%.*}"
				
				write_to_log "Installing Package \"${this_install_package_name}\""

				if ! installer -pkg "${this_install_package_path}" -target '/'; then
					error_installing_package=true
					break
				fi
			fi
		done


		if ! $error_installing_package; then

			# DELETE LAUNCH DAEMON
			
			rm -f "${launch_daemon_path}" # Do NOT bootout/unload the LaunchDaemon or this script will be terminated immediately. It won't be loaded anyway because it will no longer exist on next boot.


			if [[ ! -f "${launch_daemon_path}" ]]; then

				write_to_log 'Successfully Completed Customizations'

				sleep 3 # Give the Progress app a few seconds to update it's status after the LaunchDaemon file has been deleted.


				# ANNOUNCE REBOOTING (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)

				osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
				afplay "${SCRIPT_DIR}/Announcements/fg-rebooting.aiff"


				# DELETE PARENT FOLDER

				rm -rf "${SCRIPT_DIR}"


				if [[ ! -d "${SCRIPT_DIR}" ]]; then

					# KILL CAFFEINATE

					kill "${caffeinate_pid}" &> /dev/null


					# REBOOT
					
					shutdown -r now &> /dev/null

					exit 0
				fi
			fi
		else

			if id 'fg-demo'; then

				# HIDE FG-DEMO USER (in case fg-demo got created before the critical error)

				dscl . -create '/Users/fg-demo' IsHidden 1
			fi

			if [[ -f '/private/etc/kcpassword' ]]; then

				# DISABLE AUTO-LOGIN (in case it got enabled before the critical error)

				rm -f '/private/etc/kcpassword'
				defaults delete '/Library/Preferences/com.apple.loginwindow' autoLoginUser &> /dev/null
			fi
		fi
		
		
		# ANNOUNCE ERROR (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)

		if ! grep -qF $'\tERROR:' "${log_path}"; then
			# No need to add another error line if an error occurred and was logged during package installation.
			write_to_log 'ERROR: Failed to Perform Previous Task'
		fi

		osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
		afplay "${SCRIPT_DIR}/Announcements/fg-error-occurred.aiff"
		afplay "${SCRIPT_DIR}/Announcements/fg-deliver-to-it.aiff"
	else
		
		# ANNOUNCE ERROR (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)
		# Audio drivers (or something) need a few seconds before audio will be able to play when run early on boot via LaunchDaemon. So try for up to 60 seconds before continuing.	
		
		for (( wait_to_play_seconds = 0; wait_to_play_seconds < 60; wait_to_play_seconds ++ )); do
			osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
			if afplay "${SCRIPT_DIR}/Announcements/fg-error-occurred.aiff" &> /dev/null; then
				afplay "${SCRIPT_DIR}/Announcements/fg-deliver-to-it.aiff"
				break
			else
				sleep 1
			fi
		done
	fi
fi
