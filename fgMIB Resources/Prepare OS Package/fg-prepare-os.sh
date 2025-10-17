#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

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

readonly SCRIPT_VERSION='2025.10.16-1'

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy.

DARWIN_MAJOR_VERSION="$(uname -r | cut -d '.' -f 1)" # 19 = 10.15 Catalina, 20 = 11 Big Sur, 21 = 12 Monterey, 22 = 13 Ventura, 23 = 14 Sonoma, 24 = 15 Sequoia, 25 = 26 Tahoe, etc.
readonly DARWIN_MAJOR_VERSION

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}/" || echo '/private/tmp/')" # Make sure "TMPDIR" is always set and that it always has a trailing slash for consistency regardless of the current environment.

critical_error_occurred=false

if (( DARWIN_MAJOR_VERSION >= 17 )) && [[ ! -f '/private/var/db/.AppleSetupDone' || -f '/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist' ]] &&
	[[ "$3" == '/' && "${EUID:-$(id -u)}" == '0' && -z "$(dscl . -list /Users ShadowHashData 2> /dev/null | awk '($1 != "_mbsetupuser") { print $1 }')" ]]; then # "_mbsetupuser" may have a password if customizing a clean install that presented Setup Assistant.

	log_path='/Users/Shared/Build Info/Prepare OS Log.txt'
	if [[ ! -d '/Users/Shared/Build Info' ]]; then # "Build Info" folder should already exist from the install log, but double-check and create it if needed.
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

		rm -f '/private/var/db/.AppleSetupTermsOfService' # Starting in macOS 15.4 Sequoia, this file may exist by default and is DELETED when the "Terms and Conditions" are manually agreed to during Setup Assistant. So, delete it so that the T&C Setup Assistant screen is not shown when we are trying to totally skip Setup Assistant.

		if [[ ! -f '/private/var/db/.AppleSetupDone' || -f '/private/var/db/.AppleSetupTermsOfService' ]]; then
			write_to_log 'ERROR: Failed to Skip Setup Assistant'
			critical_error_occurred=true
		fi
	fi


	if [[ -f '/private/var/db/dslocal_orig.cpgz' || -n "$(find '/private/var/db' -maxdepth 1 -type f -name 'PreviousSystem*' -print -quit 2> /dev/null)" ]]; then

		# DELETE FILES LEFTOVER FROM THE "UPGRADE/RE-INSTALL TRICK"
		# Search for "UPGRADE/RE-INSTALL TRICK" in the "fg-install-os" script for more information about that process.
		# Oddly, it seems on Apple Silicon that just "PreviousSystemVersion.plist" will exist while on Intel "PreviousSystemVersion.plist" WILL NOT exist
		# and "PreviousSystemFiles.plist" and "PreviousSystemLogs.plist" will exist (both of which don't exist on Apple Silicon).
		# I'm not sure if that difference is because of using "startosinstall" on Intel vs manually running the
		# "InstallAssistant" app on Apple Silicon or if it is because of platform differences.
		# Also, "dslocal_orig.cpgz" will always exist on both Apple Silicon and Intel.
		# So, no matter which ones of these files exist, delete all of them since they are not useful and just leftovers
		# and having them not exist makes the system closer to an actual "clean install" state like we are intending.

		write_to_log 'Deleting Leftover Files From Upgrade/Re-Install Trick'

		rm -f '/private/var/db/dslocal_orig.cpgz' '/private/var/db/PreviousSystem'*
	fi


	if [[ -f "$1" ]]; then

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
		elif [[ "$1" != '/Users/Shared/fg-customization-resources/'* ]]; then
			# Log a note if installed via "startosinstall --installpackage" and package is in a different location.

			write_to_log 'NOTE: New Location for Package Parent Folder'
		fi
	fi


	should_install_apps_in_darwin_folder() {
		local this_darwin_folder_name="${1##*/}"

		if [[ "${this_darwin_folder_name}" == 'darwin-all-versions' ]]; then
			return 0
		else
			IFS='-' read -rd '' -a this_darwin_folder_name_parts < <(echo -n "${this_darwin_folder_name}") # MUST to use "echo -n" and process substitution since a here-string would add a trailing line break that would be included in the last value.
			local this_darwin_comparison
			this_darwin_comparison="$(echo "${this_darwin_folder_name_parts[1]}" | tr '[:upper:]' '[:lower:]')"
			local this_darwin_version="${this_darwin_folder_name_parts[2]}"

			if [[ -n "${this_darwin_comparison}" && "${this_darwin_version}" =~ ^[[:digit:]]+$ ]] && {
					{ [[ "${this_darwin_comparison}" == 'eq' ]] && (( DARWIN_MAJOR_VERSION == this_darwin_version )); } ||
					{ [[ "${this_darwin_comparison}" == 'lt' ]] && (( DARWIN_MAJOR_VERSION < this_darwin_version )); } ||
					{ [[ "${this_darwin_comparison}" == 'le' ]] && (( DARWIN_MAJOR_VERSION <= this_darwin_version )); } ||
					{ [[ "${this_darwin_comparison}" == 'gt' ]] && (( DARWIN_MAJOR_VERSION > this_darwin_version )); } ||
					{ [[ "${this_darwin_comparison}" == 'ge' ]] && (( DARWIN_MAJOR_VERSION >= this_darwin_version )); }
				}; then
				return 0
			fi
		fi

		return 1
	}

	verify_code_signature() {
		# USAGE NOTES: By default, this function will verify the specified path is code signed with any Developer ID. The specified path can be any type of signed/notarized bundle or flat file.
		# To verify the path is notarized, also pass "notarized" or "notarization" as an argument (order of arguments doesn't matter).
		# To verify the Team ID of the Developer ID used to sign the path, also pass the 10-character Team ID as an argument.
		# To verify the path is signed by Apple directly (which would otherwise fail all other default or explicit verifications mentioned above), pass just "apple" as an argument along with the path.
		# NOTE: Mac App Store apps CANNOT be verified with this function as it is only intended to verify things downloaded/installed from the internet outside of the Mac App Store.

		local verify_code_signature_path=''
		local verify_apple_signed=false
		local verify_notarization=false
		local verify_team_id=''

		local this_arg
		while (( $# > 0 )); do
			if [[ -n "$1" ]]; then
				this_arg="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" # Make args all caps so they can be case-insensitive and so that Team IDs are always valid since they must always be all caps.
				if [[ "${this_arg}" == 'DO-NOT-VERIFY' ]]; then
					return 0
				elif [[ "${this_arg}" == 'APPLE' ]]; then
					verify_apple_signed=true
				elif [[ "${this_arg}" == 'NOTARIZED' || "${this_arg}" == 'NOTARIZATION' ]]; then
					if (( DARWIN_MAJOR_VERSION >= 18 )); then
						# The "spctl -a ..." output on macOS 10.13 High Sierra will only ever include "source=Developer ID" even if it is actually notarized while macOS 10.14 Mojave and newer will include "source=Notarized Developer ID",
						# and the "notarized" token that can be verified via "codesign -vR ..." is also only available on macOS 10.14 Mojave and newer.
						verify_notarization=true
					else
						echo 'NOTICE: Notarization WILL NOT be verified. Notarization verification requires running on macOS 10.14 Mojave or newer.'
					fi
				elif [[ -e "$1" ]]; then
					verify_code_signature_path="$1"
				elif [[ "${this_arg}" =~ ^[A-Z0-9]{10}$ ]]; then # Team IDs are always 10 characters of capital letters and digits: https://developer.apple.com/help/account/manage-your-team/locate-your-team-id/
					verify_team_id="${this_arg}"
				else # Do not proceed if invalid args are passed.
					>&2 echo "ERROR: INVALID \"$1\" OPTION SPECIFIED (PATH MUST EXIST AND TEAM IDS MUST BE 10 CHARACTERS OF ONLY LETTERS AND DIGITS)"
					return 100
				fi
			fi

			shift
		done

		if [[ -z "${verify_code_signature_path}" ]]; then
			>&2 echo 'ERROR: NO PATH SPECIFIED'
			return 101
		fi

		echo "Verifying Code Signature of \"${verify_code_signature_path}\"..."

		declare -a codesign_verify_csreqs=() # NOTE: "declare" always and only makes "local" variables.
		# Explanation of Code Signing Requirements (CSReqs): https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements

		local is_package=false
		local is_non_app_bundle=false
		if [[ -f "${verify_code_signature_path}" ]]; then
			# NOTE: Any kind of regular flat file can be signed, but packages, disk images, and Mach-O binaries are the only flat files that can also be notarized.
			# Also, the signature for the other signed regular flat files is stored in extended attributes rather than embedded in the file contents.
			if [[ "${verify_code_signature_path}" == *'.'[Pp][Kk][Gg] ]]; then # Must detect packages since they need to be verified using "spctl -avv -t install" and "pkgutil --check-signature" (and NOT "codesign -v ...").
				echo 'Path Type: PACKAGE'
				is_package=true
			elif [[ "${verify_code_signature_path}" == *'.'[Dd][Mm][Gg] ]]; then # This and the following checks are just for display purposes, all will be verified the same way using "spctl -avv -t open ...".
				echo 'Path Type: DISK IMAGE'
			elif [[ "$(file -b --mime-type "${verify_code_signature_path}" 2> /dev/null)" == 'application/x-mach-binary'* ]]; then
				echo 'Path Type: MACH-O BINARY'
			else
				echo 'Path Type: REGULAR FILE'
			fi
		elif [[ ! -f "${verify_code_signature_path}/Contents/Info.plist" ]]; then
			>&2 echo 'ERROR: INVALID BUNDLE PATH SPECIFIED (NO "Info.plist" FILE FOUND)'
			return 102
		else
			local bundle_id=''
			if ! bundle_id="$(PlistBuddy -c 'Print :CFBundleIdentifier' "${verify_code_signature_path}/Contents/Info.plist" 2> /dev/null)" || [[ -z "${bundle_id}" ]]; then
				>&2 echo 'ERROR: INVALID BUNDLE PATH SPECIFIED (NO "CFBundleIdentifier" WITHIN "Info.plist" FILE)'
				return 103
			fi

			codesign_verify_csreqs=( "identifier \"${bundle_id}\"" ) # Doubly-verify that Bundle IDs are properly specified in the CSReqs. (This is not really necessary, but doesn't hurt to make sure everything is correct).

			if [[ "${verify_code_signature_path}" != *'.'[Aa][Pp][Pp] ]]; then # Must detect non-app bundles vs app bundles because they must be verified with "spctl -avv -t open ..." rather than just "spctl -avv" like an app bundle (and "codesign -v ..." works for both).
				echo 'Path Type: NON-APP BUNDLE'
				is_non_app_bundle=true
			else
				echo 'Path Type: APP BUNDLE'
			fi
		fi

		if $verify_apple_signed; then
			echo 'Explicit Verification: APPLE SIGNED'
		else
			if $verify_notarization; then
				echo 'Explicit Verification: NOTARIZATION'
			fi

			if [[ -n "${verify_team_id}" ]]; then
				echo "Explicit Verification: TEAM ID \"${verify_team_id}\""
			fi
		fi

		if ! $is_package; then # Output CSReqs just for debug/display purposes.
			echo -e '\nCODE SIGNING REQUIREMENTS (codesign -dr -):'
			codesign -dr - "${verify_code_signature_path}" 2>&1
		fi

		declare -a spctl_assess_args=( '-avv' ) # "spctl" defaults to "-t execute" when no other "-t" ("--type") is specified.
		if $is_package; then
			spctl_assess_args+=( '-t' 'install' )
		elif [[ -z "${bundle_id}" ]] || $is_non_app_bundle; then
			# Verifying signed/notarized non-app bundles or files such as disk images, Mach-O binaries, and any other signed (file such as a script) MUST be done using
			# "spctl -avv -t open --context context:primary-signature" since just "spctl -avv" only works for app bundles and "spctl -avv -t install" only works with packages.
			# (But, "codesign -v ..." works with any of these files as well as apps and only doesn't work with packages.)
			# If just "spctl -avv" (which is equivalent to "spctl -avv -t execute") is used on a non-app bundle or non-package file, they error with
			# "rejected (the code is valid but does not seem to be an app)" and also DO NOT show any "source" info where the notarization status is listed.
			# Running "spctl -avv -t open" on its own for these files will be rejected with "source=Insufficient Context" and adding "--context context:primary-signature"
			# solves that problem, but oddly that "--context" option is not listed in "man spctl" or the usage/help info for "spctl".
			# But, this "--context context:primary-signature" usage is offically documented here in regards to verifying disk images (but also works for all other non-app and non-package verifications):
			# https://developer.apple.com/library/archive/technotes/tn2206/_index.html#//apple_ref/doc/uid/DTS40007919-CH1-TNTAG18
			spctl_assess_args+=( '-t' 'open' '--context' 'context:primary-signature' )
		fi

		echo -e "\nSECURITY ASSESSMENT OUTPUT (spctl ${spctl_assess_args[*]}):"
		local spctl_assess_output
		spctl_assess_output="$(spctl "${spctl_assess_args[@]}" "${verify_code_signature_path}" 2>&1)"
		local spctl_assess_exit_code="$?"

		echo -e "${spctl_assess_output}\nSECURITY ASSESSMENT EXIT CODE: ${spctl_assess_exit_code}"
		if (( spctl_assess_exit_code != 0 )); then
			echo 'SECURITY ASSESSMENT EXIT CODE NOTE: A "rejected" status and non-zero (failure) exit code from "spctl" DOES NOT fail verification in this function since specified factors will be verified explicitly whether or not "spctl" rejected the path.'

			# NOTE: NOT relying on the "accepted" or "rejected" status or exit code from the "spctl -a" assessment because we may be intentionally verifying more or less strict than the "spctl -a" assessment.
			# Here are some (but not all possible) examples of when our verifications won't necessarily match the status or exit code from the "spctl -a" assessment:
			# - Signed but unnotarized app bundles are "accepted" by "spctl -avv" so the zero exit code is irrelevant if we are explicitly verifying notarization.
			# - Signed scripts are "rejected" by "spctl -avv -t open ..." and fail with a non-zero exit code, but they CANNOT be notarized so we want to be able to pass even when the "spctl -a" assessment fails.
			# - Signed but unnotarized packages are "rejected" by by "spctl -avv -t install" and fail with a non-zero exit code but there are times when we may want to verify a signed but unnotarized package for internal usage.
			# - If macOS security settings are set to only allow apps downloaded from the Mac App Store, all notarized apps are "rejected" by "spctl -avv" and fail with a non-zero exit code, but we may still want to be able to just confirm that they are properly signed/notarized.
			# - On macOS 10.14 Mojave and older, unnotarized flat files such as disk images, packages, or scripts are "accepted" while on macOS 10.15 Catalina and newer they are "rejected", so would not get consistent results across all versions of macOS if the "spctl -a" assessment status was relied on.
			# - The "spctl -a" status can be manually overridden by a user using Right-Click+Open to explicitly allowing opening/launching, so an "accepted" status with "source=explicit preference" and zero exit code is possible even if something like a package is not even signed but has been manually allowed by a user.
		fi

		# NOTE: Along with the the "spctl_assess_output" verifications done below, packages and other products will also be double-checked with "pkgutil --check-signature" and "codesign -v ..." respectively.
		# Package verifications are double-checked immediately after the "spctl_assess_output" verification passes using the "pkgutil_check_signature_output" that is set below from "pkgutil --check-signature" since "codesign" cannot be used to verify packages.
		# All other bundle/file verifications will be double-checked all at once using "codesign -v ..." with the CSReq conditions that are added to the "codesign_verify_csreqs" by passing them to the "-R" ("--test-requirement") as a Code Signing Requirement condition string.
		# These double-checks should be guaranteed to success after the explicit "spctl" verifications, but still do them anyway just to be extremely thorough.

		local pkgutil_check_signature_output=''
		if $is_package; then
			echo -e '\nPACKAGE SIGNATURE CHECK OUTPUT (pkgutil --check-signature):'
			pkgutil_check_signature_output="$(pkgutil --check-signature "${verify_code_signature_path}" 2>&1)"
			local pkgutil_check_signature_exit_code="$?"

			echo -e "${pkgutil_check_signature_output}\nPACKAGE SIGNATURE CHECK EXIT CODE: ${pkgutil_check_signature_exit_code}"

			if (( pkgutil_check_signature_exit_code != 0 )); then # DO exit upon "pkgutil --check-signature" failure since it would only fail if completely unsigned, regardless of notarization (unlike "spctl -a ...").
				>&2 echo "ERROR: PACKAGE SIGNATURE CHECK FAILED WITH EXIT CODE ${pkgutil_check_signature_exit_code} (SEE OUTPUT ABOVE FOR MORE INFO)"
				return "${pkgutil_check_signature_exit_code}"
			fi
		fi

		echo -e '\nEXPLICIT VERIFICATIONS:'
		if $verify_apple_signed; then
			echo -n 'Verifying Apple Signed via "spctl" Output...'
			if [[ "${spctl_assess_output}" != *$'\nsource=Apple '"$($is_package && echo 'Installer' || echo 'System')"$'\n'* ]]; then
				echo ''
				>&2 echo 'ERROR: FAILED TO EXPLICITLY VERIFY APPLE SIGNED VIA "spctl" OUTPUT (SEE OUTPUT ABOVE FOR MORE INFO)'
				return 104
			else
				echo ' VERIFIED'
				if $is_package; then
					echo -n 'Verifying Apple Signed via "pkgutil" Output...'
					if [[ "${pkgutil_check_signature_output}" != *$'\n    1. Software Update\n'* ]]; then
						echo ''
						>&2 echo 'ERROR: FAILED TO EXPLICITLY VERIFY APPLE SIGNED VIA "pkgutil" OUTPUT (SEE OUTPUT ABOVE FOR MORE INFO)'
						return 105
					fi
					echo ' VERIFIED'
				else
					codesign_verify_csreqs+=( 'anchor apple' ) # This anchor can only exist 1st party products signed directly by Apple.
				fi
			fi
		else
			# NOTE: Mac App Store installed apps would always fail the following verification since they will always be "source=Mac App Store" and "origin=Apple Mac OS Application Signing" as well as different
			# CSReq certificates, but this function is for verifying products downloaded/installed via script, so verifying Mac App Store apps is unnecessary and out of the scope of what this function is designed for.

			if ! $is_package; then
				codesign_verify_csreqs+=(
					'anchor apple generic' # This anchor exists for Developer ID (or Mac App Store) signed products.
					'certificate 1[field.1.2.840.113635.100.6.2.6] exists' # Developer ID Certification Authority certificate used by Apple to issue Developer ID signing certificates.
					'certificate leaf[field.1.2.840.113635.100.6.1.13] exists' # Developer ID Application signing certificates issued by Apple.
				)
				# Specific details about these Developer ID certificates are available here: https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements#Developer-ID-default-designated-requirement
				# (If Mac App Store apps were being verified, would need to check for "certificate leaf[field.1.2.840.113635.100.6.1.9] exists" instead of the 2 listed above.)
			fi

			if $verify_notarization; then
				# Only bundles, packages, disk images, or Mach-O binaries can be notarized while files such as scripts can only be signed but not notarized.
				# If notarization is specified to be verified against a signed script (which cannot be notarized), this check will always fail,
				# but the user of the function should simply not be specifying notarization verification for valid signed files that are known
				# to not be notarized and only Team ID verification should be done instead.

				echo -n 'Verifying Notarization via "spctl" Output...'
				if [[ "${spctl_assess_output}" != *$'\nsource=Notarized Developer ID\n'* ]]; then
					echo ''
					>&2 echo 'ERROR: FAILED TO EXPLICITLY VERIFY NOTARIZATION VIA "spctl" OUTPUT (SEE OUTPUT ABOVE FOR MORE INFO)'
					return 106
				else
					echo ' VERIFIED'
					if $is_package; then
						if (( DARWIN_MAJOR_VERSION >= 21 )); then
							echo -n 'Verifying Notarization via "pkgutil" Output...'
							if [[ "${pkgutil_check_signature_output}" != *$'\n   Notarization: trusted by the Apple notary service\n'* ]]; then # This "Notarization" line will only exist in the "pkgutil --check-signature" output on macOS 12 Monterey and newer.
								echo ''
								>&2 echo 'ERROR: FAILED TO EXPLICITLY VERIFY NOTARIZATION VIA "pkgutil" OUTPUT (SEE OUTPUT ABOVE FOR MORE INFO)'
								return 107
							fi
							echo ' VERIFIED'
						else
							echo 'NOTICE: Notarization has been verified via "spctl" output, but cannot be double-checked via "pkgutil" unless running running on macOS 12 Monterey or newer.'
						fi
					else
						codesign_verify_csreqs+=( 'notarized' ) # NOTE: Starting on macOS 10.14 Mojave, there is a "notarized" token which can be included in the CSReq string to confirm the app is notarized (discovered this wasn't supported/available on macOS 10.13 High Sierra through testing).
						# This "notarized" token can be seen in the output of "spctl --list" on macOS 10.14 Mojave and newer and can also be seen here: https://gregoryszorc.com/docs/apple-codesign/stable/apple_codesign_gatekeeper.html
						# And using this "notarized" token to verify notarization can be seen here: https://developer.apple.com/forums/thread/128683?answerId=404727022#404727022 & https://developer.apple.com/forums/thread/130560
					fi
				fi
			fi

			if [[ -n "${verify_team_id}" ]]; then
				echo -n "Verifying Team ID \"${verify_team_id}\" via \"spctl\" Output..."
				if [[ "${spctl_assess_output}" != *$'\norigin=Developer ID '"$($is_package && echo 'Installer' || echo 'Application'): "*" (${verify_team_id})" ]]; then
					echo ''
					>&2 echo "ERROR: FAILED TO EXPLICITLY VERIFY TEAM ID \"${verify_team_id}\" VIA \"spctl\" OUTPUT (SEE OUTPUT ABOVE FOR MORE INFO)"
					return 108
				else
					echo ' VERIFIED'
					if $is_package; then
						echo -n "Verifying Team ID \"${verify_team_id}\" via \"pkgutil\" Output..."
						if [[ "${pkgutil_check_signature_output}" != *$'\n    1. Developer ID Installer: '*" (${verify_team_id})"$'\n'* ]]; then
							echo ''
							>&2 echo "ERROR: FAILED TO EXPLICITLY VERIFY TEAM ID \"${verify_team_id}\" VIA \"pkgutil\" OUTPUT (SEE OUTPUT ABOVE FOR MORE INFO)"
							return 109
						fi
						echo ' VERIFIED'
					else
						codesign_verify_csreqs+=( "certificate leaf[subject.OU] = \"${verify_team_id}\"" ) # NOTE: "verify_team_id" value MUST be quoted in case it starts with a NUMBER (but quotes are not required if it starts with a LETTER).
					fi
				fi
			else
				echo -n 'Verifying Any Developer ID via "spctl" Output...'
				if [[ "${spctl_assess_output}" != *$'\norigin=Developer ID '"$($is_package && echo 'Installer' || echo 'Application'): "*' ('??????????')' ]]; then # Still verify Developer ID and SOME Team ID when not verifying a specific 10-character Team ID.
					echo ''
					>&2 echo 'ERROR: FAILED TO EXPLICITLY VERIFY DEVELOPER ID VIA "spctl" OUTPUT (SEE OUTPUT ABOVE FOR MORE INFO)'
					return 110
				else
					echo ' VERIFIED'
					if $is_package; then
						echo -n 'Verifying Any Developer ID via "pkgutil" Output...'
						if [[ "${pkgutil_check_signature_output}" != *$'\n    1. Developer ID Installer: '*' ('??????????$')\n'* ]]; then
							echo ''
							>&2 echo 'ERROR: FAILED TO EXPLICITLY VERIFY DEVELOPER ID VIA "pkgutil" OUTPUT (SEE OUTPUT ABOVE FOR MORE INFO)'
							return 111
						fi
						echo ' VERIFIED'
					fi
				fi
			fi
		fi

		if (( ${#codesign_verify_csreqs[@]} > 0 )); then
			# As explained above, "spctl -a ..." is used for primary verification, and packages were double-checked above using "pkgutil --check-signature".
			# Now, all other bundle/file verifications will be double-checked below all at once using "codesign -v ..." with the CSReq conditions that were added to the "codesign_verify_csreqs" by passing them to the "-R" ("--test-requirement") as a Code Signing Requirement condition string.

			local codesign_verify_csreqs_condition_string # "codesign_verify_csreqs_condition_string" will never be empty since the "codesign_verify_csreqs" array will always contain at least "anchor apple" or "anchor apple generic" and may also contain more verification conditions.
			printf -v codesign_verify_csreqs_condition_string '%s and ' "${codesign_verify_csreqs[@]}" # Join the elements of the "codesign_verify_csreqs" array into a string using a "printf" format string that adds " and " after of each element to create a valid condition string.
			codesign_verify_csreqs_condition_string="${codesign_verify_csreqs_condition_string% and }" # BUT, joining array elements using a "printf" format string like this still includes a trailing " and " so remove it from the end of the string.

			# CODESIGN NOTES:
			# Information about using "--deep" and "--strict" options during "codesign" verification:
				# https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/resolving_common_notarization_issues#3087735
				# https://developer.apple.com/library/archive/technotes/tn2206/_index.html#//apple_ref/doc/uid/DTS40007919-CH1-TNTAG211
				# https://developer.apple.com/library/archive/technotes/tn2206/_index.html#//apple_ref/doc/uid/DTS40007919-CH1-TNTAG404
			# The "--deep" option is DEPRECATED in macOS 13 Ventura for SIGNING but I don't think it's deprecated for VERIFYING since verification is where it was always really intended to be used (as explained in the note in the last link in the list above).
			# NOT using "--check-notarization" (added in macOS 10.15 Catalina) since the command seems to just to always exit 0 even if the specifed app is signed but NOT notarized, so doesn't seem useful. (Maybe it would make a difference if the notarization ticket was not stapled, but that's not normal and maybe should fail if not stapled.)

			local codesign_verify_output
			codesign_verify_output="$(codesign -vv --deep --strict -R "=${codesign_verify_csreqs_condition_string}" "${verify_code_signature_path}" 2>&1)" # "--deep" is not necessary when verifying non-bundles, but doesn't hurt.
			local codesign_verify_exit_code="$?"

			echo -e "\nCODE SIGNATURE AND EXPLICIT CSREQS VERIFICATION OUTPUT (codesign -vv --deep --strict -R '=${codesign_verify_csreqs_condition_string}'):\n${codesign_verify_output}\nCODE SIGNATURE AND EXPLICIT CSREQS VERIFICATION EXIT CODE: ${codesign_verify_exit_code}"

			if (( codesign_verify_exit_code != 0 )); then # DO exit upon "codesign -v ..." failure since it would only fail if completely unsigned or our explicit requirements are not met (unlike "spctl -a ...").
				>&2 echo "ERROR: CODE SIGNATURE VERIFICATION FAILED WITH EXIT CODE ${codesign_verify_exit_code} (SEE OUTPUT ABOVE FOR MORE INFO)"
				return "${codesign_verify_exit_code}"
			fi
		fi

		return 0 # If no error returned non-zero before this point, all verifications were successful.
	}

	install_app_from_package() {
		local package_to_install=''
		declare -a app_verification_args=()

		while (( $# > 0 )); do # Args can be passed in any order.
			# Any existing ".pkg" file path will be "package_to_install" and all other args will be
			# collected in "app_verification_args" to be passed on to the "verify_code_signature" function.
			if [[ -n "$1" ]]; then
				if [[ -f "$1" && "$1" == *'.'[Pp][Kk][Gg] ]]; then
					package_to_install="$1"
				else
					app_verification_args+=( "$1" )
				fi
			fi

			shift
		done

		if [[ -z "${package_to_install}" ]]; then
			return 1
		fi

		if [[ "${package_to_install}" == *'/Safari'* ]]; then # NOTE: Just install and do not check for app within package for Safari packages since they more complex, especially for macOS 13 Ventura with Cryptexes.
			if ! verify_code_signature "${app_verification_args[@]}" "${package_to_install}" &> /dev/null || ! installer -pkg "${package_to_install}" -target '/'; then
				return 3
			fi
		else
			local this_packaged_app_filename
			this_packaged_app_filename="$(pkgutil --payload-files "${package_to_install}" | grep -im 1 '\.app$')" # NOTE: There technically could be multiple apps or apps that install into locations other than "/Applications" within a package, but none that we install are like that so not worrying about that complexity (but they would still get installed, just not verified or logged properly).
			local this_packaged_app_filename="${this_packaged_app_filename##*/}"
			printf '%s' "${this_packaged_app_filename}" # Output file name for retrieval via command substitution for usage in other commands and logging (whether or not there is an error).

			if [[ -z "${this_packaged_app_filename}" ]]; then
				return 2
			fi

			rm -rf "/Applications/${this_packaged_app_filename}" # Delete app if it already exist from previous customization before reset.

			if ! verify_code_signature "${app_verification_args[@]}" "${package_to_install}" &> /dev/null || ! installer -pkg "${package_to_install}" -target '/' || ! verify_code_signature "${app_verification_args[@]}" "/Applications/${this_packaged_app_filename}" &> /dev/null; then
				rm -rf "/Applications/${this_packaged_app_filename}"
				return 3
			fi

			xattr -drs com.apple.quarantine "/Applications/${this_packaged_app_filename}"
			touch "/Applications/${this_packaged_app_filename}"
		fi
	}

	install_app_from_archive() {
		local archive_to_install=''
		local app_install_folder='/Applications'
		declare -a app_verification_args=()

		while (( $# > 0 )); do # Args can be passed in any order.
			# Any existing ".zip" file path will be "archive_to_install" and any existing folder will be "app_install_folder",
			# and all other args will be collected in "app_verification_args" to be passed on to the "verify_code_signature" function.
			if [[ -n "$1" ]]; then
				if [[ -f "$1" && "$1" == *'.'[Zz][Ii][Pp] ]]; then
					archive_to_install="$1"
				elif [[ -d "$1" ]]; then
					app_install_folder="$1"
				else
					app_verification_args+=( "$1" )
				fi
			fi

			shift
		done

		if [[ -z "${archive_to_install}" ]]; then
			return 1
		fi

		local this_archived_app_filename
		this_archived_app_filename="$(zipinfo -1 "${archive_to_install}" | grep -im 1 '\.app/$')" # NOTE: There technically could be multiple apps within an archive, but none that we install are like that so not worrying about that complexity (but they would still get installed, just not verified or logged properly).
		local this_archived_app_filename="${this_archived_app_filename%/}"

		local this_archived_app_parent_folder=''
		if [[ "${this_archived_app_filename}" == *'/'* ]]; then # Detect if the archive will extract the app within a folder rather than directly in the target install folder.
			this_archived_app_parent_folder="${this_archived_app_filename%/*}"
			this_archived_app_filename="${this_archived_app_filename##*/}"
		fi

		printf '%s' "${this_archived_app_filename}" # Output file name for retrieval via command substitution for usage in other commands and logging (whether or not there is an error).

		if [[ -z "${this_archived_app_filename}" ]]; then
			return 2
		fi

		if [[ -n "${this_archived_app_parent_folder}" ]]; then
			rm -rf "${app_install_folder:?}/${this_archived_app_parent_folder}" # Delete parent folder if it already exist from previous installation.
		fi

		rm -rf "${app_install_folder:?}/${this_archived_app_filename}" # Delete app if it already exist from previous installation.

		if ! ditto -xk --noqtn "${archive_to_install}" "${app_install_folder}" &> /dev/null; then
			if [[ -n "${this_archived_app_parent_folder}" ]]; then
				rm -rf "${app_install_folder:?}/${this_archived_app_parent_folder}" # Delete parent folder if it already exist from previous installation.
			fi

			rm -rf "${app_install_folder:?}/${this_archived_app_filename}"

			return 3
		fi

		if [[ -n "${this_archived_app_parent_folder}" ]]; then # If archive extracted app into a folder, move the app to the target install folder and delete the parent folder.
			mv -f "${app_install_folder:?}/${this_archived_app_parent_folder}/${this_archived_app_filename}" "${app_install_folder:?}/${this_archived_app_filename}"
			rm -rf "${app_install_folder:?}/${this_archived_app_parent_folder}"
		fi

		if [[ ! -d "${app_install_folder}/${this_archived_app_filename}" ]] || ! verify_code_signature "${app_verification_args[@]}" "${app_install_folder}/${this_archived_app_filename}" &> /dev/null; then
			rm -rf "${app_install_folder:?}/${this_archived_app_filename}"
			return 4
		fi

		touch "${app_install_folder}/${this_archived_app_filename}"
	}

	install_app_from_disk_image() {
		local disk_image_to_install=''
		local app_install_folder='/Applications'
		local verify_disk_image=true # NOTE: It is not uncommon for valid disk images to NOT be signed/notarized (even from big developers),
		# so a "DO-NOT-VERIFY-DMG" arg can be passed to this function to bypass disk image verification when needed while still verifying the app itself.

		declare -a app_verification_args=()

		while (( $# > 0 )); do # Args can be passed in any order.
			# Any existing ".dmg" file path will be "disk_image_to_install" and any existing folder will be "app_install_folder",
			# and all other args (other than "DO-NOT-VERIFY-DMG" mentioned above) will be collected in "app_verification_args" to be passed on to the "verify_code_signature" function.
			if [[ -n "$1" ]]; then
				if [[ -f "$1" && "$1" == *'.'[Dd][Mm][Gg] ]]; then
					disk_image_to_install="$1"
				elif [[ -d "$1" ]]; then
					app_install_folder="$1"
				elif [[ "$1" == 'DO-NOT-VERIFY-DMG' ]]; then
					verify_disk_image=false
				else
					app_verification_args+=( "$1" )
				fi
			fi

			shift
		done

		if [[ -z "${disk_image_to_install}" ]]; then
			return 1
		fi

		if $verify_disk_image && ! verify_code_signature "${app_verification_args[@]}" "${disk_image_to_install}" &> /dev/null; then # See notes above about bypassing disk image verification when needed by passing the "DO-NOT-VERIFY-DMG" arg.
			return 2
		fi

		local dmg_mount_path
		dmg_mount_path="$(echo 'Y' | hdiutil attach "${disk_image_to_install}" -nobrowse -readonly -plist 2> /dev/null | awk '($0 == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"), ($0 == "</plist>")' | xmllint --xpath 'string(//string[starts-with(text(), "/Volumes/")])' - 2> /dev/null)"
		# NOTE: Pipe "echo 'Y'" to "hdiutil attach" in case there is a license agreement that needs to be agreed to AND use an "awk" range pattern to retrieve only the plist lines from the output since the whole license agreement will be included in the output which would break "xmllint" parsing if it was included.
		# ALSO NOTE: There technically could be multiple volumes mounted by a disk image, but none that we install are like that so not worrying about that complexity and the "xmllint" command being used will only return the path of the first volume listed within the plist output
		# (because of the XPath "string()" commands behavior of only ever returning a single value even if an array is passed to it) and also only the first app detected in that volume will be installed (more notes about single app installs from within a disk image below).

		if [[ ! -d "${dmg_mount_path}" ]]; then
			return 3
		fi

		local install_app_from_dmg_return_code=0 # Save return code for end of function instead of returning immediately so that disk image can always be detached even if there was an error within the loop.

		local this_app_in_dmg_path
		local this_app_in_dmg_filename
		for this_app_in_dmg_path in "${dmg_mount_path}/"*'.'[Aa][Pp][Pp]; do # NOTE: Only the FIRST app found within a disk image will only ever be installed even though there technically could be multiple apps within a volume from a mounted disk image, but none that we install are like that so not worrying about that complexity.
			if ! verify_code_signature "${app_verification_args[@]}" "${this_app_in_dmg_path}" &> /dev/null; then
				printf '%s' "${dmg_mount_path}" # Output disk image mount path for retrieval via command substitution for logging (whether or not there is an error).
				install_app_from_dmg_return_code=4
				break
			fi

			this_app_in_dmg_filename="${this_app_in_dmg_path##*/}"
			printf '%s' "${this_app_in_dmg_filename}" # Output file name for retrieval via command substitution for usage in other commands and logging (whether or not there is an error).

			rm -rf "${app_install_folder:?}/${this_app_in_dmg_filename}" # Delete app if it already exist from previous customization before reset.

			if ! ditto "${this_app_in_dmg_path}" "${app_install_folder}/${this_app_in_dmg_filename}" &> /dev/null || ! verify_code_signature "${app_verification_args[@]}" "${app_install_folder}/${this_app_in_dmg_filename}" &> /dev/null; then
				rm -rf "${app_install_folder:?}/${this_app_in_dmg_filename}"

				install_app_from_dmg_return_code=5
				break
			fi

			xattr -drs com.apple.quarantine "${app_install_folder}/${this_app_in_dmg_filename}"
			touch "${app_install_folder}/${this_app_in_dmg_filename}"

			break # NOTE: There technically could be multiple apps within a volume from a mounted disk image, but none that we install are like that so not worrying about that complexity (any other apps within a disk image will NOT be installed).
		done

		hdiutil detach "${dmg_mount_path}" &> /dev/null

		return "${install_app_from_dmg_return_code}"
	}

	if ! $critical_error_occurred; then

		# INSTALL GLOBAL APPS
		# Do this before creating reset Snapshot since we want the customer to have these Apps pre-installed.

		for this_global_apps_darwin_folder_path in "$2/Global/Apps/darwin-"*; do
			if should_install_apps_in_darwin_folder "${this_global_apps_darwin_folder_path}"; then
				for this_global_app_installer in "${this_global_apps_darwin_folder_path}/"*'.'*; do
					if [[ -f "${this_global_app_installer}" ]]; then
						this_global_app_installer_name="${this_global_app_installer##*/}"
						this_global_app_installer_name="${this_global_app_installer_name%.*}"

						declare -a global_app_verification_args=( 'YRW6NUGA63' ) # Use my (Pico Mitchell) Team ID as the default value, which means any newly added apps that are not internal testing tools and are not explictly specified with a different value below will fail verification.

						if [[ "${this_global_app_installer}" == *'.'[Pp][Kk][Gg] ]]; then
							if [[ "${this_global_app_installer_name}" != 'Safari'* || -z "$(ioreg -rc AppleSEPManager)" ]] || (( DARWIN_MAJOR_VERSION < 21 )); then # DON'T BOTHER updating Safari on T2 or Apple Silicon Macs running macOS 12 Monterey or newer that would be reset via "Erase All Content & Settings" since that would revert the update anyways, but do update Safari on Macs that will be reset by Snapshot since the update will be preserved for them.
								write_to_log "Installing Global App \"${this_global_app_installer_name}\" From Package"

								if [[ "${this_global_app_installer_name}" == 'Safari'* ]]; then
									global_app_verification_args=( 'apple' )
								elif [[ "${this_global_app_installer_name}" == 'Firefox'* ]]; then
									global_app_verification_args=( 'notarized' '43AQ936H96' ) # Team ID of "Mozilla Corporation"
								fi

								this_packaged_app_filename="$(install_app_from_package "${global_app_verification_args[@]}" "${this_global_app_installer}")"
								install_app_from_package_exit_code="$?"

								if (( install_app_from_package_exit_code == 0 )); then
									if [[ -n "${this_packaged_app_filename}" ]]; then
										chown -R 501:20 "/Applications/${this_packaged_app_filename}" # Make sure the customer user account ends up owning the pre-installed apps.
									fi
								else
									if (( install_app_from_package_exit_code == 2 )); then
										write_to_log "ERROR: Failed to Detect App Within \"${this_global_app_installer_name}\" Package for Global App"
									elif (( install_app_from_package_exit_code == 3 )); then
										write_to_log "ERROR: Failed to Install or Verify Global App \"${this_packaged_app_filename:-${this_global_app_installer_name}}\""
									fi

									critical_error_occurred=true
									break
								fi
							fi
						elif [[ "${this_global_app_installer}" == *'.'[Zz][Ii][Pp] ]]; then # There are not currently any global apps installed via ZIP, but keep this code for easy future use.
							write_to_log "Installing Global App \"${this_global_app_installer_name}\" From Archive"

							this_archived_app_filename="$(install_app_from_archive "${global_app_verification_args[@]}" "${this_global_app_installer}")"
							install_app_from_archive_exit_code="$?"

							if (( install_app_from_archive_exit_code == 0 )); then
								chown -R 501:20 "/Applications/${this_archived_app_filename}" # Make sure the customer user account ends up owning the pre-installed apps.
							else
								if (( install_app_from_archive_exit_code == 2 )); then
									write_to_log "ERROR: Failed to Detect App Within \"${this_global_app_installer_name}\" Archive for Global App"
								elif (( install_app_from_archive_exit_code == 3 )); then
									write_to_log "ERROR: Failed to Install Global App \"${this_archived_app_filename}\""
								elif (( install_app_from_archive_exit_code == 4 )); then
									write_to_log "ERROR: Failed to Verify Global App \"${this_archived_app_filename}\""
								fi

								critical_error_occurred=true
								break
							fi
						elif [[ "${this_global_app_installer}" == *'.'[Dd][Mm][Gg] ]]; then # There are not currently any global apps installed via DMG, but keep this code for easy future use.
							write_to_log "Installing Global App \"${this_global_app_installer_name}\" From Disk Image"

							this_dmg_app_filename="$(install_app_from_disk_image "${global_app_verification_args[@]}" "${this_global_app_installer}")"
							install_app_from_disk_image_exit_code="$?"

							if (( install_app_from_disk_image_exit_code == 0 )); then
								chown -R 501:20 "/Applications/${this_dmg_app_filename}" # Make sure the customer user account ends up owning the pre-installed apps.
							else
								if (( install_app_from_disk_image_exit_code == 2 )); then
									write_to_log "ERROR: Failed to Verify \"${this_global_app_installer_name}\" Disk Image for Global App"
								elif (( install_app_from_disk_image_exit_code == 3 )); then
									write_to_log "ERROR: Failed to Detect Mount Path of \"${this_global_app_installer_name}\" Disk Image for Global App"
								elif (( install_app_from_disk_image_exit_code == 4 )); then
									write_to_log "ERROR: Failed to Detect or Verify App In Mounted Disk Image \"${this_dmg_app_filename}\" for Global App" # "this_dmg_app_filename" will be the "dmg_mount_path" when this error occurs.
								elif (( install_app_from_disk_image_exit_code == 5 )); then
									write_to_log "ERROR: Failed to Install or Verify Global App \"${this_dmg_app_filename}\""
								fi

								critical_error_occurred=true
								break
							fi
						else
							write_to_log "Skipping Unrecognized Global App Installer \"${this_global_app_installer##*/}\""
						fi
					fi
				done

				if $critical_error_occurred; then
					break
				fi
			fi
		done


		if ! $critical_error_occurred; then
			if (( DARWIN_MAJOR_VERSION < 19 )); then

				# FIX EXPIRED LET'S ENCRYPT CERTFICATE FOR MOJAVE AND OLDER
				# This removes the expired Let's Encrypt certificate based on these instructions: https://docs.hedge.video/remove-dst-root-ca-x3-certificate
				# If the expired certificate exists, using curl with sites using Let's Encrypt will fail, but just removing the certificate allows curl to work.
				# But, I'm not exactly sure what certificate is getting used to authenticate the connection after the expired on is removed. Kinda weird.
				# NOTE: We no longer install macOS 10.14 Mojave and older, but keep this code here for possible testing or future reference.

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
			elif [[ -z "$(ioreg -rc AppleSEPManager)" ]] || (( DARWIN_MAJOR_VERSION < 21 )); then

				# WHEN THE SNAPSHOT RESET TECHNIQUE IS USED, PREPARE fg-snapshot-reset RESOURCES AND LAUNCH DAEMON AND SNAPSHOT FOR FULL RESET *BEFORE* DOING *ANYTHING* ELSE

				# The Snapshot Reset techinque will only be used on pre-T2 Macs or any Mac running macOS 10.15 Catalina or macOS 11 Big Sur since the "Erase All Content & Settings" (via "Erase Assistant") is not available for those Macs.
				# For T2 or Apple Silicon Macs (determined by checking for a Secure Enclave which is present on T2 or Apple Silicon Macs, and NOT on T1 Macs or older) running macOS 12 Monterey or newer,
				# the "Free Geek Reset" app will automate the "Erase Assistant" app to perform "Erase All Content & Settings" instead of doing the Snapshot Reset technique.

				# Previously, we would do resets with a custom "fgreset" script on macOS 10.14 Mojave and older, but we no longer install macOS 10.14 Mojave and older anyways.
				# The Snapshot Reset technique was not used on older than macOS 10.15 Catalina because macOS 10.14 Mojave and older do not store "trimforce" setting in NVRAM (it is stored in the filesystem, so it would get undone with the reset Snapshot),
				# and macOS 10.13 High Sierra is not guaranteed to be APFS so the Snapshot could not always be created and it would be confusing to have multiple reset options for the same version of macOS.

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

					if [[ -f '/Users/Shared/fg-customization-resources/actual-snapshot-time.txt' ]]; then
						# If time was already set back by fg-install-packages, then save that actual time for Snapshot reset, and set back to it after reset Snapshot is created.
						actual_snapshot_time="$(< '/Users/Shared/fg-customization-resources/actual-snapshot-time.txt')"
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

					rm -f '/Library/LaunchDaemons/org.freegeek.fg-snapshot-reset.plist' # Only want this to launch on first boot after restoring from the reset Snapshot, never another time.

					if [[ ! -f '/Users/Shared/.fgResetSnapshotCreated' || -f '/Library/LaunchDaemons/org.freegeek.fg-snapshot-reset.plist' ]]; then
						write_to_log 'ERROR: Failed to Create Reset Snapshot'
						critical_error_occurred=true
					fi

					# NOTE: Previously would create fg-snapshot-preserver LaunchDaemon here, but now creating during User Specific Tasks setup so that the LaunchDeamon can be properly associated with the "Free Geek Snapshot Helper"
					# app when on macOS 13 Ventura (via the new "AssociatedBundleIdentifiers" key), which requires the app be installed before the LaunchDaemon is created for the app name to be displayed properly in the list of login items.
				fi
			fi

			if [[ ! -f '/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist' && "$(sudo systemsetup -getusingnetworktime)" == *': Off' ]]; then # "sudo" is needed for "systemsetup" within subshell.

				# MAKE SURE TIME IS SYNCED
				# This will already have been done if launched via LaunchDaemon or may have already been done above in this script after reset Snapshot is created if is pre-T2 Mac on macOS 10.15 Catalina and newer,
				# but double-check here since T2 or Apple Silicon Macs won't have the reset Snapshot created above.

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

		is_laptop=false # This "is_laptop" variable will be set based on whether the "short model name" (machine_name) contains "Book", and it is used later in this script.

		sp_hardware_plist_path="${TMPDIR}fg-prepare-os-sp-hardware.plist"
		for (( get_model_id_attempt = 0; get_model_id_attempt < 60; get_model_id_attempt ++ )); do
			rm -rf "${sp_hardware_plist_path}"
			system_profiler -xml SPHardwareDataType > "${sp_hardware_plist_path}"

			model_id="$(PlistBuddy -c 'Print :0:_items:0:machine_model' "${sp_hardware_plist_path}" 2> /dev/null)"

			if [[ "${model_id}" == *'Mac'* ]]; then
				short_model_name="$(PlistBuddy -c 'Print :0:_items:0:machine_name' "${sp_hardware_plist_path}" 2> /dev/null)"
				if [[ "${short_model_name}" == *'Book'* ]]; then is_laptop=true; fi

				serial_number="$(PlistBuddy -c 'Print :0:_items:0:serial_number' "${sp_hardware_plist_path}" 2> /dev/null)"

				if [[ -z "${serial_number}" || "${serial_number}" == 'Not Available' ]]; then
					serial_number="$(PlistBuddy -c 'Print :0:_items:0:riser_serial_number' "${sp_hardware_plist_path}" 2> /dev/null)"

					if [[ -z "${serial_number}" || "${serial_number}" == 'Not Available' ]]; then
						serial_number="UNKNOWNSERIAL-$(jot -rs '' 3 0 9)"
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

		wifi_ssid='FG Staff'
		wifi_password='[BUILD PACKAGE SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]'

		while read -ra this_network_hardware_ports_line_elements; do
			if [[ "${this_network_hardware_ports_line_elements[0]}" == 'Device:' ]] && getairportnetwork_output="$(networksetup -getairportnetwork "${this_network_hardware_ports_line_elements[1]}" 2> /dev/null)" && [[ "${getairportnetwork_output}" != *'disabled.' ]]; then
				write_to_log "Connecting \"${this_network_hardware_ports_line_elements[1]}\" to \"${wifi_ssid}\" Wi-Fi"

				if networksetup -getairportpower "${this_network_hardware_ports_line_elements[1]}" 2> /dev/null | grep -q '): Off$'; then
					networksetup -setairportpower "${this_network_hardware_ports_line_elements[1]}" on &> /dev/null
				fi

				networksetup -setairportnetwork "${this_network_hardware_ports_line_elements[1]}" "${wifi_ssid}" "${wifi_password}" &> /dev/null
			fi
		done < <(networksetup -listallhardwareports 2> /dev/null)


		# INSTALL GLOBAL SCRIPTS
		# NOTE: The "fgreset" global script is no longer installed since we are no longer installing older than macOS 10.15 Catalina.
		# So, this code to install it is now commented out, but it is being left in place in case it is useful in the future.

		# for this_global_script_zip in "$2/Global/Scripts/"*'.'[Zz][Ii][Pp]; do
		# 	if [[ -f "${this_global_script_zip}" ]]; then
		# 		this_global_script_name="${this_global_script_zip##*/}"
		# 		this_global_script_name="${this_global_script_name%.*}"

		# 		write_to_log "Installing Global Script \"${this_global_script_name}\" From Archive"

		# 		rm -rf "/Applications/${this_global_script_name}.sh" "/Applications/${this_global_script_name}"

		# 		if ditto -xk --noqtn "${this_global_script_zip}" '/Applications' &> /dev/null && verify_code_signature 'YRW6NUGA63' "/Applications/${this_global_script_name}.sh" &> /dev/null; then
		# 			mv -f "/Applications/${this_global_script_name}.sh" "/Applications/${this_global_script_name}"

		# 			chmod +x "/Applications/${this_global_script_name}"
		# 			chflags hidden "/Applications/${this_global_script_name}"

		# 			if [[ ! -d '/usr/local/bin' ]]; then
		# 				mkdir -p '/usr/local/bin'
		# 			fi

		# 			ln -s "/Applications/${this_global_script_name}" '/usr/local/bin'
		# 		else
		# 			rm -f "/Applications/${this_global_script_name}.sh" "/Applications/${this_global_script_name}"
		# 			write_to_log "ERROR: Failed to Install or Verify Global Script \"${this_global_script_name}\""
		# 			critical_error_occurred=true
		# 			break
		# 		fi
		# 	fi
		# done


		# CREATE TESTING USERS

		mkuser_path="$2/Tools/mkuser/mkuser.sh"
		chmod +x "${mkuser_path}"

		fg_user_picture_path="$2/Global/Users/Free Geek User Picture.png"


		if ! $critical_error_occurred; then

			# CREATE HIDDEN ADMIN USER

			write_to_log "Creating Hidden Admin User \"${hidden_admin_user_full_name}\" (${hidden_admin_user_account_name})"

			declare -a create_hidden_admin_user_options=(
				'--account-name' "${hidden_admin_user_account_name}"
				'--full-name' "${hidden_admin_user_full_name}"
				'--generated-uid' '0CAA0000-0A00-0000-BA00-0B000C00B00A' # This GUID is from the "johnappleseed" user shown on https://web.archive.org/web/20221023033850/https://support.apple.com/en-us/HT208050
				'--stdin-password'
				'--password-hint' 'If you do not know this password, then you should not be logging in as this user.'
				'--picture' "${fg_user_picture_path}"
				'--administrator'
				'--hidden'
				'--skip-setup-assistant'
				'--prohibit-user-password-changes'
				'--prohibit-user-picture-changes'
				'--prevent-secure-token-on-big-sur-and-newer'
				'--suppress-status-messages' # Don't output stdout messages, but we will still get stderr to save to variable.
			)

			# PREVENT SECURE TOKEN ON BIG SUR AND NEWER
			# See comments in "mkuser.sh" for more information about preventing Secure Tokens on macOS 11 Big Sur.
			# This is nice for being able to use Snapshot reset and having the customer user account get a Secure Token on macOS 11 Big Sur:
			# Although, this DOES NOT work on macOS 10.15 Catalina. BUT, I found that I can remove the crypto user references after the users no longer exist (on non-SEP Macs)
			# after restoring the reset Snapshot, so this isn't the only way to be able to do a Snapshot reset (on non-SEP Macs) and have the customer user account be able to get a Secure Token.
			# But, since Secure Tokens cannot be removed on SEP Macs (T2/Apple Silicon), this is still a very critical thing to do to be able to do a Snapshot reset on those newer Macs.
			# See comments in fg-snapshot-reset for more info about deleting crypto user references on macOS 10.15 Catalina.

			create_hidden_admin_user_error="$(printf '%s' "${hidden_admin_user_password}" | "${mkuser_path}" "${create_hidden_admin_user_options[@]}" 2>&1)" # Redirect stderr to save to variable.
			create_hidden_admin_user_exit_code="$?" # Do not check "create_user" exit code directly by putting the function within an "if" since we want to print it as well when an error occurs.

			if (( create_hidden_admin_user_exit_code != 0 )) || [[ "$(id -u "${hidden_admin_user_account_name}" 2> /dev/null)" != '501' ]]; then # Confirm hidden_admin_user_account_name was assigned UID 501 to be sure all is as expected.
				if [[ -z "${create_hidden_admin_user_error}" ]]; then create_hidden_admin_user_error="$(id -u "${hidden_admin_user_account_name}" 2>&1)"; fi
				write_to_log "ERROR: \"${hidden_admin_user_account_name}\" User Creation Failed:\n\t${create_hidden_admin_user_error//$'\n'/$'\n\t'}"
				critical_error_occurred=true
			elif [[ -n "${create_hidden_admin_user_error}" ]]; then
				write_to_log "WARNINGS Creating Hidden Admin User:\n\t${create_hidden_admin_user_error//$'\n'/$'\n\t'}"
			fi
		fi


		if ! $critical_error_occurred; then

			# CREATE STANDARD AUTO-LOGIN USER

			write_to_log "Creating Standard Auto-Login User \"${standard_autologin_user_full_name}\" (${standard_autologin_user_account_name})"

			declare -a create_standard_autologin_user_options=(
				'--account-name' "${standard_autologin_user_account_name}"
				'--full-name' "${standard_autologin_user_full_name}"
				'--generated-uid' 'B0ABCAB0-D000-00C0-A0D0-00000CA000C0' # This GUID is from the "johnappleseed" user shown on https://support.apple.com/102547 (which is different from the one above)
				'--stdin-password'
				'--password-hint' "The password is \"${standard_autologin_user_password}\"."
				'--picture' "${fg_user_picture_path}"
				'--skip-setup-assistant'
				'--automatic-login'
				'--do-not-share-public-folder'
				'--prohibit-user-password-changes'
				'--prohibit-user-picture-changes'
				'--suppress-status-messages' # Don't output stdout messages, but we will still get stderr to save to variable.
			)

			if [[ -f '/Users/Shared/.fgResetSnapshotCreated' ]]; then
				# If a reset Snapshot was not created (which would happen if this is T2 or Apple Silicon Mac running macOS running macOS 12 Monterey or newer), "fg-demo" can be allowed to get the first
				# Secure Token since the user must have a Secure Token to be able to run "Erase All Content & Settings" (which will remove all users and Secure Tokens) and allowing it to be granted upon
				# user creation instead of it being granted when the "Erase All Content & Settings" reset process is started by "Free Geek Reset" allows the reset to run more quickly and the user having
				# a Secure Token is not an issue like it is with the Snapshot Reset process which would not be able to remove the Secure Token.

				create_standard_autologin_user_options+=( '--prevent-secure-token-on-big-sur-and-newer' )
			fi

			create_standard_autologin_user_error="$(printf '%s' "${standard_autologin_user_password}" | "${mkuser_path}" "${create_standard_autologin_user_options[@]}" 2>&1)" # Redirect stderr to save to variable.
			create_standard_autologin_user_exit_code="$?" # Do not check "create_user" exit code directly by putting the function within an "if" since we want to print it as well when an error occurs.

			if (( create_standard_autologin_user_exit_code != 0 )) || [[ "$(id -u "${standard_autologin_user_account_name}" 2> /dev/null)" != '502' ]]; then # Confirm standard_autologin_user_account_name was assigned UID 502 to be sure all is as expected.
				if [[ -z "${create_standard_autologin_user_error}" ]]; then create_standard_autologin_user_error="$(id -u "${standard_autologin_user_account_name}" 2>&1)"; fi
				write_to_log "ERROR: \"${standard_autologin_user_account_name}\" User Creation Failed:\n\t${create_standard_autologin_user_error//$'\n'/$'\n\t'}"
				critical_error_occurred=true
			elif [[ -n "${create_standard_autologin_user_error}" ]]; then
				write_to_log "WARNINGS Creating Standard Auto-Login User:\n\t${create_standard_autologin_user_error//$'\n'/$'\n\t'}"
			fi
		fi


		if ! $critical_error_occurred; then

			# USER SPECIFIC TASKS (based on home folders)
			# About running "defaults" commands as another user: https://scriptingosx.com/2020/08/running-a-command-as-another-user/

			for this_home_folder in '/Users/'*; do
				if [[ -d "${this_home_folder}" && "${this_home_folder}" != '/Users/Shared' && "${this_home_folder}" != '/Users/Guest' ]]; then
					this_username="$(dscl . -search /Users NFSHomeDirectory "${this_home_folder}" | awk '{ print $1; exit }')"
					this_uid="$(dscl -plist . -read "/Users/${this_username}" UniqueID 2> /dev/null | xmllint --xpath 'string(//string)' - 2> /dev/null)"

					if [[ -n "${this_uid}" && -d "${this_home_folder}/Library" ]]; then

						write_to_log "Setting Custom User Preferences for \"${this_username}\" User"

						# NOTE: Tried to use "sysadminctl -screenLock off" (when running on macOS 10.14 Mojave or newer since that's when it was added) at this point to
						# disable Screen Lock for the users in advance (by running the command as each user properly like all other commands are done at this point), but
						# it seems to always fail for users that are not currently graphically logged in (even after they have logged in before to create their Keychain).
						# The error that it outputs is: MKBDeviceSetGracePeriod error -8
						# That's alright though since the "Free Geek Setup" app will successfully disable Screen Lock right when it launches at login.


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


						if (( DARWIN_MAJOR_VERSION >= 23 )); then

							# DISABLE "CLICK WALLPAPER TO SHOW DESKTOP ITEMS" ON SONOMA AND NEWER

							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.WindowManager' EnableStandardClickToShowDesktop -bool false
						fi


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


						# SET KEYBOARD SHORTCUT SETTINGS
						# This disables the default F11 action to Show Desktop so that the keyboard can be fully tested without activating the Show Desktop action (not sure why this requires 2 keys/values to be set to disable a single action, but it does).
						# The following keys/values have been confirmed to be the same on macOS 10.13 High Sierra, macOS 10.14 Mojave, macOS 10.15 Catalina, macOS 11 Big Sur, macOS 12 Monterey, and macOS 13 Ventura.

						symbolic_hot_key_base_dict="$(echo '<dict/>' | # NOTE: Starting with this plist fragment "<dict/>" is a way to create an empty plist with root type of dictionary. This is effectively same as starting with "plutil -create xml1 -" (which can be verified by comparing the output to "echo '<dict/>' | plutil -convert xml1 -o - -") but the "plutil -create" option is only available on macOS 12 Monterey and newer.
							plutil -insert 'enabled' -bool false -o - - | # Using a pipeline of "plutil" commands reading from stdin and outputting to stdout is a clean way of creating a plist string without needing to hardcode the plist contents and without creating a file (which would be required if PlistBuddy was used) even though doing this is technically less efficient vs just hard coding a plist string, it makes for cleaner and smaller code.
							plutil -insert 'value' -xml '<dict/>' -o - - | # The "-dictionary" type option is only available on macOS 12 Monterey and newer, so use the "-xml" type option with a "<dict/>" plist fragment instead for maximum compatibility with the same effect.
							plutil -insert 'value.parameters' -xml '<array/>' -o - - | # The "-array" type option is also only available on macOS 12 Monterey and newer, so use the "-xml" type option with an "<array/>" plist fragment instead for maximum compatibility with the same effect.
							plutil -insert 'value.parameters.0' -integer '65535' -o - - |
							plutil -insert 'value.parameters.1' -integer '103' -o - - |
							plutil -insert 'value.type' -string 'standard' -o - -)"

						# "defaults write" can take plists (or plist fragments) as input instead of only single values.
						# So, we can pass a plist dictionary structure to add the desired nested dictionaries for newly added keys of the "AppleSymbolicHotKeys" top-level dictionary.
						# The plist created above is the base dictionary for the value of both of the keys we are adding, but the last element of the
						# "parameters" array is different for each value so those are added into the base dictionary before the value is set below.
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.symbolichotkeys' AppleSymbolicHotKeys -dict-add \
							36 "$(echo "${symbolic_hot_key_base_dict}" | plutil -insert 'value.parameters.2' -integer '8388608' -o - -)" \
							37 "$(echo "${symbolic_hot_key_base_dict}" | plutil -insert 'value.parameters.2' -integer '8519680' -o - -)"


						# DISABLE SCREEN SAVER

						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.screensaver' idleTime -int 0


						# DISABLE NOTIFICATIONS

						if (( DARWIN_MAJOR_VERSION >= 20 )); then
							# On macOS 11 Big Sur, the Do Not Disturb data is stored as an encoded binary plist within the "dnd_prefs" key of "com.apple.ncprefs": https://www.reddit.com/r/osx/comments/ksbmay/comment/gq5fu0m/
							# On macOS 12 Monterey and newer, the DND Schedule settings have moved to being stored in "~/Library/DoNotDisturb/DB/ModeConfigurations.json" (within data[0].modeConfigurations["com.apple.donotdisturb.mode.default"].triggers),
							# but these old settings are migrated (a "migratedLegacySchedule" key is set to "true" in the "com.apple.ncprefs" preferences) and still properly take effect (even on macOS 13 Ventura) so continue only setting these for simplicity.

							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.ncprefs' dnd_prefs -data "$(echo '<dict/>' | # Search for "<dict/>" above in this script for comments about creating the plist this way.
								plutil -insert 'dndDisplayLock' -bool true -o - - |
								plutil -insert 'dndDisplaySleep' -bool true -o - - |
								plutil -insert 'dndMirrored' -bool true -o - - |
								plutil -insert 'facetimeCanBreakDND' -bool false -o - - |
								plutil -insert 'repeatedFacetimeCallsBreaksDND' -bool false -o - - |
								plutil -insert 'scheduledTime' -xml '<dict/>' -o - - | # The "-dictionary" type option is only available on macOS 12 Monterey and newer, so use the "-xml" type option with a "<dict/>" plist fragment instead for maximum compatibility with the same effect.
								plutil -insert 'scheduledTime.enabled' -bool true -o - - |
								plutil -insert 'scheduledTime.end' -float 1439 -o - - |
								plutil -insert 'scheduledTime.start' -float 0 -o - - |
								plutil -convert binary1 -o - - | xxd -p | tr -d '[:space:]')" # "xxd" converts the binary data into hex, which is what "defaults write" needs.
						else
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' dndEnabledDisplayLock -bool true
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' dndEnabledDisplaySleep -bool true
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' dndMirroring -bool true
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' dndEnd -float 1439
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' dndStart -float 0
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults -currentHost write 'com.apple.notificationcenterui' doNotDisturb -bool false
						fi


						# DISABLE NOTIFICATIONS FOR BACKGROUND TASK MANAGEMENT ON VENTURA (TO HIDE NOTIFICATIONS WHEN ADDING A LAUNCHDAEMON OR LAUNCHAGENT)
						# On macOS 13 Ventura and newer, each new login item, LaunchDaemon, or LaunchAgent added posts a notification to inform the user, which is great for regular users but unnecessary for our technicians during testing (such as when the "Free Geek Demo Helper" LaunchAgent is created by "Free Geek Setup").
						# So, completely disable all notifications from the "BTMNotificationAgent" process which will hide these new "Background Task Management" notifications.
						# Credit to @macmol.tech on the MacAdmins Slack for discovering and sharing how to disable these notifications: https://macadmins.slack.com/archives/GA92U9YV9/p1663919213484999?thread_ts=1663782045.275729&channel=GA92U9YV9&message_ts=1663919213.484999

						# On macOS 26 Tahoe, the settings to disable notifications have moved from the "com.apple.ncprefs" preferences domain to "~/Library/Group Containers/group.com.apple.usernoted/Library/Preferences/group.com.apple.usernoted.plist"
						# and any settings set in "com.apple.ncprefs" domain will be migrated to there, EXCEPT macOS will overwrite the "com.apple.BTMNotificationAgent" settings with a "flags" value that show the notifications (even if set directly in the new path).
						# But, if the "flags" value is set after login, they seem at least take effect temporarily before macOS overwrites them again.
						# So, on macOS 26 Tahoe and newer, also set up a LaunchAgent run by "Free Geek Task Runner" (which has Full Disk Access which is required to modify files in another apps Group Container)
						# to run at login and also whenever the new "usernoted" preferences path is modified (via "WatchPaths") to re-set the "flags" value for "com.apple.BTMNotificationAgent" to be re-disabled immediately whenever macOS overwrites them.
						# NOTE: The LaunchAgent described above is created below after the "Free Geek Task Runner" app has been installed.

						notification_center_disable_all_flags='8401217' # macOS 11 Big Sur and newer: "Allow Notifications" disabled, alert style "None", and every checkbox option disabled.

						if (( DARWIN_MAJOR_VERSION >= 22 )) && [[ -d '/System/Library/UserNotifications/Bundles/com.apple.BTMNotificationAgent.bundle' ]]; then
							write_to_log "Disabling \"Background Task Management\" Notifications for \"${this_username}\" User"
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.ncprefs' apps -array-add "$(echo '<dict/>' | # Search for "<dict/>" above in this script for comments about creating the plist this way.
								plutil -insert 'bundle-id' -string 'com.apple.BTMNotificationAgent' -o - - |
								plutil -insert 'flags' -integer "${notification_center_disable_all_flags}" -o - - |
								plutil -insert 'path' -string '/System/Library/UserNotifications/Bundles/com.apple.BTMNotificationAgent.bundle' -o - -)"
						fi


						# DISABLE SAFARI AUTO-FILL AND AUTO-OPENING DOWNLOADS
						# Safari 13 and newer are now Sandboxed and store their preferences at "~/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.plist"
						# This Safari Container location is also protected: https://lapcatsoftware.com/articles/containers.html
						# That article says the Safari Container is protected by SIP, but I think it's actually TCC since drag-and-dropping the location onto a Terminal window or granting Full Disk Access makes it accessible as well as manually trashing the folder in Finder. SIP wouldn't allow any of that.
						# But, since Safari hasn't been launched at this point, we can set the preferences in the old unprotected location and Safari will migrate them when launched for the first time.
						# This approach is also nice in that it supports any older versions of Safari which may be pre-installed on macOS 10.13 High Sierra through macOS 10.15 Catalina.

						# BUT: This no longer works in macOS 12 Monterey because the Safari Container is created upon login instead of first Safari launch.
						# The preferences within the Safari Container don't exist until launch, but the preferences from the old location DO NOT get migrated like they do on older versions of macOS because the Safari Container already exists.
						# Modifying the preferences within the Safari Container requires Full Disk Access TCC privileges.
						# Therefore, "Free Geek Setup Setup" will set these Safari preferences within the Safari Container location on first login since it will always be granted Full Disk Access right off the bat during a customized installation by "fg-install-os" (which you can read about in the comments in that script).

						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.Safari' AutoFillPasswords -bool false
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.Safari' AutoFillFromAddressBook -bool false
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.Safari' AutoFillCreditCardData -bool false
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.Safari' AutoFillMiscellaneousForms -bool false
						launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.Safari' AutoOpenSafeDownloads -bool false


						# USER SPECIFIC TASKS IF USER RESOURCES EXIST

						this_user_resources_folder="$2/User/${this_username}"
						this_user_apps_folder="${this_home_folder}/Applications"

						if [[ -d "${this_user_resources_folder}" ]]; then
							if (( DARWIN_MAJOR_VERSION <= 22 )) && [[ -d "${this_user_resources_folder}/Pics" ]]; then

								# UNZIP FREE GEEK PROMO PICS TO USER PICTURES FOLDER (FOR SCREENSAVER AUTOMATION DURING DEMO MODE)
								# UNLESS running on macOS 14 Sonoma or newer since only the new Aerial screen savers will be used there.

								this_user_pictures_folder="${this_home_folder}/Pictures"

								for this_pics_zip in "${this_user_resources_folder}/Pics/"*'.'[Zz][Ii][Pp]; do
									if [[ -f "${this_pics_zip}" ]]; then
										write_to_log "Installing Screen Saver Promo Pics for \"${this_username}\" User"

										ditto -xk --noqtn "${this_pics_zip}" "${this_user_pictures_folder}" &> /dev/null
									fi
								done

								chown -R "${this_uid}:20" "${this_user_pictures_folder}"
							fi


							if [[ -d "${this_user_resources_folder}/Apps" ]]; then

								# INSTALL USER APPS

								for this_user_apps_darwin_folder_path in "${this_user_resources_folder}/Apps/darwin-"*; do
									if should_install_apps_in_darwin_folder "${this_user_apps_darwin_folder_path}"; then
										if [[ ! -f "${this_user_apps_folder}" ]]; then
											mkdir -p "${this_user_apps_folder}"
											chown -R "${this_uid}:20" "${this_user_apps_folder}"
										fi

										for this_user_app_installer in "${this_user_apps_darwin_folder_path}/"*'.'*; do
											if [[ -f "${this_user_app_installer}" ]]; then
												this_user_app_installer_name="${this_user_app_installer##*/}"
												this_user_app_installer_name="${this_user_app_installer_name%.*}"

												declare -a user_app_verification_args=( 'YRW6NUGA63' ) # Use my (Pico Mitchell) Team ID as the default value, which means any newly added apps that are not internal testing tools and are not explictly specified with a different value below will fail verification.

												if [[ "${this_user_app_installer}" == *'.'[Zz][Ii][Pp] ]]; then
													this_user_app_installer_name="${this_user_app_installer_name//-/ }"

													should_install_this_user_app=true
													if [[ "${this_user_app_installer_name}" == 'Free Geek Snapshot Helper' && ! -f '/Users/Shared/.fgResetSnapshotCreated' ]]; then
														# "Free Geek Snapshot Helper" does not need to be installed if a reset Snapshot was not created, which would happen if this is T2 or Apple Silicon Mac running macOS running macOS 12 Monterey or newer
														# where the "Free Geek Reset" app will automate the "Erase Assistant" app to perform "Erase All Content & Settings" instead of doing the Snapshot Reset technique.
														# Also, no reset Snapshot was created on macOS 10.14 Mojave and older where a custom "fgreset" script used to be used instead (but we no longer install macOS 10.14 Mojave and older anyways).
														# NOTE: The "Free Geek Reset" app is still installed even if the Snapshot Reset technique is used and it will just show instructions for the Snapshot Reset and allow auto-rebooting into recoverOS by setting an NVRAM key.

														should_install_this_user_app=false
													fi

													if $should_install_this_user_app; then
														if [[ "${this_user_app_installer_name}" == 'QAHelper'* ]]; then this_user_app_installer_name='QA Helper'; fi

														write_to_log "Installing User App \"${this_user_app_installer_name}\" for \"${this_username}\" User From Archive"

														if [[ "${this_user_app_installer_name}" == 'DriveDx'* ]]; then
															user_app_verification_args=( 'notarized' '4ZNF85T75D' ) # Team ID of "Kirill Luzanov"
														elif [[ "${this_user_app_installer_name}" == 'Geekbench'* ]]; then
															user_app_verification_args=( 'notarized' 'SRW94G4YYQ' ) # Team ID of "Primate Labs Inc."
														elif [[ "${this_user_app_installer_name}" == 'KeyboardCleanTool'* ]]; then
															user_app_verification_args=( 'notarized' 'DAFVSXZ82P' ) # Team ID of "folivora.AI GmbH"
														elif [[ "${this_user_app_installer_name}" == 'Mactracker'* ]]; then
															user_app_verification_args=( 'notarized' '63TP32R3AB' ) # Team ID of "Ian Page"
														elif [[ "${this_user_app_installer_name}" == 'QA Helper' ]]; then
															user_app_verification_args+=( 'notarized' ) # The Team ID of "Pico Mitchell" is already the default value, so just ALSO check notarization since "QA Helper" is notarized (unlike other internal testing apps).
														fi # All other apps should be internal testing apps signed with my Team ID (specified in the original declaration), but are NOT notarized (since it's not worth the extra time on each build).

														this_archived_app_filename="$(install_app_from_archive "${user_app_verification_args[@]}" "${this_user_apps_folder}" "${this_user_app_installer}")"
														install_app_from_archive_exit_code="$?"

														if (( install_app_from_archive_exit_code == 0 )); then
															chown -R "${this_uid}:20" "${this_user_apps_folder}/${this_archived_app_filename}"
														else
															if (( install_app_from_archive_exit_code == 2 )); then
																write_to_log "ERROR: Failed to Detect App Within \"${this_user_app_installer_name}\" Archive for User App"
															elif (( install_app_from_archive_exit_code == 3 )); then
																write_to_log "ERROR: Failed to Install User App \"${this_archived_app_filename}\" for \"${this_username}\""
															elif (( install_app_from_archive_exit_code == 4 )); then
																write_to_log "ERROR: Failed to Verify User App \"${this_archived_app_filename}\" for \"${this_username}\""
															fi

															critical_error_occurred=true
															break
														fi
													fi
												elif [[ "${this_user_app_installer}" == '.'[Dd][Mm][Gg] ]]; then # There are not currently any user apps installed via DMG, but keep this code for easy future use.
													write_to_log "Installing User App \"${this_user_app_installer_name}\" for \"${this_username}\" User From Disk Image"

													this_dmg_app_filename="$(install_app_from_disk_image "${user_app_verification_args[@]}" "${this_user_apps_folder}" "${this_user_app_installer}")"
													install_app_from_disk_image_exit_code="$?"

													if (( install_app_from_disk_image_exit_code == 0 )); then
														chown -R "${this_uid}:20" "${this_user_apps_folder}/${this_dmg_app_filename}"
													else
														if (( install_app_from_disk_image_exit_code == 2 )); then
															write_to_log "ERROR: Failed to Verify \"${this_user_app_installer_name}\" Disk Image for User App"
														elif (( install_app_from_disk_image_exit_code == 3 )); then
															write_to_log "ERROR: Failed to Detect Mount Path of \"${this_user_app_installer_name}\" Disk Image for User App"
														elif (( install_app_from_disk_image_exit_code == 4 )); then
															write_to_log "ERROR: Failed to Detect or Verify App In Mounted Disk Image \"${this_dmg_app_filename}\" for User App" # "this_dmg_app_filename" will be the "dmg_mount_path" when this error occurs.
														elif (( install_app_from_disk_image_exit_code == 5 )); then
															write_to_log "ERROR: Failed to Install or Verify User App \"${this_dmg_app_filename}\" for \"${this_username}\""
														fi

														critical_error_occurred=true
														break
													fi
												elif [[ "${this_user_app_installer}" != *'.driveDxLicense' && "${this_user_app_installer}" != *'.preferences' ]]; then
													write_to_log "Skipping Unrecognized \"${this_username}\" User App Installer \"${this_user_app_installer##*/}\""
												fi
											fi
										done

										if $critical_error_occurred; then
											break
										fi
									fi
								done

								if $critical_error_occurred; then
									break
								fi

								# SET PREFERENCES (AND LICENSES AND DISABLE NOTIFICATIONS) FOR USER APPS
								# Notifications are disabled so that notification approval is not prompted for the technician to have to dismiss (even though QA Helper does not send any notifications and DriveDx will have all notifications disabled).
								# Doing this because the notification approval prompt is not hidden with Do Not Disturb enabled on macOS 11 Big Sur like it is on macOS 10.15 Catalina and older (but went ahead and disabled notifications for all versions of macOS anyway).

								if (( DARWIN_MAJOR_VERSION == 18 || DARWIN_MAJOR_VERSION == 19 )); then
									notification_center_disable_all_flags='8409409' # macOS 10.14 Mojave & macOS 10.15 Catalina: "Allow Notifications" disabled, alert style "None", notification previews "when unlocked", and every checkbox option disabled.
								elif (( DARWIN_MAJOR_VERSION == 17 )); then
									notification_center_disable_all_flags='4417' # macOS 10.13 High Sierra: Alert style "None", and every checkbox option disabled.
								fi

								if [[ -d "${this_user_apps_folder}/QA Helper.app" ]]; then
									write_to_log "Disabling \"QA Helper\" App Notifications for \"${this_username}\" User"
									launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.ncprefs' apps -array-add "$(echo '<dict/>' | # Search for "<dict/>" above in this script for comments about creating the plist this way.
										plutil -insert 'bundle-id' -string 'org.freegeek.QA-Helper' -o - - |
										plutil -insert 'flags' -integer "${notification_center_disable_all_flags}" -o - - |
										plutil -insert 'path' -string "${this_user_apps_folder}/QA Helper.app" -o - -)"
								fi

								if [[ -d "${this_user_apps_folder}/DriveDx.app" ]]; then
									if [[ -f "${this_user_resources_folder}/Apps/darwin-all-versions/DriveDx.driveDxLicense" ]]; then
										write_to_log "Disabling \"DriveDx\" App Notifications for \"${this_username}\" User"
										launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.ncprefs' apps -array-add "$(echo '<dict/>' | # Search for "<dict/>" above in this script for comments about creating the plist this way.
											plutil -insert 'bundle-id' -string 'com.binaryfruit.DriveDx' -o - - |
											plutil -insert 'flags' -integer "${notification_center_disable_all_flags}" -o - - |
											plutil -insert 'path' -string "${this_user_apps_folder}/DriveDx.app" -o - -)"

										write_to_log "Setting Preferences for \"DriveDx\" App for \"${this_username}\" User"
										launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.binaryfruit.DriveDx' App_UIMode -int 1 # Only show in Dock (not Menu Bar).
										launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.binaryfruit.DriveDx' DriveDiagnostics_AutoCheck -bool false # Do not check drive health periodically.
										launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.binaryfruit.DriveDx' DriveDiagnostics_Notifications_ShowDiskStatus -bool false # Do not show drive health notifications.
										launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.binaryfruit.DriveDx' DriveDiagnostics_Tests_ShowNotification -bool false # Do not show notification when self-test is complete.
										launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.binaryfruit.DriveDx' DriveDiagnostics_DisplayTemperatureInFahrenheit -bool true # Show temps in Fahrenheit.
										launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.binaryfruit.DriveDx' DriveDx_OS_Mode -bool true # Sync diagnostics KB online.
										launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.binaryfruit.DriveDx' App_Updater_CheckForUpdates -bool false # Do not check for updates.

										ditto "${this_user_resources_folder}/Apps/darwin-all-versions/DriveDx.driveDxLicense" "${this_home_folder}/Library/Application Support/DriveDx/DriveDx.driveDxLicense" &> /dev/null # Do not need to "mkdir" first since "ditto" takes care of that automatically.
									else
										write_to_log "WARNING: Uninstalling \"DriveDx\" App for \"${this_username}\" User Because License Not Found"
										rm -rf "${this_user_apps_folder}/DriveDx.app"
									fi
								fi

								for geekbench_app_path in "${this_user_apps_folder}/Geekbench "*'.app'; do # NOTE: Geekbench 5 will be installed on macOS 10.15 Catalina and older and Geekbench 6 will be installed on macOS 11 Big Sur and newer.
									# Instead of needing to explicitly check for which version of macOS is running or which version of Geekbench got installed, just use a glob to match any version of Geekbench that got installed.
									# This glob should only ever match a single Geekbench app, doing it in a loop is a safe and correct way to handle the output of a glob since it shouldn't be assumed that there will be only one match.

									if [[ -d "${geekbench_app_path}" ]]; then
										geekbench_app_name="${geekbench_app_path##*/}"
										geekbench_app_name="${geekbench_app_name%.*}"

										declare -a geekbench_license_paths=( "${this_user_resources_folder}/Apps/darwin-"*"/${geekbench_app_name}.preferences" ) # To locate the correct license file for the version of Geekbench that was installed, we will again use a glob,
										# but this time searching any "darwin-" version folder from the app installers for the correct license file name containing "geekbench_app_name" (which will have the app version in it and always be present in the same folder as the installer).
										geekbench_license_path="${geekbench_license_paths[0]}" # Again, this glob should only ever have a single match but to be extra safe assign the output of the glob to an array and only every use the first element of the array (which should be the only element).

										if [[ -f "${geekbench_license_path}" ]]; then
											write_to_log "Setting Preferences for \"${geekbench_app_name}\" App for \"${this_username}\" User"

											geekbench_bundle_id="$(PlistBuddy -c 'Print :CFBundleIdentifier' "${geekbench_app_path}/Contents/Info.plist")"
											launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write "${geekbench_bundle_id}" AgreedToEULA -bool true
											launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write "${geekbench_bundle_id}" SUEnableAutomaticChecks -bool false

											geekbench_license_json="$(< "${geekbench_license_path}")" # This file could be placed in the "this_user_apps_folder" alongside the app to license it automatically, but instead read it to manually set the values in the preferences so that it's not as easily seen by technicians.
											launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write "${geekbench_bundle_id}" LicenseEmail -string "$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).license_user' -- "${geekbench_license_json}" 2> /dev/null)"
											launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write "${geekbench_bundle_id}" LicenseKey -string "$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).license_key' -- "${geekbench_license_json}" 2> /dev/null)"
											# NOTE: Could also pass this user and key to the "geekbench_x86_64" or "geekbench_aarch64" binary (within "Geekbench #.app/Contents/Resources") with the "--unlock" option, but that just sets these preferences so just do that directly instead.
										else
											write_to_log "WARNING: Uninstalling \"${geekbench_app_name}\" App for \"${this_username}\" User Because License Not Found"
											rm -rf "${geekbench_app_path}"
										fi
									fi
								done

								if [[ -d "${this_user_apps_folder}/Mactracker.app" ]]; then
									write_to_log "Setting Preferences for \"Mactracker\" App for \"${this_username}\" User"
									launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.mactrackerapp.Mactracker' 'SUCheckAtStartup' -bool false
									launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.mactrackerapp.Mactracker' 'WindowLocations' -dict 'MainWindow' "$(echo '<dict/>' | # Search for "<dict/>" above in this script for comments about creating the plist this way.
										plutil -insert 'LastSelection' -integer '2' -o - -)" # Open to the "This Mac" section.
									launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.mactrackerapp.Mactracker' 'MultipleFindMyMac' -bool false # Do not show alert if the Model ID matches multiple models on first open of "This Mac" section (which would be on first launch).
								fi

								if [[ -d "${this_user_apps_folder}/KeyboardCleanTool.app" ]]; then
									write_to_log "Setting Preferences for \"KeyboardCleanTool\" App for \"${this_username}\" User"
									launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.hegenberg.KeyboardCleanTool' startAfterStart -bool true # Start cleaning mode (disabling keyboard) upon app launch.
								fi


								this_user_launch_agents_folder="${this_home_folder}/Library/LaunchAgents"
								mkdir -p "${this_user_launch_agents_folder}"

								if [[ -d "${this_user_apps_folder}/Free Geek Setup.app" ]]; then

									write_to_log "Preparing \"Free Geek Setup\" for \"${this_username}\" User"


									# SYMLINK FREE GEEK SETUP ON DESKTOP

									this_user_desktop_folder="${this_home_folder}/Desktop"

									ln -s "${this_user_apps_folder}/Free Geek Setup.app" "${this_user_desktop_folder}"
									chown -R "${this_uid}:20" "${this_user_desktop_folder}"


									# SETUP FREE GEEK SETUP AUTO-LAUNCH

									# NOTE: In the following "Free Geek Setup" LaunchAgent, the AssociatedBundleIdentifiers key is set to "org.freegeek.Free-Geek-Setup" so that the LaunchAgent is displayed nicely in the new Login Items section in macOS 13 Ventura.
									# This also requires "Program" argument be a SIGNED script or binary with with the same Team ID as the app of the AssociatedBundleIdentifiers, so the "Launch Free Geek Setup" script
									# (which just runs "open" and the path to the app) is created and signed by "MacLand Script Builder" when an applet has the build flag "IncludeSignedLauncher" which the "Free Geek Setup" app has specified.
									# This LaunchAgent is setup AFTER the "Free Geek Setup" app is installed since macOS must know about the app before the LaunchAgent is setup for its name to be displayed properly in the new login items list in the System Setting app.
									# See this documentation from Apple for more info: https://developer.apple.com/documentation/servicemanagement/updating_helper_executables_from_earlier_versions_of_macos?language=objc#4065210

									# ALSO NOTE: The following 2 commands are necessary for making the "Free Geek Setup" app name and icon properly show for the following LaunchAgent in the Login Items section in macOS 13 Ventura.
									# As the documentation linked above states, "LSRegisterURL" is required, to make macOS aware of the application before it has been launched, I believe especially since it is not within the global Applications folder.
									# But, I found that only running "LSRegisterURL" made the icon of the "Free Geek Setup" app display correctly, but the name was still only listed as "Pico Mitchell" (the Team ID name name for the signed script).
									# In an attempt to make both the icon and the name display correctly, I tried ALSO launching the app as the "fg-demo" user, and THAT WORKED.
									# To confirm I was doing truly required steps, I tried the following things which DID NOT work: Only running "LSRegisterURL" as "fg-demo" user without launching the app, only launching the app as "fg-demo" without running "LSRegisterURL" as root, launching the app as root after running "LSRegisterURL" as root.
									# All this testing indicated that running BOTH "LSRegisterURL" as root AND launching the app as the "fg-demo" user are required to make the icon and name correctly show as "Free Geek Setup" for this LaunchDaemon right of the bat.
									# In prior testing, I found that running "stltool resetbtm" upon first boot to completely clear the Background Task Management database and then rebooting made the app icon and name display correctly in the list after reboot,
									# I think because by that time the app had been fully registered and launched. But, I that was not a solution to the problem of making the app icon and name display correctly right away.
									# It's also worth noting that the following "open" command will fail because the app cannot be launched before login during this setup phase.
									# But, whatever "open" is doing internally before failing to actually launch to app makes the icon and name show correctly for the LaunchDaemon.

									osascript -l 'JavaScript' -e 'ObjC.import("LaunchServices"); run = argv => $.LSRegisterURL($.NSURL.fileURLWithPath(argv[0]), true)' -- "${this_user_apps_folder}/Free Geek Setup.app" &> /dev/null
									launchctl asuser "${this_uid}" sudo -u "${this_username}" open -na "${this_user_apps_folder}/Free Geek Setup.app"

									PlistBuddy \
										-c 'Add :Label string org.freegeek.Free-Geek-Setup' \
										-c "Add :Program string '${this_user_apps_folder}/Free Geek Setup.app/Contents/Resources/Launch Free Geek Setup'" \
										-c 'Add :AssociatedBundleIdentifiers string org.freegeek.Free-Geek-Setup' \
										-c 'Add :RunAtLoad bool true' \
										-c 'Add :StartInterval integer 600' \
										-c 'Add :StandardOutPath string /dev/null' \
										-c 'Add :StandardErrorPath string /dev/null' \
										"${this_user_launch_agents_folder}/org.freegeek.Free-Geek-Setup.plist" &> /dev/null
								fi

								if (( DARWIN_MAJOR_VERSION >= 25 )) && [[ -d "${this_user_apps_folder}/Free Geek Task Runner.app" && -d '/System/Library/UserNotifications/Bundles/com.apple.BTMNotificationAgent.bundle' ]]; then

									write_to_log "Creating LaunchAgent to Disable BTM Notifications for \"${this_username}\" User"

									# NOTE: See comments in "SETUP FREE GEEK SETUP AUTO-LAUNCH" section above for information about "AssociatedBundleIdentifiers", and using "LSRegisterURL" and "open" for the "Free Geek Task Runner" app name and icon properly show for the following LaunchAgent in the Login Items section.
									osascript -l 'JavaScript' -e 'ObjC.import("LaunchServices"); run = argv => $.LSRegisterURL($.NSURL.fileURLWithPath(argv[0]), true)' -- "${this_user_apps_folder}/Free Geek Task Runner.app" &> /dev/null
									launchctl asuser "${this_uid}" sudo -u "${this_username}" open -na "${this_user_apps_folder}/Free Geek Task Runner.app"

									# NOTE: See comments in "DISABLE NOTIFICATIONS FOR BACKGROUND TASK MANAGEMENT" section above for information about why this LaunchAgent is being created on macOS 26 Tahoe to disable BTM notifications.
									PlistBuddy \
										-c 'Add :Label string org.freegeek.Disable-BTM-Notifications' \
										-c 'Add :ProgramArguments array' \
										-c "Add :ProgramArguments: string '${this_user_apps_folder}/Free Geek Task Runner.app/Contents/Resources/Launch Free Geek Task Runner'" \
										-c "Add :ProgramArguments: string bash" \
										-c 'Add :AssociatedBundleIdentifiers string org.freegeek.Free-Geek-Task-Runner' \
										-c 'Add :RunAtLoad bool true' \
										-c 'Add :WatchPaths array' \
										-c "Add :WatchPaths: string '${this_home_folder}/Library/Group Containers/group.com.apple.usernoted/Library/Preferences/group.com.apple.usernoted.plist'" \
										-c 'Add :StandardOutPath string /dev/null' \
										-c 'Add :StandardErrorPath string /dev/null' \
										"${this_user_launch_agents_folder}/org.freegeek.Disable-BTM-Notifications.plist" &> /dev/null

									disable_btm_notifications_code="
PATH='/usr/bin:/bin:/usr/sbin:/sbin'

TMPDIR=\"\$([[ -d \"\${TMPDIR}\" && -w \"\${TMPDIR}\" ]] && echo \"\${TMPDIR%/}/\" || echo '/private/tmp/')\" # Make sure TMPDIR is always set and that it always has a trailing slash for consistency regardless of the current environment.

rm -rf \"\${TMPDIR}fg-usernoted.plist\"

usernoted_preferences_domain='${this_home_folder}/Library/Group Containers/group.com.apple.usernoted/Library/Preferences/group.com.apple.usernoted'
defaults export \"\${usernoted_preferences_domain}\" \"\${TMPDIR}fg-usernoted.plist\"

this_usernoted_apps_index=0
while this_usernoted_apps_bundle_id=\"\$(plutil -extract \"apps.\${this_usernoted_apps_index}.bundle-id\" raw \"\${TMPDIR}fg-usernoted.plist\" -o - 2> /dev/null)\"; do
	if [[ \"\${this_usernoted_apps_bundle_id}\" == 'com.apple.BTMNotificationAgent' ]]; then
		if [[ \"\$(plutil -extract \"apps.\${this_usernoted_apps_index}.flags\" raw \"\${TMPDIR}fg-usernoted.plist\" -o - 2> /dev/null)\" != '${notification_center_disable_all_flags}' ]]; then
			plutil -replace \"apps.\${this_usernoted_apps_index}.flags\" -integer '${notification_center_disable_all_flags}' \"\${TMPDIR}fg-usernoted.plist\"
			defaults import \"\${usernoted_preferences_domain}\" \"\${TMPDIR}fg-usernoted.plist\"
			killall usernoted
		fi

		break
	fi

	(( this_usernoted_apps_index ++ ))
done

rm -f \"\${TMPDIR}fg-usernoted.plist\"
"

									plutil -insert 'ProgramArguments' -string "${disable_btm_notifications_code}" -append "${this_user_launch_agents_folder}/org.freegeek.Disable-BTM-Notifications.plist"
									# Use "plutil" for script code that may contain special xml/plist characters that need to be escaped.
									# "PlistBuddy" would escape special xml/plist characters in values properly too, but because of how "PlistBuddy" values need to be specified inside of commands that
									# are within a quoted string means that quotes in the values (which also exist) would need to be escaped to not break the "PlistBuddy" commands themselves.
									# That possible nested quoting issue doesn't exist with "plutil" because of how values are specified as their own separate argument rather than within commands like with "PlistBuddy".
								fi

								chown -R "${this_uid}:20" "${this_user_launch_agents_folder}"


								if [[ -f '/Users/Shared/.fgResetSnapshotCreated' && -d "${this_user_apps_folder}/Free Geek Snapshot Helper.app" ]]; then

									write_to_log 'Setting Up Snapshot Preserver LaunchDaemon'

									# Copy fg-snapshot-preserver out of fg-snapshot-reset resources to keep it around and start is running with a LaunchDaemon.
									snapshot_preserver_resources_install_path='/Users/Shared/.fg-snapshot-preserver' # NOTICE: INVISIBLE folder.
									mkdir -p "${snapshot_preserver_resources_install_path}"
									mv "${snapshot_reset_resources_install_path}/fg-snapshot-preserver.sh" "${snapshot_preserver_resources_install_path}/fg-snapshot-preserver.sh"
									mv "${snapshot_reset_resources_install_path}/Resources" "${snapshot_preserver_resources_install_path}/Resources"
									chmod +x "${snapshot_preserver_resources_install_path}/fg-snapshot-preserver.sh"

									rm -rf "${snapshot_reset_resources_install_path}" # Delete remaining fg-snapshot-reset resources since they are only needed on first boot after restoring from the reset Snapshot.

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

									# NOTE: See comments above in "Free Geek Setup" LaunchAgent setup about setting up this app with "AssociatedBundleIdentifiers" to properly display in the Login Items section in macOS 13 Ventura (including the following two commands being necessary).
									# This also requires the "fg-snapshot-preserver.sh" script being SIGNED with the same Team ID as the app of the AssociatedBundleIdentifiers, so that script is signed in the "build-fg-prepare-os-pkg.sh" script.

									osascript -l 'JavaScript' -e 'ObjC.import("LaunchServices"); run = argv => $.LSRegisterURL($.NSURL.fileURLWithPath(argv[0]), true)' -- "${this_user_apps_folder}/Free Geek Snapshot Helper.app" &> /dev/null
									launchctl asuser "${this_uid}" sudo -u "${this_username}" open -na "${this_user_apps_folder}/Free Geek Snapshot Helper.app"

									# NOTE: These values are written by passing the commands to PlistBuddy via stdin instead of using "-c" args like is usually done.
									# One reason is because the contents are created dynamically using a loop instead of needing to hard code each 5 minute interval value which is clean and simple to do by creating a single string to be passed via stdin.
									# But, it would still be pretty trivial to create an array of "-c" commands dynamically to be passed to PlistBuddy all at once.
									# The more important reason is because there seems to be a bug in PlistBuddy where if you pass more than 14 "-c" args at once, it will crash with an "Abort trap: 6" error.
									# That is a big issue for *reading* values since when that crash happens none of the output can be piped or captured with command subtitution.
									# But, in the case of writing (like is being done below), the entire plist seems to still get created properly even though PlistBuddy will crash with the "Abort trap: 6" error.
									# So, to be extra safe and avoid crashing PlistBuddy, pass all the "Add" commands via stdin instead which seems to not ever crash PlistBuddy with any amount of commands that I've tested.
									# The only difference vs using "-c" args is that we have to end the set of "Add" commands with a "Save" command or else the plist will not be created
									# See more info about this testing on the MacAdmins Slack: https://macadmins.slack.com/archives/CGXNNJXJ9/p1669083521933659?thread_ts=1668984083.421349&cid=CGXNNJXJ9
									echo "
Add :Label string org.freegeek.fg-snapshot-preserver
Add :Program string ${snapshot_preserver_resources_install_path}/fg-snapshot-preserver.sh
Add :AssociatedBundleIdentifiers string org.freegeek.Free-Geek-Snapshot-Helper
Add :RunAtLoad bool true
Add :StandardOutPath string /dev/null
Add :StandardErrorPath string /dev/null
Add :StartCalendarInterval array
$(for (( start_calendar_interval_minute = 55; start_calendar_interval_minute >= 0; start_calendar_interval_minute -= 5 )); do
	echo "Add :StartCalendarInterval:0 dict
Add :StartCalendarInterval:0:Minute integer ${start_calendar_interval_minute}"
done)
Save
" | PlistBuddy '/Library/LaunchDaemons/org.freegeek.fg-snapshot-preserver.plist' &> /dev/null

									if [[ ! -f '/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist' ]]; then # Do not need to load right away if started via LaunchDaemon since we will restart.
										launchctl bootstrap system '/Library/LaunchDaemons/org.freegeek.fg-snapshot-preserver.plist'
									fi
								fi
							fi
						fi


						# SETUP DOCK
						# Add "QA Helper" to the front (if installed), add "DriveDx" and "Geekbench" and "Mactracker" after "QA Helper" (if installed),
						# and then add "KeyboardCleanTool" after that (if installed and is a laptop),
						# replace "Safari" with "Firefox" (if installed which it will be on macOS 10.15 Catalina and older),
						# add "LibreOffice" after "Reminders" (if installed, which it won't be anymore but the code is left in place as an example),
						# lock contents size and position, and hide recents (on macOS 10.14 Mojave and newer).

						# NOTE: The user Dock prefs will not exist yet, so we need start with the "persistent-apps" from the default source plist within the Dock app.
						# Do this AFTER user specific tasks so that we can check if QA Helper was installed for this user.

						write_to_log "Customizing Dock for \"${this_username}\" User"

						default_dock_plist='/System/Library/CoreServices/Dock.app/Contents/Resources/default.plist' # This is location on macOS 10.15 Catalina and newer.
						if [[ ! -f "${default_dock_plist}" ]]; then
							default_dock_plist='/System/Library/CoreServices/Dock.app/Contents/Resources/en.lproj/default.plist' # This is location on macOS 10.14 Mojave and older.
						fi

						if [[ -f "${default_dock_plist}" ]]; then # Do not try to customize the Dock contents if the default Dock plist is moved in a future version of macOS.
							declare -a custom_dock_persistent_apps=()

							dock_app_dict_for_path() { # This function will generate a plist dict string that is suitable to be passed to "defaults write ... -array".
								if [[ "$1" != *'.'[Aa][Pp][Pp] || ! -d "$1" ]]; then # Make sure the specified path is for an app that exists.
									return 1
								fi

								echo '<dict/>' | # Search for "<dict/>" above in this script for comments about creating the plist this way.
									plutil -insert 'tile-data' -xml '<dict/>' -o - - | # The "-dictionary" type option is only available on macOS 12 Monterey and newer, so use the "-xml" type option with a "<dict/>" plist fragment instead for maximum compatibility with the same effect.
									plutil -insert 'tile-data.file-data' -xml '<dict/>' -o - - |
									plutil -insert 'tile-data.file-data._CFURLString' -string "$1" -o - - | # Another benefit of building the plist this way is that "plutil" will take care of any necessary character escaping for XML/plist (https://stackoverflow.com/a/1091953)
									plutil -insert 'tile-data.file-data._CFURLStringType' -integer '0' -o - -
							}

							if dock_app_dict_for_qa_helper="$(dock_app_dict_for_path "${this_user_apps_folder}/QA Helper.app")"; then
								custom_dock_persistent_apps+=( "${dock_app_dict_for_qa_helper}" )
							fi

							if dock_app_dict_for_drivedx="$(dock_app_dict_for_path "${this_user_apps_folder}/DriveDx.app")"; then
								custom_dock_persistent_apps+=( "${dock_app_dict_for_drivedx}" )
							fi

							for geekbench_app_path in "${this_user_apps_folder}/Geekbench "*'.app'; do # NOTE: Geekbench 5 will be installed on macOS 10.15 Catalina and older and Geekbench 6 will be installed on macOS 11 Big Sur and newer.
								# Instead of needing to explicitly check for which version of macOS is running or which version of Geekbench got installed, just use a glob to match any version of Geekbench that got installed.
								# This glob should only ever match a single Geekbench app, doing it in a loop is a safe and correct way to handle the output of a glob since it shouldn't be assumed that there will be only one match.

								if dock_app_dict_for_geekbench="$(dock_app_dict_for_path "${geekbench_app_path}")"; then
									custom_dock_persistent_apps+=( "${dock_app_dict_for_geekbench}" )
								fi
							done

							if dock_app_dict_for_mactracker="$(dock_app_dict_for_path "${this_user_apps_folder}/Mactracker.app")"; then
								custom_dock_persistent_apps+=( "${dock_app_dict_for_mactracker}" )
							fi

							if $is_laptop && dock_app_dict_for_keyboard_clean_tool="$(dock_app_dict_for_path "${this_user_apps_folder}/KeyboardCleanTool.app")"; then # Add "KeyboardCleanTool" only when the Mac is a laptop.
								custom_dock_persistent_apps+=( "${dock_app_dict_for_keyboard_clean_tool}" )
							fi

							dock_app_dict_for_libreoffice="$(dock_app_dict_for_path '/Applications/LibreOffice.app')" # This app plist dict will be added into the Dock below if the app exists (see comments below for more info).

							# The following loop will iterate through every app path listed in the default Dock and generate a new Dock app list suitable to be passed to "defaults write ... -array" by replacing and adding custom apps as well as removing any defaults that aren't installed (see comments below for more info).
							declare -i this_dock_persistent_app_index=0 # Since it is not super easy to get the count of the "persistent-apps" array in advance, manually increment the index in a while loop that continues until PlistBuddy exits with an error because the index didn't exist.
							while this_dock_persistent_app_path="$(PlistBuddy -c "Print :persistent-apps:${this_dock_persistent_app_index}:tile-data:file-data:_CFURLString" "${default_dock_plist}" 2> /dev/null)"; do
								if dock_app_dict_for_this_app_path="$(dock_app_dict_for_path "${this_dock_persistent_app_path}")"; then
									# The default Dock contents will include Pages, Numbers, and Keynote which will not be installed, so make sure to only include existing apps to the customized Dock.
									# If the Dock were allowed to initialize on it's own, these app would be removed from the Dock by macOS when they are not installed.

									if [[ "${this_dock_persistent_app_path}" == *'/Applications/Safari.app' ]] && dock_app_dict_for_firefox="$(dock_app_dict_for_path '/Applications/Firefox.app')"; then # Replace "Safari" with "Firefox" if it has been installed (which will only be done on macOS 10.15 Catalina and older).
										custom_dock_persistent_apps+=( "${dock_app_dict_for_firefox}" )
									else
										if [[ "${this_dock_persistent_app_path}" == *'/Applications/System Preferences.app' || "${this_dock_persistent_app_path}" == *'/Applications/System Settings.app' ]]; then
											# Disable the "dock-extra" flag for System Preferences/Settings so that no update badges are ever displayed in the Dock since they should never be run during testing: https://lapcatsoftware.com/articles/badge.html
											dock_app_dict_for_this_app_path="$(echo "${dock_app_dict_for_this_app_path}" | plutil -insert 'tile-data.dock-extra' -bool false -o - -)"
										fi

										custom_dock_persistent_apps+=( "${dock_app_dict_for_this_app_path}" )

										if [[ "${this_dock_persistent_app_path}" == *'/Applications/Reminders.app' && -n "${dock_app_dict_for_libreoffice}" ]]; then # Add "LibreOffice" after "Reminders" if it has been installed (which will no longer be done anymore, but leave this here as an example of how to add a new app after an existing app if needed in the future).
											custom_dock_persistent_apps+=( "${dock_app_dict_for_libreoffice}" )
											dock_app_dict_for_libreoffice='' # Clear this variable to indicate that it has already been added to the Dock so that the fallback check after the loop is done will not add it again to the end of the Dock.
										fi
									fi
								fi

								this_dock_persistent_app_index+=1
							done

							if [[ -n "${dock_app_dict_for_libreoffice}" ]]; then # This should never happen when "LibreOffice" installed (which it will no longer be anymore), but in case "Reminders" was not in the Dock then add "LibreOffice" to the end of the Dock (also still leaving this here as an example fallback for the "add after existing app" code above).
								custom_dock_persistent_apps+=( "${dock_app_dict_for_libreoffice}" )
							fi

							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.dock' persistent-apps -array "${custom_dock_persistent_apps[@]}"

							# VERY IMPORTANT: If this "version" key is not set, the Dock contents will get reset when Dock runs.
							# I've confirmed it to get set to "1" by Dock on macOS 10.13 High Sierra through macOS 12 Monterey.
							launchctl asuser "${this_uid}" sudo -u "${this_username}" defaults write 'com.apple.dock' version -int 1
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


			if [[ ! -d "/Users/${standard_autologin_user_account_name}/Applications/Free Geek Setup.app" || ! -f "/Users/${standard_autologin_user_account_name}/Library/LaunchAgents/org.freegeek.Free-Geek-Setup.plist" ]]; then
				write_to_log 'ERROR: Free Geek Setup Not Installed or LaunchAgent Not Configured'
				critical_error_occurred=true
			fi

			if [[ -f '/Users/Shared/.fgResetSnapshotCreated' && ( ! -d "/Users/${standard_autologin_user_account_name}/Applications/Free Geek Snapshot Helper.app" || ! -f "${snapshot_preserver_resources_install_path}/fg-snapshot-preserver.sh" || ! -f '/Library/LaunchDaemons/org.freegeek.fg-snapshot-preserver.plist' || -d "${snapshot_reset_resources_install_path}" ) ]]; then
				write_to_log 'ERROR: Free Geek Snapshot Helper Not Installed or LaunchDaemon Not Configured'
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

			launchctl bootstrap system '/Library/LaunchDaemons/org.freegeek.fg-error-occurred.plist'
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

if [[ "$2" == *'fg-prepare-os'* && -d "$2" ]]; then
	rm -rf "$2"
fi


# NOTE: Do not need to worry about deleting this script itself since macOS seems to take care of that right after it's done running.


if $critical_error_occurred; then
	exit 1
fi

exit 0
