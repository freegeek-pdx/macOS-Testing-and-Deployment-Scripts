#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell (of Free Geek) on 5/30/23.
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

PATH='/usr/bin:/bin:/usr/sbin:/sbin'

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"
readonly SCRIPT_DIR

# The goal of this script is to combine Intel Mac Marketing Model Names with Model IDs (which are not always unique for each Marketing Model Name) and Serial Number Configuration Codes (which are unique for each Marketing Model Name).
# A Configuration Code is the last 3 characters of 11 character serials and the last 4 characters of 12 character serials.

# The following Intel Mac Model IDs within the "every_intel_mac_model_id_with_known_serial_config_codes" variable come from combining unique values from the "SupportedModelProperties" array within every
# "/System/Library/CoreServices/PlatformSupport.plist" file from Mac OS X 10.7 Lion through macOS 13 Ventura since those Model IDs are only for Intel Macs since Apple Silicon Mac support is checked in a different way.
# But, since Mac OS X 10.6 Snow Leopard and earlier did not have this "PlatformSupport.plist" file to analyze, 6 of the earliest Intel Mac Model IDs were missing: iMac4,1 iMac4,2 MacBook1,1 MacBookPro1,1 MacBookPro1,2 Macmini1,1
# Those 6 earliest Intel Mac Model IDs were collected from the "/System/Library/PrivateFrameworks/ServerInformation.framework/Versions/A/Resources/en.lproj/SIMachineAttributes.plist" file and verified/cross-referenced using Mactracker.
# The "SIMachineAttributes.plist" file was NOT used for the whole listing since that also includes some PowerPC models and also does not include some of the last Intel Mac models.
# So, the following list of Intel Mac Model IDs all come from original Apple source lists from within the macOS, and this list is static and will never change since there will never be any new Intel Macs.

# Most of the Config Codes included after each Model ID in the "every_intel_mac_model_id_with_known_serial_config_codes" variable come from logged specs info for Macs that were refurbished at Free Geek.
# This means we know for a fact that these Config Codes are associated with these Model IDs from actual Macs and are not based on any outside sources.
# But, a handful of models have never come through Free Geek, so those models were searched on eBay to find listing that had pictures which include both a Model ID and Serial Number to include a known Config Code that is associated with that Model ID.

# But still, there are a few models that have never come through Free Geek, and that I could not find eBay listings for that had pictures containing both the Model ID and Serial Number.
# The following models are the ones that I could not independently verify, but I am still confident the associated config codes below are accurate for these Marketing Model Names,
# since all except the "MacPro5,1" are models where the same Model ID was never used for multiple Marketing Model Name.
# Since at least one config code for these Model IDs and Marketing Model Names MUST be included in the "every_intel_mac_model_id_with_known_serial_config_codes" variable for them not to be omitted from the output,
# I manually added the following config codes which I copied from the "every_mac_marketing_model_name_with_grouped_serial_config_codes.txt" for each of these missing Model IDs and Marketing Model Names:
	# iMac4,2 "iMac (17-inch, Mid 2006)": V2H
	# iMac20,1 & iMac20,2 "iMac (Retina 5K, 27-inch, 2020)": 046L & PNRJ
	# MacBookPro16,3 "MacBook Pro (13-inch, 2020, Two Thunderbolt 3 ports)": 0056
	# MacBookPro16,4 "MacBook Pro (16-inch, 2019)": 0051
	# MacPro5,1 "Mac Pro Server (Mid 2010)": HPW
	# MacPro5,1 "Mac Pro Server (Mid 2012)": F4MF

every_intel_mac_model_id_with_known_serial_config_codes='iMac4,1:U2N:U2P:U2R:U2S:V4Q:V66:VGM:
iMac4,2:V2H:
iMac5,1:AC1:VUV:VUW:VUX:VUY:WRS:WRW:WRX:
iMac5,2:WH4:WH5:WRQ:
iMac6,1:VGN:VGP:WSG:XA6:
iMac7,1:X8A:X85:X86:X87:X88:X89:ZCT:ZCV:
iMac8,1:0KM:0N4:2PN:28A:ZE2:ZE3:ZE4:ZE5:ZE6:ZE7:
iMac9,1:0TF:0TG:0TH:0TJ:0TL:0TM:6MJ:6X0:6X1:6X2:8TT:250:259:E86:
iMac10,1:5PC:5PE:5PK:5PM:B9S:B9U:DMY:H9R:
iMac11,1:5PJ:5RU:D4V:DMZ:
iMac11,2:DAS:DB7:DNM:DNN:
iMac11,3:DB5:DB6:DNP:DNR:GRQ:GXU:
iMac12,1:DHJF:DHJN:DHJR:DHJT:DKL9:
iMac12,2:DHJP:DHJQ:DHJV:DHJW:DMW8:DWTR:
iMac13,1:DNCR:DNCT:DNML:DNMM:FC6M:FC6N:FC6P:
iMac13,2:DNCV:DNCW:DNMN:DNMP:F29N:FFM8:FFMM:FFMN:
iMac13,3:FFYV:
iMac14,1:F8J2:F8J7:FQMV:
iMac14,2:F8J4:F8J5:F8J9:F8JC:FLHH:FQPG:
iMac14,3:F8J3:F8J8:FQMW:
iMac14,4:FY0T:FY0V:G5W4:
iMac15,1:FY6F:FY10:FY11:FY13:FY14:GDR6:
iMac16,1:GF1J:GF1L:H0N6:
iMac16,2:GG7D:GG77:GG78:H0P6:H0P7:HYGQ:
iMac17,1:GG7J:GG7L:GG7N:GG7V:GQ18:H3GQ:
iMac18,1:07DW:H7JY:H7VF:
iMac18,2:J1G5:J1G6:J1G9:J1GC:
iMac18,3:J1GG:J1GH:J1GJ:J1GN:J1GQ:
iMac19,1:JV3N:
iMac19,2:JWF1:
iMac20,1:046L:
iMac20,2:PNRJ:
iMacPro1,1:HX87:
MacBook1,1:U9B:U9C:U9D:U9E:VMM:VMN:WBV:WE7:
MacBook2,1:WGK:WGL:WGM:WGN:WGP:WGQ:WGT:X6H:X6J:X97:X98:YA2:YA3:YA4:YA5:YA7:YA8:YA9:YQ7:YQ8:YX1:Z5V:Z5W:Z5X:Z5Y:Z5Z:Z60:ZA8:ZA9:
MacBook3,1:0HB:0HC:Z62:Z63:Z64:Z66:
MacBook4,1:0P0:0P1:0P2:0P5:0P6:1QA:3VY:5HS:
MacBook5,1:1AQ:1AX:1B0:1B5:6KJ:7WU:8QR:8QS:8QT:8QU:56K:
MacBook5,2:4R1:4R3:9GU:
MacBook6,1:8PW:8PX:CJ6:FYN:
MacBook7,1:F5W:F5X:GST:
MacBook8,1:FWW4:GCN3:GCN4:GF84:GF85:GKK3:
MacBook9,1:GTHV:GTHY:GTJ2:H3QX:
MacBook10,1:HH22:HH24:HH29:
MacBookAir1,1:Y51:
MacBookAir2,1:5LA:9A5:9A7:22E:
MacBookAir3,1:DDQW:DDQX:DDQY:DDR0:DJDL:
MacBookAir3,2:DDR1:DDR2:DDR3:DDR4:DJ5F:DJ5G:DJDK:
MacBookAir4,1:DJY8:DJY9:DJYC:DJYD:DRHF:DTJW:DWWM:DWWN:
MacBookAir4,2:DJWQ:DJWR:DJWT:DJWV:DRQ4:DTJT:
MacBookAir5,1:DRV6:DRV7:DRV9:F56C:F57H:F67K:F569:
MacBookAir5,2:DRVC:DRVD:DRVF:DRVG:F5MW:F56D:F56F:F56J:F57J:F67P:
MacBookAir6,1:F5N7:F5N8:F5YV:F5YW:FH51:FKYN:FKYP:G4FY:G4H0:G5RK:G5RL:G083:G084:
MacBookAir6,2:F5V7:F5V8:F6T5:F6T6:FH53:FKYQ:FLCG:FM74:FMRL:FMRY:FN40:FP2P:G2CC:G2CD:G4H1:G4H2:G5RN:G5RP:G5RQ:G085:G086:
MacBookAir7,1:GFWK:GFWL:GFWM:GFWN:GFWP:GKJY:
MacBookAir7,2:G940:G941:G942:G943:G944:GKJV:GM38:GMC3:H3QD:H3QF:H3QJ:H3QK:H569:J1WK:J1WL:J1WT:J1WV:J8XH:
MacBookAir8,1:JK7D:JK7P:JK77:
MacBookAir8,2:LYWG:LYWH:LYWK:LYWR:
MacBookAir9,1:MNHP:MNHX:MNHY:
MacBookPro1,1:VJ0:VJ1:VJ3:VWW:VWX:VWY:VWZ:WBJ:
MacBookPro1,2:THY:
MacBookPro2,1:W0J:X6C:
MacBookPro2,2:W0G:W0H:W0K:W0L:X2F:X6A:X6B:
MacBookPro3,1:0S3:X91:X92:X94:XA9:XAG:XAH:YAL:YAM:
MacBookPro4,1:1EM:1Q3:1XR:1XW:3DD:6CT:YJX:YJY:YJZ:YK0:YP3:YP4:
MacBookPro5,1:1G0:1GA:1GN:6GN:6HZ:6J2:6J5:8Q1:71A:71C:
MacBookPro5,2:2QP:2QT:7AP:8YA:8YB:91T:
MacBookPro5,3:64B:64C:642:644:AMM:B22:
MacBookPro5,4:7XJ:7XK:
MacBookPro5,5:66D:66E:66H:66J:
MacBookPro6,1:DC7C:DC79:DD6Y:DHYC:
MacBookPro6,2:AGU:AGV:AGW:AGX:AGY:AGZ:GD6:GPH:HE6:
MacBookPro7,1:ATM:ATN:ATP:ATQ:GRL:
MacBookPro8,1:DH2G:DH2H:DH2L:DH2M:DRJ7:DRJ9:DRJJ:DRJK:DV13:DV14:DV16:DV17:DVHJ:DVHK:
MacBookPro8,2:DF8V:DF8X:DF8Y:DF91:DMDG:DMGG:DRJC:DRJD:DRJF:DRJL:DRJM:DV7L:DV7M:DV7N:DV7P:DVHL:DVHM:DW47:DY1N:
MacBookPro8,3:DF92:DF93:DMGH:DRJG:DRJH:DRJN:DV11:DVHN:DW48:
MacBookPro9,1:DV33:DV35:F1G3:F1G4:F2J4:F5Y7:F5YF:F5YP:F24T:FCQT:
MacBookPro9,2:DTY3:DTY4:DV30:DV31:F4JL:F5WV:F5WW:F5Y3:F447:FCMM:FYGC:
MacBookPro10,1:DKQ1:DKQ2:DKQ4:DKQ5:F6F3:F6L9:F9F2:F51R:F69W:F69Y:FCQ3:FFT0:FFT1:FFT2:FFT3:FFT4:FG1H:
MacBookPro10,2:DR53:DR54:DR55:F775:FFRP:FFRR:FGM8:FGN6:
MacBookPro11,1:FGYY:FH00:FH01:FH02:FH03:FH04:FH05:FT4V:FTPH:G3QH:G3QJ:G3QK:G3QL:G3QR:G3QT:G9FR:G96Y:G970:G971:G972:
MacBookPro11,2:FD56:FD58:FRG2:FTPR:G3QC:G3QN:G973:
MacBookPro11,3:FD57:FD59:FR1M:G3QD:G3QG:G3QP:G974:
MacBookPro11,4:G8WL:G8WN:GP4H:GQ62:
MacBookPro11,5:G8WM:G8WP:G8WQ:GP4J:
MacBookPro12,1:FVH3:FVH4:FVH5:FVH6:FVH7:FVH8:FVH9:GKJG:GKJM:
MacBookPro13,1:GVC1:GVC8:HV5G:
MacBookPro13,2:GTDX:GTFJ:GYFH:HF1R:HF1T:
MacBookPro13,3:GTDY:GTF1:GTFL:GTFM:H03M:H03Q:H03T:H03Y:H040:
MacBookPro14,1:HV2D:HV2F:HV2H:HV2J:HV22:HV29:J9JM:J9K9:JJ3D:
MacBookPro14,2:HV2L:HV2M:HV2P:HV2Q:HV2R:HV2T:HV2V:HV2W:J9J7:
MacBookPro14,3:HTD5:HTD6:HTD8:HTD9:HTDC:HTDD:HTDF:HTDG:HTDH:
MacBookPro15,1:JG5H:JG5J:JG5K:JG5M:JGH5:JGH7:JGH8:LVCF:LVDQ:
MacBookPro15,2:JHC8:JHCF:JHD2:JHD3:JHD4:JHD5:LVDL:
MacBookPro15,3:JGH8:LVDV:
MacBookPro15,4:L410:L411:
MacBookPro16,1:MD6M:MD6N:
MacBookPro16,2:ML87:
MacBookPro16,3:0056:
MacBookPro16,4:0051:
Macmini1,1:U36:U38:U39:VJN:W0A:W0B:WKN:
Macmini2,1:YL1:YL2:YL4:
Macmini3,1:1BU:1BV:9G5:9G6:9G7:9G8:19X:19Y:B9X:
Macmini4,1:DD6H:DD6K:DD6L:DDVN:
Macmini5,1:DJD0:DJD2:
Macmini5,2:DJD1:DJD3:
Macmini5,3:DKDJ:
Macmini6,1:DWYL:DY3G:F9VV:FD9G:
Macmini6,2:DWYM:DWYN:DY3H:DY3J:F9VW:
Macmini7,1:G1HV:G1HW:G1HY:G1J0:G1J1:G1J2:
Macmini8,1:JYVW:JYVY:PJH8:
MacPro1,1:0GN:UPZ:UQ2:WS4:
MacPro2,1:UPZ:
MacPro3,1:XYK:XYL:
MacPro4,1:4PC:4PD:20G:20H:
MacPro5,1:EUE:EUF:EUG:EUH:F4MC:F4MD:F4MG:F4MH:F648:GWR:HPW:F4MF:
MacPro6,1:F9VM:F9VN:
MacPro7,1:K7GF:N5RN:
Xserve1,1:V2Q:
Xserve2,1:X8S:
Xserve3,1:6HS:'

every_mac_marketing_model_name_with_grouped_serial_config_codes_file_path="${SCRIPT_DIR}/every_mac_marketing_model_name_with_grouped_serial_config_codes.txt" # This file is generated from the "get_every_apple_serial_config_code.sh" script.

if [[ -f "${every_mac_marketing_model_name_with_grouped_serial_config_codes_file_path}" ]]; then
	# Get Marketing Model Names for each Model ID based on the KNOWN Config Codes for that Model ID since one Model ID may be associated with multiple Marketing Model Names.
	every_marketing_model_name_with_model_id=''
	while IFS=':' read -ra this_model_id_and_known_serial_config_codes; do
		this_model_id="${this_model_id_and_known_serial_config_codes[0]}"
		for this_known_serial_config_code in "${this_model_id_and_known_serial_config_codes[@]:1}"; do
			while IFS=':' read -r this_marketing_model_name these_serial_config_codes; do
				if [[ ":${these_serial_config_codes}:" == *":${this_known_serial_config_code}:"* ]]; then
					every_marketing_model_name_with_model_id+=$'\n'"${this_marketing_model_name}:${this_model_id}"
					break
				fi
			done < "${every_mac_marketing_model_name_with_grouped_serial_config_codes_file_path}"
		done
	done <<< "${every_intel_mac_model_id_with_known_serial_config_codes}"

	# Group the Model IDs together for each unique Marketing Model Name.
	every_marketing_model_name_with_grouped_model_ids=''
	previous_marketing_model_name=''
	while IFS=':' read -r this_marketing_model_name this_model_id; do
		if [[ "${this_marketing_model_name}" != "${previous_marketing_model_name}" ]]; then
			every_marketing_model_name_with_grouped_model_ids+=$'\n'"${this_marketing_model_name}:${this_model_id}:"
			previous_marketing_model_name="${this_marketing_model_name}"
		else
			every_marketing_model_name_with_grouped_model_ids+="${this_model_id}:"
		fi
	done < <(echo "${every_marketing_model_name_with_model_id}" | grep '.' | sort -uf)

	# For Marketing Model Names which DON'T have unique Model IDs, add ALL Config Codes to the row after with the associated Model IDs.
	every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes=''
	while IFS=':' read -ra this_marketing_model_name_and_model_ids; do
		this_marketing_model_name="${this_marketing_model_name_and_model_ids[0]}"
		model_id_has_multiple_marketing_model_names=false
		for this_model_id in "${this_marketing_model_name_and_model_ids[@]:1}"; do
			if [[ "${this_model_id}" == 'MacPro4,1' ]] || (( $(echo "${every_marketing_model_name_with_grouped_model_ids}" | grep -c ":${this_model_id}:") > 1 )); then
				# Always inluding Config Codes for "MacPro4,1" since they are commonly flash to "MacPro5,1" to allow OS upgrades but the Config Code wouldn't properly match any of the "MacPro5,1" Config Codes.
				model_id_has_multiple_marketing_model_names=true
				break
			fi
		done

		if $model_id_has_multiple_marketing_model_names; then
			while IFS=':' read -r that_marketing_model_name these_serial_config_codes; do
				if [[ "${this_marketing_model_name}" == "${that_marketing_model_name}" ]]; then
					every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes+=$'\n'"$(printf '%s:' "${this_marketing_model_name_and_model_ids[@]}")${these_serial_config_codes}"
					break
				fi
			done < "${every_mac_marketing_model_name_with_grouped_serial_config_codes_file_path}"
		else
			every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes+=$'\n'"$(printf '%s:' "${this_marketing_model_name_and_model_ids[@]}")"
		fi
	done < <(echo "${every_marketing_model_name_with_grouped_model_ids}" | grep '.')

	# Cleanup funky Marketing Model Names (making small tweaks to make things more consistent among all model names).
	every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes="${every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes//original/Original}" # MacBook Pro (original) > MacBook Pro (Original)
	every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes="${every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes//-inch /-inch, }" # MacBook Pro (15-inch Core 2 Duo) > MacBook Pro (15-inch, Core 2 Duo) - AND OTHERS
	every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes="${every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes//  / }" # MacBook Pro (15-inch,  2.4 2.2GHz) > MacBook Pro (15-inch, 2.4 2.2GHz)
	every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes="${every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes//2.4 2.2GHz/2.4/2.2GHz}" # MacBook Pro (15-inch, 2.4 2.2GHz) > MacBook Pro (15-inch, 2.4/2.2GHz)
	every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes="${every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes//GHZ/GHz}" # MacBook Pro (17-inch, 2.4GHZ) > MacBook Pro (17-inch, 2.4GHz)

	echo "${every_marketing_model_name_with_grouped_model_ids_and_serial_config_codes}" | sort -f | grep '.' | tee "${SCRIPT_DIR}/every_intel_mac_marketing_model_name_with_grouped_model_ids_and_serial_config_codes.txt"

	# The following lists of Model IDs for different OS support are directly from combining the Model IDs in the "PlatformSupport.plist" file for the specified OS version and newer.
	# el_capitan_and_newer_supported_model_ids=( 'iMac7,1' 'iMac8,1' 'iMac9,1' 'iMac10,1' 'iMac11,1' 'iMac11,2' 'iMac11,3' 'iMac12,1' 'iMac12,2' 'iMac13,1' 'iMac13,2' 'iMac13,3' 'iMac14,1' 'iMac14,2' 'iMac14,3' 'iMac14,4' 'iMac15,1' 'iMac16,1' 'iMac16,2' 'iMac17,1' 'iMac18,1' 'iMac18,2' 'iMac18,3' 'iMac19,1' 'iMac19,2' 'iMac20,1' 'iMac20,2' 'iMacPro1,1' 'MacBook5,1' 'MacBook5,2' 'MacBook6,1' 'MacBook7,1' 'MacBook8,1' 'MacBook9,1' 'MacBook10,1' 'MacBookAir2,1' 'MacBookAir3,1' 'MacBookAir3,2' 'MacBookAir4,1' 'MacBookAir4,2' 'MacBookAir5,1' 'MacBookAir5,2' 'MacBookAir6,1' 'MacBookAir6,2' 'MacBookAir7,1' 'MacBookAir7,2' 'MacBookAir8,1' 'MacBookAir8,2' 'MacBookAir9,1' 'MacBookPro3,1' 'MacBookPro4,1' 'MacBookPro5,1' 'MacBookPro5,2' 'MacBookPro5,3' 'MacBookPro5,4' 'MacBookPro5,5' 'MacBookPro6,1' 'MacBookPro6,2' 'MacBookPro7,1' 'MacBookPro8,1' 'MacBookPro8,2' 'MacBookPro8,3' 'MacBookPro9,1' 'MacBookPro9,2' 'MacBookPro10,1' 'MacBookPro10,2' 'MacBookPro11,1' 'MacBookPro11,2' 'MacBookPro11,3' 'MacBookPro11,4' 'MacBookPro11,5' 'MacBookPro12,1' 'MacBookPro13,1' 'MacBookPro13,2' 'MacBookPro13,3' 'MacBookPro14,1' 'MacBookPro14,2' 'MacBookPro14,3' 'MacBookPro15,1' 'MacBookPro15,2' 'MacBookPro15,3' 'MacBookPro15,4' 'MacBookPro16,1' 'MacBookPro16,2' 'MacBookPro16,3' 'MacBookPro16,4' 'Macmini3,1' 'Macmini4,1' 'Macmini5,1' 'Macmini5,2' 'Macmini5,3' 'Macmini6,1' 'Macmini6,2' 'Macmini7,1' 'Macmini8,1' 'MacPro3,1' 'MacPro4,1' 'MacPro5,1' 'MacPro6,1' 'MacPro7,1' 'Xserve3,1' )
	# high_sierra_and_newer_supported_model_ids=( 'iMac10,1' 'iMac11,1' 'iMac11,2' 'iMac11,3' 'iMac12,1' 'iMac12,2' 'iMac13,1' 'iMac13,2' 'iMac13,3' 'iMac14,1' 'iMac14,2' 'iMac14,3' 'iMac14,4' 'iMac15,1' 'iMac16,1' 'iMac16,2' 'iMac17,1' 'iMac18,1' 'iMac18,2' 'iMac18,3' 'iMac19,1' 'iMac19,2' 'iMac20,1' 'iMac20,2' 'iMacPro1,1' 'MacBook6,1' 'MacBook7,1' 'MacBook8,1' 'MacBook9,1' 'MacBook10,1' 'MacBookAir3,1' 'MacBookAir3,2' 'MacBookAir4,1' 'MacBookAir4,2' 'MacBookAir5,1' 'MacBookAir5,2' 'MacBookAir6,1' 'MacBookAir6,2' 'MacBookAir7,1' 'MacBookAir7,2' 'MacBookAir8,1' 'MacBookAir8,2' 'MacBookAir9,1' 'MacBookPro6,1' 'MacBookPro6,2' 'MacBookPro7,1' 'MacBookPro8,1' 'MacBookPro8,2' 'MacBookPro8,3' 'MacBookPro9,1' 'MacBookPro9,2' 'MacBookPro10,1' 'MacBookPro10,2' 'MacBookPro11,1' 'MacBookPro11,2' 'MacBookPro11,3' 'MacBookPro11,4' 'MacBookPro11,5' 'MacBookPro12,1' 'MacBookPro13,1' 'MacBookPro13,2' 'MacBookPro13,3' 'MacBookPro14,1' 'MacBookPro14,2' 'MacBookPro14,3' 'MacBookPro15,1' 'MacBookPro15,2' 'MacBookPro15,3' 'MacBookPro15,4' 'MacBookPro16,1' 'MacBookPro16,2' 'MacBookPro16,3' 'MacBookPro16,4' 'Macmini4,1' 'Macmini5,1' 'Macmini5,2' 'Macmini5,3' 'Macmini6,1' 'Macmini6,2' 'Macmini7,1' 'Macmini8,1' 'MacPro5,1' 'MacPro6,1' 'MacPro7,1' )
	# catalina_and_newer_supported_model_ids=( 'iMac13,1' 'iMac13,2' 'iMac13,3' 'iMac14,1' 'iMac14,2' 'iMac14,3' 'iMac14,4' 'iMac15,1' 'iMac16,1' 'iMac16,2' 'iMac17,1' 'iMac18,1' 'iMac18,2' 'iMac18,3' 'iMac19,1' 'iMac19,2' 'iMac20,1' 'iMac20,2' 'iMacPro1,1' 'MacBook8,1' 'MacBook9,1' 'MacBook10,1' 'MacBookAir5,1' 'MacBookAir5,2' 'MacBookAir6,1' 'MacBookAir6,2' 'MacBookAir7,1' 'MacBookAir7,2' 'MacBookAir8,1' 'MacBookAir8,2' 'MacBookAir9,1' 'MacBookPro9,1' 'MacBookPro9,2' 'MacBookPro10,1' 'MacBookPro10,2' 'MacBookPro11,1' 'MacBookPro11,2' 'MacBookPro11,3' 'MacBookPro11,4' 'MacBookPro11,5' 'MacBookPro12,1' 'MacBookPro13,1' 'MacBookPro13,2' 'MacBookPro13,3' 'MacBookPro14,1' 'MacBookPro14,2' 'MacBookPro14,3' 'MacBookPro15,1' 'MacBookPro15,2' 'MacBookPro15,3' 'MacBookPro15,4' 'MacBookPro16,1' 'MacBookPro16,2' 'MacBookPro16,3' 'MacBookPro16,4' 'Macmini6,1' 'Macmini6,2' 'Macmini7,1' 'Macmini8,1' 'MacPro6,1' 'MacPro7,1' )
	# TODO: Maybe make new lists that are only for El Capitan, High Sierra, and Catalina and newer to not include models that will never be seen in code that only runs on those versions of macOS.
else
	>&2 echo "MISSING REQUIRED FILE: ${every_mac_marketing_model_name_with_grouped_serial_config_codes_file_path}"
fi