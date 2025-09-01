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

# The https://support.apple.com/109509 page is also useful to identify power adapters, but it's not as specific and doesn't include Model IDs, so there's not much value in scraping it.

declare -a all_mac_identification_pages=() # All Mac identification pages are listed on https://support.apple.com/102604 as well as in the "Product or packaging" section of https://support.apple.com/102767
all_mac_identification_pages+=( '108052' ) # MacBook Pro
all_mac_identification_pages+=( '102869' ) # MacBook Air
all_mac_identification_pages+=( '103257' ) # MacBook
# all_mac_identification_pages+=( '108054' ) # iMac
# all_mac_identification_pages+=( '102852' ) # Mac mini
# all_mac_identification_pages+=( '102231' ) # Mac Studio
# all_mac_identification_pages+=( '102887' ) # Mac Pro

# NOTE: MagSafe 1 lists have older Model IDs that aren't included on the specs pages pre-included in them.
every_85w_magsafe1_model='MacBookPro1,1+MacBookPro1,2+MacBookPro2,1+MacBookPro2,2+MacBookPro3,1+MacBookPro4,1+MacBookPro5,1+'
every_60w_magsafe1_model='MacBook1,1+MacBook2,1+MacBook3,1+MacBook4,1+MacBook5,1+'
every_45w_magsafe1_model='MacBookAir1,1+'
every_85w_magsafe2_model=''
every_60w_magsafe2_model=''
every_45w_magsafe2_model=''
every_96w_usbc_model=''
every_87w_usbc_model=''
every_67w_usbc_model=''
every_61w_usbc_model=''
every_30w_usbc_model=''
every_29w_usbc_model=''

# NOTE: The newer Apple Silicon Macs with MagSafe 3 tend to support multiple different wattages with and without fast
# charge capabilities so their descriptions are not as clear and clean to analyze in code as the past power adapter types
# since the MagSafe 3 capability is listed on a separate line as just the cable and not the power adapter itself.
# So, instead of trying, just manually check the outputs and come up with more concise descriptions and pre-add them to their respective lists instead.
every_140w_magsafe3_model='MacBookPro18,1+MacBookPro18,2+Mac14,6+Mac14,10+Mac15,7+Mac15,9+Mac15,11+Mac16,7+Mac16,5+'
every_67w_or_96w_magsafe3_model='MacBookPro18,3+MacBookPro18,4+Mac14,5+Mac14,9+'
every_30w_or_35W_dp_or_70w_magsafe3_model='Mac14,2+Mac15,12+Mac16,12+'
every_35W_dp_or_70w_magsafe3_model='Mac14,15+Mac15,13+Mac16,13+'
every_70w_or_96w_magsafe3_model='Mac15,3+Mac15,6+Mac15,8+Mac15,10+Mac16,1+Mac16,6+Mac16,8+'

every_unknown_model=''

for this_mac_idenification_page in "${all_mac_identification_pages[@]}"; do
	this_mac_idenification_page_source="$(curl -m 5 -sfL "https://support.apple.com/${this_mac_idenification_page}")"

	this_model_identifier=''
	while IFS='' read -r this_model_id_or_specs_url; do
		if [[ "${this_model_id_or_specs_url}" == 'https://'* ]]; then
			echo " (${this_model_id_or_specs_url}):"
			power_adapter_elements_from_page="$(curl -m 5 -sfL "${this_model_id_or_specs_url}" | xmllint --html --xpath '//*[contains(text(),"Power Adapter") or contains(text(),"MagSafe")]' - 2> /dev/null)"
			power_adapter_elements_from_page="${power_adapter_elements_from_page//></>$'\n'<}"
			power_adapter_elements_from_page="${power_adapter_elements_from_page//; /$'\n'}"

			# Suppress ShellCheck warning to use bash string replacement since it cannot do this regex style replacement.
			# shellcheck disable=SC2001
			power_adapter_elements_from_page="$(echo "${power_adapter_elements_from_page}" | sed 's/<[^>]*>//g')"

			if [[ "${power_adapter_elements_from_page}" == *'with cable management'* ]]; then
				power_adapter_elements_from_page="$(echo "${power_adapter_elements_from_page}" | grep 'with cable management')" # Remove extraneous lines for MagSafe 2 and MagSafe 1 that aren't for the actual power adapter.
				power_adapter_elements_from_page="${power_adapter_elements_from_page% with cable management*}"
			else
				power_adapter_elements_from_page="$(echo "${power_adapter_elements_from_page}" | grep -v 'USB-C power port\|Power Adapter Extension Cable')" # Remove extraneous lines for some USB-C adapters.
				power_adapter_elements_from_page="$(echo "${power_adapter_elements_from_page}" | grep -v 'MagSafe 3 port\|MagSafe 3 charging port\|USB-C to MagSafe 3 Cable (2 m)')" # Remove extraneous lines for some MagSafe 3 adapters.
			fi

			power_adapter_elements_from_page="$(echo "${power_adapter_elements_from_page//‑/-}" | sort -u)"
			echo -e "\t${power_adapter_elements_from_page//$'\n'/$'\n\t'}"

			power_adapter_elements_from_page_lowercase="$(echo "${power_adapter_elements_from_page}" | tr '[:upper:]' '[:lower:]')"
			case "${power_adapter_elements_from_page_lowercase}" in
				'85w magsafe power adapter')
					every_85w_magsafe1_model+="${this_model_identifier}+"
					;;
				'60w magsafe power adapter')
					every_60w_magsafe1_model+="${this_model_identifier}+"
					;;
				'60w or 85w magsafe power adapter')
					if [[ "${this_model_identifier}" == 'MacBookPro5,3' || "${this_model_identifier}" == 'MacBookPro5,4' ]]; then
						# The specs pages (https://support.apple.com/kb/SP544?locale=en_US) combine MacBookPro5,3 and MacBookPro5,4 (which isn't even listed, but check for it just in case),
						# and list them both as MacBookPro5,3 even though "MacBook Pro (15-inch, 2.53 GHz, Mid 2009)" is actually MacBookPro5,4 (and not MacBookPro5,3)
						# and state "60W or 85W MagSafe Power Adapter" in the "Battery and power" section, but the table in the "15-inch Configurations" section properly shows
						# that the "2.53GHz MacBook Pro (MC118LL/A)" model (which is actually MacBookPro5,4), takes the 60W MagSafe Power Adapter while the other configurations
						# (which are the MacBookPro5,3 models) take the 85W MagSafe Power Adapter rather than both of these models being able to take either/or power adapter wattage.
						# 60W = MacBookPro5,4 / MC118LL/A: https://everymac.com/systems/apple/macbook_pro/specs/macbook-pro-core-2-duo-2.53-aluminum-15-mid-2009-sd-unibody-specs.html
						# 85W = MacBookPro5,3 / MB985LL/A: https://everymac.com/systems/apple/macbook_pro/specs/macbook-pro-core-2-duo-2.66-aluminum-15-mid-2009-sd-unibody-specs.html
						# 85W = MacBookPro5,3 / MB986LL/A: https://everymac.com/systems/apple/macbook_pro/specs/macbook-pro-core-2-duo-2.8-aluminum-15-mid-2009-sd-unibody-specs.html

						echo -e '\tMANUAL CORRECTION: MacBookPro5,4 = 60W MagSafe 1\n\tMANUAL CORRECTION: MacBookPro5,3 = 85W MagSafe 1'
						every_85w_magsafe1_model+="MacBookPro5,3+"
						every_60w_magsafe1_model+="MacBookPro5,4+"
					else
						echo -e '\tERROR: UNKNOWN Power Adater'
						every_unknown_model+="${this_model_identifier}+"
					fi
					;;
				'45w magsafe power adapter')
					every_45w_magsafe1_model+="${this_model_identifier}+"
					;;
				'85w magsafe 2 power adapter')
					every_85w_magsafe2_model+="${this_model_identifier}+"
					;;
				'60w magsafe 2 power adapter')
					every_60w_magsafe2_model+="${this_model_identifier}+"
					;;
				'45w magsafe 2 power adapter')
					every_45w_magsafe2_model+="${this_model_identifier}+"
					;;
				'96w usb-c power adapter')
					every_96w_usbc_model+="${this_model_identifier}+"
					;;
				'87w usb-c power adapter')
					every_87w_usbc_model+="${this_model_identifier}+"
					;;
				'67w usb-c power adapter')
					every_67w_usbc_model+="${this_model_identifier}+"
					;;
				'61w usb-c power adapter')
					every_61w_usbc_model+="${this_model_identifier}+"
					;;
				'30w usb-c power adapter')
					every_30w_usbc_model+="${this_model_identifier}+"
					;;
				'29w usb-c power adapter')
					every_29w_usbc_model+="${this_model_identifier}+"
					;;
				*)
					if [[ "+${every_140w_magsafe3_model}" == *"+${this_model_identifier}+"* ]]; then
						echo -e '\tMANUAL CONCISE DESCRIPTION: 140W USB-C/MagSafe 3'
					elif [[ "+${every_67w_or_96w_magsafe3_model}" == *"+${this_model_identifier}+"* ]]; then
						echo -e '\tMANUAL CONCISE DESCRIPTION: 67W or 96W USB-C/MagSafe 3'
					elif [[ "+${every_30w_or_35W_dp_or_70w_magsafe3_model}" == *"+${this_model_identifier}+"* ]]; then
						echo -e '\tMANUAL CONCISE DESCRIPTION: 30W or 35W Dual Port or 70W USB-C/MagSafe 3'
					elif [[ "+${every_35W_dp_or_70w_magsafe3_model}" == *"+${this_model_identifier}+"* ]]; then
						echo -e '\tMANUAL CONCISE DESCRIPTION: 35W Dual Port or 70W USB-C/MagSafe 3'
					elif [[ "+${every_70w_or_96w_magsafe3_model}" == *"+${this_model_identifier}+"* ]]; then
						echo -e '\tMANUAL CONCISE DESCRIPTION: 70W or 96W USB-C/MagSafe 3'
					else
						echo -e '\tERROR: UNKNOWN Power Adater'
						every_unknown_model+="${this_model_identifier}+"
					fi
					;;
			esac
		elif [[ "${this_model_id_or_specs_url}" == *','* ]]; then
			this_model_identifier="${this_model_id_or_specs_url}"
			echo -en "\n\n${this_model_identifier}"
		fi
	done < <(echo "${this_mac_idenification_page_source}" | sed s'/<\/p><p/<\/p>\n<p/g' | awk -F ':|"' '/Model Identifier:/ { gsub("&nbsp;", " ", $NF); gsub(", ", "+", $NF); gsub("; ", "+", $NF); gsub(" ", "", $NF); gsub("</b>", "", $NF); gsub("</p>", "", $NF); print ""; print $NF } /Tech Specs/ { for (f = 1; f <= NF; f ++) { if (($f ~ /support.apple.com/) && !($f ~ /\/specs$/)) { print "https:" $f; break } else if (($f ~ /^\//) && !($f ~ /\./)) { print "https://support.apple.com" $f; break } } }')
	# echo "${this_mac_idenification_page_source}" | xmllint --html --xpath '//a[contains(@href,"/kb/SP")]/@href' - 2> /dev/null | tr '"' '\n' | grep '/kb/SP' | sort -ur
done

echo -e '\n\n85W MagSafe 1'
every_85w_magsafe1_model="$(echo "${every_85w_magsafe1_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_85w_magsafe1_model//$'\n'/", "}\""

echo -e '\n60W MagSafe 1'
every_60w_magsafe1_model="$(echo "${every_60w_magsafe1_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_60w_magsafe1_model//$'\n'/", "}\""

echo -e '\n45W MagSafe 1'
every_45w_magsafe1_model="$(echo "${every_45w_magsafe1_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_45w_magsafe1_model//$'\n'/", "}\""

echo -e '\n85W MagSafe 2'
every_85w_magsafe2_model="$(echo "${every_85w_magsafe2_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_85w_magsafe2_model//$'\n'/", "}\""

echo -e '\n60W MagSafe 2'
every_60w_magsafe2_model="$(echo "${every_60w_magsafe2_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_60w_magsafe2_model//$'\n'/", "}\""

echo -e '\n45W MagSafe 2'
every_45w_magsafe2_model="$(echo "${every_45w_magsafe2_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_45w_magsafe2_model//$'\n'/", "}\""

echo -e '\n96W USB-C'
every_96w_usbc_model="$(echo "${every_96w_usbc_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_96w_usbc_model//$'\n'/", "}\""

echo -e '\n87W USB-C'
every_87w_usbc_model="$(echo "${every_87w_usbc_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_87w_usbc_model//$'\n'/", "}\""

echo -e '\n67W USB-C'
every_67w_usbc_model="$(echo "${every_67w_usbc_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_67w_usbc_model//$'\n'/", "}\""

echo -e '\n61W USB-C'
every_61w_usbc_model="$(echo "${every_61w_usbc_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_61w_usbc_model//$'\n'/", "}\""

echo -e '\n30W USB-C'
every_30w_usbc_model="$(echo "${every_30w_usbc_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_30w_usbc_model//$'\n'/", "}\""

echo -e '\n29W USB-C'
every_29w_usbc_model="$(echo "${every_29w_usbc_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_29w_usbc_model//$'\n'/", "}\""

echo -e '\n140W USB-C/MagSafe 3'
every_140w_magsafe3_model="$(echo "${every_140w_magsafe3_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_140w_magsafe3_model//$'\n'/", "}\""

echo -e '\n67W or 96W USB-C/MagSafe 3'
every_67w_or_96w_magsafe3_model="$(echo "${every_67w_or_96w_magsafe3_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_67w_or_96w_magsafe3_model//$'\n'/", "}\""

echo -e '\n30W or 35W Dual Port or 70W USB-C/MagSafe 3'
every_30w_or_35W_dp_or_70w_magsafe3_model="$(echo "${every_30w_or_35W_dp_or_70w_magsafe3_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_30w_or_35W_dp_or_70w_magsafe3_model//$'\n'/", "}\""

echo -e '\n35W Dual Port or 70W USB-C/MagSafe 3'
every_35W_dp_or_70w_magsafe3_model="$(echo "${every_35W_dp_or_70w_magsafe3_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_35W_dp_or_70w_magsafe3_model//$'\n'/", "}\""

echo -e '\n70W or 96W USB-C/MagSafe 3'
every_70w_or_96w_magsafe3_model="$(echo "${every_70w_or_96w_magsafe3_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_70w_or_96w_magsafe3_model//$'\n'/", "}\""

echo -e '\nUNKNOWN Power Adapter (REQUIRES MANUAL EXAMINATION)'
every_unknown_model="$(echo "${every_unknown_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_unknown_model//$'\n'/", "}\""

echo ''

# Example output from 5/15/25:

# 85W MagSafe 1
# "MacBookPro1,1", "MacBookPro1,2", "MacBookPro2,1", "MacBookPro2,2", "MacBookPro3,1", "MacBookPro4,1", "MacBookPro5,1", "MacBookPro5,2", "MacBookPro5,3", "MacBookPro6,1", "MacBookPro6,2", "MacBookPro8,2", "MacBookPro8,3", "MacBookPro9,1"

# 60W MagSafe 1
# "MacBook1,1", "MacBook2,1", "MacBook3,1", "MacBook4,1", "MacBook5,1", "MacBook5,2", "MacBook6,1", "MacBook7,1", "MacBookPro5,4", "MacBookPro5,5", "MacBookPro7,1", "MacBookPro8,1", "MacBookPro9,2"

# 45W MagSafe 1
# "MacBookAir1,1", "MacBookAir2,1", "MacBookAir3,1", "MacBookAir3,2", "MacBookAir4,1", "MacBookAir4,2"

# 85W MagSafe 2
# "MacBookPro10,1", "MacBookPro11,2", "MacBookPro11,3", "MacBookPro11,4", "MacBookPro11,5"

# 60W MagSafe 2
# "MacBookPro10,2", "MacBookPro11,1", "MacBookPro12,1"

# 45W MagSafe 2
# "MacBookAir5,1", "MacBookAir5,2", "MacBookAir6,1", "MacBookAir6,2", "MacBookAir7,1", "MacBookAir7,2"

# 96W USB-C
# "MacBookPro16,1", "MacBookPro16,4"

# 87W USB-C
# "MacBookPro13,3", "MacBookPro14,3", "MacBookPro15,1", "MacBookPro15,3"

# 67W USB-C
# "Mac14,7"

# 61W USB-C
# "MacBookPro13,1", "MacBookPro13,2", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro15,2", "MacBookPro15,4", "MacBookPro16,2", "MacBookPro16,3", "MacBookPro17,1"

# 30W USB-C
# "MacBook10,1", "MacBookAir8,1", "MacBookAir8,2", "MacBookAir9,1", "MacBookAir10,1"

# 29W USB-C
# "MacBook8,1", "MacBook9,1"

# 140W USB-C/MagSafe 3
# "Mac14,6", "Mac14,10", "Mac15,7", "Mac15,9", "Mac15,11", "Mac16,5", "Mac16,7", "MacBookPro18,1", "MacBookPro18,2"

# 67W or 96W USB-C/MagSafe 3
# "Mac14,5", "Mac14,9", "MacBookPro18,3", "MacBookPro18,4"

# 30W or 35W Dual Port or 70W USB-C/MagSafe 3
# "Mac14,2", "Mac15,12", "Mac16,12"

# 35W Dual Port or 70W USB-C/MagSafe 3
# "Mac14,15", "Mac15,13", "Mac16,13"

# 70W or 96W USB-C/MagSafe 3
# "Mac15,3", "Mac15,6", "Mac15,8", "Mac15,10", "Mac16,1", "Mac16,6", "Mac16,8"

# UNKNOWN Power Adapter (REQUIRES MANUAL EXAMINATION)
# ""