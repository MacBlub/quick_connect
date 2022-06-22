#!/usr/bin/env bash

set -e

HELP="quick_connect\n
    usage: quick_connect [--list] [--profile]
    --list : list all registered connections
    --connect <profile_name>: connect to device under <profile_name>\n
    --register : register profile for future connection\n
    --help : Print this message\n
    -------------------------------------------\n
    Profiles are stored under the location of this script, and are folders, which contain files with id_rsa (private-key), info.conf\n
    Example info.conf:
        username=user_a
        server=255.255.255.255
        identity=identity_filename\n"

# setup program if run for first time
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
history_file_cmd="${SCRIPT_DIR}/.cmd_history"
history_file_pth="${SCRIPT_DIR}/.pth_history"
touch "${history_file_cmd}"
touch "${history_file_pth}"
history -r "${history_file_cmd}"
mkdir -p "${SCRIPT_DIR}/profiles"

# Setup Helper functions
COLOR_STD=$'\033[0m'
COLOR_INFO=$'\033[0;37m'
COLOR_WARN=$'\033[0;33m'
COLOR_HIGH=$'\033[0;93m'
COLOR_ERR=$'\033[0;31m'

info () { echo -e "${COLOR_INFO}$1${COLOR_STD}\c"; }
warn () { echo -e "${COLOR_WARN}$1${COLOR_STD}\c"; }
err () { echo -e "${COLOR_ERR}$1${COLOR_STD}\c"; }
highlight () { echo -e "${COLOR_HIGH}$1${COLOR_STD}\c"; }

fancy_read () { read -e -p "$(echo -e ${COLOR_INFO}${1}${COLOR_HIGH}${2}${COLOR_INFO}${3}${COLOR_STD})" result ; }

find_dir () { 
    history -w "${history_file_cmd}"
    history -r "${history_file_pth}"
    echo -e "${COLOR_INFO}${1}${COLOR_HIGH}${2}${COLOR_INFO}${3}${COLOR_STD}"
    options="ls - list directories\ncd - change dir"
    echo -e "${COLOR_INFO}$options${COLOR_STD}"
    prev_path="$(pwd)"
    while [[ true ]] ; do
        cur_path="$(pwd)"
        read -e -p "${cur_path}> " answer
        if [ "${answer:0:3}" = "cd " ] ; then
            set +e
            cd "${answer:3}"
            set -e
            continue;
        elif [ "${answer:0:2}" = "ls" ] ; then
            set +e
            echo $(ls)
            set -e
            continue;
        fi
        
        clean_answer=$(echo $answer | sed 's:/*$::')
        pot_path="${cur_path}/${clean_answer}"
        if [[ -d "${pot_path}" ]] ; then
            cur_path="${pot_path}"
            cd "$cur_path"
        elif [[ -f  "${pot_path}" ]] ; then
            cur_path="${pot_path}"
            cd "$prev_path"
            break;
        fi
    done
    result="${cur_path}"
    history -r "${history_file_cmd}"
}

# Actual functions
get_value () {
    infofile="${SCRIPT_DIR}/profiles/${profilename}/info.conf"
    if [[ -f "${infofile}" ]] ; then
        set +e
        extract0=$(grep "$1" "${infofile}")
        extract1=$(grep "$1" "${infofile}" | sed -e 's/'"$1"'[[:space:]]*=[[:space:]]*\(.*\)[[:space:]]*$/\1/g')
        set -e
        if [ "$extract0" = "$extract1" ] ; then
            result=""
        else
            result="${extract1}"
        fi
    else
        result=""
    fi
}

quick_connect0 () {
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    
    profilename="${1,,}"
    profile="${SCRIPT_DIR}/profiles/${profilename}"
    if [ -d "$profile" ] ; then
        get_value "username"
        username="$result"
        
        get_value "address"
        server="$result"
        
        get_value "keyfile"
        identity="$result"
        
        get_value "port"
        port="$result"
        
        info "Connecting to ${1}...\n"
        CMD="ssh -i ${identity} -p ${port} ${username}@${server}"
        info "${CMD}\n"
        ${CMD}
    else
        err "Profile \"$1\" is not known!\n"   
    fi
}

list_connections0 () {
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    
    header_set=false
    profiles=(${SCRIPT_DIR}/profiles/*)
    for f in ${profiles[@]} ; do
        if [[ -d "${f}" ]] ; then
            if [ ${header_set} = false ]; then
                info "Available connections:\n"
                header_set=true
            fi
            info "${f}\n" 
        fi
    done
    
    # Case nothing was found
    if [ ${header_set} = false ]; then
        info "No connections registered!\n"
    fi

}

register_connections0 () {
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
#    
    confirm () {
        result=""
        msg="${1}"
        while [ true ] ; do
            fancy_read "${1}" "${2}" "${3}"
            answer=${result}
            if  [ "${answer}" = "n" ] || \
                [ "${answer}" = "N" ] ; then
                result="false"
                return;
            elif [ "${answer}" = "y" ] || \
                 [ "${answer}" = "Y" ] ; then
                result="true"
                return;
            fi    
        done
    }
    
    request_value () {
        key="$1"
        if [ "${key}" == "username" ] ; then
            fancy_read "Please enter your " "username" ": "
        elif [ "${key}" == "address" ] ; then
            fancy_read "Please enter the " "server address" ": "
        elif [ "${key}" == "port" ] ; then
            fancy_read "Please enter the " "port" ": "
        elif [ "${key}" == "keyfile" ] ; then
            find_dir "Please enter the location of the " "private key" ": "
        else
            err "Unknown parameter requested! "
        fi
        history -s "${result}"
    }

    check_overwrite () {
        confirm "Do you want to change parameter " "$1" "? (y/n) "
    }
    
    find_index () {
        local -n arr=$1
        local val="$2"
        result="-1"
        for i in "${!arr[@]}"; do
            if [[ "${arr[$i]}" = "${val}" ]]; then
                result="${i}";
            fi
        done
    }

    verify_and_update () {
        local -n private_all_keys=$1
        local -n private_all_values=$2
        local answer=""
        
        # Print current state of infos
        info "Connection Setting:\n"
        for i in "${!private_all_keys[@]}"; do 
            printf "%-20b : " "${COLOR_INFO}${private_all_keys[$i]}${COLOR_STD}"
            printf "%-30b\n" "${COLOR_INFO}${private_all_values[$i]}${COLOR_STD}"
        done
        highlight "If this Connection Setting is correct, please type 'accept', else 'edit'.\n"
        highlight "Type command (e.g. accept, help)\n"

        while [[ "accept" != "${answer}" ]] ;
        do  
            fancy_read "" "" "> "
            history -s "${result}"
            answer=(${result})

            description=("Prints this help message" \
                         "Print Current Setting" \
                         "Accept the current Connect Setting" \
                         "Edit a specific key-value pair 'edit my_key' or 'edit my_key my_value' works.")
            commands=("help" "list" "accept" "edit <key> [value]")
            if [[ "help" == "${answer}" ]]; then
                for i in "${!commands[@]}"; do
                    printf "%-30b : " "${COLOR_WARN}${commands[$i]}${COLOR_STD}"
                    printf "%-30b\n" "${COLOR_WARN}${description[$i]}${COLOR_STD}"
                done
            elif [[ "accept" == "${answer}" ]]; then # just pass
                true;
            elif [[ "list" == "${answer}" ]]; then
                # Print current state of infos
                info "Connection Setting:\n"
                for i in "${!private_all_keys[@]}"; do 
                    printf "%-20b : " "${COLOR_INFO}${private_all_keys[$i]}${COLOR_STD}"
                    printf "%-30b\n" "${COLOR_INFO}${private_all_values[$i]}${COLOR_STD}"
                done
            elif [[ "edit" == "${answer}" ]]; then
                # Find index
                find_index private_all_keys "${answer[1]}"
                if [[ "${result}" == -1 ]] ; then
                    warn "Key ${answer[1]} does not exist! Ignore.\n"
                    continue;
                fi
                idx="${result}"
                
                if [[ "${answer[2]}" == "" ]] ; 
                then
                    request_value "${answer[1]}"
                    private_all_values[$idx]="${result}"
                else
                    private_all_values[$idx]="${answer[2]}"
                fi
            else 
                warn "Command '${answer}' unknown. Ignore.\n"
            fi
        done
    }

    # Setup profile
    fancy_read "Please enter your " "profilename" ": "
    info "Note: This will be converted to lower-case!"
    profilename=${result,,}
    history -s "${profilename}"

    profile="${SCRIPT_DIR}/profiles/${profilename}"
    if [[ -d "${profile}" ]] ; then
        profile_exist=true
        warn "Profile exists!\n"
        confirm "Do you want to overwrite the profile? (y/n) "
        answer="${result}"
        if [ "${answer}" = true ] ; then
            info "\rContinuing...\n"
        else
            warn "\rUser aborted registration\n"
            return;
        fi
    else
        profile_exist=false
        mkdir -p "${profile}"
    fi
    
    # Create List with full (parametrization), 
    # not only the minimum required ones
    keys=("username" "address" "keyfile" "port")
    values=("" "" "" "22")
   
    # If info exists, load current setting
    if [ "$profile_exist" = true ];
    then
        for i in ${!keys[@]}; do
            get_value "${keys[$i]}"
            if [[ "${result}" != "" ]]; then
                values["$i"]="${result}"
            fi
        done
    fi

    # Verify that everything is ok to user?
    verify_and_update keys values

    # Move keylocation
    loc_keyfile="${SCRIPT_DIR}/profiles/${profilename}/rsa_key"
    if [ "${values[2]}" != "$loc_keyfile" ] ; then
        cp "${values[2]}" "$loc_keyfile"
        chmod 600 "$loc_keyfile"
        all_values[2]="$loc_keyfile"
    fi
       
    # Write to info file
    infofile="${SCRIPT_DIR}/profiles/${profilename}/info.conf"
    echo "" > ${infofile}
    for i in "${!keys[@]}"; do 
        echo "${keys[$i]}=${values[$i]}" >> ${infofile}
    done
}


# parse Arguments
REQUEST="Invalid"
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--connect)
      REQUEST="connect"
      PROFILE="$2"
      shift # past argument
      shift # past value
      ;;
    -l|--list)
      REQUEST="list"
      shift # past argument
      ;;
    -r|--register)
      REQUEST="register"
      shift # past argument
      ;;
    -h|--help)
      REQUEST="help"
      shift # past argument
      ;;
    -*|--*)
      err "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

history -r "${history_file_cmd}"

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [ "${REQUEST}" = "connect" ]; then
    quick_connect0 "$PROFILE"
elif [ "${REQUEST}" = "list" ]; then
    list_connections0
elif [ "${REQUEST}" = "register" ]; then
    register_connections0
elif [ "${REQUEST}" = "help" ]; then
    info "\n${HELP}"
else
    err "Error: No Request provided! Abort!\n"
    info "\n${HELP}"
fi

history -w "${history_file_cmd}"
