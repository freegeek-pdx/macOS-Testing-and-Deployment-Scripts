#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell (of Free Geek) on 5/15/25.
#
# Uses: AppleDB.dev (https://github.com/littlebyteorg/appledb) MIT License (https://github.com/littlebyteorg/appledb/blob/main/LICENSE)
#
# MIT License
#
# Copyright (c) 2024 Free Geek
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

PATH='/usr/bin:/bin:/usr/sbin:/sbin'

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"
readonly SCRIPT_DIR

readonly OUTPUT_DIR="${SCRIPT_DIR}/appledb-parsing-output"
mkdir -p "${OUTPUT_DIR}"

every_model_id_with_marketing_model_name_from_appledb="${OUTPUT_DIR}/every_model_id_with_marketing_model_name_from_appledb.txt"

if [[ -f "${every_model_id_with_marketing_model_name_from_appledb}" ]]; then
	echo "ALREADY CREATED FILE: ${every_model_id_with_marketing_model_name_from_appledb}"
else
	apple_db_device_folders_path="$1"

	if [[ ! -d "${apple_db_device_folders_path}/Macbook Air" ]]; then
		>&2 echo 'MUST SPECIFY PATH TO AppleDB "deviceFiles" FOLDER'
		exit 2
	fi

	apple_db_device_product_types_and_folder_names='Mac Laptop:Macbook Pro
Mac Laptop:Macbook Air
Mac Laptop:Macbook
Mac Laptop:iBook
Mac Laptop:PowerBook
Mac Desktop:iMac
Mac Desktop:Mac mini
Mac Desktop:Mac Studio
Mac Desktop:Mac Pro
Mac Desktop:eMac
Mac Desktop:PowerMac
Mac Desktop:Macintosh
Mac Server:Xserve
iPhone:iPhone
iPad:iPad
iPod:iPod touch
Apple TV:Apple TV
Apple Watch:Apple Watch
HomePod:HomePod
Apple Vision:Vision Pro
Accessory:Apple Pencil'
	# NOTE: I don't want to parse EVERY folder in the "deviceFiles" folder, just the ones that may get refurbished and we would want model names for.

	while IFS=':' read -r this_product_type this_apple_db_device_folder_name; do
		if [[ -d "${apple_db_device_folders_path}/${this_apple_db_device_folder_name}" ]]; then
			for this_apple_db_device_json_path in "${apple_db_device_folders_path}/${this_apple_db_device_folder_name}/"*'.json'; do
				# Suppress ShellCheck warning that expressions don't expand in single quotes since this is intended.
				# shellcheck disable=SC2016
				osascript -l 'JavaScript' -e '
function run(argv) {
	const thisProductType = argv[0]
	const thisAppleDeviceDictionary = JSON.parse($.NSString.stringWithContentsOfFileEncodingError(argv[1], $.NSUTF8StringEncoding, $()).js)

	const thisMarketingModelName = (thisAppleDeviceDictionary.name ? thisAppleDeviceDictionary.name : "UNKNOWN Marketing Model Name")
		.replace(" Max 20", " Max, 20")
		.replace("Mac Pro (Late 2010)", "Mac Pro (Mid 2010)")
		.replace("MacBook Pro (15-inch, Mid 2018", "MacBook Pro (15-inch, 2018")
		.replace("MacBook Pro (15-inch, Late 2018", "MacBook Pro (15-inch, 2018")
	// Fix missing comma in https://github.com/littlebyteorg/appledb/blob/main/deviceFiles/Macbook%20Pro/Mac14%2C5.json
	// Fix incorrect year prefix in https://github.com/littlebyteorg/appledb/blob/main/deviceFiles/Mac%20Pro/MacPro5%2C1-2010.json
	// Fix incorrect year prefix in https://github.com/littlebyteorg/appledb/blob/main/deviceFiles/Macbook%20Pro/MacBookPro15%2C1-2018.json & https://github.com/littlebyteorg/appledb/blob/main/deviceFiles/Macbook%20Pro/MacBookPro15%2C3-2018.json

	if (!thisMarketingModelName.startsWith("Unreleased") && !thisMarketingModelName.includes("Unknown Model") && (thisMarketingModelName != "Developer Transition Kit")) {
		let thisModelIdentifier = (thisAppleDeviceDictionary.identifier ? thisAppleDeviceDictionary.identifier : "unknown")
		if (Array.isArray(thisModelIdentifier)) // This will only be https://github.com/littlebyteorg/appledb/blob/main/deviceFiles/HomePod/AudioAccessory5%2C1.json
			thisModelIdentifier = thisModelIdentifier[0] // and only want the first Model ID.

		let theseModelANumbers = (thisAppleDeviceDictionary.model ? thisAppleDeviceDictionary.model : "unknown")
		if (Array.isArray(theseModelANumbers)) theseModelANumbers = theseModelANumbers.sort().join(":")

		if ((thisModelIdentifier != "unknown") || (theseModelANumbers != "unknown"))
			return `${thisProductType}:${thisModelIdentifier}:${thisMarketingModelName}:${theseModelANumbers}:`
	}
}
' -- "${this_product_type}" "${this_apple_db_device_json_path}" | tee -a "${every_model_id_with_marketing_model_name_from_appledb}"
			done
		else
			>&2 echo "AppleDB DEVICE FOLDER FOR \"${this_apple_db_device_folder_name}\" IS MISSING IN ${this_apple_db_device_folder_name}"
		fi
	done <<< "${apple_db_device_product_types_and_folder_names}"

	sort -ufV "${every_model_id_with_marketing_model_name_from_appledb}" -o "${every_model_id_with_marketing_model_name_from_appledb}"
fi



# TODO: "MacBook Air (Late 2008)" incorrectly matches to the "MacBook Air (Mid 2009)" Specs ID because the Model IDs are the same, and there is no alternate available from the Identification Pages because it's too old.
# But I know from the Config Codes output that the actual Specs ID for the 2008 is "112447"
# Mac Laptop;112660;MacBookAir2,1:MacBook Air (Late 2008):A1304:
# Mac Laptop;112660;MacBookAir2,1:MacBook Air (Mid 2009):A1304:

readonly SCRAPE_SUPPORT_PAGES_OUTPUT_DIR="${SCRIPT_DIR}/scrape-support-pages-output"

every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path="${SCRAPE_SUPPORT_PAGES_OUTPUT_DIR}/every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages.txt"

if [[ ! -f "${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}" ]]; then
	>&2 echo -e "MISSING REQUIRED FILES:\n${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}"
	exit 1
fi

every_model_id_and_specs_id_with_marketing_model_name_from_appledb_file_path="${OUTPUT_DIR}/every_model_id_and_specs_id_with_marketing_model_name_from_appledb.txt"

if [[ -f "${every_model_id_and_specs_id_with_marketing_model_name_from_appledb_file_path}" ]]; then
	>&2 echo "ALREADY CREATED FILE: ${every_model_id_and_specs_id_with_marketing_model_name_from_appledb_file_path}"
	exit 2
fi

match_count=0
matched_lines_from_identification_pages=''

# Suppress ShellCheck warning to not read and write the same file in the same pipeline since only reading multiple times (grepping within while read).
# shellcheck disable=SC2094
while IFS=':' read -r this_product_type_from_appledb this_model_id_from_appledb this_marketing_model_name_from_appledb these_a_numbers_from_appledb; do
	this_line_from_appledb="${this_product_type_from_appledb}:${this_model_id_from_appledb}:${this_marketing_model_name_from_appledb}:${these_a_numbers_from_appledb%:}:"

	model_year_from_appledb="$(echo "${this_marketing_model_name_from_appledb}" | sed -E 's/.*[^0-9]([12][90][0-9]{2})[^0-9].*/\1/')"
	if [[ "${model_year_from_appledb}" == "${this_marketing_model_name_from_appledb}" ]]; then
		model_year_from_appledb='' # No year extracted if full model string was returned.
	fi

	did_match_this_model=false
	possible_matches_from_identification_pages=''

	while IFS=';:' read -r this_product_type_from_identification_page this_specs_id_from_identification_page this_marketing_model_name_from_identification_page this_marketing_model_name_from_specs_page_via_identification_page these_model_identifiers_from_identification_page; do
		if [[ "${this_product_type_from_appledb}" == "${this_product_type_from_identification_page}" ]]; then
			
			model_year_from_from_identification_page=''
			if [[ -n "${model_year_from_appledb}" ]]; then # Do not bother trying to extract a year if there is no year in the model name being matched (because it noticably slows the script down).
				model_year_from_from_identification_page="$(echo "${this_marketing_model_name_from_identification_page}" | sed -E 's/.*[^0-9]([12][90][0-9]{2})[^0-9].*/\1/')"
				if [[ "${model_year_from_from_identification_page}" == "${this_marketing_model_name_from_identification_page}" ]]; then
					model_year_from_from_identification_page='' # No year extracted if full model string was returned.
				fi
			fi

			if [[ -z "${model_year_from_from_identification_page}" || "${model_year_from_appledb}" == "${model_year_from_from_identification_page}" ]]; then # Only try to match model names if model years match (or there are no years).
				this_line_from_identification_page="${this_product_type_from_identification_page};${this_specs_id_from_identification_page};${this_marketing_model_name_from_identification_page}:${this_marketing_model_name_from_specs_page_via_identification_page}:${these_model_identifiers_from_identification_page%:}:"

				while IFS='' read -r this_model_id_or_a_number_from_appledb; do
					if [[ -n "${this_model_id_or_a_number_from_appledb}" && ":${these_model_identifiers_from_identification_page}:" == *":${this_model_id_or_a_number_from_appledb}:"* ]]; then
						possible_matches_from_identification_pages+=$'\n?\t'"${this_line_from_identification_page}"

						echo -e "\n\nPOSSIBLE MODEL ID MATCH:
-\t${this_line_from_appledb}
?\t${this_line_from_identification_page}"

						if [[ "${this_marketing_model_name_from_appledb}" == "${this_marketing_model_name_from_identification_page}" ]]; then
							echo -e 'APPLEDB MARKETING MODEL NAME EXACT MATCHES IDENTIFICATION PAGE MARKETING MODEL NAME'
							did_match_this_model=true
						elif [[ "${this_marketing_model_name_from_appledb}" == "${this_marketing_model_name_from_specs_page_via_identification_page}" ]]; then
							echo -e 'APPLEDB MARKETING MODEL NAME EXACT MATCHES *SPECS PAGE* MARKETING MODEL NAME'
							did_match_this_model=true
						else
							this_marketing_model_name_from_appledb_to_match="$(echo "${this_marketing_model_name_from_appledb}" | tr -dc '[:alnum:]' | tr '[:upper:]' '[:lower:]')"
							this_marketing_model_name_from_identification_page_to_match="$(echo "${this_marketing_model_name_from_identification_page}" | tr -dc '[:alnum:]' | tr '[:upper:]' '[:lower:]')"
							this_marketing_model_name_from_specs_page_via_identification_page_to_match="$(echo "${this_marketing_model_name_from_specs_page_via_identification_page}" | tr -dc '[:alnum:]' | tr '[:upper:]' '[:lower:]')"

							if [[ "${this_marketing_model_name_from_appledb_to_match}" == "${this_marketing_model_name_from_identification_page_to_match}" ]]; then
								echo -e 'APPLEDB MARKETING MODEL NAME *ALNUM* MATCHES IDENTIFICATION PAGE MARKETING MODEL NAME'
								did_match_this_model=true
							elif [[ "${this_marketing_model_name_from_appledb_to_match}" == "${this_marketing_model_name_from_specs_page_via_identification_page_to_match}" ]]; then
								echo -e 'APPLEDB MARKETING MODEL NAME *ALNUM* MATCHES *SPECS PAGE* MARKETING MODEL NAME'
								did_match_this_model=true
							elif [[ "${this_marketing_model_name_from_identification_page_to_match}" == "${this_marketing_model_name_from_appledb_to_match}"* ]]; then
								echo -e 'APPLEDB MARKETING MODEL NAME *ALNUM PREFIX* MATCHES IDENTIFICATION PAGE MARKETING MODEL NAME'
								did_match_this_model=true
							elif [[ "${this_marketing_model_name_from_specs_page_via_identification_page_to_match}" == "${this_marketing_model_name_from_appledb_to_match}"* ]]; then
								echo -e 'APPLEDB MARKETING MODEL NAME *ALNUM PREFIX* MATCHES *SPECS PAGE* MARKETING MODEL NAME'
								did_match_this_model=true
							elif [[ "${this_marketing_model_name_from_appledb_to_match}" == "${this_marketing_model_name_from_identification_page_to_match}"* ]]; then
								echo -e 'APPLEDB MARKETING MODEL NAME IS AN *ALNUM PREFIX MATCH* OF IDENTIFICATION PAGE MARKETING MODEL NAME'
								did_match_this_model=true
							elif [[ "${this_marketing_model_name_from_appledb_to_match}" == "${this_marketing_model_name_from_specs_page_via_identification_page_to_match}"* ]]; then
								echo -e 'APPLEDB MARKETING MODEL NAME IS AN *ALNUM PREFIX MATCH* OF *SPECS PAGE* MARKETING MODEL NAME'
								did_match_this_model=true
							else
								echo -e "APPLEDB MARKETING MODEL NAME DOES NOT MATCH IDENTIFICATION PAGE NOR SPECS PAGE MARKETING MODEL NAME"
							fi
						fi

						if $did_match_this_model; then
							this_line_from_appledb_with_specs_id_from_identification_page="${this_product_type_from_appledb};${this_specs_id_from_identification_page};${this_model_id_from_appledb}:${this_marketing_model_name_from_appledb}:${these_a_numbers_from_appledb%:}:"
							echo "${this_line_from_appledb_with_specs_id_from_identification_page}" >> "${every_model_id_and_specs_id_with_marketing_model_name_from_appledb_file_path}"

							matched_lines_from_identification_pages+=$'\n'"${this_line_from_identification_page}"$'\n'

							echo -e "\n\nGOT MODEL ID *AND* MARKETING MODEL NAME MATCH:
-\t${this_line_from_appledb}
+\t${this_line_from_identification_page}
=\t${this_line_from_appledb_with_specs_id_from_identification_page}"

							break
						fi
					fi
				done <<< "${this_model_id_from_appledb}"$'\n'"${these_a_numbers_from_appledb//:/$'\n'}"

				if $did_match_this_model; then
					break
				fi
			fi
		fi
	done < "${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}"

	if $did_match_this_model; then
		(( match_count ++ ))
	else
		this_line_from_appledb_with_unknown_specs_id="${this_product_type_from_appledb};unknown;${this_model_id_from_appledb}:${this_marketing_model_name_from_appledb}:${these_a_numbers_from_appledb%:}:"

		if [[ -n "${possible_matches_from_identification_pages}" ]]; then
			possible_match_count="$(echo "${possible_matches_from_identification_pages}" | grep -c '^\?\t')"
			possible_specs_id_matches="$(echo "${possible_matches_from_identification_pages}" | cut -d ';' -f 2 | grep '.' | sort -u)"
			possible_specs_id_match_count="$(echo "${possible_specs_id_matches}" | wc -l | awk '{ print $1; exit }')"

			if (( possible_specs_id_match_count == 1 )); then
				this_line_from_appledb_with_single_specs_id_match_from_identification_page="${this_product_type_from_appledb};${possible_specs_id_matches};${this_model_id_from_appledb}:${this_marketing_model_name_from_appledb}:${these_a_numbers_from_appledb%:}:"

				echo "${this_line_from_appledb_with_single_specs_id_match_from_identification_page}" >> "${every_model_id_and_specs_id_with_marketing_model_name_from_appledb_file_path}"

				matched_lines_from_identification_pages+="${possible_matches_from_identification_pages//$'?\t'/}"$'\n'
				(( match_count ++ ))

				echo -e "\n\nGOT SINGLE POSSIBLE SPECS ID FOR MODEL ID MATCH:
-\t${this_line_from_appledb}${possible_matches_from_identification_pages}
=\t${this_line_from_appledb_with_single_specs_id_match_from_identification_page}"
			else
				echo "${this_line_from_appledb_with_unknown_specs_id}" >> "${every_model_id_and_specs_id_with_marketing_model_name_from_appledb_file_path}"

				echo -e "\n\nDID NOT MATCH (WITH ${possible_match_count} POSSIBLE MATCHES AND ${possible_specs_id_match_count} SPECS IDS):
-\t${this_line_from_appledb}${possible_matches_from_identification_pages}
=\t${this_line_from_appledb_with_unknown_specs_id}"
			fi
		else
			echo "${this_line_from_appledb_with_unknown_specs_id}" >> "${every_model_id_and_specs_id_with_marketing_model_name_from_appledb_file_path}"

			echo -e "\n\nDID NOT MATCH (WITH NO POSSIBLE MATCHES):
-\t${this_line_from_appledb}
=\t${this_line_from_appledb_with_unknown_specs_id}"
		fi
	fi
done < "${every_model_id_with_marketing_model_name_from_appledb}"

echo -e "\n\nMATCH COUNT: ${match_count}"

while IFS=';:' read -r this_product_type_from_identification_page this_specs_id_from_identification_page this_marketing_model_name_from_identification_page this_marketing_model_name_from_specs_page_via_identification_page these_model_identifiers_from_identification_page; do
	this_line_from_identification_page="${this_product_type_from_identification_page};${this_specs_id_from_identification_page};${this_marketing_model_name_from_identification_page}:${this_marketing_model_name_from_specs_page_via_identification_page}:${these_model_identifiers_from_identification_page%:}:"

	if [[ "${matched_lines_from_identification_pages}" != *$'\n'"${this_line_from_identification_page}"$'\n'* ]]; then
		echo -e "\n\nDID NOT MATCH LINE FROM IDENTIFICATION PAGE:
-\t${this_line_from_identification_page}"

		did_match_model_id_and_specs_id_to_other_model_name=false
		these_lines_with_specs_id_from_appledb="$(grep ";${this_specs_id_from_identification_page};" "${every_model_id_and_specs_id_with_marketing_model_name_from_appledb_file_path}")"
		while IFS='' read -r this_model_identifier_from_identification_page; do
			if [[ -n "${this_model_identifier_from_identification_page}" ]] && echo "${these_lines_with_specs_id_from_appledb}" | grep "${this_model_identifier_from_identification_page}:"; then
				echo 'BUT MATCHED MODEL ID AND SPECS ID TO ANOTHER MODEL NAME'
				did_match_model_id_and_specs_id_to_other_model_name=true
				break
			fi
		done <<< "${these_model_identifiers_from_identification_page//:/$'\n'}"

		if ! $did_match_model_id_and_specs_id_to_other_model_name; then
			echo '*AND DID NOT MATCH MODEL ID AND SPECS ID TO ANOTHER MODEL NAME*'
		fi
	fi
done < "${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}"