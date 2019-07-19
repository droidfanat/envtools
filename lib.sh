#!/bin/bash
urlencode(){ 
    echo -E "$@" | perl -MURI::Escape -ne 'chomp;print uri_escape($_),"\n"'
}

urldecode() {
    # urldecode <string>

    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}


green_text() {
    echo -e '\033[32m' "$@" '\033[0m'	
}

red_text() {
	echo -e '\033[1;31m' "$@" '\033[0m'
	}

check_installed() {
    # arguments is list of progs

    # exaple:
    #       check_installed ssh python htop

	if [[ -z "$*" ]]  ; then 
		echo "No arguments" 
		return 1
	fi

	for prog in "$@"; do
		if ! command -v $prog >/dev/null 2>&1; then 
                LIST_TO_INSTALL+="$prog "
		fi
	done
	}


spinner(){
    ## spinner for backgroud procces
    ## example 
    # sleep 7 & 
    # spinner
    echo
    PID="$!"

    i=1
    sp="/-\|"
    echo -n ' '
        
    while [ -d /proc/$PID ]
    do
        printf "\b${sp:i++%${#sp}:1}"
    done
}


install_requarements(){
    # use function check_install
    check_installed curl sshpass jq perl zenity
        if [[ ! -z $LIST_TO_INSTALL ]]; then

            green_text "
            Will be installed $LIST_TO_INSTALL
            
            Please, enter sudo password"

                sudo true
                sudo apt update > /dev/null 2>&1
                sudo apt-get install -y "$LIST_TO_INSTALL" > /dev/null
            unset LIST_TO_INSTALL
        fi
}

silent(){
    "$@" >/dev/null 2>&1 &
    spinner
}

api_get_group_id() {
    # gitlab api get search group id
    GITLAB_GROUP=$1

    curl \
        -s \
        --header "PRIVATE-TOKEN: $TOKEN" \
        -X GET "$GIT_LAB_API/namespaces?search=$GITLAB_GROUP" | \
            jq --raw-output '.[] | .id' | \
                head -1
}

api_create_project(){
    local IMPORT_REPO_URL=${GIT_LAB_URL}/${GITLAB_GROUP}/${IMPORT_PROJECT}.git
    # request to gitlab api for create project from other project
    IMPORT_REPO="https://oauth2:${TOKEN}@${IMPORT_REPO_URL#http?://}"
    NAMESPACE_ID="$(api_get_group_id "$GITLAB_GROUP")"

    curl \
        -s \
        --header "PRIVATE-TOKEN: $TOKEN" \
        -X POST \
        "$GIT_LAB_API/projects?name=${PROJECT_NAME}&namespace_id=${NAMESPACE_ID}&import_url=${IMPORT_REPO}"
}

api_add_variable(){
    # api ruquest for add project variable
    NEW_KEY=$1
    NEW_VALUE=$2

    PROJECT_PATH_ENCODED=$(urlencode "$GIT_PROJECT_PATH")

    curl \
        -s \
        --request POST \
        --header "PRIVATE-TOKEN: $TOKEN" \
        "$GIT_LAB_API/projects/${PROJECT_PATH_ENCODED}/variables" \
        --form "key=${NEW_KEY}" \
        --form "value=${NEW_VALUE}"
}

api_update_variable(){

    # api ruquest for add project variable
    UPDATE_KEY=$1
    UPDATE_VALUE=$2

    PROJECT_PATH_ENCODED=$(urlencode "$GIT_PROJECT_PATH")
    VALIDE_KEY=$(echo "$UPDATE_KEY" | tr -dc _A-Za-z0-9)

    RESPONSE=$(curl \
        -s \
        --request PUT \
        --header "PRIVATE-TOKEN: $TOKEN" \
        "$GIT_LAB_API/projects/${PROJECT_PATH_ENCODED}/variables/${VALIDE_KEY}" \
        --form "key=${VALIDE_KEY}" \
        --form "value=${UPDATE_VALUE}")

    if [[ $RESPONSE =~ '404 Variable Not Found' ]]; then
        api_add_variable "$1" "$2"
    fi
    
}

api_add_webhook(){
    PROJECT_PATH_ENCODED=$(urlencode "$GIT_PROJECT_PATH")
    curl \
        -s \
        --request POST \
        --header "PRIVATE-TOKEN: $TOKEN" \
        "$GIT_LAB_API/projects/${PROJECT_PATH_ENCODED}/hooks" \
        --form "merge_requests_events=true" \
        --form "url=https://chat.artjoker.ua/hooks/vJWcdgBjWh3S6dCju/rmJxMLk8u8SgPDCYWqxjRTbAoZaaM6hxEHYKrHz6v8J8nmFL" \
        --form "enable_ssl_verification=true" \
        --form "token=vJWcdgBjWh3S6dCju/rmJxMLk8u8SgPDCYWqxjRTbAoZaaM6hxEHYKrHz6v8J8nmFL" \
        --form "push_events=false"
}

api_run_pipeline(){
    PROJECT_PATH_ENCODED=$(urlencode "$GIT_PROJECT_PATH")
    curl \
        -s \
        --request POST \
        --header "PRIVATE-TOKEN: $TOKEN" \
         "$GIT_LAB_API/projects/${PROJECT_PATH_ENCODED}/pipeline?ref=master"
}

api_get_project_list(){
    # gitlab api get group project list
    NAMESPACE_ID="$(api_get_group_id "$GITLAB_GROUP")"
    curl \
        -s \
        --header "PRIVATE-TOKEN: $TOKEN" \
        -X GET \
        --form "order_by=path" \
        --form "sort=asc" \
        --form "with_shared=false" \
        "$GIT_LAB_API/groups/${NAMESPACE_ID}/projects?per_page=100" \
            | jq --raw-output '.[] | .path' 

}

api_get_env_variable(){
    # get .env file from secret variable
    GIT_PROJECT_PATH="${GITLAB_GROUP}/${PROJECT_NAME}"
    PROJECT_PATH_ENCODED=$(urlencode "$GIT_PROJECT_PATH")
    TYPE=$(echo $SERVER_TYPE | tr '[:lower:]' '[:upper:]')

    TEMP_FILE=$(mktemp)
    curl \
        -s \
        --header "PRIVATE-TOKEN: $TOKEN" \
        -X GET "$GIT_LAB_API/projects/${PROJECT_PATH_ENCODED}/variables/${TYPE}_ENV_VARIABLES" \
            | jq --raw-output .value \
            | base64 --decode > .env
    }

edit_env_variable(){
    # open .env file in defult editor, end after close push file to gitlab variable in base64
    editor .env
    ENV_VARIABLES=$(cat .env | base64)
    api_update_variable "${TYPE}_ENV_VARIABLES"  "$ENV_VARIABLES"
}

select_project(){
    # generate project selector from gitlab projects list
    PS3='Введите номер проекта: '
    select name in $(api_get_project_list); do
            echo "$name"
        break
        done
    # generate project selector from gitlab projects list
#        echo $(zenity \
#                --list \
#                --title="Выбери проект" --column="Доступные проекты $GITLAB_GROUP" \
#                $(api_get_project_list) \
#                --width=320 --height=480 2> /dev/null)

}


ssh_create(){
	local KEY_FILE_NAME="${PROJECT_NAME}_${SERVER_TYPE}"
	# ssh keygen if not found key_file.pub
	if [[ ! -f "$HOME/.ssh/$KEY_FILE_NAME" ]]; then

		if [[ ! -d "$HOME/.ssh" ]]; then
            mkdir -p "$HOME/.ssh"
        fi 
		chmod 700 "$HOME/.ssh"
		ssh-keygen -t rsa -f "$HOME/.ssh/$KEY_FILE_NAME" -C "Deploy@$HOSTNAME" -N ""
	fi

    if  nc -z -w1 "${SSH_SERVER}" "${SSH_PORT:-22}"; then
        sshpass -p "$SSH_PASSWORD" \
            ssh-copy-id -i "$HOME/.ssh/$KEY_FILE_NAME" \
                        -o StrictHostKeyChecking=no \
                        -p "${SSH_PORT:-22}" "${SSH_USER}"@"${SSH_SERVER}"
    else 
        red_text "Сервер ${SSH_SERVER} не отвечает по SSH на порту ${SSH_PORT:-22}"
        exit
    fi

    }

ssh_config() {
	if [[ "$#" -ne '4' ]]  ; then 
red_text 'Number of parameters is not 4
Perhaps you passed the parameters in ""'
		
		echo -e "

This function add to $HOME/.ssh/config server ip and link name

All parameters is required:
\$1=host1_name 
\$2=host1.com or 10.10.10.10
\$3=user_name
\$4=ssh_port

Example of use:
ssh_config node-1 10.10.10.10 username 2222
" 
		return 1
	fi

	echo -e \
	"
### Added by Laravel setup script
Host $1 $2
    HostName $2
    User $3
    Port $4
    IdentityFile ~/.ssh/${PROJECT_NAME}_${SERVER_TYPE}" \
	>> "$HOME"/.ssh/config

	echo "Use \"ssh $1\" for connect to server"
}

server_quest(){
        echo -e "Выберите сервер :
            1) Dev 
            2) Production
            3) Staging"
        echo -n ' ▶▶▶ '
        read -re SERVER_TYPE
            case $SERVER_TYPE in
            1) SERVER_TYPE=dev
                ;;
            2) SERVER_TYPE=prod
                ;;
            3) SERVER_TYPE=staging
                ;;
            '') SERVER_TYPE=dev
                ;;
            *) red_text 'Неверный выбор. Введите только номер'
                server_quest
                ;;
            esac
    }

get_token(){

    if [[ -f .apikey ]]; then
        TOKEN=$(cat .apikey)
        return
    fi
    
        green_text "
ver[${VERSION}]

####################################### TOKEN #######################################
#
# Go to link and create token with API permisions
# https://git.artjoker.ua/profile/personal_access_tokens
# ✓ api
#
"

    echo "Введите токен[uqhUhS-kwUHga68vw8QH]: "
    echo -n ' ▶▶▶ '
    read -re TOKEN
    
    while ! curl -f \
                    -s \
                    --header "PRIVATE-TOKEN: $TOKEN" \
                    -X GET "$GIT_LAB_API/namespaces?search=" > /dev/null
    do
        echo "Токен не работает, попробуйте снова"
        get_token
    done
    }