#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell (of Free Geek) on 8/9/22.
#
# MIT License
#
# Copyright (c) 2022 Free Geek
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

serial_number="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" # Use a specified serial number from the first argument.

if [[ -z "$1" ]]; then # Get the current Mac serial number if no argument specified.
	serial_number="$(/usr/libexec/PlistBuddy -c 'Print :0:IOPlatformSerialNumber' /dev/stdin <<< "$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)" 2> /dev/null)"
fi

if (( ${#serial_number} == 3 || ${#serial_number} == 4 )); then # Allow just the Config Code portion of older serial numbers to be passed as an argument as well.
	serial_config_code="${serial_number}"
	echo "Serial Config Code: ${serial_config_code}"

	serial_number="XXXXXXXX${serial_config_code}" # For 4 character config codes, passing all X's works for the first portion of the 12 character serial which isn't relevant to the model.
	if (( ${#serial_config_code} == 3 )); then
		serial_number="RM101000${serial_config_code}"
		# For 3 character config codes, passing all X's DOES NOT work for the first portion of the serial which isn't relevant to the model and some valid format must be used,
		# so append the config code to a remanufactured/refurb serial (starting with "RM") made in year 1, week 01, and a unique ID of 000 which would never exist but allows the API call to work properly.
		# More info about this old 11 character serial format: https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/
	fi
else
	echo "Serial: ${serial_number}"
fi

# The following URLs were discovered from examining how "https://support.apple.com/specs/${serial_number}" loads the specs URL via JavaScript (as of August 9th, 2022 *BUT NO LONGER WORKS*).

# IMPORTANT NOTE: On March 20th, 2024, Apple released a new "Manuals, Specs, and Downloads" page at "https://support.apple.com/docs" (https://www.macrumors.com/2024/03/20/apple-manuals-specs-downloads-website/).
# The previous "https://support.apple.com/specs" now forwards to this new "docs" page, and the previous "https://support.apple.com/specs/${serial_number}" functionality *NO LONGER WORKS* with the new "docs" page.

# EVEN MORE IMPORTANT: On May 15th, 2025, "https://km.support.apple.com/kb/index?page=categorydata" started returning 403 Forbidden! But other active "page" values that are still used on other parts of their site still work, so I think this was intentionally taken down.
# The first part of this code which could previously retrieve the Marketing Model Name and Docs IDs from a serial using this URL API *STOPPED WORKING* on May 15th, 2025 (and the 2nd part to get the Specs URL *STOPPED WORKING* on March 20th, 2024).

serial_search_results_json="$(curl -m 10 --retry 3 -sfL "https://km.support.apple.com/kb/index?page=categorydata&serialnumber=${serial_number}" 2> /dev/null)" # I have seen this URL API timeout after 5 seconds when called multiple times rapidly (likely because of rate limiting), so give it a 10 second timeout which seems to always work.

# printf '%s' "${serial_search_results_json}" | jq # DEBUG

if [[ -z "${serial_search_results_json}" ]]; then
	>&2 echo 'ERROR: SERIAL SEARCH FAILED -  INTERNET REQUIRED'
	exit 1
fi

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

if (( ${#serial_search_results_values[@]} != 5 )); then
	>&2 echo "ERROR: SERIAL SEARCH DOES NOT CONTAIN EXPECTED/REQUIRED VALUES $(declare -p serial_search_results_values | cut -d '=' -f 2-)"
	exit 2
fi

docs_id="${serial_search_results_values[0]}"
docs_parent_id="${serial_search_results_values[1]}"
docs_grandparent_id="${serial_search_results_values[2]}"
docs_greatgrandparent_id="${serial_search_results_values[3]}"
marketing_model_name="${serial_search_results_values[4]}"
marketing_model_name="${marketing_model_name//$'\xC2\xA0'/ }" # Replace any non-breaking spaces with regular spaces that exist in some Apple Watch model names, such as "https://km.support.apple.com/kb/index?page=categorydata&serialnumber=XXXXXXXXQ20P" and others.
marketing_model_name="${marketing_model_name//  / }" # Replace any double spaces with a single space that exist in some model names, such as "https://km.support.apple.com/kb/index?page=categorydata&serialnumber=RM101000YAM" and others.
marketing_model_name="${marketing_model_name// ,/,}" # Replace any space+comma with a just comma that exist in some model names, such as "https://km.support.apple.com/kb/index?page=categorydata&serialnumber=RM101000MYZ" and others.
marketing_model_name="${marketing_model_name% }" # Remove single trailing spaces which values from the the Specs API may include, like "https://km.support.apple.com/kb/index?page=categorydata&serialnumber=XXXXXXXXGTDX" and others.

echo "DEBUG: ${docs_greatgrandparent_id} > ${docs_grandparent_id} > ${docs_parent_id} > ${docs_id} > ${marketing_model_name}"

if [[ "${docs_id}" == 'null' ]]; then
	>&2 echo 'ERROR: SERIAL NOT FOUND'
	exit 3
fi

docs_pf_id=''
docs_pl_id=''
docs_pp_id=''
for this_docs_ancestor_id in "${docs_greatgrandparent_id}" "${docs_grandparent_id}" "${docs_parent_id}"; do
	# Some products could have multiple PF IDs, such as Displays (such as Config Code "P2RH") could have a Grandparent ID of "PF8" (for all accessories) and Parent ID of "PF5" (just for displays).
	# So, the order of this loop is very important to overwrite each variable with the lowest tier PF ID.
	if [[ "${this_docs_ancestor_id}" == 'PF'* ]]; then
		docs_pf_id="${this_docs_ancestor_id}"
	elif [[ "${this_docs_ancestor_id}" == 'PL'* ]]; then
		docs_pl_id="${this_docs_ancestor_id}"
	elif [[ "${this_docs_ancestor_id}" == 'PP'* ]]; then
		docs_pp_id="${this_docs_ancestor_id}"
	fi
done

echo -e "DEBUG: PF = ${docs_pf_id:-N/A}\nDEBUG: PL = ${docs_pl_id:-N/A}\nDEBUG: PP = ${docs_pp_id:-N/A}"

echo "Marketing Model Name: ${marketing_model_name}"

if [[ -z "${docs_pf_id}" ]]; then
	>&2 echo 'ERROR: PF ID MISSING'
	exit 4
fi

docs_category='unknown'
product_type='UNKNOWN'
docs_url_id="${docs_id}"

if [[ "${docs_pf_id}" == 'PF1' || "${docs_pf_id}" == 'PF2' || "${docs_pf_id}" == 'PF6' || "${docs_pf_id}" == 'PF11' ]]; then
	docs_category='mac'
	product_type='Mac'

	if [[ "${docs_pf_id}" == 'PF1' ]]; then
		product_type+=' Desktop'
	elif [[ "${docs_pf_id}" == 'PF2' ]]; then
		product_type+=' Laptop'
	elif [[ "${docs_pf_id}" == 'PF6' ]]; then
		product_type='macOS'
	else
		product_type+=' Server' # NOTE: There are no docs pages for server products such as Xserve (such as Config Code "HDE") as well as old Power Mac Server and Mac Pro Server models.
	fi
elif [[ "${docs_pf_id}" == 'PF3' ]]; then
	docs_category='ipod'
	product_type='iPod'
elif [[ "${docs_pf_id}" == 'PF5' ]]; then
	docs_category='displays'
	product_type='Display'
elif [[ "${docs_pf_id}" == 'PF7' ]]; then
	docs_category='accessories'
	product_type='AirPort'
elif [[ "${docs_pf_id}" == 'PF8' ]]; then
	docs_category='accessories'

	if [[ "${docs_pl_id}" == 'PL177' ]]; then
		product_type='AirTag'
	else
		product_type='Accessory'
	fi
elif [[ "${docs_pf_id}" == 'PF9' ]]; then
	docs_category='iphone'
	product_type='iPhone'

	if [[ "${docs_pl_id}" == 'PL134' ]]; then
		if [[ "${docs_pp_id}" == 'PP70' ]]; then
			docs_category='airpods'
			product_type='AirPods'
		else
			product_type+=' Accessory'
		fi
	fi
elif [[ "${docs_pf_id}" == 'PF10' ]]; then
	docs_category='apple-tv'
	product_type='Apple TV'
elif [[ "${docs_pf_id}" == 'PF12' || "${docs_pf_id}" == 'PF13' || "${docs_pf_id}" == 'PF14' || "${docs_pf_id}" == 'PF16' ]]; then
	if [[ "${marketing_model_name}" == *'Mac OS X'* ]]; then
		docs_category='mac'
		product_type='macOS'
	else
		docs_category='software'
		product_type='Software'
	fi
elif [[ "${docs_pf_id}" == 'PF22' ]]; then
	docs_category='ipad'
	product_type='iPad'

	if [[ "${docs_pl_id}" == 'PL221' ]]; then
		product_type+=' Accessory'

		if [[ "${docs_id}" == '300111' ]]; then
			docs_url_id='pp125' # Can see on "https://support.apple.com/docs/ipad" that the Docs ID for Config Code "JKM9" [PF22 > PL221 > 3001111 > 300111 > Apple Pencil (2nd generation)] is actually "pp125" even though there is no PP ID in the info from the Specs API.
		fi
	fi
elif [[ "${docs_pf_id}" == 'PF27' ]]; then
	docs_category='accessories' # NOTE: There are no Docs pages for Beats products, except for the 2024 Beats Pill which is listed under accessories.
	product_type='Beats'
elif [[ "${docs_pf_id}" == 'PF28' ]]; then
	docs_category='watch'
	product_type='Apple Watch'
elif [[ "${docs_pf_id}" == 'PF34' ]]; then
	docs_category='homepod'
	product_type='HomePod'
elif [[ "${docs_pf_id}" == 'PF36' ]]; then
	docs_category='vision'
	product_type='Apple Vision'
fi

if [[ "${docs_category}" == 'unknown' ]]; then
	>&2 echo 'ERROR: UNKNOWN DOCS CATEGORY'
	exit 5
fi

echo "Product Type: ${product_type}"

found_valid_docs_url=false
specs_url_id=''
for this_possible_docs_url_id in "${docs_url_id}" "$(printf '%s' "${docs_pl_id}" | tr '[:upper:]' '[:lower:]')"; do
	if [[ -n "${this_possible_docs_url_id}" ]]; then
		# Some Software and iPhone/iPad/iPod Accessories may use PL ID, so check and use if Docs ID doesn't have a valid Docs page.
		# Also, some Apple Watch Docs IDs don't have Tech Specs links, but there may be Tech Specs associated with the PL ID for all the variants of a whole generation (as they are listed on "https://support.apple.com/docs/watch").

		# TODO: Add more internet connection error checking with each CURL
		this_docs_page_source="$(curl -m 10 --retry 3 -sf "https://support.apple.com/en-us/docs/${docs_category}/${this_possible_docs_url_id}")" # DO NOT FOLLOW REDIRECTS to catch invalid Docs URLs more easily since they would redirect to the category URL.
		curl_exit_code="$?"

		if [[ "${curl_exit_code}" == '0' && -n "${this_docs_page_source}" ]]; then # Docs page source would be empty if not valid URL that would be redirected to the Docs category page.
			this_specs_url="$(echo "${this_docs_page_source}" | xmllint --html --xpath 'string(//a[text()="Tech Specs"]/@href)' - 2> /dev/null)"
			specs_url_id="${this_specs_url##*/}"

			if ! $found_valid_docs_url; then
				found_valid_docs_url=true

				if [[ "${docs_url_id}" != "${this_possible_docs_url_id}" ]]; then # Do not change Docs URL if already found a valid one without Tech Specs (since subsequent ones may be less specific and still not have Tech Specs), but kept checking for Tech Specs in PL ID.
					docs_url_id="${this_possible_docs_url_id}"
				fi
			fi

			if [[ -n "${specs_url_id}" ]]; then
				if [[ "${docs_url_id}" != "${this_possible_docs_url_id}" ]]; then # But if a Docs URL was found Tech Specs, always use it as the Docs ID.
					docs_url_id="${this_possible_docs_url_id}"
				fi

				break
			fi
		fi
	fi
done

echo "Docs URL: https://support.apple.com/docs/${docs_category}/${docs_url_id}"

echo "Image URL: https://cdsassets.apple.com/content/services/pub/image?productid=$(printf '%s' "${docs_url_id}" | tr '[:lower:]' '[:upper:]')"

if [[ -n "${specs_url_id}" ]]; then
	echo "Specs URL: https://support.apple.com/${specs_url_id}"
else
	echo 'Specs URL: UNKNOWN Specs URL'
fi


# IMPORTANT NOTE: THE CODE BELOW THIS POINT STOPPED WORKING ON March 20th, 2024 (see IMPORTANT NOTE comments above).

# specs_search_results_json="$(curl -m 10 --retry 3 -sfL "https://km.support.apple.com/kb/index?page=specs_browse&category=${docs_id}&parent=${docs_parent_id}&grandparent=${docs_grandparent_id}&greatgrandparent=${docs_greatgrandparent_id}" 2> /dev/null)"

# printf '%s' "${specs_search_results_json}" | jq # DEBUG

# if [[ -z "${specs_search_results_json}" ]]; then
# 	>&2 echo 'INTERNET REQUIRED - SPECS SEARCH FAILED'
# 	exit 6
# fi

# specs_url_kb_part="$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).specs[0].url' -- "${specs_search_results_json}" 2> /dev/null)"

# if [[ -z "${specs_url_kb_part}" ]]; then
# 	>&2 echo 'UNEXPECTED ERROR - SPECS SEARCH DOES NOT CONTAIN KB SPECS URL'
# 	exit 7
# fi

# specs_url="https://support.apple.com${specs_url_kb_part}"
