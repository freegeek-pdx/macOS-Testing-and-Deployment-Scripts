#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

get_marketing_model_name() {
	##
	## Created by Pico Mitchell (of Free Geek)
	##
	## Version: 2023.5.31-1
	##
	## MIT License
	##
	## Copyright (c) 2021 Free Geek
	##
	## Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
	## to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
	## and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
	##
	## The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
	##
	## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
	## WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
	##

	local PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add /usr/libexec to PATH for easy access to PlistBuddy.

	# THE NEXT 3 VARIABLES CAN OPTIONALLY BE SET TO "true" MANUALLY OR BY PASSING THE SPECIFIED ARGUMENTS TO THIS FUNCTION TO ALTER THE OUTPUT:
	local VERBOSE_LOGGING=false # Set to "true" or pass "v" argument for logging to stderr to see how the Marketing Model Name is being loaded and if and where it is being cached as well as other debug info.
	local ALWAYS_INCLUDE_MODEL_ID=false # Set to "true" or pass "i" argument if you want to always include the Model ID in the output after the Marketing Model Name (it will be included in the output from this script but it won't be cached to not alter the "About This Mac" model name).
	local INCLUDE_MODEL_PART_NUMBER=false # Set to "true" or pass "p" argument if you want to include the "M####LL/A" style Model Part Number in the output after the Marketing Model Name for T2 and Apple Silicon Macs (it will be included in the output from this script but it won't be cached to not alter the "About This Mac" model name).

	local this_option
	while getopts 'vip' this_option; do
		case "${this_option}" in
			'v') VERBOSE_LOGGING=true ;;
			'i') ALWAYS_INCLUDE_MODEL_ID=true ;;
			'p') INCLUDE_MODEL_PART_NUMBER=true ;;
			*) return 1 ;; # This matches any invalid options and "getopts" will output an error, so we don't need to.
		esac
	done
	readonly VERBOSE_LOGGING
	readonly ALWAYS_INCLUDE_MODEL_ID
	readonly INCLUDE_MODEL_PART_NUMBER

	local MODEL_IDENTIFIER
	MODEL_IDENTIFIER="$(sysctl -n hw.model 2> /dev/null)"
	if [[ -z "${MODEL_IDENTIFIER}" ]]; then MODEL_IDENTIFIER='UNKNOWN Model Identifier'; fi # This should never happen, but will result in some useful feedback if somehow "sysctl" fails to return a Model Identifier.
	readonly MODEL_IDENTIFIER
	if $VERBOSE_LOGGING; then >&2 echo "DEBUG - MODEL ID: ${MODEL_IDENTIFIER}"; fi

	local IS_APPLE_SILICON
	IS_APPLE_SILICON="$([[ "$(sysctl -in hw.optional.arm64)" == '1' ]] && echo 'true' || echo 'false')"
	readonly IS_APPLE_SILICON

	local IS_VIRTUAL_MACHINE
	# "machdep.cpu.features" is always EMPTY on Apple Silicon (whether or not it's a VM) so it cannot be used to check for the "VMM" feature flag when the system is a VM,
	# but I examined the full "sysctl -a" output when running a VM on Apple Silicon and found that "kern.hv_vmm_present" is set to "1" when running a VM and "0" when not.
	# Though testing, I found the "kern.hv_vmm_present" key is also the present on Intel Macs starting with macOS version macOS 11 Big Sur and gets properly set to "1"
	# on Intel VMs, but still check for either since "kern.hv_vmm_present" is not available on every version of macOS that this script may be run on.
	IS_VIRTUAL_MACHINE="$([[ " $(sysctl -in machdep.cpu.features) " == *' VMM '* || "$(sysctl -in kern.hv_vmm_present)" == '1' ]] && echo 'true' || echo 'false')"
	readonly IS_VIRTUAL_MACHINE
	if $VERBOSE_LOGGING; then >&2 echo "DEBUG - IS VM: ${IS_VIRTUAL_MACHINE}"; fi

	local possible_marketing_model_name
	local marketing_model_name

	if $IS_APPLE_SILICON; then
		# This local Marketing Model Name within "ioreg" only exists on Apple Silicon Macs.
		if $VERBOSE_LOGGING; then >&2 echo 'DEBUG - LOADING FROM IOREG ON APPLE SILICON'; fi
		possible_marketing_model_name="$(PlistBuddy -c 'Print :0:product-name' /dev/stdin <<< "$(ioreg -arc IOPlatformDevice -k product-name)" 2> /dev/null | tr -d '[:cntrl:]')" # Remove control characters because this decoded value could end with a NUL char.

		if $IS_VIRTUAL_MACHINE; then
			# It appears that Apple Silicon Virtual Machines will always output "Apple Virtual Machine 1" as their local Marketing Model Name from the previous "ioreg" command.
			# I'm not sure if that trailing "1" could ever be another number and whether it indicates some version or what.
			# But, if the retrieved local Marketing Model Name contains "Virtual Machine", we will only output "Apple Silicon Virtual Machine" instead to be more specific instead.
			# If this ever changes in the future and the local Marketing Model Name DOES NOT contain "Virtual Machine", then the retrieved local Marketing Model Name will
			# ALSO be displayed like "Apple Silicon Virtual Machine: [LOCAL MARKETING MODEL NAME]" to give the most possible info, like is done for Intel Virtual Machines.

			marketing_model_name='Apple Silicon Virtual Machine'

			if [[ -n "${possible_marketing_model_name}" && "${possible_marketing_model_name}" != *'Virtual Machine'* ]]; then
				marketing_model_name+=": ${possible_marketing_model_name}"
			fi
		else
			marketing_model_name="${possible_marketing_model_name}"
		fi
	else
		local SERIAL_NUMBER
		SERIAL_NUMBER="$(PlistBuddy -c 'Print :0:IOPlatformSerialNumber' /dev/stdin <<< "$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)" 2> /dev/null)"
		readonly SERIAL_NUMBER
		if $VERBOSE_LOGGING; then >&2 echo "DEBUG - SERIAL: ${SERIAL_NUMBER}"; fi

		local load_fallback_marketing_model_name=false

		if [[ -n "${SERIAL_NUMBER}" ]]; then
			local marketing_model_name_was_cached=false

			local serial_config_code=''
			local serial_number_length="${#SERIAL_NUMBER}"
			if (( serial_number_length == 11 || serial_number_length == 12 )); then
				# The Configuration Code part of the Serial Number which indicates the model is the last 4 characters for 12 character serials and the last 3 characters for 11 character serials (which are very old and shouldn't actually be encountered: https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/).
				# Starting with the 2021 MacBook Pro models, randomized 10 character Serial Numbers are now used which do not have any model specific characters, but those Macs will never get here or need to load the Marketing Model Name over the internet since they are Apple Silicon and the local Marketing Model Name will have been retrieved above.
				serial_config_code="${SERIAL_NUMBER:8}"
			fi

			local logged_in_user_id
			logged_in_user_id="$(echo 'show State:/Users/ConsoleUser' | scutil | awk '(($1 == "Name") && (($NF == "loginwindow") || ($NF ~ /^_/))) { exit } ($1 == "UID") { print $NF; exit }')"
			# NOTES ABOUT RETRIEVING LOGGED IN USER VIA "scutil" (RATHER THAN USING "stat")
			# Retrieving the logged in user UID with "stat -f '%u' /dev/console" will returns "0" (for the "root" user) very early on boot before any user is logged in and before even getting to the login window, and it will also return "0" when at the login window.
			# Both of those scenarios could be mistaken for the "root" user actually being logged in graphically if the "stat" technique is used instead of "scutil".
			# Using "scutil" (with some "awk" filtering) can do better in both of those situations vs using "stat" to be able to return an empty string early on boot and at the login window while correctly returning the logged in user UID when a user is actually logged in (even if that is actually the root user).
			# Early on boot (before getting to the login window), "echo 'show State:/Users/ConsoleUser' | scutil" will return "No such key" so an empty string will be returned after piping to "awk" since no "UID" field would be found.
			# When at the initial boot login window, there will be no top level "Name" or "UID" fields, but there will be "SessionInfo" array with either the "root" user (UID 0) indicated on macOS 10.14 Mojave and older or "_windowserver" user (UID 88)
			# indicated on macOS 10.15 Catalina and newer, but those "SessionInfo" fields are NOT checked by this code. So an empty string will be properly returned when at the initial boot login window after piping to "awk".
			# When at the login window after a user has logged out, the top level "Name" will be "loginwindow" (and "UID" will be "0") on macOS 10.15 Catalina and newer so we want to ignore it and return an empty string so that the "root" user is not
			# considered to be logged in at the login window (on macOS 10.14 Mojave and older, the same info as the initial boot login window as described above is also shown after logout which will also result in an empty string being properly returned).
			# Also, return an empty string if any service/role account is logged in which would start with "_" (such as "_mbsetupuser" which would indicate that the system is at Setup Assistant).
			# Otherwise return the actual logged in user UID (which could be "0" if actually logged in as root, even though that is quite rare and not a recommended thing to do).
			# For more information, see https://scriptingosx.com/2020/02/getting-the-current-user-in-macos-update/

			local is_logged_in_as_root=false
			if [[ -n "${logged_in_user_id}" ]] && (( logged_in_user_id == 0 )); then
				is_logged_in_as_root=true
			fi

			local logged_in_user_name=''
			if [[ -n "${serial_config_code}" ]]; then
				if ! $is_logged_in_as_root && (( ${EUID:-$(id -u)} == 0 )); then
					# If running as root (but not logged in graphically as root), check for the cached Marketing Model Name from the logged in user, if a user is logged it.
					# If not found or no user is logged in, check for the cached Marketing Model Name from other users with home folders within "/Users".
					# If runnning as root and the root user is graphically logged in (which is rare but possible), only their preferences will be checked (and cached to) just like any other running user (even though they could technically check other users preferences).

					if [[ -n "${logged_in_user_id}" ]]; then
						logged_in_user_name="$(dscl /Search -search /Users UniqueID "${logged_in_user_id}" 2> /dev/null | awk '{ print $1; exit }')"
					fi

					if [[ -n "${logged_in_user_name}" ]]; then # Always check cached preferences for logged in user first so that we know whether or not it needs to be cached for the logged in user if it is already cached for another user.
						if $VERBOSE_LOGGING; then >&2 echo "DEBUG - CHECKING LOGGED IN USER ${logged_in_user_name} DEFAULTS"; fi
						# Since "defaults read" has no option to traverse into keys of dictionary values, use the whole "defaults export" output and parse it with "PlistBuddy" to get at the specific key of the "CPU Names" dictionary value that we want.
						# Using "defaults export" instead of accessing the plist file directly with "PlistBuddy" is important since preferences are not guaranteed to be written to disk if they were just set.
						possible_marketing_model_name="$(PlistBuddy -c "Print :'CPU Names':${serial_config_code}-en-US_US" /dev/stdin <<< "$(launchctl asuser "${logged_in_user_id}" sudo -u "${logged_in_user_name}" defaults export com.apple.SystemProfiler -)" 2> /dev/null)"

						if [[ "${possible_marketing_model_name}" == *'Mac'* ]]; then
							if $VERBOSE_LOGGING; then >&2 echo "DEBUG - LOADED FROM LOGGED IN USER ${logged_in_user_name} CACHE"; fi
							marketing_model_name="${possible_marketing_model_name}"
							marketing_model_name_was_cached=true
						fi
					fi

					if [[ -z "${marketing_model_name}" ]]; then # If was not cached for logged in user, check other users with home folders in "/Users" (there could technically users with home folders in other locations, but this is thorough enough for normal scenarios).
						local this_home_folder
						local user_name_for_home
						local user_id_for_home
						for this_home_folder in '/Users/'*; do
							if [[ -d "${this_home_folder}" && "${this_home_folder}" != '/Users/Shared' && "${this_home_folder}" != '/Users/Guest' ]]; then
								user_name_for_home="$(dscl /Search -search /Users NFSHomeDirectory "${this_home_folder}" | awk '{ print $1; exit }')"

								if [[ -n "${user_name_for_home}" ]]; then
									user_id_for_home="$(dscl -plist /Search -read "/Users/${user_name_for_home}" UniqueID 2> /dev/null | xmllint --xpath 'string(//string)' - 2> /dev/null)"

									if [[ -n "${user_id_for_home}" && "${user_id_for_home}" != '0' && "${user_name_for_home}" != "${logged_in_user_name}" ]]; then # No need to check logged in user in this loop since it was already checked.
										if $VERBOSE_LOGGING; then >&2 echo "DEBUG - CHECKING ${this_home_folder} DEFAULTS"; fi
										possible_marketing_model_name="$(PlistBuddy -c "Print :'CPU Names':${serial_config_code}-en-US_US" /dev/stdin <<< "$(launchctl asuser "${user_id_for_home}" sudo -u "${user_name_for_home}" defaults export com.apple.SystemProfiler -)" 2> /dev/null)" # See notes above about using "PlistBuddy" with "defaults export".

										if [[ "${possible_marketing_model_name}" == *'Mac'* ]]; then
											if $VERBOSE_LOGGING; then >&2 echo "DEBUG - LOADED FROM ${this_home_folder} CACHE"; fi
											marketing_model_name="${possible_marketing_model_name}"

											if [[ -z "${logged_in_user_name}" ]]; then # DO NOT consider the Marketing Model Name cached if there is a logged in user that it was not cached for so that it can be cached to the logged in user.
												marketing_model_name_was_cached=true
											elif $VERBOSE_LOGGING; then
												>&2 echo 'DEBUG - NOT CONSIDERING IT CACHED SINCE THERE IS A LOGGED IN USER'
											fi

											break
										fi
									elif $VERBOSE_LOGGING; then
										>&2 echo "DEBUG - SKIPPING ${this_home_folder} SINCE IS LOGGED IN USER"
									fi
								fi
							fi
						done
					fi
				else # If running as a user, won't be able to check others home folders, so only check running user preferences.
					if $VERBOSE_LOGGING; then >&2 echo "DEBUG - CHECKING RUNNING USER $(id -un) DEFAULTS"; fi
					possible_marketing_model_name="$(PlistBuddy -c "Print :'CPU Names':${serial_config_code}-en-US_US" /dev/stdin <<< "$(defaults export com.apple.SystemProfiler -)" 2> /dev/null)" # See notes above about using "PlistBuddy" with "defaults export".

					if [[ "${possible_marketing_model_name}" == *'Mac'* ]]; then
						if $VERBOSE_LOGGING; then >&2 echo "DEBUG - LOADED FROM RUNNING USER $(id -un) CACHE"; fi
						marketing_model_name="${possible_marketing_model_name}"
						marketing_model_name_was_cached=true
					fi
				fi
			fi

			if [[ -z "${marketing_model_name}" && -n "${serial_config_code}" ]]; then
				local marketing_model_name_xml
				marketing_model_name_xml="$(curl -m 5 -sfL "https://support-sp.apple.com/sp/product?cc=${serial_config_code}" 2> /dev/null)"

				if [[ "${marketing_model_name_xml}" == '<?xml'* ]]; then
					possible_marketing_model_name="$(echo "${marketing_model_name_xml}" | xmllint --xpath 'normalize-space(//configCode)' - 2> /dev/null)"

					if [[ "${possible_marketing_model_name}" == *'Mac'* ]]; then
						if $VERBOSE_LOGGING; then >&2 echo "DEBUG - LOADED FROM \"About This Mac\" URL API: ${possible_marketing_model_name}"; fi
						marketing_model_name="${possible_marketing_model_name}"

						if [[ "${marketing_model_name}" != *[[:digit:]]* ]]; then
							# If Marketing Model Name does not contain a digit, the "About This Mac" URL API may have just returned the Short Model Name, such as how "MacBook Air" will only be returned for *SOME* 2013 "MacBookAir6,1" or "MacBookAir6,2" serials),
							# But, the "Specs Search" URL API will retrieve the proper full Marketing Model Name of "MacBook Air (11-inch, Mid 2013)" for the 2013 "MacBookAir6,1" and "MacBook Air (13-inch, Mid 2013)" for the 2013 "MacBookAir6,2", so fallback to using that if there are no digits in the Marketing Model Name.
							load_fallback_marketing_model_name=true
						fi
					else
						if $VERBOSE_LOGGING; then >&2 echo "DEBUG - INVALID FROM \"About This Mac\" URL API (${possible_marketing_model_name:-N/A}): ${marketing_model_name_xml}"; fi

						marketing_model_name="${MODEL_IDENTIFIER} (Invalid Serial Number for Marketing Model Name)"
						load_fallback_marketing_model_name=true
					fi
				elif $VERBOSE_LOGGING; then
					>&2 echo 'DEBUG - FAILED TO LOAD FROM "About This Mac" URL API'
				fi
			fi

			if $load_fallback_marketing_model_name || [[ -z "${marketing_model_name}" ]]; then
				# The following URL API and JSON structure was discovered from examining how "https://support.apple.com/specs/${SERIAL_NUMBER}" loads the specs URL via JavaScript (as of August 9th, 2022 in case this breaks in the future).
				# This alternate technique of getting the Marketing Model Name for a Serial Number from this "Specs Search" URL API should not be necessary as the previous one should have always worked for valid serials,
				# but including it here anyway just in case the older "About This Mac" URL API stops working at some point and also as a reference for how this "Specs Search" URL API method can be used.
				# Also worth noting that this technique also works for the new randomized 10 character serial numbers for Apple Silicon Macs, but the local Marketing Model Name will always be retrieved instead on Apple Silicon Macs.
				# For more information about this "Specs Search" URL API, see: https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/get_specs_url_from_serial.sh

				local serial_search_results_json
				serial_search_results_json="$(curl -m 10 -sfL "https://km.support.apple.com/kb/index?page=categorydata&serialnumber=${SERIAL_NUMBER}" 2> /dev/null)" # I have seem this URL API timeout after 5 seconds when called multiple times rapidly (likely because of rate limiting), so give it a 10 second timeout which seems to always work.

				if [[ "${serial_search_results_json}" == *'"id":'* ]]; then # A valid JSON structure containing an "id" key should always be returned, even for invalid serials.
					possible_marketing_model_name="$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).name.replace(/\s+/g, " ").trim()' -- "${serial_search_results_json}" 2> /dev/null)" # Parsing JSON with JXA: https://paulgalow.com/how-to-work-with-json-api-data-in-macos-shell-scripts & https://twitter.com/n8henrie/status/1529513429203300352

					if [[ "${possible_marketing_model_name}" == *'Mac'* ]]; then
						if $VERBOSE_LOGGING; then >&2 echo "DEBUG - LOADED FROM \"Specs Search\" URL API: ${possible_marketing_model_name}"; fi
						marketing_model_name="${possible_marketing_model_name}"
						load_fallback_marketing_model_name=false
					else
						if $VERBOSE_LOGGING; then >&2 echo "DEBUG - INVALID FROM \"Specs Search\" URL API (${possible_marketing_model_name:-N/A}): $(echo "${serial_search_results_json}" | tr -d '[:space:]')"; fi # Remove all whitespace from JSON results just for a brief DEBUG display.

						marketing_model_name="${MODEL_IDENTIFIER} (Invalid Serial Number for Marketing Model Name)"
						load_fallback_marketing_model_name=true
					fi
				elif $VERBOSE_LOGGING; then
					>&2 echo 'DEBUG - FAILED TO LOAD FROM "Specs Search" URL API'
				fi
			fi

			if ! $load_fallback_marketing_model_name; then
				if [[ -n "${marketing_model_name}" ]]; then
					if ! $marketing_model_name_was_cached && [[ -n "${serial_config_code}" ]]; then
						# Cache the Marketing Model Name into the "About This Mac" preference key...
							# for the running user (if not running as root, unless graphically logged in as root) if the Marketing Model Name was downloaded,
							# OR if running as root, for the logged in user (if a user is logged in) and the Marketing Model Name was downloaded or was loaded from another users cache,
							# OR for the first valid home folder detected within "/Users" if running as root and there is no user logged in and the Marketing Model Name was downloaded.

						local cpu_name_key_for_serial="${serial_config_code}-en-US_US"
						local quoted_marketing_model_name_for_defaults
						quoted_marketing_model_name_for_defaults="$([[ "${marketing_model_name}" =~ [\(\)] ]] && echo "'${marketing_model_name}'" || echo "${marketing_model_name}")"
						# If the model contains parentheses, "defaults write" has trouble with it and the value needs to be specially quoted: https://apple.stackexchange.com/questions/300845/how-do-i-handle-e-g-correctly-escape-parens-in-a-defaults-write-key-val#answer-300853

						if ! $is_logged_in_as_root && (( ${EUID:-$(id -u)} == 0 )); then # As noted above, if graphically logged in as root, only cache to their preferences just like when running as any other user.
							local user_id_for_cache
							local user_name_for_cache
							if [[ -n "${logged_in_user_name}" ]]; then # Always cache for logged in user if there is one.
								user_id_for_cache="${logged_in_user_id}"
								user_name_for_cache="${logged_in_user_name}"
							else # Otherwise cache to first valid home folder detected.
								for this_home_folder in '/Users/'*; do
									if [[ -d "${this_home_folder}" && "${this_home_folder}" != '/Users/Shared' && "${this_home_folder}" != '/Users/Guest' ]]; then
										user_name_for_home="$(dscl /Search -search /Users NFSHomeDirectory "${this_home_folder}" | awk '{ print $1; exit }')"

										if [[ -n "${user_name_for_home}" ]]; then
											user_id_for_home="$(dscl -plist /Search -read "/Users/${user_name_for_home}" UniqueID 2> /dev/null | xmllint --xpath 'string(//string)' - 2> /dev/null)"

											if [[ -n "${user_id_for_home}" && "${user_id_for_home}" != '0' ]]; then
												user_id_for_cache="${user_id_for_home}"
												user_name_for_cache="${user_name_for_home}"
												break
											fi
										fi
									fi
								done
							fi

							if [[ -n "${user_id_for_cache}" && "${user_id_for_cache}" != '0' && -n "${user_name_for_cache}" ]]; then
								launchctl asuser "${user_id_for_cache}" sudo -u "${user_name_for_cache}" defaults write com.apple.SystemProfiler 'CPU Names' -dict-add "${cpu_name_key_for_serial}" "${quoted_marketing_model_name_for_defaults}"

								if $VERBOSE_LOGGING; then
									if [[ "${logged_in_user_name}" == "${user_name_for_cache}" ]]; then
										>&2 echo "DEBUG - CACHED FOR LOGGED IN USER ${user_name_for_cache}"
									else
										>&2 echo "DEBUG - CACHED FOR OTHER USER ${user_name_for_cache}"
									fi

									>&2 launchctl asuser "${user_id_for_cache}" sudo -u "${user_name_for_cache}" defaults read com.apple.SystemProfiler 'CPU Names'
								fi
							elif $VERBOSE_LOGGING; then
								>&2 echo 'DEBUG - NO USER TO CACHE FOR'
							fi
						else
							defaults write com.apple.SystemProfiler 'CPU Names' -dict-add "${cpu_name_key_for_serial}" "${quoted_marketing_model_name_for_defaults}"

							if $VERBOSE_LOGGING; then
								>&2 echo "DEBUG - CACHED FOR RUNNING USER $(id -un)"
								>&2 defaults read com.apple.SystemProfiler 'CPU Names'
							fi
						fi
					fi
				else
					marketing_model_name="${MODEL_IDENTIFIER} (Internet Required for Marketing Model Name)"
					load_fallback_marketing_model_name=true
				fi
			fi
		else
			marketing_model_name="${MODEL_IDENTIFIER} (No Serial Number for Marketing Model Name)"
			load_fallback_marketing_model_name=true
		fi

		if $load_fallback_marketing_model_name; then
			# A slightly different Marketing Model Name is available locally for all Intel Macs except for the last few models: https://scriptingosx.com/2017/11/get-the-marketing-name-for-a-mac/
			# Since these are not the same a what is loaded in "About This Mac", these are only used as a fallback option and are never cached.
			local si_machine_attributes_plist_path='/System/Library/PrivateFrameworks/ServerInformation.framework/Versions/A/Resources/en.lproj/SIMachineAttributes.plist' # The path to this file changed to this in macOS 10.15 Catalina.
			if [[ ! -f "${si_machine_attributes_plist_path}" ]]; then si_machine_attributes_plist_path='/System/Library/PrivateFrameworks/ServerInformation.framework/Versions/A/Resources/English.lproj/SIMachineAttributes.plist'; fi

			if [[ -f "${si_machine_attributes_plist_path}" ]]; then
				local fallback_marketing_model_name
				fallback_marketing_model_name="$(PlistBuddy -c "Print :${MODEL_IDENTIFIER}:_LOCALIZABLE_:marketingModel" "${si_machine_attributes_plist_path}" 2> /dev/null)"

				if [[ -n "${fallback_marketing_model_name}" ]]; then
					marketing_model_name+=" / Fallback: ${fallback_marketing_model_name}"
				fi
			fi
		fi

		if $IS_VIRTUAL_MACHINE; then
			marketing_model_name="Intel Virtual Machine: ${marketing_model_name}"
		fi
	fi

	if $ALWAYS_INCLUDE_MODEL_ID && [[ "${marketing_model_name}" != *"${MODEL_IDENTIFIER}"* ]]; then
		marketing_model_name+=" / ${MODEL_IDENTIFIER}"
	fi

	if $INCLUDE_MODEL_PART_NUMBER && { $IS_APPLE_SILICON || [[ -n "$(ioreg -rc AppleUSBDevice -n 'Apple T2 Controller' -d 1)" ]]; }; then # The "M####LL/A" style Model Part Number is only be accessible in software on Apple Silicon or T2 Macs.
		local possible_model_part_number
		possible_model_part_number="$(/usr/libexec/remotectl dumpstate | awk '($1 == "RegionInfo") { if ($NF == "=>") { region_info = "LL/A" } else { region_info = $NF } } ($1 == "ModelNumber") { if ($NF ~ /\//) { print $NF } else { print $NF region_info } exit }')" # I have seen a T2 Mac without any "RegionInfo" specified, so just assume "LL/A" (USA) in that case.
		if [[ "${possible_model_part_number}" == *'/'* ]]; then
			marketing_model_name+=" / ${possible_model_part_number}"
		fi
	fi

	echo "${marketing_model_name}"
}

get_marketing_model_name "$@"
