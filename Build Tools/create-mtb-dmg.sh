#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# MIT License
#
# Copyright (c) 2023 Free Geek
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


PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy.

DARWIN_MAJOR_VERSION="$(uname -r | cut -d '.' -f 1)" # 19 = 10.15 Catalina, 20 = 11 Big Sur, 21 = 12 Monterey, 22 = 13 Ventura, 23 = 14 Sonoma, 24 = 15 Sequoia, 25 = 26 Tahoe, etc.
readonly DARWIN_MAJOR_VERSION

PROJECT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)/.."
readonly PROJECT_DIR

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}/" || echo '/private/tmp/')" # Make sure "TMPDIR" is always set and that it always has a trailing slash for consistency regardless of the current environment.

mtb_source_path=''
mtb_source_device_id=''

for this_mtb_volume in '/Volumes/Mac Test Boot'*; do
	this_mtb_volume_info_plist="$(diskutil info -plist "${this_mtb_volume}" 2> /dev/null)"
	if [[ "$(echo "${this_mtb_volume_info_plist}" | plutil -extract 'WritableVolume' raw - 2> /dev/null)" == 'true' ]]; then # Do not want to detect UNWRITABLE mounted DMG as source.
		this_mtb_parent_disk_size="$(diskutil info -plist "$(echo "${this_mtb_volume_info_plist}" | plutil -extract 'ParentWholeDisk' raw - 2> /dev/null)" 2> /dev/null | plutil -extract 'TotalSize' raw - 2> /dev/null)"
		if (( this_mtb_parent_disk_size <= 33000000000 )); then # The MTB source drive is 32 GB but all production drives are 120+ GB.
			mtb_source_path="${this_mtb_volume}"
			mtb_source_device_id="$(echo "${this_mtb_volume_info_plist}" | plutil -extract 'DeviceIdentifier' raw - 2> /dev/null)"
			break
		fi
	fi
done

if [[ -z "${mtb_source_path}" || "${mtb_source_device_id}" != 'disk'* || ! -d "${mtb_source_path}" ]]; then
	>&2 echo 'MAC TEST BOOT SOURCE DRIVE NOT DETECTED'
	exit 1
else
	echo "DETECTED MTB SOURCE VOLUME \"${this_mtb_volume}\" WITH DEVICE ID \"${mtb_source_device_id}\""
fi

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

echo -e '\n\nUpdating Apps...'

freegeek_apps_latest_versions="$(curl -m 5 -sfL 'https://apps.freegeek.org/macland/download/latest-versions.txt')"

declare -a tracked_apps=()
while IFS='' read -rd '' this_app_path; do
	if [[ "${this_app_path}" != *'.app'*'.app' && "${this_app_path}" != *'/Utilities/VoiceOver Utility.app' ]]; then # Ignore nested apps, and ignore "VoiceOver Utility" which fails "spctl" check as an Apple app for some reason.
		install_path="${this_app_path%/*}"

		this_app_name="${this_app_path##*/}"
		this_app_name="${this_app_name%.*}"

		spctl_assess_output="$(spctl -avv "${this_app_path}" 2>&1)"
		if [[ "${spctl_assess_output}" != *$'\nsource=Apple System\n'* && "${this_app_name}" != 'Safari' && "${this_app_name}" != 'GpuTest_GUI' ]]; then # Ignore Apple and Free Geek apps (all FG apps will be updated separately) and "GpuTest_GUI.app" since "GpuTest.app" will be checked.
			app_version="$(PlistBuddy -c 'Print :CFBundleShortVersionString' "${this_app_path}/Contents/Info.plist" 2> /dev/null)"
			if [[ -z "${app_version}" ]]; then
				app_version="$(PlistBuddy -c 'Print :CFBundleVersion' "${this_app_path}/Contents/Info.plist" 2> /dev/null)"
			fi

			if [[ "${this_app_name}" == 'GpuTest' ]]; then # The "GpuTest" app bundle version is wrong, use the latest version in the "changelog.txt" instead.
				app_version="$(awk '($1 == "GpuTest") { print substr($2, 2); exit }' "${this_app_path}/Contents/Resources/changelog.txt")"
				rm -f "${this_app_path}/data/apple_logo.jpg" # Delete "apple_logo.jpg" from GpuTest app since don't want/need to Apple logo in the bottom right corner during the GPU Test.

				if [[ "${install_path}" == *'_0.7.0' ]]; then # Remove version from GpuTest folder name (if exists from previous manual installation).
					mv -f "${install_path}" "${install_path%_*}"
					install_path="${install_path%_*}"
				fi
			fi

			echo -e "\n${this_app_name}\nInstalled Version: ${app_version}"

			latest_version=''

			if [[ "${spctl_assess_output}" == *$'\nsource=Mac App Store\n'* ]]; then
				mas_url=''
				case "${this_app_name}" in
					'AmorphousDiskMark')
						mas_url='https://apps.apple.com/us/app/amorphousdiskmark/id1168254295'
						;;
					'Blackmagic Disk Speed Test')
						mas_url='https://apps.apple.com/us/app/blackmagic-disk-speed-test/id425264550'
						;;
					*)
						echo -e 'ERROR: UNTRACKED (EXTRA) MAC APP STORE APP'
						exit 1
						;;
				esac

				latest_version="$(curl -m 5 -sfL "${mas_url}" | xmllint --html --xpath 'substring-after(//h4[starts-with(text(),"Version ")], " ")' - 2> /dev/null)"

				if [[ -n "${latest_version}" ]]; then
					tracked_apps+=( "${this_app_name}" )

					if [[ "${app_version}" == "${latest_version}" ]]; then
						echo 'Latest Version Already Installed'
					else
						echo "Latest Version: ${latest_version}"
						echo 'WARNING: Mac App Store Update Available (CANNOT AUTOMATE)'
					fi
				else
					echo 'ERROR: NO LATEST VERSION'
					exit 1
				fi
			else
				download_url=''
				declare -a app_verification_args=()

				case "${this_app_name}" in
					'Breakaway')
						app_verification_args=( 'DO-NOT-VERIFY' ) # Not signed at all, so bypass verification.
						download_url="https://mutablecode.com$(curl -m 5 -sfL 'https://mutablecode.com/apps/breakaway' | xmllint --html --xpath 'string(//a[contains(@href,"breakaway") and contains(@href,".zip")]/@href)' - 2> /dev/null)"
						latest_version="$(echo "${download_url%.*}" | cut -d '-' -f 2)"

						breakaway_scripts=( 'Set Volume for Headphones.applescript' 'Set Volume for Speakers.applescript' )
						for this_breakway_script in "${breakaway_scripts[@]}"; do
							if [[ -f "${PROJECT_DIR}/Testing Scripts/Volume Scripts for Breakaway/${this_breakway_script}" ]]; then
								if ! cmp -s "${PROJECT_DIR}/Testing Scripts/Volume Scripts for Breakaway/${this_breakway_script}" "${mtb_source_path}/Users/Tester/Documents/${this_breakway_script}"; then
									rm -f "${mtb_source_path}/Users/Tester/Documents/${this_breakway_script}"
									echo "UPDATING \"${this_breakway_script}\"..."
									ditto "${PROJECT_DIR}/Testing Scripts/Volume Scripts for Breakaway/${this_breakway_script}" "${mtb_source_path}/Users/Tester/Documents/${this_breakway_script}" || exit 1
								else
									echo "EXACT COPY EXISTS: \"${this_breakway_script}\""
								fi
							else
								echo "ERROR: \"${PROJECT_DIR}/Testing Scripts/Volume Scripts for Breakaway/${this_breakway_script}\" NOT FOUND"
								exit 1
							fi
						done
						;;
					'coconutBattery')
						app_verification_args=( 'notarized' 'R5SC3K86L5' ) # Team ID of "Christoph Sinai"
						latest_version='3.9.18' # coconutBattery version 3.9.18 is the last version to support macOS 10.14 Mojave.
						download_url='https://www.coconut-flavour.com/downloads/coconutBattery_3918.zip'
						;;
					'coconutID')
						app_verification_args=( 'DO-NOT-VERIFY' )
						# Just signed with "origin=Developer ID Application: Christoph Sinai", NOT Notarized and no Team ID listed (probably because of old signing process).
						# Since the "verify_code_signature" function is expecting SOME Team ID, we must bypass the verification.
						coconutid_appcast_xml="$(curl -m 5 -sfL 'https://www.coconut-flavour.com/updates/coconutID.xml')"
						download_url="$(echo "${coconutid_appcast_xml}" | xmllint --xpath 'string(//enclosure/@url)' -)"
						latest_version="$(echo "${coconutid_appcast_xml}" | xmllint --xpath 'string(//enclosure/@*[name()="sparkle:version"])' -)"
						;;
					'CPUTest')
						app_verification_args=( 'DO-NOT-VERIFY' ) # Not signed at all, so bypass verification.
						latest_version='0.2' # URL SEEMS TO HAVE GONE DOWN SOMETIMES BETWEEN 10/23/24 and 11/04/24 "$(curl -m 5 -sfL 'https://www.coolbook.se/CPUTest.html' | xmllint --html --xpath 'substring-before(substring-after(//div[starts-with(text(),"The most recent version of CPUTest is ")], " is "), ",")' - 2> /dev/null)"
						download_url='http://www.coolbook.se/CPUTest/CPUTest.zip'
						;;
					'DriveDx')
						app_verification_args=( 'notarized' '4ZNF85T75D' ) # Team ID of "Kirill Luzanov"
						latest_version="$(curl -m 5 -sfL 'https://binaryfruit.com/download/drivedx/mac/1/updates/?appcast&amp;appName=DriveDxMac' | xmllint --xpath 'string(//enclosure/@*[name()="sparkle:shortVersionString"])' -)"
						download_url='https://binaryfruit.com/download/drivedx/mac/1/'
						;;
					'FingerMgmt')
						app_verification_args=( 'DO-NOT-VERIFY' ) # Not signed at all, so bypass verification.
						fingermgmt_github_json="$(curl -m 5 -sfL 'https://api.github.com/repos/jnordberg/FingerMgmt/releases/latest')"
						latest_version="$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).tag_name' -- "${fingermgmt_github_json}" 2> /dev/null)"
						download_url="$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).assets[0].browser_download_url' -- "${fingermgmt_github_json}" 2> /dev/null)"
						;;
					'Geekbench 5')
						app_verification_args=( 'notarized' 'SRW94G4YYQ' ) # Team ID of "Primate Labs Inc."
						download_url="$(curl -m 5 -sfL 'https://www.geekbench.com/legacy/' | xmllint --html --xpath 'string(//a[contains(@href,"Geekbench-5") and contains(@href,"Mac.zip")]/@href)' - 2> /dev/null)"
						latest_version="$(echo "${download_url}" | cut -d '-' -f 2)"
						;;
					'GpuTest')
						app_verification_args=( 'DO-NOT-VERIFY' ) # Not signed at all, so bypass verification.
						latest_version="$(curl -m 5 -sfL 'https://www.geeks3d.com/gputest/download/' | xmllint --html --xpath 'string(//div[contains(text(),"OSX")]/b)' -)"
						download_url="https://ozone3d.net/gputest/dl/GpuTest_OSX_x64_${latest_version}.zip"
						;;
					'KeyboardCleanTool')
						app_verification_args=( 'notarized' 'DAFVSXZ82P' ) # Team ID of "folivora.AI GmbH"
						keyboardcleantool_homebrew_cask_json="$(curl -m 5 -sfL 'https://formulae.brew.sh/api/cask/keyboardcleantool.json')" # https://folivora.ai/keyboardcleantool DOES NOT list a latest version,
						# but there is a Homebrew Cask and the JSON for it does list the latest version, so using that as the source and hoping it is kept up-to-date (but KeyboardCleanTool updates are rare).
						latest_version="$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).version' -- "${keyboardcleantool_homebrew_cask_json}" 2> /dev/null)"
						download_url='https://folivora.ai/releases/KeyboardCleanTool.zip'
						;;
					'Mactracker')
						rm -rf "${mtb_source_path}/Users/Tester/Library/Containers/com.mactrackerapp.Mactracker" # Mactracker used be installed via MAS, but now installing the manual version. Make sure the old MAS Container is deleted to not confuse the preferences.

						app_verification_args=( 'notarized' '63TP32R3AB' ) # Team ID of "Ian Page"
						mactracker_appcast_xml="$(curl -m 5 -sfL 'https://update.mactracker.ca/appcast-b.xml')"
						download_url="$(echo "${mactracker_appcast_xml}" | xmllint --xpath 'string(//enclosure/@url)' -)"
						latest_version="$(echo "${mactracker_appcast_xml}" | xmllint --xpath 'string(//enclosure/@*[name()="sparkle:version"])' -)"
						;;
					'PiXel Check')
						app_verification_args=( 'DO-NOT-VERIFY' )
						# Just signed with "origin=Developer ID Application: Flexibits Inc.", NOT Notarized and no Team ID listed (probably because of old signing process).
						# Since the "verify_code_signature" function is expecting SOME Team ID, we must bypass the verification.
						download_url="$(curl -m 5 -sfL 'http://macguitar.me/apps/pixelcheck/' | xmllint --html --xpath 'string(//a[contains(@href,"pixelcheck") and contains(@href,".zip")]/@href)' - 2> /dev/null)"
						latest_version="${download_url##*/}"
						latest_version="${latest_version%.*}"
						latest_version="$(echo "${latest_version}" | tr -d '[:alpha:]')"
						;;
					'SilentKnight')
						app_verification_args=( 'notarized' 'QWY4LRW926' ) # Team ID of "Howard Oakley"
						eclecticapps_github_plist="$(curl -m 5 -sfL 'https://raw.githubusercontent.com/hoakleyelc/updates/master/eclecticapps.plist')"
						download_url="$(echo "${eclecticapps_github_plist}" | xmllint --xpath 'string(//string[text()="SilentKnight"]/../key[text()="URL"]/following-sibling::string[1])' -)"
						latest_version="$(echo "${eclecticapps_github_plist}" | xmllint --xpath 'string(//string[text()="SilentKnight"]/../key[text()="Version"]/following-sibling::string[1])' -)"
						;;
					'XRG')
						app_verification_args=( 'notarized' '28EXY66HMA' ) # Team ID of "Gaucho Software, LLC."
						latest_version="$(curl -m 5 -sfL 'https://download.gauchosoft.com/xrg/latest_version.txt')"
						download_url="https://download.gauchosoft.com/xrg/XRG-release-${latest_version}.zip"
						;;
					'QA Helper')
						app_verification_args=( 'notarized' 'YRW6NUGA63' ) # Team ID of "Pico Mitchell"
						latest_version="$(curl -m 5 -sfL 'https://apps.freegeek.org/qa-helper/download/latest-version.php')"
						download_url='https://apps.freegeek.org/qa-helper/download/QAHelper-mac-universal.zip'
						;;
					*)
						if [[ "${spctl_assess_output}" == *$'\norigin=Developer ID Application: Pico Mitchell (YRW6NUGA63)'* ]]; then # Instead of tracking all FG apps by name, track them all together since the latest version info can all be pulled the same way.
							app_verification_args=( 'YRW6NUGA63' ) # Team ID of "Pico Mitchell" (FG test apps are not Notarized since it's not necessary and saves build time).
							latest_version="$(echo "${freegeek_apps_latest_versions}" | AWK_ENV_APP_NAME="${this_app_name}" awk -F ': ' '($1 == ENVIRON["AWK_ENV_APP_NAME"]) { print $2; exit }')"
							download_url="https://apps.freegeek.org/macland/download/${this_app_name// /-}.zip"
						else
							echo -e 'ERROR: UNTRACKED (EXTRA) APP'
							exit 1
						fi
						;;
				esac

				if [[ -n "${latest_version}" && -n "${download_url}" ]]; then
					if [[ "${app_version}" == "${latest_version}" ]]; then
						echo 'Latest Version Already Installed'
						tracked_apps+=( "${this_app_name}" )
					else
						echo "Downloading ${this_app_name} ${latest_version} from \"${download_url}\"..."

						download_tmp_path="${TMPDIR}${this_app_name} ${latest_version}.zip"
						rm -rf "${download_tmp_path}"

						if curl --connect-timeout 5 --progress-bar -fL "${download_url}" -o "${download_tmp_path}" && [[ -f "${download_tmp_path}" ]]; then
							echo "Downloaded ${this_app_name} ${latest_version}"

							if [[ "${this_app_name}" == 'GpuTest' && "${install_path}" == *'GpuTest_OSX_x64' ]]; then
								rm -rf "${install_path:?}/"*
							fi

							echo "Installing ${this_app_name} ${latest_version} into \"${install_path}\"..."

							this_archived_app_filename="$(install_app_from_archive "${app_verification_args[@]}" "${download_tmp_path}" "${install_path}")"
							install_app_from_archive_exit_code="$?"

							rm -rf "${download_tmp_path}"

							if (( install_app_from_archive_exit_code == 0 )); then
								updated_app_version="$(PlistBuddy -c 'Print :CFBundleShortVersionString' "${this_app_path}/Contents/Info.plist" 2> /dev/null)"
								if [[ -z "${updated_app_version}" ]]; then
									updated_app_version="$(PlistBuddy -c 'Print :CFBundleVersion' "${this_app_path}/Contents/Info.plist" 2> /dev/null)"
								fi

								if [[ "${this_app_name}" == 'GpuTest' ]]; then # The "GpuTest" app bundle version is wrong, use the latest version in the "changelog.txt" instead.
									updated_app_version="$(awk '($1 == "GpuTest") { print substr($2, 2); exit }' "${this_app_path}/Contents/Resources/changelog.txt")"
									rm -f "${this_app_path}/data/apple_logo.jpg" # Delete "apple_logo.jpg" from GpuTest app since don't want/need to Apple logo in the bottom right corner during the GPU Test.
								fi

								if [[ -n "${updated_app_version}" ]]; then
									echo "Installed ${this_app_name} ${updated_app_version}"
									tracked_apps+=( "${this_app_name}" )

									if [[ "${updated_app_version}" != "${latest_version}" ]]; then
										echo "WARNING: Latest Version (${latest_version}) DOES NOT MATCH Updated App Version (${updated_app_version})"
									fi
								else
									echo 'ERROR: Failed to Detect Updated App Version'
									exit 1
								fi
							else
								if (( install_app_from_archive_exit_code == 2 )); then
									echo "ERROR: Failed to Detect App Within \"${this_app_name}\" Archive"
								elif (( install_app_from_archive_exit_code == 3 )); then
									echo "ERROR: Failed to Install App \"${this_archived_app_filename}\""
								elif (( install_app_from_archive_exit_code == 4 )); then
									echo "ERROR: Failed to Verify App \"${this_archived_app_filename}\""
								fi

								exit 1
							fi
						else
							curl_exit_code="$?"
							echo "ERROR ${curl_exit_code} DOWNLOADING ${download_url}"

							rm -rf "${download_tmp_path}"

							exit "${curl_exit_code}"
						fi
					fi
				else
					echo 'ERROR: NO LATEST VERSION OR DOWNLOAD URL'
					exit 1
				fi
			fi
		fi
	fi
done < <(find "${mtb_source_path}/Applications" "${mtb_source_path}/Users/Tester/Applications" -type d -iname '*.app' -print0)

echo -e '\n\nVerifying All Required Apps Were Found...'

required_apps=( 'AmorphousDiskMark' 'Blackmagic Disk Speed Test' ) # Mac App Store apps

required_apps+=( 'Breakaway' 'coconutBattery' 'coconutID' 'CPUTest' 'DriveDx' 'FingerMgmt' 'Geekbench 5'
				'GpuTest' 'KeyboardCleanTool' 'Mactracker' 'PiXel Check' 'SilentKnight' 'XRG' ) # Manually installed 3rd party apps

required_apps+=( 'Audio Test' 'Camera Test' 'CPU Stress Test' 'Free Geek Updater' 'GPU Stress Test' 'Internet Test' 'Keyboard Test' 'Mac Scope'
				'Microphone Test' 'Screen Test' 'Startup Picker' 'Test Boot Setup' 'Test CD' 'Test DVD' 'Trackpad Test' 'QA Helper' ) # Free Geek apps.

diff_tracked_and_required_apps="$(diff <(printf '%s\n' "${tracked_apps[@]}" | sort -f) <(printf '%s\n' "${required_apps[@]}" | sort -f) 2> /dev/null)"

untracked_extra_apps="$(echo "${diff_tracked_and_required_apps}" | grep '^<')"
if [[ -n "${untracked_extra_apps}" ]]; then
	echo -e "\nUNTRACKED (EXTRA) APPS DETECTED:\n${untracked_extra_apps}"
fi

missing_required_apps="$(echo "${diff_tracked_and_required_apps}" | grep '^>')"
if [[ -n "${missing_required_apps}" ]]; then
	echo -e "\nMISSING REQUIRED APPS:\n${missing_required_apps}"
fi

if [[ -n "${untracked_extra_apps}" || -n "${missing_required_apps}" ]]; then
	exit 1
else
	echo 'ALL APPS VERIFIED'
fi


echo -e '\n\nCleaning MTB Source Volume...'

# Delete a few things from: https://bombich.com/kb/ccc5/some-files-and-folders-are-automatically-excluded-from-backup-task
# Delete vm and temporary files
# "com.bombich.ccc" get's created if drive was selected with Carbon Copy Cloner
rm -rf "${mtb_source_path}/usr/local/bin/" \
	"${mtb_source_path}/Users/Shared/Build Info/" \
	"${mtb_source_path}/private/var/db/softwareupdate/journal.plist" \
	"${mtb_source_path}/.fseventsd" \
	"${mtb_source_path}/private/var/db/systemstats" \
	"${mtb_source_path}/private/var/db/dyld/dyld_"* \
	"${mtb_source_path}/.VolumeIcon.icns" \
	"${mtb_source_path}/private/var/vm/"* \
	"${mtb_source_path}/private/var/folders/"* \
	"${mtb_source_path}/private/var/tmp/"* \
	"${mtb_source_path}/private/tmp/"* \
	"${mtb_source_path}/Library/Application Support/com.bombich.ccc" \
	"${mtb_source_path}/Users/"*'/Desktop/QA Helper - Computer Specs.txt' \
	"${mtb_source_path}/Users/"*'/Desktop/TESTING' \
	"${mtb_source_path}/Users/"*'/Desktop/REINSTALL' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/ByHost/' \
	"${mtb_source_path}/Users/"*'/Library/Application Support/com.apple.sharedfilelist/' \
	"${mtb_source_path}/Users/"*'/Library/Application Support/App Store/updatejournal.plist' \
	"${mtb_source_path}/Users/"*'/.bash_history' \
	"${mtb_source_path}/Users/"*'/.bash_sessions/' \
	"${mtb_source_path}/Users/"*'/_geeks3d_gputest_log.txt' \
	"${mtb_source_path}/Users/"*'/Library/Safari' \
	"${mtb_source_path}/Users/"*'/Library/Caches/Apple - Safari - Safari Extensions Gallery' \
	"${mtb_source_path}/Users/"*'/Library/Caches/Metadata/Safari' \
	"${mtb_source_path}/Users/"*'/Library/Caches/com.apple.Safari' \
	"${mtb_source_path}/Users/"*'/Library/Caches/com.apple.WebKit.PluginProcess' \
	"${mtb_source_path}/Users/"*'/Library/Containers/com.apple.Safari' \
	"${mtb_source_path}/Users/"*'/Library/Cookies/Cookies.binarycookies' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/Apple - Safari - Safari Extensions Gallery' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/com.apple.Safari.LSSharedFileList.plist' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/com.apple.Safari.RSS.plist' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/com.apple.Safari.plist' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/com.apple.Safari.SafeBrowsing.plist' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/com.apple.Safari.SandboxBroker.plist' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/com.apple.SafariBookmarksSyncAgent.plist' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/com.apple.SafariCloudHistoryPushAgent.plist' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/com.apple.WebFoundation.plist' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/com.apple.WebKit.PluginHost.plist' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/com.apple.WebKit.PluginProcess.plist' \
	"${mtb_source_path}/Users/"*'/Library/Preferences/com.apple.SystemProfiler.plist' \
	"${mtb_source_path}/Users/"*'/Library/PubSub/Database' \
	"${mtb_source_path}/Users/"*'/Library/Saved Application State/com.apple.Safari.savedState' \
	"${mtb_source_path}/Users/"*'/Pictures/GPU Stress Test/' \
	"${mtb_source_path}/Users/"*'/Music/iTunes/'

# TODO: Check past Mac scripts archives to see if there should be more removals for Mojave systems.

find "${mtb_source_path}" -name '.DS_Store' -type f -print -delete 2> /dev/null

desktop_picture_path="${PROJECT_DIR}/Testing Scripts/Test Boot Setup/Source/Test Boot Desktop Picture/MacTestBoot-DesktopPicture.png"
if [[ -f "${desktop_picture_path}" ]]; then
	echo -e "\n\nSetting Free Geek Mac Test Boot Desktop Picture (for Device ID ${mtb_source_device_id})..."
	cp -f "${desktop_picture_path}" "${mtb_source_path}/Users/Staff/Public/Mac Test Boot Desktop Picture.png"
fi

user_picture_path="${PROJECT_DIR}/fgMIB Resources/Prepare OS Package/Package Resources/Global/Users/Free Geek User Picture.png"
if [[ -f "${user_picture_path}" ]]; then
	echo -e "\n\nSetting Free Geek User Picture (for Device ID ${mtb_source_device_id})..."
	cp -f "${user_picture_path}" "${mtb_source_path}/Users/Staff/Public/Free Geek User Picture.png"
fi

volume_icon_path="${PROJECT_DIR}/Build Tools/MTB-VolumeIcon/MTB-VolumeIcon.icns"
if [[ -f "${volume_icon_path}" ]]; then
	echo -e "\n\nSetting Free Geek Volume Icon (for Device ID ${mtb_source_device_id})..."
	cp -f "${volume_icon_path}" "${mtb_source_path}/.VolumeIcon.icns"
fi

echo -e "\n\nCreating MTB Disk Image (of Device ID ${mtb_source_device_id})..."
date '+%Y%m%d' > "${mtb_source_path}/private/var/root/.mtbVersion"
diskutil unmountDisk "${mtb_source_device_id}" || diskutil unmountDisk force "${mtb_source_device_id}"

mtb_dmg_path='/Users/Shared/Mac Deployment'
if [[ ! -d "${mtb_dmg_path}" ]]; then
	mkdir -p "${mtb_dmg_path}"
fi

rm -rf "${mtb_dmg_path}/FreeGeek-MacTestBoot-Mojave-$(date +%Y%m%d).dmg"
sudo hdiutil create "${mtb_dmg_path}/FreeGeek-MacTestBoot-Mojave-$(date +%Y%m%d).dmg" -srcdevice "${mtb_source_device_id}" || exit 1
sudo asr imagescan --source "${mtb_dmg_path}/FreeGeek-MacTestBoot-Mojave-$(date +%Y%m%d).dmg" || exit 1
