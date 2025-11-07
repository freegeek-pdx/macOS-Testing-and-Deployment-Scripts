#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell (of Free Geek) on 5/16/25.
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

readonly OUTPUT_DIR="${SCRIPT_DIR}/scrape-support-pages-output"
mkdir -p "${OUTPUT_DIR}"



every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path="${OUTPUT_DIR}/every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages.txt"

if [[ -f "${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}" ]]; then
	>&2 echo "ALREADY CREATED FILE: ${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}"
else
	# All identification pages are listed on https://support.apple.com/102604 (as well as in the "Product or packaging" section of https://support.apple.com/102767 for Macs).
	all_identification_pages_info='108052:Mac Laptop:MacBook Pro
102869:Mac Laptop:MacBook Air
103257:Mac Laptop:MacBook
108054:Mac Desktop:iMac
102852:Mac Desktop:Mac mini
102231:Mac Desktop:Mac Studio
102887:Mac Desktop:Mac Pro
108044:iPhone:
108043:iPad:
101605:Apple TV:'

	# TODO: Include part numbers in Mac outputs?

	# DOES NOT CONTAIN ANY TECH SPECS LINKS: (STILL SCRAPE FROM MODEL ID TO MODEL NAME MATCHING?)
	# 103823:iPod:
	# 108056:Apple Watch:
	# 109525:AirPods:

	# DOES NOT CONTAIN ANY MODEL IDENTIFIERS:
	# 102744:Display:
	# 101609:HomePod:

	while IFS=':' read -r this_identification_page_id this_product_type _; do
		if [[ -n "${this_identification_page_id}" ]]; then
			# Suppress ShellCheck warning that expressions don't expand in single quotes since this is intended.
			# shellcheck disable=SC2016
			awk_model_name_scraping_code='
/class="gb-header"/ {
	gsub(/[<][^<>]*[>]/, "", $NF)
	gsub(">", "", $NF)
	print ""
	print "Name: " $NF
}

/<p class="gb-paragraph"><b>MacBook/ {
	gsub(/[<][^<>]*[>]/, "", $NF)
	gsub(">", "", $NF)
	print ""
	print "Name: " $NF
}
'
			# Suppress ShellCheck warning that expressions don't expand in single quotes since this is intended.
			# shellcheck disable=SC2016
			awk_tech_specs_link_scraping_code='
(tolower($0) ~ /tech specs/) {
	for (f = 1; f <= NF; f ++) {
		if (($f ~ /support.apple.com/) && !($f ~ /\/specs$/)) {
			print "https:" $f
			break
		} else if (($f ~ /^\//) && !($f ~ /\./)) {
			print "https://support.apple.com" $f
			break
		}
	}
}
'

			awk_model_id_scraping_code=''
			if [[ "${this_product_type}" == 'Mac '* ]]; then
				# Suppress ShellCheck warning that expressions don't expand in single quotes since this is intended.
				# shellcheck disable=SC2016
				awk_model_id_scraping_code='
/Model Identifier:/ {
	gsub(/[<][^<>]*[>]/, "", $NF)
	gsub("&nbsp;", " ", $NF)
	gsub(", ", ":", $NF)
	gsub("; ", ":", $NF)
	gsub(" ", "", $NF)
	print "ID: " $NF
}
'
			elif [[ "${this_product_type}" == 'iPhone' ]]; then
				# Suppress ShellCheck warning that expressions don't expand in single quotes since this is intended.
				# shellcheck disable=SC2016
				awk_model_id_scraping_code='
/Model number/ {
	gsub(/[<][^<>]*[>]/, "", $NF)
	gsub(/[(][^()]*[)]/, "", $NF)
	gsub(" ", "", $NF)
	gsub(",", ":", $NF)
	gsub("::", ":", $NF)
	print "ID: " $NF
}

/The model number on the back case is / {
	gsub(">The model number on the back case is ", "", $NF)
	gsub(".</p>", "", $NF)
	print "ID: " $NF
}
'
				# TODO: What to do about: "<p class="gb-paragraph">Model number on the back cover: A1453, A1457, A1518, A1528,</p>
				#						   <p class="gb-paragraph">A1530, A1533</p>"
			elif [[ "${this_product_type}" == 'iPad' ]]; then
				# Suppress ShellCheck warning that expressions don't expand in single quotes since this is intended.
				# shellcheck disable=SC2016
				awk_model_id_scraping_code='
/<p class="gb-paragraph">A[0-9]{4}[, ]/ {
	split($NF, id_and_variant, " on ")
	variant_part = id_and_variant[2]
	gsub(/[<][^<>]*[>]/, "", variant_part)
	gsub(/&.*/, "", variant_part)
	gsub("the ", "", variant_part)
	gsub(" mainland only)", ")", variant_part)
	gsub(" only)", ")", variant_part)
	gsub(" model)", ")", variant_part)
	print "Variant: " variant_part

	id_part = id_and_variant[1]
	gsub(">", "", id_part)
	gsub(" or ", ":", id_part)
	gsub(" ", "", id_part)
	gsub(",", ":", id_part)
	print "ID: " id_part
}
'
			elif [[ "${this_product_type}" == 'Apple TV' ]]; then
				# Suppress ShellCheck warning that expressions don't expand in single quotes since this is intended.
				# shellcheck disable=SC2016
				awk_model_id_scraping_code='
/Model number/ {
	gsub(/ for .*/, "", $NF)
	gsub(/[<][^<>]*[>]/, "", $NF)
	gsub(" or ", ":", $NF)
	gsub(" ", "", $NF)
	print "ID: " $NF
}
'
			fi

			if [[ -n "${awk_model_id_scraping_code}" ]]; then
				this_identification_page_source="$(curl -m 10 --retry 3 -sfL "https://support.apple.com/${this_identification_page_id}?nocache=$(date '+%s')")"
				if [[ -z "${this_identification_page_source}" ]]; then
					>&2 echo "ERROR: NO RESPONSE FROM https://support.apple.com/${this_identification_page_id}"
					exit 1
				fi

				# DEBUG echo "${this_identification_page_source}" | sed 's/<\/p><p/<\/p>\n<p/g; s/<\/li><li/<\/li>\n<li/g; s/<\/h2><img/<\/h2>\n<img/g' | awk -F ':|"' "${awk_model_name_scraping_code}${awk_model_id_scraping_code}${awk_tech_specs_link_scraping_code}"

				previous_line=''
				this_marketing_model_name_from_identification_page=''
				this_variant_name_from_identification_page=''
				these_variants_and_model_ids=''
				this_marketing_model_name_from_specs_page=''
				these_model_identifiers=''
				while IFS='' read -r this_model_id_or_specs_url; do
					if [[ "${this_model_id_or_specs_url}" == 'https://'* ]]; then
						this_specs_url="${this_model_id_or_specs_url}"
						this_specs_page_source="$(curl -m 10 --retry 3 -sfL "${this_specs_url}?nocache=$(date '+%s')" 2> /dev/null)"
						if [[ -z "${this_specs_page_source}" ]]; then
							>&2 echo "ERROR: NO RESPONSE FROM ${this_specs_url}"
						fi

						# Some Specs URLs listed on the identification pages are the old "/kb/" links that will forward to the new format of URLs with the Specs ID at the end.
						# The following "meta" property will contain the redirected URL which we always want to use. 
						this_specs_url="$(echo "${this_specs_page_source}" | xmllint --html --xpath 'string(//meta[@property="og:url"]/@content)' - 2> /dev/null)"
						this_marketing_model_name_from_specs_page="$(echo "${this_specs_page_source}" | xmllint --html --xpath 'normalize-space(substring-before(//title, " - "))' - 2> /dev/null)"
						this_marketing_model_name_from_specs_page="${this_marketing_model_name_from_specs_page//$'\xC2\xA0'/ }" # Replace any non-breaking spaces with regular spaces that exist in page titles like "https://support.apple.com/122242" and others.
						this_marketing_model_name_from_specs_page="${this_marketing_model_name_from_specs_page//$'\xE2\x80\x91'/-}" # Replace any non-breaking hyphens with regular hyphens that exist in page titles like "https://support.apple.com/122242" and others.
						this_marketing_model_name_from_specs_page="${this_marketing_model_name_from_specs_page// and / or }" # Replace " and " with " or " that exists in page titles like "https://support.apple.com/112624"

						if [[ -n "${these_variants_and_model_ids}" ]]; then
							while IFS=':' read -r this_variant_name these_variant_model_ids; do
								if [[ -n "${this_variant_name}" ]]; then
									if [[ "${this_variant_name}" != "${this_marketing_model_name_from_specs_page}" ]]; then
										>&2 echo 'DEBUG: GOT DIFFERENT MODEL NAMES (OF VARIANT)'
									fi

									this_line="${this_product_type};${this_specs_url##*/};${this_variant_name-:UNKNOWN Marketing Model Name from Identification Page}:${this_marketing_model_name_from_specs_page-:UNKNOWN Marketing Model Name from Specs Page}:${these_variant_model_ids%:}:"
									if [[ "${this_line}" != "${previous_line}" ]]; then
										echo "${this_line}" | tee -a "${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}"
										previous_line="${this_line}"
									fi
								fi
							done <<< "${these_variants_and_model_ids}"

							these_variants_and_model_ids=''
						else
							if [[ "${this_marketing_model_name_from_identification_page}" != "${this_marketing_model_name_from_specs_page}" ]]; then
								>&2 echo 'DEBUG: GOT DIFFERENT MODEL NAMES'
							fi

							this_line="${this_product_type};${this_specs_url##*/};${this_marketing_model_name_from_identification_page-:UNKNOWN Marketing Model Name from Identification Page}:${this_marketing_model_name_from_specs_page-:UNKNOWN Marketing Model Name from Specs Page}:${these_model_identifiers}"
							if [[ "${this_line}" != "${previous_line}" ]]; then
								echo "${this_line}" | tee -a "${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}"
								previous_line="${this_line}"
							fi
						fi

						these_model_identifiers=''
					elif [[ "${this_model_id_or_specs_url}" == 'Name: '* ]]; then
						this_marketing_model_name_from_identification_page="${this_model_id_or_specs_url:6}"
					elif [[ "${this_model_id_or_specs_url}" == 'Variant: '* ]]; then # Variants will only exist from iPad pages.
						this_variant_name_from_identification_page="${this_model_id_or_specs_url:9}"

						if [[ "${this_variant_name_from_identification_page}" == "${this_marketing_model_name_from_identification_page}"* ]]; then
							>&2 echo "DEBUG: VARIANT NAME STARTS WITH MODEL NAME [${this_marketing_model_name_from_identification_page} = ${this_variant_name_from_identification_page}]"
						else
							>&2 echo -n "DEBUG: MERGING MODEL NAME WITH VARIANT NAME [${this_variant_name_from_identification_page} TO "
							if [[ "${this_variant_name_from_identification_page}" == 'iPad Pro'* ]]; then # Seems like this is the only one that will actually get used.
								this_variant_name_from_identification_page="${this_variant_name_from_identification_page/iPad Pro/${this_marketing_model_name_from_identification_page}}"
							elif [[ "${this_variant_name_from_identification_page}" == 'iPad Air'* ]]; then # But set up these other conditions just in case.
								this_variant_name_from_identification_page="${this_variant_name_from_identification_page/iPad Air/${this_marketing_model_name_from_identification_page}}"
							elif [[ "${this_variant_name_from_identification_page}" == 'iPad mini'* ]]; then
								this_variant_name_from_identification_page="${this_variant_name_from_identification_page/iPad mini/${this_marketing_model_name_from_identification_page}}"
							elif [[ "${this_variant_name_from_identification_page}" == 'iPad'* ]]; then
								this_variant_name_from_identification_page="${this_variant_name_from_identification_page/iPad/${this_marketing_model_name_from_identification_page}}"
							fi
							>&2 echo "${this_variant_name_from_identification_page}]"
						fi
					elif [[ "${this_model_id_or_specs_url}" == 'ID: '* ]]; then
						if [[ -n "${this_variant_name_from_identification_page}" ]]; then
							this_variant_and_model_ids="${this_variant_name_from_identification_page}:${this_model_id_or_specs_url:4}:"
							echo "DEBUG: ADDING TO VARIANTS [${this_variant_and_model_ids}]"
							these_variants_and_model_ids+=$'\n'"${this_variant_and_model_ids}"

							this_variant_name_from_identification_page=''
						else
							these_model_identifiers+="${this_model_id_or_specs_url:4}:"
						fi
					fi
				done < <(echo "${this_identification_page_source}" | sed 's/<\/p><p/<\/p>\n<p/g; s/<\/li><li/<\/li>\n<li/g; s/<\/h2><img/<\/h2>\n<img/g' | awk -F ':|"' "${awk_model_name_scraping_code}${awk_model_id_scraping_code}${awk_tech_specs_link_scraping_code}")
			else
				>&2 echo "CODE NOT YET WRITTEN FOR ${this_product_type}: https://support.apple.com/${this_identification_page_id}"
			fi
		fi
	done <<< "${all_identification_pages_info}"
fi



every_docs_and_specs_id_with_marketing_model_name_from_docs_pages_file_path="${OUTPUT_DIR}/every_docs_and_specs_id_with_marketing_model_name_from_docs_pages.txt"

if [[ -f "${every_docs_and_specs_id_with_marketing_model_name_from_docs_pages_file_path}" ]]; then
	>&2 echo "ALREADY CREATED FILE: ${every_docs_and_specs_id_with_marketing_model_name_from_docs_pages_file_path}"
else

	every_docs_device_type_url="$(curl -m 10 --retry 3 -sfL "https://support.apple.com/docs?nocache=$(date '+%s')" | xmllint --html --xpath '//a[contains(@href, "/docs/") and not(contains(@href, "/docs/localeselector"))]/@href' - 2> /dev/null | cut -d '"' -f 2)"
	if [[ -z "${every_docs_device_type_url}" ]]; then
		>&2 echo 'ERROR: NO RESPONSE FROM https://support.apple.com/docs'
		exit 2
	fi

	while IFS='' read -r this_docs_device_type_url; do
		this_docs_device_type_info="$(curl -m 10 --retry 3 -sfL "${this_docs_device_type_url}?nocache=$(date '+%s')" | xmllint --html --xpath '
//a[contains(@href, "/docs/") and not(contains(@href, "/docs/localeselector")) and not(starts-with(@data-ss-analytics-link-component_name, "All "))]/@href |
//a[contains(@href, "/docs/") and not(contains(@href, "/docs/localeselector")) and not(starts-with(@data-ss-analytics-link-component_name, "All "))]/@data-ss-analytics-link-component_name |
//a[contains(@href, "/docs/") and not(contains(@href, "/docs/localeselector")) and not(starts-with(@data-ss-analytics-link-component_name, "All "))]/@data-ss-analytics-link-text
' - 2> /dev/null | cut -d '"' -f 2)"

		if [[ -z "${this_docs_device_type_url}" ]]; then
			>&2 echo "ERROR: NO RESPONSE FROM ${this_docs_device_type_url}"
			exit 3
		fi

		assumed_product_type='UNKNOWN Product Type'
		# For the following docs pages, "data-ss-analytics-link-component_name" will not be set (since there is only one device type on these pages), so manually set the product type.
		if [[ "${this_docs_device_type_url}" == *'/vision' ]]; then
			assumed_product_type='Apple Vision'
		elif [[ "${this_docs_device_type_url}" == *'/airpods' ]]; then
			assumed_product_type='AirPods'
		elif [[ "${this_docs_device_type_url}" == *'/homepod' ]]; then
			assumed_product_type='HomePod'
		elif [[ "${this_docs_device_type_url}" == *'/ipod' ]]; then
			assumed_product_type='iPod'
		elif [[ "${this_docs_device_type_url}" == *'/displays' ]]; then
			assumed_product_type='Display'
		fi

		this_device_docs_url=''
		this_device_product_type=''
		this_device_marketing_model_name=''
		this_marketing_model_name_from_docs_page=''
		this_marketing_model_name_from_specs_page=''
		this_specs_url_id=''
		while IFS='' read -r this_device_docs_url_or_product_type_or_marketing_model_name; do
			if [[ -z "${this_device_docs_url}" ]]; then
				this_device_docs_url="${this_device_docs_url_or_product_type_or_marketing_model_name}"
			elif [[ -z "${this_device_product_type}" ]]; then
				this_device_product_type="${this_device_docs_url_or_product_type_or_marketing_model_name:-${assumed_product_type}}"
				this_device_product_type="${this_device_product_type/tops/top}" # Make Product Types singular.
				this_device_product_type="${this_device_product_type/ories/ory}"
				if [[ "${this_device_product_type}" == 'Watch' ]]; then
					this_device_product_type='Apple Watch'
				fi
			else
				this_device_marketing_model_name="${this_device_docs_url_or_product_type_or_marketing_model_name:-UNKNOWN Marketing Model Name from Docs Page}"
				this_device_marketing_model_name="${this_device_marketing_model_name//$'\xC2\xA0'/ }" # Replace any non-breaking spaces with regular spaces that exist in values from "https://support.apple.com/docs/watch/pl291" and others.
				this_device_marketing_model_name="${this_device_marketing_model_name//  / }" # Replace any double spaces with a single space that exist in some model names, such as "https://support.apple.com/docs/mac/119741" and others.
				this_device_marketing_model_name="${this_device_marketing_model_name// ,/,}" # Replace any space+comma with a just comma that exist in some model names, such as "https://support.apple.com/en-us/docs/ipod/113636" and others.
				this_device_marketing_model_name="${this_device_marketing_model_name% }" # Remove single trailing spaces that exist in values from "https://support.apple.com/docs/mac/503556" and others.

				this_device_docs_page_source="$(curl -m 10 --retry 3 -sfL "${this_device_docs_url}?nocache=$(date '+%s')")"
				if [[ -z "${this_device_docs_page_source}" ]]; then
					>&2 echo "ERROR: NO RESPONSE FROM ${this_device_docs_url}"
				fi
				this_marketing_model_name_from_docs_page="$(echo "${this_device_docs_page_source}" | xmllint --html --xpath 'normalize-space(//h1)' - 2> /dev/null)" # "normalize-space" will take care of any double spaces and leading/trailing spaces.
				this_marketing_model_name_from_docs_page="${this_marketing_model_name_from_docs_page//$'\xC2\xA0'/ }" # Replace any non-breaking spaces with regular spaces that exist in values from "https://support.apple.com/docs/watch/pl291" and others.
				this_marketing_model_name_from_docs_page="${this_marketing_model_name_from_docs_page// ,/,}" # Replace any space+comma with a just comma that exist in some model names, such as "https://support.apple.com/en-us/docs/ipod/113636" and others.

				if [[ "${this_device_marketing_model_name}" != "${this_marketing_model_name_from_docs_page}" ]]; then
					>&2 echo 'DEBUG: GOT DIFFERENT MODEL NAMES BETWEEN DOCS LIST AND DOCS PAGE'
				fi

				this_specs_url="$(echo "${this_device_docs_page_source}" | xmllint --html --xpath 'string(//a[text()="Tech Specs"]/@href)' - 2> /dev/null)"
				if [[ -n "${this_specs_url}" ]]; then
					this_specs_page_source="$(curl -m 10 --retry 3 -sfL "${this_specs_url}?nocache=$(date '+%s')" 2> /dev/null)"
					if [[ -z "${this_specs_page_source}" ]]; then
						>&2 echo "ERROR: NO RESPONSE FROM ${this_specs_url}"
					fi

					# Some Specs URLs listed on the identification pages are the old "/kb/" links that will forward to the new format of URLs with the Specs ID at the end.
					# The following "meta" property will contain the redirected URL which we always want to use. 
					this_specs_url="$(echo "${this_specs_page_source}" | xmllint --html --xpath 'string(//meta[@property="og:url"]/@content)' - 2> /dev/null)"
					this_specs_url_id="${this_specs_url##*/}"

					this_marketing_model_name_from_specs_page="$(echo "${this_specs_page_source}" | xmllint --html --xpath 'normalize-space(substring-before(//title, " - "))' - 2> /dev/null)" # "normalize-space" will take care of any double spaces and leading/trailing spaces.
					this_marketing_model_name_from_specs_page="${this_marketing_model_name_from_specs_page//$'\xC2\xA0'/ }" # Replace any non-breaking spaces with regular spaces that exist in page titles like "https://support.apple.com/122242" and others.
					this_marketing_model_name_from_specs_page="${this_marketing_model_name_from_specs_page//$'\xE2\x80\x91'/-}" # Replace any non-breaking hyphens with regular hyphens that exist in page titles like "https://support.apple.com/122242" and others.
					this_marketing_model_name_from_specs_page="${this_marketing_model_name_from_specs_page//$'\xE2\x80\x93'/-}" # Replace any en-dashes with regular hyphens that exist in page titles like "https://support.apple.com/121955" and others.
					this_marketing_model_name_from_specs_page="${this_marketing_model_name_from_specs_page// and / or }" # Replace " and " with " or " that exists in page titles like "https://support.apple.com/112624"
					this_marketing_model_name_from_specs_page="${this_marketing_model_name_from_specs_page/ Technical Specifications/}" # Remove " Technical Specifications" that exists in page titles like "https://support.apple.com/112006"
					this_marketing_model_name_from_specs_page="${this_marketing_model_name_from_specs_page%:}" # Remove single trailing colon that will be left after removing " Technical Specifications" that exist in page titles like "https://support.apple.com/112267" and others.

					if [[ "${this_marketing_model_name_from_docs_page}" != "${this_marketing_model_name_from_specs_page}" ]]; then
						>&2 echo 'DEBUG: GOT DIFFERENT MODEL NAMES BETWEEN DOCS PAGE AND SPECS PAGE'
					fi

					if [[ "${this_device_marketing_model_name}" != "${this_marketing_model_name_from_specs_page}" ]]; then
						>&2 echo 'DEBUG: GOT DIFFERENT MODEL NAMES BETWEEN DOCS LIST AND SPECS PAGE'
					fi
				fi

				echo "${this_device_product_type}:${this_device_docs_url##*/docs/}:${this_specs_url_id:-unknown}:${this_device_marketing_model_name}:${this_marketing_model_name_from_docs_page:-UNKNOWN Marketing Model Name from Docs Page}:${this_marketing_model_name_from_specs_page:-UNKNOWN Marketing Model Name from Specs Page}:" | tee -a "${every_docs_and_specs_id_with_marketing_model_name_from_docs_pages_file_path}"
				this_device_docs_url=''
				this_device_product_type=''
				this_device_marketing_model_name=''
				this_marketing_model_name_from_docs_page=''
				this_marketing_model_name_from_specs_page=''
				this_specs_url_id=''
			fi
		done <<< "${this_docs_device_type_info}"
	done <<< "${every_docs_device_type_url}"
fi



# TODO: The following code to merge the data from the Identification and Docs pages IS NOT COMPLETE!

if [[ ! -f "${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}" || ! -f "${every_docs_and_specs_id_with_marketing_model_name_from_docs_pages_file_path}" ]]; then
	>&2 echo -e "MISSING REQUIRED FILES:\n${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}\n${every_docs_and_specs_id_with_marketing_model_name_from_docs_pages_file_path}"
	exit 4
fi

every_docs_and_specs_id_with_marketing_model_name_and_model_ids_file_path="${OUTPUT_DIR}/every_docs_and_specs_id_with_marketing_model_name_and_model_ids.txt"

if [[ -f "${every_docs_and_specs_id_with_marketing_model_name_and_model_ids_file_path}" ]]; then
	>&2 echo "ALREADY CREATED FILE: ${every_docs_and_specs_id_with_marketing_model_name_and_model_ids_file_path}"
	exit 5
fi

match_count=0
matched_lines_from_identification_pages=''

# Suppress ShellCheck warning to not read and write the same file in the same pipeline since only reading multiple times (grepping within while read).
# shellcheck disable=SC2094
while IFS=':' read -r this_product_type_from_docs_page this_docs_id_from_docs_page this_specs_id_from_docs_page this_marketing_model_name_from_docs_listing_page this_marketing_model_name_from_docs_page this_marketing_model_name_from_specs_page_via_docs_page; do
	this_line_from_docs_page="${this_product_type_from_docs_page}:${this_docs_id_from_docs_page}:${this_specs_id_from_docs_page}:${this_marketing_model_name_from_docs_listing_page}:${this_marketing_model_name_from_docs_page}:${this_marketing_model_name_from_specs_page_via_docs_page}"

	this_marketing_model_name_from_docs_listing_page_to_match="$(echo "${this_marketing_model_name_from_docs_listing_page}" | tr -dc '[:alnum:]' | tr '[:upper:]' '[:lower:]')"

	did_match_this_model=false
	possible_matches_from_identification_pages=''

	while IFS=';:' read -r this_product_type_from_identification_page this_specs_id_from_identification_page this_marketing_model_name_from_identification_page this_marketing_model_name_from_specs_page_via_identification_page these_model_identifiers_from_identification_page; do
		if [[ "${this_product_type_from_docs_page}" == "${this_product_type_from_identification_page}" ]]; then
			this_line_from_identification_page="${this_product_type_from_identification_page};${this_specs_id_from_identification_page};${this_marketing_model_name_from_identification_page}:${this_marketing_model_name_from_specs_page_via_identification_page}:${these_model_identifiers_from_identification_page%:}:"

			if [[ "${matched_lines_from_identification_pages}" != *$'\n'"${this_line_from_identification_page}"$'\n'* ]]; then
				if [[ "${this_specs_id_from_docs_page}" == "${this_specs_id_from_identification_page}" ]]; then
					possible_matches_from_identification_pages+=$'\n+\t'"${this_line_from_identification_page}"
				fi

	# 			whole_listing_dump="
	# this_product_type_from_identification_page: ${this_product_type_from_identification_page}
	# this_specs_id_from_identification_page: ${this_specs_id_from_identification_page}
	# this_marketing_model_name_from_identification_page: ${this_marketing_model_name_from_identification_page}
	# this_marketing_model_name_from_specs_page_via_identification_page: ${this_marketing_model_name_from_specs_page_via_identification_page}
	# these_model_identifiers_from_identification_page: ${these_model_identifiers_from_identification_page}
	# this_product_type_from_docs_page: ${this_product_type_from_docs_page}
	# this_docs_id_from_docs_page: ${this_docs_id_from_docs_page}
	# this_specs_id_from_docs_page: ${this_specs_id_from_docs_page}
	# this_marketing_model_name_from_docs_listing_page: ${this_marketing_model_name_from_docs_listing_page}
	# this_marketing_model_name_from_docs_page: ${this_marketing_model_name_from_docs_page}
	# this_marketing_model_name_from_specs_page_via_docs_page: ${this_marketing_model_name_from_specs_page_via_docs_page}"

				if [[ "${this_marketing_model_name_from_identification_page}" == "${this_marketing_model_name_from_docs_listing_page}" ]]; then
					did_match_this_model=true
					matched_lines_from_identification_pages+=$'\n'"${this_line_from_identification_page}"$'\n'

					echo -e "\n\nGOT EXACT MODEL NAME MATCH:
-\t${this_line_from_docs_page}
=\t${this_line_from_identification_page}"
				else
					this_marketing_model_name_from_identification_page_to_match="$(echo "${this_marketing_model_name_from_identification_page}" | tr -dc '[:alnum:]' | tr '[:upper:]' '[:lower:]')"

					if [[ "${this_marketing_model_name_from_docs_listing_page_to_match}" == "${this_marketing_model_name_from_identification_page_to_match}" ]]; then
						did_match_this_model=true
						matched_lines_from_identification_pages+=$'\n'"${this_line_from_identification_page}"$'\n'

						echo -e "\n\nGOT ALNUM MODEL NAME MATCH:
-\t${this_line_from_docs_page}
=\t${this_line_from_identification_page}"
					elif [[ "${this_specs_id_from_docs_page}" == "${this_specs_id_from_identification_page}" &&
							"$(grep -c ":${this_specs_id_from_docs_page}:" "${every_docs_and_specs_id_with_marketing_model_name_from_docs_pages_file_path}")" == '1' &&
							"$(grep -c ";${this_specs_id_from_identification_page};" "${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}")" == '1' ]]; then
						did_match_this_model=true
						matched_lines_from_identification_pages+=$'\n'"${this_line_from_identification_page}"$'\n'

						echo -e "\n\nGOT SINGLE SPECS ID MATCH:
-\t${this_line_from_docs_page}
=\t${this_line_from_identification_page}"
					fi
				fi
			fi
		fi
	done < "${every_specs_id_with_marketing_model_name_and_model_ids_from_identification_pages_file_path}"

	if $did_match_this_model; then
		(( match_count ++ ))
	elif [[ -n "${possible_matches_from_identification_pages}" ]]; then
		echo -e "\n\nDID NOT MATCH (WITH POSSIBLE MATCHES):
-\t${this_line_from_docs_page}${possible_matches_from_identification_pages}"
	else
		echo -e "\n\nDID NOT MATCH (WITH NO POSSIBLE MATCHES):
-\t${this_line_from_docs_page}"
	fi
done < "${every_docs_and_specs_id_with_marketing_model_name_from_docs_pages_file_path}"

echo -e "\n\nMATCH COUNT: ${match_count}"