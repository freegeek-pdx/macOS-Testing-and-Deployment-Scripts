#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell (of Free Geek) on 5/25/23.
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

# NOTE: This list outputted from the script should now be static with no new additions since all new serials are randomized and the last chars do not indicate the model: https://www.macrumors.com/2021/03/09/apple-randomized-serial-numbers-early-2021/
# But, the Marketing Model Name can still be retreived for those entire randomized serials using the "Specs Search" URL API: https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/get_specs_url_from_serial.sh
# Also, all new Macs with the randomized serials are Apple Silicon and their Marketing Model Name is stored locally anyways: https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/5b0d100bbc1f5baced895dd5a7c37a2d6de549fa/Other%20Scripts/get_marketing_model_name.sh#L70

PATH='/usr/bin:/bin:/usr/sbin:/sbin'

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"
readonly SCRIPT_DIR

every_apple_serial_config_code_with_marketing_model_name_file_path="${SCRIPT_DIR}/every_apple_serial_config_code_with_marketing_model_name.txt"
if [[ ! -f "${every_apple_serial_config_code_with_marketing_model_name_file_path}" ]]; then

	serial_config_codes_save_dir="${SCRIPT_DIR}/every_apple_serial_config_code_with_marketing_model_name-output"
	mkdir -p "${serial_config_codes_save_dir}" # Each serial configuration code is saved to its own file since queries are asynchronous/simultaneous to not ever clobber any single file output.

	check_possible_serial_config_code() {
		local this_possible_serial_config_code="$1"
		local url_api_used='API=ABOUT'
		local this_marketing_model_name=''
		local got_response_from_api=false

		# The following URL API is what "About This Mac" uses to load the Marketing Model Name.
		local this_marketing_model_name_xml
		for about_api_attempt_count in {1..5}; do # Do multiple attempts in case of failures because of rate limiting.
			this_marketing_model_name_xml="$(curl -m 5 -sfL "https://support-sp.apple.com/sp/product?cc=${this_possible_serial_config_code}")"
			local curl_exit_code="$?"
			if [[ "${this_marketing_model_name_xml}" == '<?xml'* ]]; then # Error if not a valid XML structure.
				if [[ "${this_marketing_model_name_xml}" == *'<configCode>'* ]]; then # But only bother extracting anything if it has a "configCode" tag.
					this_marketing_model_name="$(echo "${this_marketing_model_name_xml}" | xmllint --xpath 'string(//configCode)' - 2> /dev/null)" # Use "string(...)" instead of ".../text()" since the former always properly interprets/renders HTML escape sequences such as "&#xE8" while the latter will only do so on macOS 13 Ventura or newer and will just output that escape sequence on macOS 12 Monterey and older (for example, see "https://support-sp.apple.com/sp/product?cc=GR81" and other Hermes Apple Watch models).

					if [[ "${this_marketing_model_name}" == 'MacBook Air' ]]; then
						# NOTE: The "About This Mac" URL API just returns "MacBook Air" for *SOME* 2013 "MacBookAir6,1" or "MacBookAir6,2" serials.
						# CONFIG CODES THAT RETURN CORRECT FULL MODEL NAME: F5N7 F5N8 FH51 FKYN FKYP F5V7 F5V8 FH53 FKYQ FM74 FMRL FMRY FN40 FP2P
						# CONFIG CODES THAT RETURN JUST "MacBook Air" FULL MODEL NAME: 5YV, 5YW, 6T5, 6T6, F5Y, F6T, FLC, LCF, LCG, F5YV, F5YW, F6T5, F6T6, FLCF, FLCG
						# This pattern seems to show that there is some bug involving these invalid MacBook Air 3 character config code since each is a suffix or prefix of these valid MacBook Air 4 character config codes, and those 3 character config codes are not even for MacBook Airs, most of which are not for any model.
						# But, the "Specs Search" URL API will retrieve the proper full Marketing Model Name of "MacBook Air (11-inch, Mid 2013)" for the 2013 "MacBookAir6,1" and "MacBook Air (13-inch, Mid 2013)" for the 2013 "MacBookAir6,2", so fallback to using that for these serial endings that return the wrong Marketing Model Name.
						>&2 echo "${this_possible_serial_config_code}:REJECTED-FROM-ABOUT=${this_marketing_model_name}"
						this_marketing_model_name=''
					fi
				fi

				got_response_from_api=true

				if (( about_api_attempt_count > 1)); then
					>&2 echo "${this_possible_serial_config_code}:ABOUT-SUCCESS-ON-ATTEMPT-${about_api_attempt_count}"
				fi

				break
			else
				if [[ -n "${this_marketing_model_name_xml}" ]]; then
					this_marketing_model_name_xml="${this_marketing_model_name_xml//$'\n'/}"
				fi

				>&2 echo "${this_possible_serial_config_code}:ABOUT-ERROR-${about_api_attempt_count}=${this_marketing_model_name_xml:-${curl_exit_code}}"

				if (( about_api_attempt_count == 5 && curl_exit_code == 22 )) && [[ "${this_possible_serial_config_code}" == 'MSDB' ]]; then # For some reason "https://support-sp.apple.com/sp/product?cc=MSDB" always returns a 403 forbidden error, so allow just this one to fallback on Specs Search API.
					>&2 echo "${this_possible_serial_config_code}:ALLOWING-SPECS-API-FALLBACK-FOR-MSDB-403"
					got_response_from_api=true
				fi

				sleep "${about_api_attempt_count}"
			fi
		done

		if $got_response_from_api && [[ -z "${this_marketing_model_name}" ]]; then
			got_response_from_api=false

			# If the "About This Mac" URL API (used above) returned nothing or only returned the Short Model Name
			# (such as the "MacBook Air" issue explained above for *SOME* 2013 "MacBookAir6,1" or "MacBookAir6,2" serials),
			# fallback on using the "Specs Search" URL API (used below) to retrieve the Marketing Model Name.
			# For more information about this "Specs Search" URL API, see: https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/get_specs_url_from_serial.sh

			this_possible_fake_serial_with_valid_serial_config_code="XXXXXXXX${this_possible_serial_config_code}" # For 4 character config codes, passing all X's works for the first portion of the 12 character serial which isn't relevant to the model.
			if (( ${#this_possible_serial_config_code} == 3 )); then
				this_possible_fake_serial_with_valid_serial_config_code="RM001000${this_possible_serial_config_code}"
				# For 3 character config codes, passing all X's DOES NOT work for the first portion of the serial which isn't relevant to the model and some valid format must be used,
				# so append the config code to a remanufactured/refurb serial (starting with "RM") made in year 0, week 01, and a unique ID of 000 which would never exist but allows the API call to work properly.
				# More info about this old 11 character serial format: https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/
			fi

			local this_marketing_model_name_json
			for specs_api_attempt_count in {1..5}; do # Do multiple attempts in case of failures because of rate limiting.
				this_marketing_model_name_json="$(curl -m 10 -sfL "https://km.support.apple.com/kb/index?page=categorydata&serialnumber=${this_possible_fake_serial_with_valid_serial_config_code}")" # This one seems to rate limit more and can timeout before 5 seconds, so give it 10 seconds.
				curl_exit_code="$?"
				if [[ "${this_marketing_model_name_json}" == *'"id"'* ]]; then # Error if not a valid JSON structure.
					if [[ "${this_marketing_model_name_json}" == *'"name"'* ]]; then # But only bother extracting anything if it has a "name" key.
						this_marketing_model_name="$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).name' -- "${this_marketing_model_name_json}" 2> /dev/null)"
						url_api_used='API=SPECS'
					fi

					if (( specs_api_attempt_count > 1)); then
						>&2 echo "${this_possible_serial_config_code}:SPECS-SUCCESS-ON-ATTEMPT-${specs_api_attempt_count}"
					fi

					got_response_from_api=true

					break
				else
					if [[ -n "${this_marketing_model_name_json}" ]]; then
						this_marketing_model_name_json="${this_marketing_model_name_json//$'\n'/}"
					fi

					>&2 echo "${this_possible_serial_config_code}:SPECS-ERROR-${specs_api_attempt_count}=${this_marketing_model_name_json:-${curl_exit_code}}"
					sleep "${specs_api_attempt_count}"
				fi
			done
		fi

		if $got_response_from_api; then
			if [[ -n "${this_marketing_model_name}" ]]; then
				this_marketing_model_name="${this_marketing_model_name//$'\xC2\xA0'/ }" # Replace any non-breaking spaces with regular spaces that exist in some Apple Watch model names, such as "https://support-sp.apple.com/sp/product?cc=Q20P" and others.
				echo "${this_possible_serial_config_code}:${url_api_used}:${this_marketing_model_name}" | tee "${serial_config_codes_save_dir}/${this_possible_serial_config_code}.txt" # Output and save each serial configuration code to its own file since queries are asynchronous/simultaneous to not ever clobber any single file output.
			else
				echo "${this_possible_serial_config_code}:<UNUSED>" > "${serial_config_codes_save_dir}/${this_possible_serial_config_code}.txt" # Save placeholder files to be able to stop and start without re-doing queries even if the serial configuration code is unused.
			fi
		else
			>&2 echo "${this_possible_serial_config_code}:TOTAL-ERROR-NOT-SAVING"
		fi
	}


	>&2 echo "TIMESTAMP:START-3-CHARS:$(date '+%s')"

	# The Configuration Code part of the Serial Number which indicates the model is the last 4 characters for 12 character serials and the last 3 characters for 11 character serials: https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/

	async_query_count=0
	async_query_max=100 # Started seeing more errors from the APIs when executing over around 100 simulaneous queries, probably because of rate limiting.

	serial_chars_array=( {0..9} {A..Z} ) # 11 character serials whose last 3 characters are the config code definitey DO contain "I" and "O", for example "INT" and "LZO" are both valid, among others. (Note at bottom of https://support.apple.com/HT204308 is NOT accurate for old 11 character serials.)

	# This loop to collect every 3 character serial configuration code takes about 20 minutes to complete.
	for serial_char_1 in "${serial_chars_array[@]}"; do
		>&2 echo "TIMESTAMP:START-${serial_char_1}##:$(date '+%s')"

		for serial_char_2 in "${serial_chars_array[@]}"; do
			for serial_char_3 in "${serial_chars_array[@]}"; do
				this_possible_serial_config_code="${serial_char_1}${serial_char_2}${serial_char_3}"

				if [[ ! -f "${serial_config_codes_save_dir}/${this_possible_serial_config_code}.txt" ]]; then
					check_possible_serial_config_code "${this_possible_serial_config_code}" &
					(( async_query_count ++ ))

					if (( async_query_count == async_query_max )); then
						wait
						async_query_count=0
					fi
				fi
			done
		done

		wait
		async_query_count=0

		>&2 echo "TIMESTAMP:END-${serial_char_1}##:$(date '+%s')"
	done

	>&2 echo "TIMESTAMP:END-3-CHARS:$(date '+%s')"


	>&2 echo "TIMESTAMP:START-4-CHARS:$(date '+%s')"

	serial_chars_array=( {0..9} {A..H} {J..N} {P..Z} ) # 12 character serials whose last 4 characters are the config code DO NOT contain "I" or "O" so don't check them to save time. (Note at bottom of https://support.apple.com/HT204308 is accurate for these serials.)

	>&2 echo "TIMESTAMP:START-ONE-OFFS:$(date '+%s')"

	# BUT, THERE IS A SINGLE "Z###" MODEL THAT ALSO HAPPENS TO CONTAINS AN "O": ZORD
	# ALSO THERE IS ONLY A SINGLE "A###" & "S####": AY5W ST61
	for this_one_off_serial_config_code in 'AY5W' 'ST61' 'ZORD'; do
		if [[ ! -f "${serial_config_codes_save_dir}/${this_one_off_serial_config_code}.txt" ]]; then
			check_possible_serial_config_code "${this_one_off_serial_config_code}" &
		fi
	done

	wait

	>&2 echo "TIMESTAMP:END-ONE-OFFS:$(date '+%s')"

	# This loop to collect every 4 character serial configuration code takes about 4 HOURS to complete.
	for serial_char_1 in '0' '1' '2' 'D' 'F' 'G' 'H' 'J' 'K' 'L' 'M' 'N' 'P' 'Q'; do # There are many first characters that aren't used (except in the one-offs above) so only check ones that are used to save time (this list was determined by previous iterations that checked every character).
		>&2 echo "TIMESTAMP:START-${serial_char_1}###:$(date '+%s')"

		for serial_char_2 in "${serial_chars_array[@]}"; do # Each of these sub-loops check an entire "X###" portion takes about 20 minutes to complete.
			for serial_char_3 in "${serial_chars_array[@]}"; do
				for serial_char_4 in "${serial_chars_array[@]}"; do
					this_possible_serial_config_code="${serial_char_1}${serial_char_2}${serial_char_3}${serial_char_4}"

					if [[ ! -f "${serial_config_codes_save_dir}/${this_possible_serial_config_code}.txt" ]]; then
						check_possible_serial_config_code "${this_possible_serial_config_code}" &
						(( async_query_count ++ ))

						if (( async_query_count == async_query_max )); then
							wait
							async_query_count=0
						fi
					fi
				done
			done
		done

		wait
		async_query_count=0

		>&2 echo "TIMESTAMP:END-${serial_char_1}###:$(date '+%s')"
	done

	>&2 echo "TIMESTAMP:END-4-CHARS:$(date '+%s')"


	>&2 echo "TIMESTAMP:START-SINGLE-FILE-OUTPUT:$(date '+%s')"

	find "${serial_config_codes_save_dir}" -name '???.txt' -exec grep -vFh '<UNUSED>' {} + | sort -f > "${every_apple_serial_config_code_with_marketing_model_name_file_path}"
	find "${serial_config_codes_save_dir}" -name '????.txt' -exec grep -vFh '<UNUSED>' {} + | sort -f >> "${every_apple_serial_config_code_with_marketing_model_name_file_path}"
	# Do not find and sort them all at once so that sorted 3 char config codes are listed first and then sorted 4 char config codes are listed next rather and 3 and 4 char config codes being mixed together.

	>&2 echo "TIMESTAMP:START-SINGLE-FILE-OUTPUT:$(date '+%s')"

fi


>&2 echo "TIMESTAMP:START-MODEL-GROUPED-FILE-OUTPUT:$(date '+%s')"

every_apple_marketing_model_name_with_grouped_serial_config_codes_file_path="${SCRIPT_DIR}/every_apple_marketing_model_name_with_grouped_serial_config_codes.txt"
if [[ ! -f "${every_apple_marketing_model_name_with_grouped_serial_config_codes_file_path}" ]]; then
	last_marketing_model_name=''
	while IFS=':' read -r this_marketing_model_name this_serial_config_code; do
		if [[ "${this_marketing_model_name}" != "${last_marketing_model_name}" ]]; then
			if [[ -n "${last_marketing_model_name}" ]]; then
				echo '' >> "${every_apple_marketing_model_name_with_grouped_serial_config_codes_file_path}"
			fi

			echo -n "${this_marketing_model_name}:${this_serial_config_code}:" >> "${every_apple_marketing_model_name_with_grouped_serial_config_codes_file_path}"
		else
			echo -n "${this_serial_config_code}:" >> "${every_apple_marketing_model_name_with_grouped_serial_config_codes_file_path}"

			# if (( ${#this_serial_config_code} != last_serial_config_codes_length )); then # THIS WAS JUST FOR DEBUGGING TO CONFIRM GROUPINGS
			# 	echo -n '<WARNING=MIXED-SERIAL-GENERATIONS>:' >> "${every_apple_marketing_model_name_with_grouped_serial_config_codes_file_path}"
			# fi
		fi

		last_marketing_model_name="${this_marketing_model_name}"
		# last_serial_config_codes_length="${#this_serial_config_code}"
	done < <(awk -F ':' '{ print $NF ":" $1 }' "${every_apple_serial_config_code_with_marketing_model_name_file_path}" | sort -uf)
	echo '' >> "${every_apple_marketing_model_name_with_grouped_serial_config_codes_file_path}"
fi

>&2 echo "TIMESTAMP:START-MODEL-GROUPED-FILE-OUTPUT:$(date '+%s')"


>&2 echo "TIMESTAMP:START-MODEL-GROUPED-MAC-FILE-OUTPUT:$(date '+%s')"

every_mac_marketing_model_name_with_grouped_serial_config_codes_file_path="${SCRIPT_DIR}/every_mac_marketing_model_name_with_grouped_serial_config_codes.txt"
if [[ ! -f "${every_mac_marketing_model_name_with_grouped_serial_config_codes_file_path}" ]]; then
	grep 'Mac\|Book\|Xserve' "${every_apple_marketing_model_name_with_grouped_serial_config_codes_file_path}" | grep -v 'OS X' | sort -f > "${every_mac_marketing_model_name_with_grouped_serial_config_codes_file_path}"
fi

>&2 echo "TIMESTAMP:START-MODEL-GROUPED-MAC-FILE-OUTPUT:$(date '+%s')"
