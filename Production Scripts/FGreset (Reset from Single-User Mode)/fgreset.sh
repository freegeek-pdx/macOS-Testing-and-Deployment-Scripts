#!/bin/bash

#
# Created by Pico Mitchell on 4/30/17.
# For MacLand @ Free Geek
# Version: 2021.12.31-1
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

readonly ADMIN_USERNAME='fg-admin'
ADMIN_PASSWORD='[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]'
readonly ADMIN_PASSWORD

readonly DEMO_USERNAME='fg-demo'

readonly CLEAR_ANSI='\033[0m' # Clears all ANSI colors and styles.
# Start ANSI colors with "0;" so they clear all previous styles for convenience in ending underline sections.
ANSI_BLACK="$([[ "$1" == 'debug_blue_log' ]] && echo '\033[0;34m' || echo '\033[0;30m')"
readonly ANSI_BLACK
readonly ANSI_RED='\033[0;31m' # Bright colors such as 91 are not supported in Single-User Mode.
readonly ANSI_GREEN='\033[0;32m'
readonly ANSI_YELLOW='\033[0;33m'
readonly ANSI_PURPLE='\033[0;35m'
readonly ANSI_CYAN='\033[0;36m'
# Do NOT start ANSI_BOLD and ANSI_UNDERLINE with "0;" so they can be combined with colors and eachother.
readonly ANSI_BOLD='\033[1m'
readonly ANSI_UNDERLINE='\033[4m'

DEBUG_MODE="$([[ "$1" == 'debug' ]] && echo 'true' || echo 'false')"
readonly DEBUG_MODE

DARWIN_MAJOR_VERSION="$(uname -r | cut -d '.' -f 1)" # 17 = 10.13, 18 = 10.14, etc.
readonly DARWIN_MAJOR_VERSION

clear

if [[ -f '/Users/Shared/.fgResetSnapshotCreated' || -f '/Users/Shared/.fgResetSnapshotLost' ]]; then
    # Still show this message even if the reset Snapshot was lost since fgreset still should not be used if the Snapshot reset was intended.
    echo -e "

    ${ANSI_YELLOW}${ANSI_UNDERLINE}T H I S   M A C   M U S T   B E   R E S E T   V I A   S N A P S H O T${ANSI_YELLOW}

    Reboot into Recovery OS by holding \"Command + R\" on boot.
    Within Recovery OS, restore the reset Snapshot using Time Machine.

    If there is an issue restoring the reset Snapshot, inform Free Geek I.T.${CLEAR_ANSI}

"
    exit 1
elif ! $DEBUG_MODE; then
    if (( DARWIN_MAJOR_VERSION != 17 && DARWIN_MAJOR_VERSION != 18 )); then
        echo -e "

    ${ANSI_YELLOW}${ANSI_UNDERLINE}C U R R E N T   O S   N O T   C O M P A T I B L E   W I T H   F G R E S E T${ANSI_YELLOW}

    \"fgreset\" is only compatible with macOS 10.13 and 10.14.${CLEAR_ANSI}


    ${ANSI_RED}!! This Mac cannot be sold and must be sent back to MacLand !!${CLEAR_ANSI}

"
        exit 1
    elif [[ -d "/Users/${DEMO_USERNAME}/Desktop/Cleanup After QA Complete.app" || -d "/Users/${DEMO_USERNAME}/Desktop/Automation Guide.app" ]]; then
        echo -e "

    ${ANSI_YELLOW}${ANSI_UNDERLINE}N O T   R E A D Y   T O   R U N   F G R E S E T${ANSI_YELLOW}

    The \"Cleanup After QA Complete\" app must be run before \"fgreset\" can be run.

    The \"Cleanup After QA Complete\" app can be launched from the Desktop
    of the \"${DEMO_USERNAME}\" account.${CLEAR_ANSI}

"
        exit 1
    elif (( $(sysctl -n kern.singleuser) == 0 )); then
        echo -e "

    ${ANSI_YELLOW}${ANSI_UNDERLINE}F G R E S E T   M U S T   R U N   I N   S I N G L E - U S E R   M O D E${ANSI_YELLOW}

    Reboot into Single-User Mode by holding \"Command + S\" on boot.
    Within Single-User Mode, re-run \"fgreset\" to prepare the OS for the customer
    and run \"Setup Assistant\" on the next boot.${CLEAR_ANSI}

"
        exit 1
    fi
fi

debug_log_and_step() {
    if $DEBUG_MODE && [[ -n "$1" ]]; then
        echo -ne "${ANSI_YELLOW}\n$1"

        if [[ -n "${2+x}" ]]; then
            echo -ne ":\n$([[ -n "$2" ]] && echo "$2" || echo 'N/A')"
        fi

        echo -ne "\nDEBUG - Press RETURN to Continue:${CLEAR_ANSI} "

        read -r
    fi
}

readonly FGRESET_HEADER="${ANSI_PURPLE}${ANSI_BOLD}
     ______    _____   _____    ______    _____   ______   _______
    |  ____|  / ____| |  __ \  |  ____|  / ____| |  ____| |__   __|
    | |__    | |  __  | |__) | | |__    | (___   | |__       | |
    |  __|   | | |_ | |  _  /  |  __|    \___ \  |  __|      | |
    | |      | |__| | | | \ \  | |____   ____) | | |____     | |
    |_|       \_____| |_|  \_\ |______| |_____/  |______|    |_|
${CLEAR_ANSI}"

fgreset_progress_display=''
bottom_of_progress_line=0

display_progress_and_hide_system_log() {
    # Reset cursor position to top of screen with ansi "\033[H" instead of using clear command (or clearing with ansi "\033[2J"),
    # because in Single-User Mode, clearing visibly blanks the screen before updating with new content, which looks bad.
    # This means that the same text keeps getting overwritten instead of being totally cleared and re-written.

    if $DEBUG_MODE; then clear; fi # clear if in DEBUG_MODE since system logs will be visible and could overlap progress text if we only reset cursor position.

    echo -e "\033[H${FGRESET_HEADER}${fgreset_progress_display}"

    if ! $DEBUG_MODE; then
        # When running any launchctl, dscl, dseditgroup, or sysadminctl commands, the system log can output warnings or errors (which are not important).
        # This system log output is displayed by the Single-User Mode console and is not captured by redirecting STDERR for these commands.
        # To hide this logging, set the text color to the background color and use prevent_scrolling_past_progress_display to stop these hidden logs from scrolling the screen.
        bottom_of_progress_line="$(( $(echo -e "${FGRESET_HEADER}${fgreset_progress_display}" | wc -l | xargs) + 1 ))"
        echo -ne "${ANSI_BLACK}"
    fi
}

prevent_scrolling_past_progress_display() {
    if ! $DEBUG_MODE; then
        # Since the hidden system logging can still scroll the screen, this function is called after each of the commands that will generate system logging to reset
        # the cursor position to the bottom of the current progress display and clear display from that point down so that logs keep starting from that point.
        echo -ne "\033[${bottom_of_progress_line}H\033[J"
    fi
}

remove_user_from_all_groups() {
    if [[ -n "$1" ]]; then
        this_user_groups="$(id -Gn "$1" 2> /dev/null)"
        for this_user_group in $this_user_groups; do
            if [[ -n "${this_user_group}" && "$(dsmemberutil checkmembership -U "$1" -G "${this_user_group}")" == 'user is a member of the group' ]]; then
                prevent_scrolling_past_progress_display
                dseditgroup_delete_user_from_some_group_output="$(dseditgroup -o edit -d "$1" -t user "${this_user_group}" 2>&1)"
                debug_log_and_step "dseditgroup_delete_user_from_some_group_output ($1 - ${this_user_group})" "${dseditgroup_delete_user_from_some_group_output}"
            fi
            prevent_scrolling_past_progress_display
        done
    fi
}

confirm_start=''
while [[ -z "${confirm_start}" ]]; do
    clear
    echo -e "${FGRESET_HEADER}"

    debug_log_and_step "! ! !   D E B U G   M O D E   E N A B L E D   ! ! !\nDARWIN_MAJOR_VERSION: ${DARWIN_MAJOR_VERSION}"

    # TODO: Add back the leading line break when we no longer need GUI fgreset.
    echo -ne "    Are you sure you want to prepare the OS for the customer
    and run \"Setup Assistant\" on the next boot?

    ${ANSI_UNDERLINE}P L E A S E   N O T E :${CLEAR_ANSI}

    - THE \"fgreset\" PROCESS CANNOT BE UNDONE!
    - The \"fgreset\" process will take around 30 seconds.
    - This Mac will be SHUT DOWN after \"fgreset\" has completed.$([[ "$(sysctl -n hw.model)" == 'MacBook'* ]] && echo -e "

    ${ANSI_UNDERLINE}I M P O R T A N T :${CLEAR_ANSI}

    - MAKE SURE THIS LAPTOP IS PLUGGED IN BEFORE STARTING THE \"fgreset\" PROCESS!")


    ${ANSI_PURPLE}To proceed, type \"freegeek\" and press RETURN.
    To cancel, type anything else and press RETURN:${CLEAR_ANSI} "
    
    read -r confirm_start
done

if [[ "$(echo "${confirm_start}" | tr '[:upper:]' '[:lower:]')" == "freegeek" ]]; then
    fgreset_progress_display+="


    ${ANSI_CYAN}${ANSI_BOLD}1 of 5:${ANSI_CYAN} Checking and Mounting File System - PLEASE WAIT, THIS MAY TAKE A MOMENT...${CLEAR_ANSI}"
    clear
    display_progress_and_hide_system_log

    fsck_output="fsck -fy:\n$(fsck -fy 2>&1)" # fsck will run fsck_apfs on APFS volumes where -f isn't implemented, but it will just be ignored.
    fsck_return="$?"
    prevent_scrolling_past_progress_display

    fsck_passed=false

    if (( fsck_return == 0 || fsck_return == 1 )); then # 0 = no errors, 1 = errors repaired.
        fsck_passed=true
    elif (( fsck_return == 65 )); then # 65 = mounted with write access.
        # If the drive is mounted with write access, just check without repairing.
        # This could happen if mounted prior to running fgreset, or if re-running fgreset after a DEBUG_MODE pass.

        fsck_output+="\n\nfsck -n:\n$(fsck -n 2>&1)"
        fsck_return="$?"
        prevent_scrolling_past_progress_display

        if (( fsck_return == 0 )); then
            fsck_passed=true
        elif (( fsck_return == 65 )) && [[ "$(echo -e "${fsck_output}" | tail -1)" == 'error: container /'*'; please re-run with -l.' ]]; then # This is an APFS drive and needs live verification mode.
            fsck_apfs_command="fsck_apfs -nl $(echo -e "${fsck_output}" | tail -1 | cut -d ' ' -f 3)"
            fsck_output+="\n\n${fsck_apfs_command}:\n$(${fsck_apfs_command} 2>&1)"
            fsck_return="$?"
            prevent_scrolling_past_progress_display

            if (( fsck_return == 0 )); then
                fsck_passed=true
            fi
        fi
    fi

    fgreset_progress_display="${fgreset_progress_display/Checking and Mounting File System - PLEASE WAIT, THIS MAY TAKE A MOMENT.../Checking and Mounting File System...\\033[K}" # Clear to the end of line since the shorter string will not overwrite the previous longer string.
    display_progress_and_hide_system_log

    if $fsck_passed && [[ "$1" != 'debug_fail_fsck' ]]; then
        mount_uw_output="$(mount -uw '/' 2>&1)"
        
        debug_log_and_step 'mount_uw_output' "${mount_uw_output}"
        prevent_scrolling_past_progress_display

        fgreset_progress_display+="

    ${ANSI_GREEN}Successfully Checked and Mounted File System${CLEAR_ANSI}


    ${ANSI_CYAN}${ANSI_BOLD}2 of 5:${ANSI_CYAN} Deleting User Accounts - PLEASE WAIT, THIS MAY TAKE A MOMENT...${CLEAR_ANSI}"
        display_progress_and_hide_system_log
        
        launchctl_load_opendirectoryd_output="$(launchctl load /System/Library/LaunchDaemons/com.apple.opendirectoryd.plist 2>&1)"
        prevent_scrolling_past_progress_display

        for dscl_list_users_attempt in {1..30}; do
            dscl_list_users_before_output="$(dscl . -list '/Users' 2> /dev/null | grep -v '^_')"
            
            if [[ -z "${dscl_list_users_before_output}" ]]; then
                prevent_scrolling_past_progress_display
                if $DEBUG_MODE; then echo "Waiting for Open Directory (Attempt $dscl_list_users_attempt)..."; fi
                # Wait and try again to make sure everything is fully loaded and ready after loading opendirectoryd
                sleep 1
            else
                debug_log_and_step 'launchctl_load_opendirectoryd_output' "${launchctl_load_opendirectoryd_output}"

                # Remove "Guest" user from list because we will attempt to delete it no matter what and don't want its existence to complicate checking for actual allowed users.
                dscl_list_users_before_output="${dscl_list_users_before_output//Guest/}"
                dscl_list_users_before_output="$(echo -e "${dscl_list_users_before_output}" | sort | xargs)"
                debug_log_and_step 'dscl_list_users_before_output' "${dscl_list_users_before_output}"
                prevent_scrolling_past_progress_display
                break
            fi
        done
        
        # Do not add "Guest" in the approved list because it's ignored from dscl_list_users_before_output
        allowed_before_usernames="$(echo -e "daemon\nnobody\nroot\n${ADMIN_USERNAME}\n${DEMO_USERNAME}" | sort -u | xargs)"
        debug_log_and_step 'allowed_before_usernames' "${allowed_before_usernames}"
        
        if [[ "${dscl_list_users_before_output}" == "${allowed_before_usernames}" ]]; then
            # For whatever reason, sysadminctl ERRORS when disabling guest and adding or deleting users IF NOT RUN WITH SUDO even though we are running as root in Single-User Mode.

            # Disable Guest in case it got enabled somehow.
            sysadminctl_disable_guest_output="$(sudo sysadminctl -guestAccount off 2>&1)"
            debug_log_and_step 'sysadminctl_disable_guest_output' "${sysadminctl_disable_guest_output}"
            prevent_scrolling_past_progress_display

            # Delete Guest in case it exists, since it can stay in the user list if enabled then disabled.
            sysadminctl_delete_guest_output="$(sudo sysadminctl -deleteUser 'Guest' 2>&1)"
            debug_log_and_step 'sysadminctl_delete_guest_output' "${sysadminctl_delete_guest_output}"
            prevent_scrolling_past_progress_display

            demo_user_uid="$(id -u "${DEMO_USERNAME}" 2> /dev/null)"
            
            # This SHOULD always work (unless DEMO_USERNAME and ADMIN_USERNAME are the same) because DEMO_USERNAME will never be last Administrator or last Secure Token User.
            # BUT, it fails 10.13 with an error about being last Administrator or last Secure Token User, even though it's not. It works on 10.14 though.
            sysadminctl_delete_demo_output="$(sudo sysadminctl -deleteUser "${DEMO_USERNAME}" 2>&1)"
            debug_log_and_step 'sysadminctl_delete_demo_output' "${sysadminctl_delete_demo_output}"
            prevent_scrolling_past_progress_display

            # Since "sudo sysadminctl -deleteUser" will fail on 10.13, do "dscl . -delete" method.
            if id "${DEMO_USERNAME}" &> /dev/null; then
                remove_user_from_all_groups "${DEMO_USERNAME}"
                
                dscl_delete_demo_user_output="$(dscl . -delete "/Users/${DEMO_USERNAME}" 2>&1)"
                debug_log_and_step 'dscl_delete_demo_user_output' "${dscl_delete_demo_user_output}"
                prevent_scrolling_past_progress_display

                # Must manually remove home folder and shared folders (deleted in next step) when a user is deleted using "dscl . -delete"
                rm -rf "/Users/${DEMO_USERNAME}"
            fi
            
            # Delete some stray files owned by DEMO_USERNAME
            rm -f '/Library/Application Support/com.apple.icloud.searchpartyd/savedConfiguration.plist'
            if [[ -n "${demo_user_uid}" ]]; then
                rm -f "/private/var/db/Spotlight/schema.${demo_user_uid}.plist"
                rm -f "/private/var/db/com.apple.xpc.launchd/disabled.${demo_user_uid}.plist"
                rm -rf "/private/var/db/mds/messages/${demo_user_uid}"
                rm -rf "/private/var/db/datadetectors/${demo_user_uid}" 2> /dev/null # Can output "Operation not permitted" errors.
            fi
            
            admin_user_uid="$(id -u "${ADMIN_USERNAME}" 2> /dev/null)"
            
            # This will fail on >= 10.13 because "sudo sysadminctl -deleteUser" won't delete last Administrator or last Secure Token User.
            # On 10.11, this will work though. If DEMO_USERNAME and ADMIN_USERNAME are the same, the previous command will have already deleted ADMIN_USERNAME, but it doesn't hurt to run and fail multiple times.
            sysadminctl_delete_admin_output="$(sudo sysadminctl -deleteUser "${ADMIN_USERNAME}" 2>&1)"
            debug_log_and_step 'sysadminctl_delete_admin_output' "${sysadminctl_delete_admin_output}"
            prevent_scrolling_past_progress_display

            # Try techniques that work on 10.13 and 10.14 (on non-T2 Macs) if ADMIN_USERNAME still exists after trying "sudo sysadminctl -deleteUser $ADMIN_USERNAME".
            if id "${ADMIN_USERNAME}" &> /dev/null; then
                # On 10.13 and 10.14 with APFS, removing ADMIN_USERNAME from "admin" group first allows the temporary Administrator (which will not have a Secure Token) to remove ADMIN_USERNAME Secure Token without error (on non-T2 Macs).
                # This is a bug that appears to have been fixed in 10.15 so the last Administrator cannot be deleted in this way on 10.15.
                # IMPORTANT: This workaround WILL NOT work on T2 Macs which store Secure Tokens in the Secure Enclave!
                # The new fg-install-os process will only allow macOS 11 Big Sur to be installed on T2 Macs, where Secure Tokens can be prevented and reset is done via Snapshot.

                # On 10.13 with HFS+, simply removing ADMIN_USERNAME from "admin" group will allow "dscl . -delete" to work.
                # And, all other group memberships are deleted because "dscl . -delete" won't remove them.
                
                remove_user_from_all_groups "${ADMIN_USERNAME}"

                # Result seems to be returned to STDERR, must redirect it to STDOUT
                syadminctl_admin_secure_token_status_output="$(sysadminctl -secureTokenStatus "${ADMIN_USERNAME}" 2>&1)"
                debug_log_and_step 'syadminctl_admin_secure_token_status_output' "${syadminctl_admin_secure_token_status_output}"
                prevent_scrolling_past_progress_display

                # On 10.13 and 10.14 with APFS, an Administrator MUST have its Secure Token removed to be able to be deleted which can only be done by another Administrator (this does not affect HFS+ 10.13 installations since they will not have Secure Tokens).
                if [[ "${syadminctl_admin_secure_token_status_output}" == *'is ENABLED for'* ]]; then
                    fgreset_progress_display="${fgreset_progress_display/Deleting User Accounts - PLEASE WAIT, THIS MAY TAKE A MOMENT.../Deleting User Accounts - PLEASE WAIT, THIS MAY TAKE A FEW MOMENTS...}"
                    display_progress_and_hide_system_log

                    # This temporary Administrator will not get a Secure Token (which is good) because it is not being created using another Administrators credentials
                    sysadminctl_create_temp_admin_output="$(sudo sysadminctl -addUser 'fg-temp' -password 'freegeek' -admin 2>&1)"
                    debug_log_and_step 'sysadminctl_create_temp_admin_output' "${sysadminctl_create_temp_admin_output}"
                    prevent_scrolling_past_progress_display

                    # This is the action that only works because of a bug on 10.13 and 10.14, but has been fixed on 10.15 (where only a Secure Token Administrator can alter other users Secure Tokens)
                    sysadminctl_turn_off_admin_secure_token_output="$(sysadminctl -secureTokenOff "${ADMIN_USERNAME}" -password "${ADMIN_PASSWORD}" -adminUser 'fg-temp' -adminPassword 'freegeek' 2>&1)"
                    debug_log_and_step 'sysadminctl_turn_off_admin_secure_token_output' "${sysadminctl_turn_off_admin_secure_token_output}"
                    prevent_scrolling_past_progress_display

                    remove_user_from_all_groups 'fg-temp'

                    # For some reason "sudo sysadminctl -deleteUser fg-temp" fails even if this temporary Administrator does not have a Secure Token is not the last Administrator
                    dscl_delete_temp_user_output="$(dscl . -delete '/Users/fg-temp' 2>&1)"
                    debug_log_and_step 'dscl_delete_temp_user_output' "${dscl_delete_temp_user_output}"
                    prevent_scrolling_past_progress_display
                        
                    # Must manually remove home folder and shared folders (deleted in next step) when a user is deleted using "dscl . -delete"
                    rm -rf '/Users/fg-temp'
                fi

                dscl_delete_admin_user_output="$(dscl . -delete "/Users/${ADMIN_USERNAME}" 2>&1)"
                debug_log_and_step 'dscl_delete_admin_user_output' "${dscl_delete_admin_user_output}"
                prevent_scrolling_past_progress_display

                # Must manually remove home folder and shared folders (deleted in next step) when a user is deleted using "dscl . -delete"
                rm -rf "/Users/${ADMIN_USERNAME}"
            fi
            
            # Delete some stray files owned by ADMIN_USERNAME
            if [[ -n "${admin_user_uid}" ]]; then
                rm -f "/private/var/db/Spotlight/schema.${admin_user_uid}.plist"
                rm -f "/private/var/db/com.apple.xpc.launchd/disabled.${admin_user_uid}.plist"
                rm -rf "/private/var/db/mds/messages/${admin_user_uid}"
                rm -rf "/private/var/db/datadetectors/${admin_user_uid}" 2> /dev/null # Can output "Operation not permitted" errors.
            fi
        fi

        dscl_list_users_after_output="$(dscl . -list '/Users' 2> /dev/null | grep -v '^_' | sort | xargs)"
        debug_log_and_step 'dscl_list_users_after_output' "${dscl_list_users_after_output}"
        prevent_scrolling_past_progress_display

        dscl_read_admin_members_after_output="$(/usr/libexec/PlistBuddy -c 'Print :dsAttrTypeStandard\:GroupMembers' /dev/stdin <<< "$(dscl -plist . -read '/Groups/admin' GroupMembers 2> /dev/null)" 2> /dev/null | awk '(($NF != "{") && ($NF != "}")) { print $NF }' | sort | xargs)"
        debug_log_and_step 'dscl_read_admin_members_after_output' "${dscl_read_admin_members_after_output}"
        prevent_scrolling_past_progress_display

        dscl_read_admin_membership_after_output="$(/usr/libexec/PlistBuddy -c 'Print :dsAttrTypeStandard\:GroupMembership' /dev/stdin <<< "$(dscl -plist . -read '/Groups/admin' GroupMembership 2> /dev/null)" 2> /dev/null | awk '(($NF != "{") && ($NF != "}")) { print $NF }' | sort | xargs)"
        debug_log_and_step 'dscl_read_admin_membership_after_output' "${dscl_read_admin_membership_after_output}"
        prevent_scrolling_past_progress_display

        dscl_read_root_user_guid_output="$(/usr/libexec/PlistBuddy -c 'Print :dsAttrTypeStandard\:GeneratedUID:0' /dev/stdin <<< "$(dscl -plist . -read '/Users/root' GeneratedUID 2> /dev/null)" 2> /dev/null)"
        debug_log_and_step 'dscl_read_root_user_guid_output' "${dscl_read_root_user_guid_output}"
        prevent_scrolling_past_progress_display
        
        allowed_after_usernames='daemon nobody root'
        allowed_after_admin_membership='root'
        allowed_after_admin_members="${dscl_read_root_user_guid_output}"
        
        debug_log_and_step 'allowed_after_usernames' "${allowed_after_usernames}"
        debug_log_and_step 'allowed_after_admin_members' "${allowed_after_admin_members}"
        debug_log_and_step 'allowed_after_admin_membership' "${allowed_after_admin_membership}"

        # Clear to the end of line since the shorter string will not overwrite the previous longer string.
        fgreset_progress_display="${fgreset_progress_display/Deleting User Accounts - PLEASE WAIT, THIS MAY TAKE A MOMENT.../Deleting User Accounts...\\033[K}"
        fgreset_progress_display="${fgreset_progress_display/Deleting User Accounts - PLEASE WAIT, THIS MAY TAKE A FEW MOMENTS.../Deleting User Accounts...\\033[K}"
        display_progress_and_hide_system_log

        if [[ "${dscl_list_users_after_output}" == "${allowed_after_usernames}" && "${dscl_read_admin_members_after_output}" == "${allowed_after_admin_members}" && "${dscl_read_admin_membership_after_output}" == "${allowed_after_admin_membership}" && "$1" != 'debug_fail_account' ]]; then
            fgreset_progress_display+="

    ${ANSI_GREEN}Successfully Deleted User Accounts${CLEAR_ANSI}


    ${ANSI_CYAN}${ANSI_BOLD}3 of 5:${ANSI_CYAN} Deleting All Shared Folders and Share Groups...${CLEAR_ANSI}"
            display_progress_and_hide_system_log

            all_share_names="$(sharing -l 2> /dev/null | grep $'name:\t\t' | cut -c 8-)"
            prevent_scrolling_past_progress_display
            IFS=$'\n' # Since names can have spaces, we only want to loop on line breaks
            for this_share_name in $all_share_names
            do
                remove_some_shared_folder_output="$(sharing -r "${this_share_name}" 2>&1)"
                debug_log_and_step "remove_some_shared_folder_output (${this_share_name})" "${remove_some_shared_folder_output}"
                prevent_scrolling_past_progress_display
            done
            unset IFS
            
            all_sharepoint_groups="$(dscl . -list '/Groups' 2> /dev/null | grep 'com.apple.sharepoint.group')"
            prevent_scrolling_past_progress_display
            for this_sharepoint_group in $all_sharepoint_groups
            do
                delete_some_sharepoint_group_output="$(dseditgroup -o delete "${this_sharepoint_group}" 2>&1)"
                debug_log_and_step "delete_some_sharepoint_group_output (${this_sharepoint_group})" "${delete_some_sharepoint_group_output}"
                prevent_scrolling_past_progress_display
            done
            
            fgreset_progress_display+="

    ${ANSI_GREEN}Successfully Deleted All Shared Folders and Share Groups${CLEAR_ANSI}


    ${ANSI_CYAN}${ANSI_BOLD}4 of 5:${ANSI_CYAN} Cleaning Up Unnecessary Files...${CLEAR_ANSI}"
            display_progress_and_hide_system_log

            # NOTES ABOUT NOT NEEDING TO CLEAR TOUCH ID FINGERPRINTS

            # Through testing, I found that Touch ID fingerprints are cleared when the users are deleted.
            # I am not sure exactly how this works internally, maybe Touch ID entries for non-existant users are allowed to be overwritten, but I tested this on both T1 and T2 Macs.
            # I tested this by filling all 5 Touch ID fingerprint slots before restoring running "fgreset" and was able to create add new Touch ID fingerprints after running
            # "fgreset" (without deleting any Touch ID fingerprint entries using "bioutil" or "xartutil") and going through Setup Assistant to create a new user.
            # It's lucky that Touch ID fingerprints do not need to be cleared in SUM since both "bioutil" and "xartutil" appear to be unusable in SUM.
            # In SUM, "bioutil" always says there are no Touch ID fingerprints and on T1 Macs, "xartutil" fails with error connecting with xART recovery service.


            rm -f '/private/etc/kcpassword' # Delete any saved auto-login password.

            # These rm -rf's still need STDERR redirected to /dev/null to not show possible "Operation not permitted" errors.
            rm -rf '/Library/Preferences/'{,.[^.],..?}* 2> /dev/null
            rm -rf '/Library/Caches/'{,.[^.],..?}* 2> /dev/null
            rm -rf '/System/Library/Caches/'{,.[^.],..?}* 2> /dev/null
            rm -rf '/private/var/vm/'{,.[^.],..?}* 2> /dev/null
            rm -rf '/private/var/folders/'{,.[^.],..?}* 2> /dev/null
            rm -rf '/private/var/tmp/'{,.[^.],..?}* 2> /dev/null
            rm -rf '/private/tmp/'{,.[^.],..?}* 2> /dev/null
            rm -rf '/.TemporaryItems/'{,.[^.],..?}* 2> /dev/null

            if [[ -d '/Users/Shared/Build Info' ]]; then
                rm -f '/Users/Shared/Build Info/'{.[^.],..?}* # Delete any HIDDEN flag FILES in the Build Info folder.
                chown -R 501:20 '/Users/Shared/Build Info' # Make sure the customer Administrator owns the Build Info folder.
            fi

            rm -f '/Users/Shared/'{,.[^.],..?}* 2> /dev/null # Delete any FILES (not folders) in the Shared folder (and ignore errors about not deleting directories).

            rm -f '/usr/local/bin/memtest'
            rm -f '/Applications/memtest'
            
            rm -f '/Applications/memtest_osx'

            if ! nvram 'EnableTRIM' &> /dev/null # DO NOT clear NVRAM if TRIM has been enabled on Catalina with "trimforce enable" because clearing NVRAM will undo it. (The TRIM flag is not stored in NVRAM before Catalina.)
            then
                clear_nvram_output="$(nvram -c 2>&1)"
                debug_log_and_step 'clear_nvram_output' "${clear_nvram_output}"
            fi

            set_computer_name_output="$(scutil --set ComputerName '' 2>&1)"
            debug_log_and_step 'set_computer_name_output' "${set_computer_name_output}"
            
            set_local_host_name_output="$(scutil --set LocalHostName '' 2>&1)"
            debug_log_and_step 'set_local_host_name_output' "${set_local_host_name_output}"

            fgreset_progress_display+="

    ${ANSI_GREEN}Successfully Cleaned Up Unnecessary Files


    ${ANSI_CYAN}${ANSI_BOLD}5 of 5:${ANSI_CYAN} Setting Mac to Run \"Setup Assistant\" on Next Boot...${CLEAR_ANSI}"
            display_progress_and_hide_system_log

            rm -f '/private/var/db/.AppleSetupDone'
            touch '/private/var/db/.RunLanguageChooserToo'
            chown 0:0 '/private/var/db/.RunLanguageChooserToo' # Make sure this file is properly owned by root:wheel.
            
            if [[ ! -f '/private/var/db/.AppleSetupDone' && -f '/private/var/db/.RunLanguageChooserToo' && "$1" != 'debug_fail_setup' ]]; then
                fgreset_progress_display+="

    ${ANSI_GREEN}Successfully Set Mac to Run \"Setup Assistant\" on Next Boot"
                display_progress_and_hide_system_log

                if $DEBUG_MODE; then
                    echo -e "


    ${ANSI_GREEN}F G R E S E T   C O M P L E T E D   I N   D E B U G   M O D E${CLEAR_ANSI}

"
                else
                    sleep 3
                    
                    clear
                    echo -ne "${ANSI_GREEN}${ANSI_BOLD}
     ______    _____   _____    ______    _____   ______   _______       _____    ____    __  __   _____    _        ______   _______   ______   _
    |  ____|  / ____| |  __ \  |  ____|  / ____| |  ____| |__   __|     / ____|  / __ \  |  \/  | |  __ \  | |      |  ____| |__   __| |  ____| | |
    | |__    | |  __  | |__) | | |__    | (___   | |__       | |       | |      | |  | | | \  / | | |__) | | |      | |__       | |    | |__    | |
    |  __|   | | |_ | |  _  /  |  __|    \___ \  |  __|      | |       | |      | |  | | | |\/| | |  ___/  | |      |  __|      | |    |  __|   | |
    | |      | |__| | | | \ \  | |____   ____) | | |____     | |       | |____  | |__| | | |  | | | |      | |____  | |____     | |    | |____  |_|
    |_|       \_____| |_|  \_\ |______| |_____/  |______|    |_|        \_____|  \____/  |_|  |_| |_|      |______| |______|    |_|    |______| (_)
${ANSI_GREEN}

    T H I S   M A C   I S   N O W   R E A D Y   F O R   I T S   N E W   O W N E R !



    ${ANSI_PURPLE}Press RETURN to shut this Mac down:${ANSI_BLACK} "
                    
                    read -r completed
                    
                    if  [[ "${completed}" != 'continue' ]]; then
                        rm -rf '/usr/local/bin' # This folder was only made for memtest and fgreset symlinks
                        rm -f '/Applications/fgreset'

                        clear
                        echo -ne "

    ${ANSI_CYAN}Shutting down this Mac...${ANSI_BLACK}" # Hide shutdown output (which isn't all hidden by redirecting to /dev/null).
                        shutdown -h now &> /dev/null
                    fi
                fi

                exit 0
            else
                echo -e "

    ${ANSI_RED}${ANSI_UNDERLINE}ERROR: Failed to Set Mac to Run \"Setup Assistant\" on Next Boot${ANSI_RED}


    !! This Mac cannot be sold and must be sent back to MacLand !!${CLEAR_ANSI}

"
                exit 2
            fi
        else
            echo -e "
${ANSI_YELLOW}>> USER ACCOUNTS DEBUG INFO >>

dscl_list_users_before_output:
${dscl_list_users_before_output}

allowed_after_usernames:
${allowed_after_usernames}

allowed_after_admin_members:
${allowed_after_admin_members}

allowed_after_admin_membership:
${allowed_after_admin_membership}

dscl_list_users_after_output:
${dscl_list_users_after_output}

dscl_read_admin_members_after_output:
${dscl_read_admin_members_after_output}

dscl_read_admin_membership_after_output:
${dscl_read_admin_membership_after_output}

${ADMIN_USERNAME} Secure Token Status:
$(sysadminctl -secureTokenStatus "${ADMIN_USERNAME}" 2>&1)

${DEMO_USERNAME} Secure Token Status:
$(sysadminctl -secureTokenStatus "${DEMO_USERNAME}" 2>&1)

<< USER ACCOUNTS DEBUG INFO <<


    ${ANSI_RED}${ANSI_UNDERLINE}ERROR: All User Accounts Were Not Deleted${ANSI_RED}

    !! See \"USER ACCOUNTS DEBUG INFO\" above for more details !!


    !! This Mac cannot be sold and must be sent back to MacLand !!${CLEAR_ANSI}

"
            exit 3
        fi
    else
        echo -e "
${ANSI_YELLOW}>> FILE SYSTEM CHECK OUTPUT >>

${fsck_output}

<< FILE SYSTEM CHECK OUTPUT <<


    ${ANSI_RED}${ANSI_UNDERLINE}ERROR: Issue With Internal Drive or OS Installation${ANSI_RED}

    !! See \"FILE SYSTEM CHECK OUTPUT\" above for more details !!


    !! This Mac cannot be sold and must be sent back to MacLand !!${CLEAR_ANSI}

"
        exit 4
    fi
else
    clear
    echo -e "

    ${ANSI_YELLOW}${ANSI_UNDERLINE}F G R E S E T   C A N C E L E D${ANSI_YELLOW}

    You did not type \"freegeek\" so \"fgreset\" will not be run.${CLEAR_ANSI}

"
    exit 5
fi
