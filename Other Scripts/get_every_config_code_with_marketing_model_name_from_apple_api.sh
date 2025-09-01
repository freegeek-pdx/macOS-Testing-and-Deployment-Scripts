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

readonly OUTPUT_DIR="${SCRIPT_DIR}/serial-config-codes-output"
mkdir -p "${OUTPUT_DIR}"


include_docs_ids=false
if [[ "$1" == '--include-docs-ids' ]]; then
	include_docs_ids=true
fi


every_config_code_with_marketing_model_name_file_path="${OUTPUT_DIR}/every_config_code_with_marketing_model_name$($include_docs_ids && echo '_and_docs_ids').txt"
if [[ ! -f "${every_config_code_with_marketing_model_name_file_path}" ]]; then

	serial_config_codes_save_dir="${OUTPUT_DIR}/every_config_code_with_marketing_model_name$($include_docs_ids && echo '_and_docs_ids')-output"
	mkdir -p "${serial_config_codes_save_dir}" # Each serial configuration code is saved to its own file since queries are asynchronous/simultaneous to not ever clobber any single file output.

	check_possible_serial_config_code() {
		local this_possible_serial_config_code="$1"
		local url_api_used='API'
		local this_marketing_model_name=''
		local this_docs_id='UNKNOWN'
		local this_docs_parent_id='UNKNOWN'
		local this_docs_grandparent_id='UNKNOWN'
		local this_docs_greatgrandparent_id='UNKNOWN'

		local got_response_from_api=false

		get_marketing_model_name_from_about_api() {
			# The following URL API is what "About This Mac" uses to load the Marketing Model Name.
			local this_marketing_model_name_xml
			local about_api_attempt_count
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
						else
							url_api_used+='=ABOUT'
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
		}

		if $include_docs_ids; then
			got_response_from_api=true
		else
			# If NOT including Docs IDs, then check About API first since there are a few Config Codes that don't show up in the Specs API.
			get_marketing_model_name_from_about_api
		fi

		if $got_response_from_api && [[ -z "${this_marketing_model_name}" ]]; then
			got_response_from_api=false

			# If the "About This Mac" URL API (used above) returned nothing or only returned the Short Model Name
			# (such as the "MacBook Air" issue explained above for *SOME* 2013 "MacBookAir6,1" or "MacBookAir6,2" serials),
			# fallback on using the "Specs Search" URL API (used below) to retrieve the Marketing Model Name.
			# For more information about this "Specs Search" URL API, see: https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/get_specs_url_from_serial.sh
			# IMPORTANT: On May 15th, 2025, "https://km.support.apple.com/kb/index?page=categorydata" started returning 403 Forbidden! But other active "page" values that are still used on other parts of their site still work, so I think this was intentionally taken down.

			this_possible_fake_serial_with_valid_serial_config_code="XXXXXXXX${this_possible_serial_config_code}" # For 4 character config codes, passing all X's works for the first portion of the 12 character serial which isn't relevant to the model.
			if (( ${#this_possible_serial_config_code} == 3 )); then
				this_possible_fake_serial_with_valid_serial_config_code="RM101000${this_possible_serial_config_code}"
				# For 3 character config codes, passing all X's DOES NOT work for the first portion of the serial which isn't relevant to the model and some valid format must be used,
				# so append the config code to a remanufactured/refurb serial (starting with "RM") made in year 1, week 01, and a unique ID of 000 which would never exist but allows the API call to work properly.
				# More info about this old 11 character serial format: https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/
			fi

			local serial_search_results_json
			local specs_api_attempt_count
			for specs_api_attempt_count in {1..5}; do # Do multiple attempts in case of failures because of rate limiting.
				serial_search_results_json="$(curl -m 10 -sfL "https://km.support.apple.com/kb/index?page=categorydata&serialnumber=${this_possible_fake_serial_with_valid_serial_config_code}")" # This one seems to rate limit more and can timeout before 5 seconds, so give it 10 seconds.
				curl_exit_code="$?"
				if [[ "${serial_search_results_json}" == *'"id"'* ]]; then # Error if not a valid JSON structure.
					IFS=$'\n' read -rd '' -a serial_search_results_values < <(osascript -l 'JavaScript' -e '
function run(argv) {
	const serialSearchResultsDict = JSON.parse(argv[0])
	return [
		serialSearchResultsDict.id,
		(serialSearchResultsDict.parent ? serialSearchResultsDict.parent : "NULL"),
		(serialSearchResultsDict.grandparent ? serialSearchResultsDict.grandparent : "NULL"),
		(serialSearchResultsDict.greatgrandparent ? serialSearchResultsDict.greatgrandparent : "NULL"),
		(serialSearchResultsDict.name ? serialSearchResultsDict.name : "UNKNOWN Marketing Model Name")
	].join("\n")
}
' -- "${serial_search_results_json}" 2> /dev/null)

					if (( ${#serial_search_results_values[@]} == 5 )) && [[ "${serial_search_results_values[0]}" != 'null' ]]; then
						this_docs_id="${serial_search_results_values[0]}"
						this_docs_parent_id="${serial_search_results_values[1]}"
						this_docs_grandparent_id="${serial_search_results_values[2]}"
						this_docs_greatgrandparent_id="${serial_search_results_values[3]}"
						this_marketing_model_name="${serial_search_results_values[4]}"

						if [[ "${this_marketing_model_name}" == 'UNKNOWN Marketing Model Name' ]]; then
							this_marketing_model_name=''
						fi

						url_api_used+='=SPECS'
					fi

					if (( specs_api_attempt_count > 1)); then
						>&2 echo "${this_possible_serial_config_code}:SPECS-SUCCESS-ON-ATTEMPT-${specs_api_attempt_count}"
					fi

					got_response_from_api=true

					break
				else
					if [[ -n "${serial_search_results_json}" ]]; then
						serial_search_results_json="${serial_search_results_json//$'\n'/}"
					fi

					>&2 echo "${this_possible_serial_config_code}:SPECS-ERROR-${specs_api_attempt_count}=${serial_search_results_json:-${curl_exit_code}}"
					sleep "${specs_api_attempt_count}"
				fi
			done
		fi

		if $got_response_from_api && $include_docs_ids && [[ -z "${this_marketing_model_name}" ]]; then
			get_marketing_model_name_from_about_api # If including Docs IDs, there are a few Config Codes that don't show up in the Specs API, but we can still get the Marketing Model Names from the About API (without any Docs IDs).
		fi

		if $got_response_from_api; then
			if $include_docs_ids && [[ -z "${this_marketing_model_name}" && "${this_docs_id:-UNKNOWN}" != 'UNKNOWN' ]]; then
				this_marketing_model_name='UNKNOWN Marketing Model Name with Docs ID' # TODO: May be able to match this Docs ID up to a Marketing Model Name of another Config Code with the same Docs ID.
			fi

			if [[ -n "${this_marketing_model_name}" ]]; then
				this_original_marketing_model_name="${this_marketing_model_name}"
				this_marketing_model_name="${this_marketing_model_name//$'\xC2\xA0'/ }" # Replace any non-breaking spaces with regular spaces that exist in some Apple Watch model names, such as "https://support-sp.apple.com/sp/product?cc=Q20P" and others.
				this_marketing_model_name="${this_marketing_model_name//  / }" # Replace any double spaces with a single space that exist in some model names, such as "https://support-sp.apple.com/sp/product?cc=YAM" and others.
				this_marketing_model_name="${this_marketing_model_name// ,/,}" # Replace any space+comma with a just comma that exist in some model names, such as "https://support-sp.apple.com/sp/product?cc=MYZ" and others.
				this_marketing_model_name="${this_marketing_model_name% }" # Remove single trailing spaces which values from the the Specs API may include, like "https://km.support.apple.com/kb/index?page=categorydata&serialnumber=XXXXXXXXGTDX" and others.

				if [[ "${this_original_marketing_model_name}" != "${this_marketing_model_name}" ]]; then
					>&2 echo "${this_possible_serial_config_code}:DEBUG-CLEANED-FROM-${url_api_used}>${this_original_marketing_model_name}<>${this_marketing_model_name}<"
				fi

				include_docs_ids_with_model_name=''
				if $include_docs_ids; then
					include_docs_ids_with_model_name="${this_docs_greatgrandparent_id};${this_docs_grandparent_id};${this_docs_parent_id};${this_docs_id};"
				fi

				echo "${this_possible_serial_config_code}:${url_api_used}:${include_docs_ids_with_model_name}${this_marketing_model_name}" | tee "${serial_config_codes_save_dir}/${this_possible_serial_config_code}.txt" # Output and save each serial configuration code to its own file since queries are asynchronous/simultaneous to not ever clobber any single file output.
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

	serial_chars_array=( {0..9} {A..Z} ) # 11 character serials whose last 3 characters are the config code definitey DO contain "I" and "O", for example "INT" and "LZO" are both valid, among others. (Note at bottom of https://support.apple.com/102858 is NOT accurate for old 11 character serials.)

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

	serial_chars_array=( {0..9} {A..H} {J..N} {P..Z} ) # 12 character serials whose last 4 characters are the config code DO NOT contain "I" or "O" so don't check them to save time. (Note at bottom of https://support.apple.com/102858 is accurate for these serials.)

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

	find "${serial_config_codes_save_dir}" -name '???.txt' -exec grep -vFh '<UNUSED>' {} + | sort -f > "${every_config_code_with_marketing_model_name_file_path}"
	find "${serial_config_codes_save_dir}" -name '????.txt' -exec grep -vFh '<UNUSED>' {} + | sort -f >> "${every_config_code_with_marketing_model_name_file_path}"
	# Do not find and sort them all at once so that sorted 3 char config codes are listed first and then sorted 4 char config codes are listed next rather and 3 and 4 char config codes being mixed together.

	>&2 echo "TIMESTAMP:END-SINGLE-FILE-OUTPUT:$(date '+%s')"

fi


every_marketing_model_name_with_grouped_serial_config_codes_file_path="${OUTPUT_DIR}/every_marketing_model_name$($include_docs_ids && echo '_and_docs_ids')_with_grouped_serial_config_codes.txt"
if [[ ! -f "${every_marketing_model_name_with_grouped_serial_config_codes_file_path}" ]]; then
	>&2 echo "TIMESTAMP:START-MODEL-GROUPED-FILE-OUTPUT:$(date '+%s')"

	last_marketing_model_name=''
	every_unknown_marketing_model_name_and_docs_id_with_grouped_serial_config_codes=''
	while IFS=':' read -r this_marketing_model_name this_serial_config_code; do
		if $include_docs_ids && [[ "${this_marketing_model_name}" == *';UNKNOWN Marketing Model Name with Docs ID' ]]; then
			every_unknown_marketing_model_name_and_docs_id_with_grouped_serial_config_codes+=$'\n'"${this_marketing_model_name}:${this_serial_config_code}:"
		else
			if [[ "${this_marketing_model_name}" != "${last_marketing_model_name}" ]]; then
					if [[ -n "${last_marketing_model_name}" ]]; then
						echo '' >> "${every_marketing_model_name_with_grouped_serial_config_codes_file_path}"
					fi

					echo -n "${this_marketing_model_name}:${this_serial_config_code}:" >> "${every_marketing_model_name_with_grouped_serial_config_codes_file_path}"
			else
				echo -n "${this_serial_config_code}:" >> "${every_marketing_model_name_with_grouped_serial_config_codes_file_path}"

				# if (( ${#this_serial_config_code} != last_serial_config_codes_length )); then # THIS WAS JUST FOR DEBUGGING TO CONFIRM GROUPINGS
				# 	echo -n '<WARNING=MIXED-SERIAL-GENERATIONS>:' >> "${every_marketing_model_name_with_grouped_serial_config_codes_file_path}"
				# fi
			fi

			last_marketing_model_name="${this_marketing_model_name}"
			# last_serial_config_codes_length="${#this_serial_config_code}"
		fi
	done < <(awk -F ':' '{ print $NF ":" $1 }' "${every_config_code_with_marketing_model_name_file_path}" | sort -uf)
	echo '' >> "${every_marketing_model_name_with_grouped_serial_config_codes_file_path}"

	if $include_docs_ids && [[ -n "${every_unknown_marketing_model_name_and_docs_id_with_grouped_serial_config_codes}" ]]; then
		every_marketing_model_name_and_docs_ids_with_grouped_serial_config_codes=''
		every_unknown_marketing_model_name_and_docs_id_with_grouped_serial_config_codes="$(echo "${every_unknown_marketing_model_name_and_docs_id_with_grouped_serial_config_codes}" | grep '.')"
		while IFS=';:' read -r this_docs_greatgrandparent_id this_docs_grandparent_id this_docs_parent_id this_docs_id this_marketing_model_name these_config_codes; do
			while IFS=';:' read -r _ _ _ this_unknown_docs_id _ this_unknown_config_code; do
				if [[ "${this_docs_id}" == "${this_unknown_docs_id}" ]]; then
					these_config_codes="$(echo "${these_config_codes%:}:${this_unknown_config_code}" | tr ':' '\n' | sort -uf | tr '\n' ':')"
					echo "DEBUG:MATCHED UNKNOWN MODEL NAME WITH DOCS ID \"${this_unknown_docs_id}\" AND CONFIG CODE \"${this_unknown_config_code}\" TO \"${this_marketing_model_name}\""
				fi
			done <<< "${every_unknown_marketing_model_name_and_docs_id_with_grouped_serial_config_codes}"
			every_marketing_model_name_and_docs_ids_with_grouped_serial_config_codes+=$'\n'"${this_docs_greatgrandparent_id};${this_docs_grandparent_id};${this_docs_parent_id};${this_docs_id};${this_marketing_model_name}:${these_config_codes%:}:"
		done < "${every_marketing_model_name_with_grouped_serial_config_codes_file_path}"
		echo "${every_marketing_model_name_and_docs_ids_with_grouped_serial_config_codes}" | grep '.' | sort -fV > "${every_marketing_model_name_with_grouped_serial_config_codes_file_path}"
	fi

	>&2 echo "TIMESTAMP:END-MODEL-GROUPED-FILE-OUTPUT:$(date '+%s')"
fi

if $include_docs_ids; then
	every_marketing_model_name_and_docs_url_with_grouped_serial_config_codes_file_path="${OUTPUT_DIR}/every_marketing_model_name_and_docs_url_with_grouped_serial_config_codes.txt"
	if [[ ! -f "${every_marketing_model_name_and_docs_url_with_grouped_serial_config_codes_file_path}" ]]; then
		every_marketing_model_name_and_docs_url_with_grouped_serial_config_codes=''
		>&2 echo "TIMESTAMP:START-MODEL-GROUPED-WITH-DOCS-URL-FILE-OUTPUT:$(date '+%s')"

		while IFS=';:' read -r this_docs_greatgrandparent_id this_docs_grandparent_id this_docs_parent_id this_docs_id this_marketing_model_name these_config_codes; do
			this_docs_pf_id=''
			this_docs_pl_id=''
			this_docs_pp_id=''
			for this_docs_ancestor_id in "${this_docs_greatgrandparent_id}" "${this_docs_grandparent_id}" "${this_docs_parent_id}"; do
				# Some products could have multiple PF IDs, such as Displays (such as Config Code "P2RH") could have a Grandparent ID of "PF8" (for all accessories) and Parent ID of "PF5" (just for displays).
				# So, the order of this loop is very important to overwrite each variable with the lowest tier PF ID.
				if [[ "${this_docs_ancestor_id}" == 'PF'* ]]; then
					this_docs_pf_id="${this_docs_ancestor_id}"
				elif [[ "${this_docs_ancestor_id}" == 'PL'* ]]; then
					this_docs_pl_id="${this_docs_ancestor_id}"
				elif [[ "${this_docs_ancestor_id}" == 'PP'* ]]; then
					this_docs_pp_id="${this_docs_ancestor_id}"
				fi
			done

			if [[ -z "${this_docs_pf_id}" ]]; then # These manually set PF IDs may not end up getting to an actual Docs page for the product, but it will at least redirect to the correct Docs Category.
				# TODO: Include example comments for each of these conditions.

				if [[ "${this_marketing_model_name}" == *'Book'* ]]; then
					this_docs_pf_id='PF2'
				elif [[ "${this_marketing_model_name}" == *'Server'* || "${this_marketing_model_name}" == *'Xserve'* ]]; then
					this_docs_pf_id='PF11'
				elif [[ "${this_marketing_model_name}" == *'Mac'* ]]; then
					this_docs_pf_id='PF1'
				elif [[ "${this_marketing_model_name}" == *'Display'* ]]; then
					this_docs_pf_id='PF5'
				elif [[ "${this_marketing_model_name}" == *'Adapter'* || "${this_marketing_model_name}" == *'QuickTake'* || "${this_marketing_model_name}" == *'Products'* ]]; then
					this_docs_pf_id='PF8'
				elif [[ "${this_marketing_model_name}" == *'Phone'* ]]; then
					this_docs_pf_id='PF9'
				elif [[ "${this_marketing_model_name}" == *'Logic'* ]]; then
					this_docs_pf_id='PF14'
				elif [[ "${this_marketing_model_name}" == *'iPad'* ]]; then
					this_docs_pf_id='PF22'
					if [[ "${this_marketing_model_name}" == *' for '* ]]; then
						this_docs_pl_id='PL221'
					fi
				elif [[ "${this_marketing_model_name}" == *[Bb]'eats'* || "${this_marketing_model_name}" == *'Solo'* ]]; then
					this_docs_pf_id='PF27'
				fi

				if [[ "${this_docs_id}" == 'UNKNOWN' ]]; then
					this_docs_id='unknown'
				fi

				>&2 echo "DEBUG:SET-PF-ID-${this_docs_pf_id}>${this_docs_pl_id}>${this_docs_pp_id}>${this_docs_id}:${this_marketing_model_name}:${these_config_codes%:}:"
			fi

			if [[ -z "${this_docs_pf_id}" ]]; then
				>&2 echo "DEBUG:UNKNOWN-PF-ID-${this_docs_pf_id}>${this_docs_pl_id}>${this_docs_pp_id}>${this_docs_id}:${this_marketing_model_name}:${these_config_codes%:}:"
			fi

			this_docs_category='unknown'
			this_product_type='UNKNOWN'
			this_docs_url_id="${this_docs_id}"

			if [[ "${this_docs_pf_id}" == 'PF1' || "${this_docs_pf_id}" == 'PF2' || "${this_docs_pf_id}" == 'PF6' || "${this_docs_pf_id}" == 'PF11' ]]; then
				this_docs_category='mac'
				this_product_type='Mac'

				if [[ "${this_docs_pf_id}" == 'PF1' ]]; then
					this_product_type+=' Desktop'

					if [[ "${this_docs_id}" == '8002' || "${this_docs_id}" == '8003' ]]; then
						# "iMac DV (Slot Loading)" and "iMac DV Special Edition (Slot Loading)" are listed as variants of "iMac (Slot Loading)" in the Tech Specs "https://support.apple.com/112301" which "https://support.apple.com/docs/mac/8001" links to.
						# NULL;NULL;NULL;8002;iMac DV (Slot Loading):CJ7:GGE:H90:HAY:HB5:HB6:HB7:HCL:HCM:HCN:HCP:HCQ:HD1:HD2:HD3:HD4:HD6:HD7:HD8:HD9:HDB:HDC:HDD:HDG:HDH:HDK:HFT:HQK:HQL:HQM:HQN:HQP:HSL:HSM:HSN:HSP:HSQ:HSR:HTC:HTD:HTE:HTG:HTT:HTU:HTV:HTW:HTX:HTY:HTZ:HU0:HU1:HU2:HU3:HU4:HU5:HU6:HU7:HU8:HU9:HUA:HUB:HUC:HUO:HVU:HVV:HVW:HVX:HVY:HZ9:J6N:J6P:J6Q:J6S:J6V:J7A:J7B:J7C:J7E:J7F:J7G:J7H:J7J:J7K:J8A:J8B:J8C:J8D:J8E:J8G:J8H:J8J:J8K:J8L:J8M:J8V:J77:J78:J79:J89:JED:JRH:JST:JV3:
						# NULL;NULL;NULL;8003;iMac DV Special Edition (Slot Loading):HCW:HCX:HCY:HD0:HFU:HQS:HTN:HTP:HTQ:HTR:HTS:HVF:HVG:HVZ:HZ8:J0Y:J6T:J8W:JEE:JUX:
						# productcategory;PF1;PL101;8001;iMac (Slot Loading):9HT:G42:HCS:HCV:HEG:HFS:HQJ:HSK:HTH:HTJ:HTK:HTL:HTM:HVE:HVT:HZA:HZN:HZP:HZQ:HZR:J6H:J7D:J7Q:J7R:J7S:J7T:J8F:J74:J88:J90:JEC:JEK:JEL:JEM:JEN:JUR:JVP:YHT:

						this_docs_url_id='8001'
					elif [[ "${this_docs_id}" == '8360' || "${this_docs_id}" == '8361' || "${this_docs_id}" == '8362' ]]; then
						# "iMac DV (Summer 2000)", "iMac DV+ (Summer 2000)", and "iMac DV Special Edition (Summer 2000)" are listed as variants of "iMac (Summer 2000)" in the Tech Specs "https://support.apple.com/112527" which "https://support.apple.com/docs/mac/8359" links to.
						# NULL;NULL;NULL;8360;iMac DV (Summer 2000):JAU:JMP:JMS:JQH:JQZ:JR0:JV5:JV8:JVK:JY6:KAG:KBD:KME:KNV:L2Z:
						# NULL;NULL;NULL;8361;iMac DV+ (Summer 2000):JAV:JMQ:JMT:JQJ:JR2:JR3:JV6:JV9:JVL:JY7:K4L:KAH:KAJ:KQ6:
						# NULL;NULL;NULL;8362;iMac DV Special Edition (Summer 2000):JB0:JMR:JMU:JQK:JR5:JR6:JV7:JVA:JVM:JY5:KAK:
						# productcategory;PF1;PL101;8359;iMac (Summer 2000):JVG:JWQ:JYG:JYH:K2N:K2P:K2Q:K2R:

						this_docs_url_id='8359'
					fi
				elif [[ "${this_docs_pf_id}" == 'PF2' ]]; then
					this_product_type+=' Laptop'

					if [[ "${this_docs_id}" == '124182' ]]; then
						# NULL;NULL;NULL;124182;iBook G4 (14-inch Early 2004):QHU:QHV:R71:R72:RA9:RAM:RAZ:RBA:RCF:RD7:RDH:RE8:RED:REE:REF:REG:RFH:RP2:
						# is a variant of
						# productcategory;PF2;PP212;124181;iBook G4 (Early 2004):QHW:QJP:QJQ:QJS:R9C:R12:R73:R74:RAK:RAL:RAP:RAS:RB8:RB9:RC7:RD8:REZ:RNE:RNG:RNR:RP1:RPN:RPZ:RQ0:RQ1:RQ2:RZR:S02:S03:S3Z:S24:S25:
						# but the latter Docs ID has a Docs page and the former doesn't (and the Tech Specs in the latters Docs ID covers both variations).

						this_docs_url_id='124181'
					fi
				elif [[ "${this_docs_pf_id}" == 'PF6' ]]; then
					this_product_type='macOS'
				else
					this_product_type+=' Server'
					# NOTE: There are no docs pages for server products such as Xserve (such as Config Code "HDE") as well as old Power Mac Server and Mac Pro Server models.
					# But for the Power Mac and Mac Pro we can manually link the Server variants to the Docs pages for their equivalent non-Server variant.

					if [[ "${this_docs_id}" == '7974' ]]; then
						# PF20;PF11;PP211;7974;Power Mac G4 Server:GUH:GUJ:GYA:GYJ:HGD:HGE:HGF:HND:HNE:HNF:J2P:J2Q:J2R:JAR:JAS:JVF:
						# productcategory;PF1;PL103;7955;Power Mac G4 (PCI Graphics):H7D:H7W:H8Y:HEA:HEC:HED:HEK:HFZ:HHC:HHD:HHF:HJ9:HJM:HJN:HJP:HJT:HJU:HK7:HL4:HM0:HM5:HN1:HN2:HN3:HN9:HNA:HV7:
						# productcategory;PF1;PL103;7956;Power Mac G4 (AGP Graphics):DGG:FZC:G5G:G5H:GJE:GJF:H5S:HES:HGU:HHG:HLA:HLK:HLZ:HM1:HNH:HNZ:HP0:HPO:HSE:HSF:HSG:HUV:HV6:J2S:J92:J93:JJ1:JJ2:JMJ:JSC:JUB:JUC:JUL:JY8:JY9:JZG:K1B:K1D:K1E:

						this_docs_url_id='7956' # I'm not sure which Graphics variant the Server models used, but choosing the higher-end one.
					elif [[ "${this_docs_id}" == '8371' ]]; then
						# NULL;NULL;NULL;8371;Power Mac G4 Server (Gigabit):JMV:JMW:JW3:JW4:JYN:K6P:K6R:K6T:K8S:
						# productcategory;PF1;PL103;8355;Power Mac G4 (Gigabit Ethernet):J3B:J3C:J3D:JFN:JFP:JFQ:JNX:JVN:JVQ:K4Z:K5A:K5B:K5C:K5V:K5W:K5X:K5Z:K8H:K8J:K8K:K50:K51:K53:K63:K69:K86:K98:KNW:KNX:KNY:

						this_docs_url_id='8355'
					elif [[ "${this_docs_id}" == '112393' ]]; then
						# NULL;NULL;NULL;112393;Power Mac G4 Server (Digital Audio):K4Y:K6M:K72:K73:K74:KHS:KHT:KHU:L4V:
						# productcategory;PF1;PL103;108892;Power Mac G4 (Digital Audio):HL1:JQF:K6V:K6W:K6X:K6Y:K6Z:K70:KAM:KAN:KAP:KKY:KKZ:KL1:KLT:KPF:KPG:KPH:KPJ:KQA:KVC:KX5:KXQ:KXR:KXS:KYC:KYD:KYE:KYK:KYZ:KZ0:KZ4:L0M:L1Z:L8Z:L65:L81:L86:L90:L91:L92:L95:LBU:LCW:LF6:LOM:LON:

						this_docs_url_id='108892'
					elif [[ "${this_docs_id}" == '111133' ]]; then
						# PF20;PF11;PP211;111133;Power Mac G4 Server (QuickSilver):KVJ:LGY:LGZ:LLH:LLJ:LRC:LRD:M7W:M79:
						# productcategory;PF1;PL103;110334;Power Mac G4 (QuickSilver):KLS:KSD:KSJ:KSK:KSL:L3E:L4Y:L4Z:L6Q:L6R:L8G:L50:L51:L52:L53:LF9:LJQ:LJR:LJS:LUX:LUY:LUZ:M4K:M4L:M5U:M5V:MJG:

						this_docs_url_id='110334'
					elif [[ "${this_docs_id}" == '111999' ]]; then
						# PF20;PF11;PP211;111999;Power Mac G4 Server (QuickSilver 2002):GM8:M33:M34:M35:M36:M58:M59:N43:N44:
						# productcategory;PF1;PL103;111993;Power Mac G4 (QuickSilver 2002):M1X:M1Y:M3B:M8G:M8H:M37:M38:M39:MDC:MDM:MDN:MDP:MJF:MJP:MK3:MK5:MK7:MK8:MK9:MQ8:MQV:MW6:N0N:N7N:N7P:NAD:NAQ:NAR:

						this_docs_url_id='111993'
					elif [[ "${this_docs_id}" == '114153' ]]; then
						# NULL;NULL;NULL;114153;Power Mac Server G4 (Mirrored Drive Doors):M5E:M5L:MBG:MGB:MR7:MR8:MXE:NHD:NMD:
						# productcategory;PF1;PL103;113853;Power Mac G4 (Mirrored Drive Doors):LKB:LKC:MFX:MM7:MM8:MMA:MQ9:MQA:MUM:MXD:MYM:MYT:MYU:MYV:NF4:NFX:NHN:NJ1:NJQ:NKZ:NLP:NLQ:NLR:NLS:NTY:NZM:P93:PA2:PJU:PK0:

						this_docs_url_id='113853'
					elif [[ "${this_docs_id}" == '133158' ]]; then
						# productcategory;PF20;PF11;133158;Mac Pro Server (Mid 2010):HPV:HPW:HPY:
						# productcategory;PF1;PL104;132966;Mac Pro (Mid 2010):EUE:EUF:EUG:EUH:GWR:GY5:GZH:GZJ:GZK:GZL:GZM:H0X:H2N:H2P:H97:H99:HF7:HF8:HF9:HFA:HFC:HFD:HFF:HFG:HFJ:HFK:HFL:HFN:HG1:HG3:HP9:HPA:

						this_docs_url_id='132966'
					elif [[ "${this_docs_id}" == '133645' ]]; then
						# productcategory;PF20;PF11;133645;Mac Pro Server (Mid 2012):F4MF:F4MJ:F501:
						# productcategory;PF1;PL104;133644;Mac Pro (Mid 2012):F4MC:F4MD:F4MG:F4MH:F4YY:F6T9:F6TC:F6TD:F6TF:F6TG:F64C:F64D:F64F:F500:F648:F649:

						this_docs_url_id='133644'
					fi
				fi
			elif [[ "${this_docs_pf_id}" == 'PF3' ]]; then
				this_docs_category='ipod'
				this_product_type='iPod'

				if [[ "${this_docs_id}" == '132939' ]]; then
					# productcategory;PF3;PL109;132939;iPod 15GB w/Dock Cntr (Early 2004):QQF:QQG:
					# is the same as
					# productcategory;PF3;PL109;119100;iPod (15 GB, With Dock Connector):NLU:NLW:P67:PRV:Q4S:
					# but the latter Docs ID has a Docs page and the former doesn't.

					this_docs_url_id='119100'
				elif [[ "${this_docs_id}" == '131142' ]]; then
					# productcategory;PF3;PL109;131142;iPod (5th generation U2 Late 2006):W9G:
					# is techincally the same as
					# productcategory;PF3;PL109;131146;iPod (5th generation Late 2006):V9K:V9L:V9M:V9N:V9P:V9Q:V9R:V9S:WU9:WUA:WUB:WUC:X3N:X82:XNJ:
					# but the latter Docs ID has a Docs page and the former doesn't (and the Tech Specs in the latters Docs ID covers both variations).

					this_docs_url_id='131146'
				elif [[ "${this_docs_id}" == '131652' ]]; then
					# productcategory;PF3;PL111;131652;iPod shuffle (2nd generation Late 2007):1ZH:1ZK:1ZM:1ZP:1ZR:8CQ:
					# is a new colors and larger storage upgrade from
					# productcategory;PF3;PL111;131239;iPod shuffle (2nd generation):VTE:VTF:XQS:XQU:XQV:XQX:XQY:XR0:XR1:XR3:
					# but the latter Docs ID has a Docs page and the former doesn't (and the Tech Specs in the latters Docs ID covers both variations).

					this_docs_url_id='131239'
				fi
			elif [[ "${this_docs_pf_id}" == 'PF5' ]]; then
				this_docs_category='displays'
				this_product_type='Display'

				if [[ "${this_docs_id}" == '131798' ]]; then
					# productcategory;PF8;PF5;131798;Apple Studio Display (17-inch LCD):NNF:
					# is the same as
					# productcategory;PF8;PF5;109732;Apple Studio Display 17 inch LCD:KPW:LB1:LB2:P6L:
					# but the latter Docs ID has a Docs page and the former doesn't.

					this_docs_url_id='109732'
				fi
			elif [[ "${this_docs_pf_id}" == 'PF7' ]]; then
				this_docs_category='accessories'
				this_product_type='AirPort'
			elif [[ "${this_docs_pf_id}" == 'PF8' ]]; then
				this_docs_category='accessories'

				if [[ "${this_docs_pl_id}" == 'PL177' ]]; then
					this_product_type='AirTag'
				else
					this_product_type='Accessory'
				fi
			elif [[ "${this_docs_pf_id}" == 'PF9' ]]; then
				this_docs_category='iphone'
				this_product_type='iPhone'

				if [[ "${this_docs_pl_id}" == 'PL134' ]]; then
					if [[ "${this_docs_pp_id}" == 'PP70' ]]; then
						this_docs_category='airpods'
						this_product_type='AirPods'
					else
						this_product_type+=' Accessory'
					fi
				elif [[ "${this_docs_id}" == '132738' ]]; then
					# NULL;NULL;NULL;132738;iPhone 3G (China Mainland):8L0:
					# is the same as
					# productcategory;PF9;PL133;132035;iPhone 3G:1R4:Y7H:Y7K:
					# but the latter Docs ID has a Docs page and the former doesn't.

					this_docs_url_id='132035'
				fi
			elif [[ "${this_docs_pf_id}" == 'PF10' ]]; then
				this_docs_category='apple-tv'
				this_product_type='Apple TV'

				if [[ "${this_docs_id}" == '133942' ]]; then
					# NULL;productcategory;PF10;133942;Apple TV (3rd generation):FF54:
					# is the same as
					# NULL;productcategory;PF10;133607;Apple TV (3rd generation):DRHN:
					# but the latter Docs ID has a Docs page and the former doesn't.

					this_docs_url_id='133607'
				fi
			elif [[ "${this_docs_pf_id}" == 'PF12' || "${this_docs_pf_id}" == 'PF13' || "${this_docs_pf_id}" == 'PF14' || "${this_docs_pf_id}" == 'PF16' ]]; then
				if [[ "${this_marketing_model_name}" == *'Mac OS X'* ]]; then
					this_docs_category='mac'
					this_product_type='macOS'
				else
					this_docs_category='software'
					this_product_type='Software'
				fi
			elif [[ "${this_docs_pf_id}" == 'PF22' ]]; then
				this_docs_category='ipad'
				this_product_type='iPad'

				if [[ "${this_docs_pl_id}" == 'PL221' ]]; then
					this_product_type+=' Accessory'

					if [[ "${this_docs_id}" == '300111' ]]; then
						this_docs_url_id='pp125' # Can see on "https://support.apple.com/docs/ipad" that the Docs ID for "PF22;PL221;3001111;300111;Apple Pencil (2nd generation):JKM9:" is actually "pp125" even though there is no PP ID in the info from the Specs API.
					fi
				fi
			elif [[ "${this_docs_pf_id}" == 'PF27' ]]; then
				this_docs_category='accessories' # NOTE: There are no Docs pages for Beats products, except for the 2024 Beats Pill which is listed under accessories (but the 2024 Beats Pill has a new 10 character randomized serial instead of an old one with a Config Code that would be caught here).
				this_product_type='Beats'
			elif [[ "${this_docs_pf_id}" == 'PF28' ]]; then
				this_docs_category='watch'
				this_product_type='Apple Watch'
			elif [[ "${this_docs_pf_id}" == 'PF34' ]]; then
				this_docs_category='homepod'
				this_product_type='HomePod'
			elif [[ "${this_docs_pf_id}" == 'PF36' ]]; then
				this_docs_category='vision'
				this_product_type='Apple Vision'
			fi

			if [[ "${this_product_type}" == 'UNKNOWN' ]]; then
				>&2 echo "DEBUG:UNKNOWN-PRODUCT-TYPE-${this_docs_pf_id}>${this_docs_pl_id}>${this_docs_pp_id}>${this_docs_id}>${this_docs_url_id}:${this_marketing_model_name}:${these_config_codes%:}:"
			fi

			if [[ "${this_docs_category}" == 'unknown' ]]; then
				>&2 echo "DEBUG:UNKNOWN-DOCS-CATEGORY-${this_docs_pf_id}>${this_docs_pl_id}>${this_docs_pp_id}>${this_docs_id}>${this_docs_url_id}:${this_marketing_model_name}:${these_config_codes%:}:"
			fi

			if [[ "${this_docs_url_id}" == 'unknown' ]]; then
				>&2 echo "DEBUG:UNKNOWN-DOCS-URL-ID-${this_docs_pf_id}>${this_docs_pl_id}>${this_docs_pp_id}>${this_docs_id}>${this_docs_url_id}:${this_marketing_model_name}:${these_config_codes%:}:"
			fi

			this_specs_url_id=''
			if [[ "${this_docs_category}" != 'unknown' ]]; then
				found_valid_docs_url=false
				for this_possible_docs_url_id in "${this_docs_url_id}" "$(printf '%s' "${this_docs_pl_id}" | tr '[:upper:]' '[:lower:]')"; do
					if [[ -n "${this_possible_docs_url_id}" ]]; then
						# Some Software and iPhone/iPad/iPod Accessories may use PL ID, so check and use if Docs ID doesn't have a valid Docs page.
						# Also, some Apple Watch Docs IDs don't have Tech Specs links, but there may be Tech Specs associated with the PL ID for all the variants of a whole generation (as they are listed on "https://support.apple.com/docs/watch").

						this_docs_page_source="$(curl -m 10 --retry 3 -sf "https://support.apple.com/en-us/docs/${this_docs_category}/${this_possible_docs_url_id}")" # DO NOT FOLLOW REDIRECTS to catch invalid Docs URLs more easily since they would redirect to the category URL.
						curl_exit_code="$?"

						if [[ "${curl_exit_code}" == '0' && -n "${this_docs_page_source}" ]]; then # Docs page source would be empty if not valid URL that would be redirected to the Docs category page.
							this_specs_url="$(echo "${this_docs_page_source}" | xmllint --html --xpath 'string(//a[text()="Tech Specs"]/@href)' - 2> /dev/null)"
							this_specs_url_id="${this_specs_url##*/}"

							if ! $found_valid_docs_url; then
								found_valid_docs_url=true

								if [[ "${this_docs_url_id}" != "${this_possible_docs_url_id}" ]]; then # Do not change Docs URL if already found a valid one without Tech Specs (since subsequent ones may be less specific and still not have Tech Specs), but kept checking for Tech Specs in PL ID.
									>&2 echo "DEBUG:CHANGED-DOCS-ID-TO-FIRST-VALID:${this_docs_category}/${this_docs_url_id}>${this_possible_docs_url_id}:${this_specs_url_id}:${this_marketing_model_name}"
									this_docs_url_id="${this_possible_docs_url_id}"
								fi
							fi

							if [[ -n "${this_specs_url_id}" ]]; then
								if [[ "${this_docs_url_id}" != "${this_possible_docs_url_id}" ]]; then # But if a Docs URL was found Tech Specs, always use it as the Docs ID.
									>&2 echo "DEBUG:CHANGED-DOCS-ID-TO-PAGE-WITH-TECH-SPECS:${this_docs_category}/${this_docs_url_id}>${this_possible_docs_url_id}:${this_specs_url_id}:${this_marketing_model_name}"
									this_docs_url_id="${this_possible_docs_url_id}"
								fi

								break
							fi
						fi
					fi
				done

				if [[ -z "${this_specs_url_id}" ]]; then
					# There are not Docs pages for some old models (either they don't have Docs IDs, or their Docs IDs aren't valid),
					# but by searching "https://support.apple.com/kb/index?page=search&q=MODEL_NAME&includeArchived=true&locale=en_US",
					# I was able to find some old Tech Specs URLs that can be manually associated.

					if [[ "${this_marketing_model_name}" == 'Power Mac G3 Minitower' ]]; then
						# UNKNOWN;UNKNOWN;UNKNOWN;UNKNOWN;Power Mac G3 Minitower:BNN:C9A:CAP:CCD:CG9:CME:CPW:

						this_specs_url_id='112045'
					elif [[ "${this_marketing_model_name}" == 'Power Mac G3 Desktop' ]]; then
						# UNKNOWN;UNKNOWN;UNKNOWN;UNKNOWN;Power Mac G3 Desktop:AK8:ESQ:

						this_specs_url_id='112279'
					elif [[ "${this_marketing_model_name}" == 'iMac' ]]; then
						# UNKNOWN;UNKNOWN;UNKNOWN;UNKNOWN;iMac:DFN:

						this_specs_url_id='112281'
					elif [[ "${this_marketing_model_name}" == 'iMac (266 MHz)' ]]; then
						# UNKNOWN;UNKNOWN;UNKNOWN;UNKNOWN;iMac (266 MHz):FMY:G2S:

						this_specs_url_id='112288'
					elif [[ "${this_marketing_model_name}" == 'iMac (333 GHz)' ]]; then
						# UNKNOWN;UNKNOWN;UNKNOWN;UNKNOWN;iMac (333 GHz):GSN:

						this_marketing_model_name='iMac (333 MHz)' # Also correct "GHz" to "MHz"
						this_specs_url_id='112286'
					elif [[ "${this_marketing_model_name}" == 'PowerBook G3 Series (Bronze Keyboard)' ]]; then
						# UNKNOWN;UNKNOWN;UNKNOWN;UNKNOWN;PowerBook G3 Series (Bronze Keyboard):FZY:G00:

						this_specs_url_id='112180'
					elif [[ "${this_marketing_model_name}" == 'PowerBook (FireWire)' ]]; then
						# UNKNOWN;UNKNOWN;UNKNOWN;UNKNOWN;PowerBook (FireWire):HDR:HDS:HKE:HZG:HZH:HZJ:HZK:HZL:HZM:JPR:JYY:K4R:K6J:K34:K35:K45:

						this_specs_url_id='112178'
					elif [[ "${this_marketing_model_name}" == 'iBook (Firewire)' || "${this_docs_id}" == '8258' ]]; then
						# UNKNOWN;UNKNOWN;UNKNOWN;UNKNOWN;iBook (Firewire):JQ5:JU6:K1L:K5M:KT2:KT3:KT8:KWT:KWV:
						# NULL;NULL;NULL;8258;iBook Special Edition:HZS:J52:

						this_specs_url_id='112550' # "iBook Special Edition" is listed as an option in the same Tech Specs as "iBook (FireWire)"
					elif [[ "${this_docs_id}" == '113053' ]]; then
						# PF20;PF11;PL136;113053;Xserve:LZD:LZE:LZF:MVN:MVP:N7Q:N7R:N7S:N9Z:N45:NA5:NA6:ND1:ND2:NJN:NJV:NMN:NUT:NZF:

						this_specs_url_id='112315'
					elif [[ "${this_docs_id}" == '117960' || "${this_docs_id}" == '118967' ]]; then
						# PF20;PF11;PL136;117960;Xserve (Slot Load):N9A:N9B:N9C:NP2:P1W:P1X:P1Y:PBR:PDT:PM7:PVY:PVZ:PW0:Q5S:Q6L:Q6M:Q9T:QHC:QHD:QHE:QHF:QQ9:RQ7:RQ8:
						# NULL;NULL;NULL;118967;Xserve (Cluster Node):P1U:P3J:P06:PWO:Q6N:
						# The "Xserve (Cluster Node)" is a variant that is listed in this same Tech Specs URL.

						this_specs_url_id='112465'
					elif [[ "${this_docs_id}" == '123485' || "${this_docs_id}" == '130268' ]]; then
						# PF20;PF11;PL136;123485;Xserve G5:PMX:PMY:PMZ:PNH:PNJ:PNK:QPW:QPX:QPY:QTU:QTV:QTW:QV2:QW6:QWG:QWH:QWJ:QWK:R5B:R5C:R5D:R62:R63:R64:R65:RB3:RB4:RB5:RDM:RET:REU:RF8:RHQ:RJC:RJD:RJE:RXV:RXX:RXY:RXZ:RY2:S4V:S4W:S4X:S8Y:S8Z:S26:S90:S93:S94:S95:SC2:SK6:SP0:SP1:
						# productcategory;PF20;PF11;130268;Xserve G5 (January 2005):RTP:RTQ:RTS:SLW:SLX:SLZ:SQW:SQX:SQY:SR0:SR1:SR2:SR8:SR9:SST:SV8:SV9:SVA:T1G:T3U:T8Q:T8R:T8S:TGG:TGH:TGJ:TRU:TS1:TXF:TXG:TXH:TXX:U3B:U75:U76:U77:UMB:UME:UMF:UMG:UQL:URS:UW0:UX4:UX5:V1Q:VJQ:VSA:VSC:VSK:VSS:W0W:W5U:W6F:WD1:WD2:WD3:WDE:WJ0:X2C:

						this_specs_url_id='112318' # This is the Tech Specs for "Xserve G5" which I'm not certain is the completely same as "Xserve G5 (January 2005)" but I can't find specific Tech Specs for the latter.
					elif [[ "${this_docs_id}" == '117972' ]]; then
						# productcategory;PF20;PF11;117972;Xserve RAID:M8K:M8L:M8M:M98:NBL:NBM:NBN:QFB:

						this_specs_url_id='112486'
					elif [[ "${this_docs_id}" == '122619' || "${this_docs_id}" == '130243' ]]; then
						# productcategory;PF20;PF11;122619;Xserve RAID (SFP):PQD:PQE:PQF:PQG:Q7D:QCU:QCV:QCW:QCX:QWN:RXW:S53:S54:S55:
						# productcategory;PF20;PF11;130243;Xserve RAID (SFP Late 2004):RS4:RS5:RS6:SAA:SAB:SAH:SJ3:SJ4:SJ5:SP2:TYD:U3G:U3H:U3J:U3K:UAG:UAH:UKN:UKP:Y0T:Y0U:YY6:

						this_specs_url_id='112314' # This is the Tech Specs for "Xserve RAID (SFP)" which I'm not certain is the completely same as "Xserve RAID (SFP Late 2004)" but I can't find specific Tech Specs for the latter.
					elif [[ "${this_docs_id}" == '131089' ]]; then
						# productcategory;PF20;PF11;131089;Xserve (Late 2006):00W:V2M:V2Q:WXM:X83:X84:XAW:XBF:XBG:XBR:XBS:XBT:XLR:XXC:XXD:XXE:XXF:Y8S:YWF:YZ8:YZ9:Z2F:

						this_specs_url_id='112534'
					elif [[ "${this_docs_id}" == '131817' ]]; then
						# productcategory;PF20;PF11;131817;Xserve (Early 2008):1DR:1H4:1ZZ:3GM:3GN:5WD:5WE:6EM:12E:20A:24B:25N:27P:31G:32A:X8S:X8T:

						this_specs_url_id='112551'
					elif [[ "${this_docs_id}" == '132435' ]]; then
						# productcategory;PF20;PF11;132435;Xserve (Early 2009):6HS:8DE:8M3:9N0:9SS:9ST:9VJ:9WM:9ZL:9ZP:9ZQ:10J:10S:A2U:A2V:A6Z:A70:AFS:AFT:AFU:AFV:BR7:CRZ:CS0:D5G:DFT:DFU:DL5:GQU:HDE:

						this_specs_url_id='112625' # This is the Tech Specs for "Xserve (2009)" which I'm not certain is the completely same as "Xserve (Early 2009)" but I can't find specific Tech Specs for the latter.
					elif [[ "${this_docs_id}" == '132589' ]]; then
						# productcategory;PF14;PL198;132589;Final Cut Server 1.5:85A:85B:

						this_specs_url_id='112646'
					elif [[ "${this_docs_id}" == '132588' ]]; then
						# productcategory;PF14;PL199;132588;Final Cut Studio (2009):36X:37A:373:

						this_specs_url_id='112300'
					elif [[ "${this_docs_id}" == '131100' ]]; then
						# productcategory;PF20;PF16;131100;Apple Remote Desktop 3.X:0TP:0TQ:8KW:8KY:U6M:U6N:U6P:

						this_specs_url_id='112426'
					elif [[ "${this_marketing_model_name}" == 'Logic Studio (2009)' ]]; then
						# UNKNOWN;UNKNOWN;UNKNOWN;UNKNOWN;Logic Studio (2009):41H:41K:41L:41M:

						this_specs_url_id='112602'
					fi

					if [[ -z "${this_specs_url_id}" ]]; then
						# The following Docs IDs are for model variants which have valid Docs pages, but which don't list a Tech Specs link.
						# So, I manually found the base (or closest) variant and manually specified the the Specs ID from that (while keeping the original Docs ID).

						if [[ "${this_docs_id}" == '119102' || "${this_docs_id}" == '119103' || "${this_docs_id}" == '120701' || "${this_docs_id}" == '119104' || "${this_docs_id}" == '120702' ]]; then
							# productcategory;PF3;PL109;119102;iPod (10 GB, With Dock Connector, Personalized):NRK:PQ4:
							# productcategory;PF3;PL109;119099;iPod (10 GB, With Dock Connector):NRH:P66:Q4R:
							# iPod:ipod/119099:112515:iPod (10 GB, With Dock Connector):NRH:P66:Q4R:

							# productcategory;PF3;PL109;119103;iPod (15 GB, With Dock Connector, Personalized):NM6:
							# productcategory;PF3;PL109;119100;iPod (15 GB, With Dock Connector):NLU:NLW:P67:PRV:Q4S:
							# iPod:ipod/119100:112515:iPod (15 GB, With Dock Connector):NLU:NLW:P67:PRV:Q4S:
							
							# productcategory;PF3;PL109;120701;iPod (20 GB with Dock Connector, Personalized):PQ5:
							# productcategory;PF3;PL109;120699;iPod (20 GB with Dock Connector):PNT:QC8:
							# iPod:ipod/120699:112515:iPod (20 GB with Dock Connector):PNT:QC8:
							
							# productcategory;PF3;PL109;119104;iPod (30 GB, With Dock Connector, Personalized):NM7:
							# productcategory;PF3;PL109;119101;iPod (30 GB, With Dock Connector):NLY:P68:Q4T:
							# iPod:ipod/119101:112515:iPod (30 GB, With Dock Connector):NLY:P68:Q4T:
							
							# productcategory;PF3;PL109;120702;iPod (40 GB with Dock Connector, Personalized):PQ6:
							# productcategory;PF3;PL109;120700;iPod (40 GB with Dock Connector):PNU:
							# iPod:ipod/120700:112515:iPod (40 GB with Dock Connector):PNU:

							this_specs_url_id='112515'
						elif [[ "${this_docs_id}" == '130186' ]]; then
							# productcategory;PF3;PL109;130186;iPod U2 Special Edition (20 GB):S2X:
							# productcategory;PF3;PL109;130003;iPod (Click Wheel):PQ7:PS9:Q8U:Q8V:RFF:RFG:RFM:RFN:RUW:
							# iPod:ipod/130003:112541:iPod (Click Wheel):PQ7:PS9:Q8U:Q8V:RFF:RFG:RFM:RFN:RUW:

							this_specs_url_id='112541'
						elif [[ "${this_docs_id}" == '130668' ]]; then
							# productcategory;PF3;PL109;130668;iPod with color display Harry Potter (20GB):U5H:
							# productcategory;PF3;PL109;130602;iPod with color display:TDS:TDU:TM2:TYG:
							# iPod:ipod/130602:112539:iPod with color display:TDS:TDU:TM2:TYG:

							this_specs_url_id='112539'
						elif [[ "${this_docs_id}" == '131013' ]]; then
							# productcategory;PF3;PL109;131013;iPod (5th generation U2):V9V:WEM:
							# productcategory;PF3;PL109;130710;iPod (5th generation):SZ9:SZA:SZT:SZU:TXK:TXL:TXM:TXN:U99:V6C:VHQ:VUP:WEC:WED:WEE:WEF:WEG:WEH:WEJ:WEK:
							# iPod:ipod/130710:111923:iPod (5th generation):SZ9:SZA:SZT:SZU:TXK:TXL:TXM:TXN:U99:V6C:VHQ:VUP:WEC:WED:WEE:WEF:WEG:WEH:WEJ:WEK:

							this_specs_url_id='111923'
						elif [[ "${this_docs_id}" == '133467' ]]; then
							# productcategory;PF3;PL113;133467;iPod touch (4th generation):DNQW:DNQY:DNR0:DT75:DT77:DT78:F96T:F96V:
							# productcategory;PF3;PL113;133019;iPod touch (4th generation):DCP7:DCP9:DCPC:
							# iPod:ipod/133019:112431:iPod touch (4th generation):DCP7:DCP9:DCPC:

							this_specs_url_id='112431'
						elif [[ "${this_docs_id}" == '133776' ]]; then
							# productcategory;PF3;PL111;133776;iPod shuffle (4th generation, Late 2012):F4RT:F4RV:F4RW:F4RY:F4T0:F4T1:F4VF:F4VG:FJDH:
							# productcategory;PF3;PL111;133017;iPod shuffle (4th generation):DCMJ:DCMK:DFDM:DFDN:DFDP:
							# iPod:ipod/133017:112422:iPod shuffle (4th generation):DCMJ:DCMK:DFDM:DFDN:DFDP:

							this_specs_url_id='112422'
						elif [[ "${this_docs_id}" == '300357' ]]; then
							# productcategory;PF8;PL177;300357;AirTag Hermès:PX9C:
							# productcategory;PF8;PL177;300356;AirTag:1NCJ:2DD2:2FK6:25W5:P0GV:
							# AirTags:accessories/300356:111847:AirTag:1NCJ:2DD2:2FK6:25W5:P0GV:

							this_specs_url_id='111847'
						elif [[ "${this_docs_id}" == '300005' || "${this_docs_id}" == '300006' ]]; then
							# productcategory;PF28;PL284;300005;Apple Watch 38mm Hermès (1st gen):GR7R:
							# productcategory;PF28;PL281;135278;Apple Watch 38mm Stainless Steel (1st gen):G9HM:G9HN:
							# Apple Watch:watch/135278:112009:Apple Watch 38mm Stainless Steel (1st gen):G9HM:G9HN:

							# productcategory;PF28;PL284;300006;Apple Watch 42mm Hermès (1st gen):GR81:
							# productcategory;PF28;PL281;135281;Apple Watch 42mm Stainless Steel (1st gen):G9J8:G9JC:
							# Apple Watch:watch/135281:112009:Apple Watch 42mm Stainless Steel (1st gen):G9J8:G9JC:

							this_specs_url_id='112009'
						elif [[ "${this_docs_id}" == '132932' || "${this_docs_id}" == '132740' ]]; then
							# productcategory;PF9;PL133;132932;iPhone 3GS (8GB):EDG:
							# productcategory;PF9;PL133;132740;iPhone 3GS (China Mainland):8M7:8M8:8M9:8MB:
							# productcategory;PF9;PL133;132537;iPhone 3GS:3NP:3NQ:3NR:3NS:
							# iPhone:iphone/132537:112307:iPhone 3GS:3NP:3NQ:3NR:3NS:

							this_specs_url_id='112307'
						elif [[ "${this_docs_id}" == '133466' || "${this_docs_id}" == '133477' ]]; then
							# productcategory;PF9;PL133;133466;iPhone 4 CDMA (8GB):DP0V:DPNG:
							# productcategory;PF9;PL133;133177;iPhone 4 (CDMA):DDP7:DDP8:DDP9:DDPC:
							# iPhone:iphone/133177:112562:iPhone 4 (CDMA):DDP7:DDP8:DDP9:DDPC:

							# productcategory;PF9;PL133;133477;iPhone 4 (8GB):DP0N:DPMW:
							# productcategory;PF9;PL133;132927;iPhone 4:A4S:A4T:DZZ:E00:
							# iPhone:iphone/132927:112562:iPhone 4:A4S:A4T:DZZ:E00:

							this_specs_url_id='112562'
						elif [[ "${this_docs_id}" == '134093' ]]; then
							# productcategory;PF9;PL133;134093;iPhone 4s (8GB):FML3:FML4:FML5:FML6:FML7:FML8:FML9:FMLC:FMLD:FMLF:
							# productcategory;PF9;PL133;133476;iPhone 4S:DT9V:DT9Y:DTC0:DTC1:DTD0:DTD1:DTD2:DTD3:DTD5:DTD6:DTD7:DTD8:DTDC:DTDD:DTDF:DTDG:DTDK:DTDL:DTDM:DTDN:DTDR:DTDT:DTDV:DTDW:DTF9:DTFC:DTFD:DTFF:DTFG:DTFH:
							# iPhone:iphone/133476:112004:iPhone 4S:DT9V:DT9Y:DTC0:DTC1:DTD0:DTD1:DTD2:DTD3:DTD5:DTD6:DTD7:DTD8:DTDC:DTDD:DTDF:DTDG:DTDK:DTDL:DTDM:DTDN:DTDR:DTDT:DTDV:DTDW:DTF9:DTFC:DTFD:DTFF:DTFG:DTFH:

							this_specs_url_id='112004'
						elif [[ "${this_docs_id}" == '133779' ]]; then
							# productcategory;PF9;PL133;133779;iPhone 5 (GSM, CDMA):DTWD:DTWF:DTWG:DTWH:F8GH:F8GJ:F8GK:F8GL:F8GM:F8GN:F8H2:F8H4:F8H5:F8H6:F8H7:F8H8:F39C:F39D:
							# productcategory;PF9;PL133;133778;iPhone 5:DTTN:DTTP:DTTQ:DTTR:F38W:F38Y:FH1C:FH1D:FH1F:FH1G:FH1H:FH19:
							# iPhone:iphone/133778:112016:iPhone 5:DTTN:DTTP:DTTQ:DTTR:F38W:F38Y:FH1C:FH1D:FH1F:FH1G:FH1H:FH19:

							this_specs_url_id='112016'
						elif [[ "${this_docs_id}" == '134095' || "${this_docs_id}" == '134505' ]]; then
							# productcategory;PF9;PL133;134095;iPhone 5c:FFT5:FFT6:FFT7:FFTM:FFTN:FL01:FL02:FL03:FL04:FL05:FLFL:FLFM:FLFN:FLFP:FLFT:FLFV:FLFW:FLFY:FLG0:FLG2:FQ0Y:FQ10:FQ11:FQ12:FQ13:FQ14:FQ15:FQ16:FQ17:FQ18:FR8F:FR8G:FR8H:FR8J:FR8M:FR8N:FR8P:FR8Q:FR8R:FR8T:FR8V:FR8W:FR8Y:FR90:FR91:FR92:FR93:FR94:FR95:FR96:
							# productcategory;PF9;PL133;134505;iPhone 5c (8GB):FYW8:FYW9:FYWC:FYWD:FYWF:FYWM:FYWN:FYWP:FYWQ:FYWR:FYY1:FYY2:FYY3:FYY4:FYY5:FYYD:FYYF:FYYG:FYYH:FYYJ:G07P:G07Q:G07R:G07T:G07V:
							# productcategory;PF9;PL133;134094;iPhone 5c:FFHG:FFHH:FFHJ:FFHK:FFHL:FFHM:FFHN:FFHP:FFHQ:FFHR:FM1N:FM1P:FM1Q:FM1R:FM1T:FM1V:FM1W:FM1Y:FM20:FM21:FNDD:FNDF:FNDG:FNDH:FNDJ:FNDK:FNDL:FNDM:FNDN:FNDP:FNLQ:FNLR:FNLT:FNLV:FNLW:FNLY:FNM0:FNM1:FNM2:FNM3:
							# iPhone:iphone/134094:111917:iPhone 5c:FFHG:FFHH:FFHJ:FFHK:FFHL:FFHM:FFHN:FFHP:FFHQ:FFHR:FM1N:FM1P:FM1Q:FM1R:FM1T:FM1V:FM1W:FM1Y:FM20:FM21:FNDD:FNDF:FNDG:FNDH:FNDJ:FNDK:FNDL:FNDM:FNDN:FNDP:FNLQ:FNLR:FNLT:FNLV:FNLW:FNLY:FNM0:FNM1:FNM2:FNM3:

							this_specs_url_id='111917'
						elif [[ "${this_docs_id}" == '134338' ]]; then
							# productcategory;PF22;PL220;134338;iPad mini Wi-Fi:FP84:
							# productcategory;PF22;PL220;133849;iPad mini:F193:F194:F195:F196:F197:F198:F637:F638:
							# iPad:ipad/133849:111978:iPad mini:F193:F194:F195:F196:F197:F198:F637:F638:

							this_specs_url_id='111978'
						elif [[ "${this_docs_id}" == '135092' ]]; then
							# productcategory;PF22;PL250;135092;iPad mini 3 Wi-Fi Cellular (China Mainland):G5TG:G5TH:G5TJ:G5TK:G5TL:G5TM:G5TN:G5TP:G5TQ:
							# productcategory;PF22;PL250;135091;iPad mini 3 Wi-Fi + Cellular:G5W8:G5Y1:G5Y2:G5Y3:G5Y4:G5Y5:G5YH:G5YJ:G5YK:
							# iPad:ipad/135091:112018:iPad mini 3 Wi-Fi + Cellular:G5W8:G5Y1:G5Y2:G5Y3:G5Y4:G5Y5:G5YH:G5YJ:G5YK:

							this_specs_url_id='112018'
						elif [[ "${this_docs_id}" == '300201' ]]; then
							# productcategory;PF22;PL250;300201;iPad (8th generation) Wi-Fi + Cellular:Q1KM:Q1KN:Q1KP:Q1KQ:Q1KR:Q1KT:Q1KV:Q1KW:Q1KX:Q1KY:Q1L0:Q1L1:Q1L2:Q1L3:Q1L4:Q1L5:Q1L6:Q1L7:
							# productcategory;PF22;PL220;300200;iPad (8th generation):Q1GC:Q1GD:Q1GF:Q1GG:Q1GH:Q1GJ:
							# iPad:ipad/300200:118451:iPad (8th generation):Q1GC:Q1GD:Q1GF:Q1GG:Q1GH:Q1GJ:

							this_specs_url_id='118451'
						elif [[ "${this_docs_id}" == '300203' ]]; then
							# productcategory;PF22;PL250;300203;iPad Air (4th generation) Wi-Fi + Cellular:Q1C0:Q1C1:Q19C:Q19D:Q19F:Q19G:Q19H:Q19J:Q19K:Q19L:Q19M:Q19N:Q19P:Q19Q:Q19R:Q19T:Q19V:Q19W:Q19X:Q19Y:Q190:Q191:Q192:Q193:Q194:Q195:Q196:Q197:Q198:Q199:
							# productcategory;PF22;PL220;300202;iPad Air (4th generation):Q16M:Q16N:Q16P:Q16Q:Q16R:Q16T:Q16V:Q16W:Q16X:Q16Y:
							# iPad:ipad/300202:111905:iPad Air (4th generation):Q16M:Q16N:Q16P:Q16Q:Q16R:Q16T:Q16V:Q16W:Q16X:Q16Y:

							this_specs_url_id='111905'
						elif [[ "${this_docs_id}" == '300347' || "${this_docs_id}" == '300348' ]]; then
							# productcategory;PF22;PL250;300347;iPad Pro, 11-inch (3rd generation) Cellular sub6/mmW:0FJX:0FJY:0FK0:0FK1:0FK2:0FK3:0FK4:0FK6:0FK7:0FK8:
							# productcategory;PF22;PL250;300348;iPad Pro, 11-inch (3rd generation) Cellular sub6:0FHL:0FHM:0FHN:0FHP:0FHQ:0FHR:0FHT:0FHV:0FHW:0FHX:0FHY:0FJ0:0FJ1:0FJ2:0FJ3:0FJ4:0FJ5:0FJ6:0FJ7:0FJ8:
							# productcategory;PF22;PL220;300346;iPad Pro, 11-inch (3rd generation):0FGW:0FGX:0FGY:0FH0:0FH1:0FH2:0FH3:0FH4:0FH5:0FH6:
							# iPad:ipad/300346:111897:iPad Pro, 11-inch (3rd generation):0FGW:0FGX:0FGY:0FH0:0FH1:0FH2:0FH3:0FH4:0FH5:0FH6:

							this_specs_url_id='111897'
						elif [[ "${this_docs_id}" == '300350' || "${this_docs_id}" == '300351' ]]; then
							# productcategory;PF22;PL250;300350;iPad Pro, 12.9-inch (5th generation) Cellular sub6/mmW:0FMH:0FMJ:0FMK:0FMM:0FMN:0FMP:0FMQ:0FMR:0FMT:0FMV:
							# productcategory;PF22;PL250;300351;iPad Pro, 12.9-inch (5th generation) Cellular sub6:0FFX:0FFY:0FG0:0FG1:0FG2:0FG3:0FG4:0FG6:0FG7:0FG8:0FG9:0FGC:0FGD:0FGF:0FGG:0FGH:0FGJ:0FGK:0FGL:0FGM:
							# productcategory;PF22;PL220;300349;iPad Pro, 12.9-inch (5th generation):0FM2:0FM3:0FM4:0FM5:0FM6:0FM7:0FM8:0FM9:0FMC:0FMD:
							# iPad:ipad/300349:111896:iPad Pro, 12.9-inch (5th generation):0FM2:0FM3:0FM4:0FM5:0FM6:0FM7:0FM8:0FM9:0FMC:0FMD:

							this_specs_url_id='111896'
						elif [[ "${this_docs_id}" == '300009' ]]; then
							# productcategory;PF1;PL101;300009;iMac (21.5-inch, Late 2015):GG7D:GG7G:GG77:GG79:H0P6:H1F1:H1F2:H1WR:H2KW:H8KX:H25M:HQ9T:HQ9V:HYGQ:J0DH:J0DJ:
							# productcategory;PF1;PL101;300010;iMac (21.5-inch, Late 2015):GF1J:GF1K:GF1L:GF1M:H0N6:H1DX:H1DY:HHMG:HQ9W:J0DG:
							# Mac Desktop:mac/300010:112036:iMac (21.5-inch, Late 2015):GF1J:GF1K:GF1L:GF1M:H0N6:H1DX:H1DY:HHMG:HQ9W:J0DG:

							this_specs_url_id='112036'
						elif [[ "${this_docs_id}" == '131484' || "${this_docs_id}" == '131485' ]]; then
							# NOTE: This one is not a variant like the changes above.
							# This model of MacBook Pro has a valid Docs URL which doesn't have Tech Specs link.
							# But, from examining the listings on "https://support.apple.com/docs/mac" I found the following URLs of PP IDs which
							# are for this model MacBook Pro and have Tech Specs links, but these specific PP IDs are not in the Docs IDs from the Specs API,
							# so I have to manually set the Tech Specs ID instead of being able to locate it programmatically.
							# I decided not to make this adjustment by setting the "this_docs_url_id" these PP IDs above since the original Docs IDs do go to valid Docs pages.

							# productcategory;PF2;PL107;131484;MacBook Pro (15-inch, 2.4 2.2GHz):0LQ:0LZ:0M0:0PA:0S3:0S6:1CY:1CZ:2QU:2QV:02V:X91:X92:XAG:XAH:Y9S:Y9T:YAL:YAM:YKX:YKY:YKZ:YL0:YQ3:YW5:YW9:YWA:YWD:YYV:YYX:YZ0:Z0G:Z05:Z09:
							# https://support.apple.com/docs/mac/pp213
							# https://support.apple.com/112519

							# productcategory;PF2;PL107;131485;MacBook Pro (17-inch, 2.4GHZ):0LR:0ND:0NM:0PD:1CW:1CX:1MF:1MG:02D:2QW:09R:09S:027:028:X94:XA9:YAA:YAN:YAP:YNQ:YNS:YNW:YQ4:YQ5:YR2:YRD:YRE:YRF:YWB:YWC:YZ1:YZ2:Z5M:
							# https://support.apple.com/docs/mac/pp215
							# https://support.apple.com/112519

							# There are also listings for "Mid 2007" (the link above are for "Late 2007"), but the Order Numbers are all the same in both Tech Specs pages.
							# https://support.apple.com/docs/mac/pp214
							# https://support.apple.com/112453

							# https://support.apple.com/docs/mac/pp216
							# https://support.apple.com/112453

							this_specs_url_id='112519'
						else
							open_urls_for_research=false # true for DEBUG

							if [[ "${this_docs_category}" == 'accessories' || "${this_product_type}" == *' Accessory' || "${this_docs_category}" == 'software' || "${this_product_type}" == 'macOS' ]]; then
								open_urls_for_research=false
							fi

							if ! $found_valid_docs_url; then
								>&2 echo "DEBUG:INVALID-DOCS-URL-${this_docs_pf_id}>${this_docs_pl_id}>${this_docs_pp_id}>${this_docs_id}>${this_docs_url_id}:${this_marketing_model_name}:${these_config_codes%:}:"
							else
								this_docs_url="https://support.apple.com/docs/${this_docs_category}/${this_docs_url_id}"
								>&2 echo "DEBUG:NO-SPECS-URL-FOR-VALID-DOCS-URL:${this_docs_url}:${this_marketing_model_name}:${these_config_codes%:}:"

								if $open_urls_for_research; then
									open "${this_docs_url}"
								fi
							fi

							if $open_urls_for_research; then
								open "https://support.apple.com/kb/index?page=search&q=$(printf '%s' "\"${this_marketing_model_name}\"" | jq -sRr '@uri')&includeArchived=true&locale=en_US" # https://stackoverflow.com/a/34407620
							else
								>&2 echo "DEBUG:NOT-OPENING-URL-FOR-RESEARCH:${this_marketing_model_name}"
							fi
						fi
					fi
				fi
			fi

			if [[ -z "${this_specs_url_id}" ]]; then
				>&2 echo "DEBUG:UNKNOWN-SPECS-ID-${this_docs_pf_id}>${this_docs_pl_id}>${this_docs_pp_id}>${this_docs_id}>${this_docs_url_id}:${this_marketing_model_name}:${these_config_codes%:}:"
			fi

			every_marketing_model_name_and_docs_url_with_grouped_serial_config_codes+=$'\n'"${this_product_type};${this_docs_category}/${this_docs_url_id};${this_specs_url_id:-unknown};${this_marketing_model_name}:${these_config_codes%:}:"
		done < "${every_marketing_model_name_with_grouped_serial_config_codes_file_path}"

		echo "${every_marketing_model_name_and_docs_url_with_grouped_serial_config_codes}" | sort -fV | grep '.' > "${every_marketing_model_name_and_docs_url_with_grouped_serial_config_codes_file_path}"
		>&2 echo "TIMESTAMP:END-MODEL-GROUPED-WITH-DOCS-URL-FILE-OUTPUT:$(date '+%s')"
	fi
fi

every_mac_marketing_model_name_with_grouped_serial_config_codes_file_path="${OUTPUT_DIR}/every_mac_marketing_model_name$($include_docs_ids && echo '_and_docs_url')_with_grouped_serial_config_codes.txt"
if [[ ! -f "${every_mac_marketing_model_name_with_grouped_serial_config_codes_file_path}" ]]; then
	>&2 echo "TIMESTAMP:START-MODEL-GROUPED-MAC-FILE-OUTPUT:$(date '+%s')"

	grep 'Mac\|Book\|Xserve' "$($include_docs_ids && echo "${every_marketing_model_name_and_docs_url_with_grouped_serial_config_codes_file_path}" || echo "${every_marketing_model_name_with_grouped_serial_config_codes_file_path}")" | grep -v 'OS X' | sort -f"$($include_docs_ids && echo 'V')" > "${every_mac_marketing_model_name_with_grouped_serial_config_codes_file_path}"

	>&2 echo "TIMESTAMP:END-MODEL-GROUPED-MAC-FILE-OUTPUT:$(date '+%s')"
fi
