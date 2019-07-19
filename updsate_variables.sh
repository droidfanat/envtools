#!/bin/bash
set +x
# shellcheck source=lib.sh
source lib.sh

GITLAB_GROUP=laravel

GIT_LAB_URL='https://git.artjoker.ua'
GIT_LAB_API="${GIT_LAB_URL}/api/v4"

VERSION=0.8.5

sure() {

red_text "
################################################################################
################################################################################

Хотите обновить проект на git.artjoker.ua? 
	"
        echo "
Продолжить? [y/N]"
        echo -n ' ▶▶▶ '
	read -er response

	case "$response" in
	    [yY][eE][sS]|[yY]) 
	        echo "Начат процесс обновления проекта"
	        ;;
	    *)
	        exit 0
	        ;;
	esac
 }

############## защита от дурака при повторном сетапе ######

check_log(){
    if [[ -f "./${PROJECT_NAME}_${SERVER_TYPE}.log" ]]; then
        red_text "$PROJECT_NAME $SERVER_TYPE уже настраивался.
Вы уверены что хотите продолжить? [y/N]"
        echo -n ' ▶▶▶ '
        read -re response
            
                case "$response" in
                    [yY][eE][sS]|[yY]) 
                        echo
                        ;;
                    *)
                        exit 0
                        ;;
                esac
    fi
    }

    


response_env_var(){
    
    ssh_user(){
        echo "Введите пользователя для SSH [$PROJECT_NAME]: "
        echo -n ' ▶▶▶ '
        read -er SSH_USER
        SSH_USER=${SSH_USER:-$PROJECT_NAME}
        NameREGEXP='^[a-zA-Z][-a-zA-Z0-9_]*$'

            if [[ ! $SSH_USER =~ $NameREGEXP ]]; then
                echo
                echo "Неверное имя пользователя. Имя может состоять из латинских букв,
    цифр и нижнего подчеркивания
    
    "
                ssh_user
            fi

    }

    ssh_pass(){
        echo "Введите пароль для SSH [Password123]: "
        echo -n ' ▶▶▶ '
        read -er SSH_PASSWORD

            if [[ -z $SSH_PASSWORD ]]; then
                echo
                echo "Пароль не может быть пустым"
                ssh_pass
            fi
    }


    echo "Введите URL сервера [https://example.com/]: "
    echo -n ' ▶▶▶ '
    read -er PROJECT_URL
    PROJECT_URL=${PROJECT_URL:-https://example.com/}

    DOMAIN=$(echo  "$PROJECT_URL" | cut -d'/' -f3)

    SSH_SERVER=$DOMAIN

    echo "Введите SSH порт (можно оставить пустым) [22]: " 
    echo -n ' ▶▶▶ '
    read -er SSH_PORT
    SSH_SERVER=${SSH_SERVER:-22}

    ssh_user
    ssh_pass
    echo "Введите путь к каталогу проекта на сервере [/var/www/]: "
    echo -n ' ▶▶▶ '
    read -er SERVER_PATH
    SERVER_PATH=${SERVER_PATH:-~/public_html}
    
#  Пароль БД: ${PASS_DB}


    echo "Введите имя базы данных [name_DB]: "
    echo -n ' ▶▶▶ '
    read -er NAME_DB
    NAME_DB=${NAME_DB:-name_DB}
    
    echo "Введите пользователя базы данных [user_DB]: "
    echo -n ' ▶▶▶ '
    read -er USER_DB
    USER_DB=${USER_DB:-user_DB}

    echo "Введите пароль базы данных [strong_Password]: "
    echo -n ' ▶▶▶ '
    read -er PASS_DB
    PASS_DB=${PASS_DB:-strong_Password}
}

push_to_git(){
    
    GIT_PROJECT_PATH="${GITLAB_GROUP}/${PROJECT_NAME}"
    TYPE=$(echo $SERVER_TYPE | tr '[:lower:]' '[:upper:]')
    DOMAIN=$DOMAIN
    ENV_VARIABLES=$ENV_VARIABLES
    SSH_PRIVATE_KEY=$(cat ~/.ssh/"${PROJECT_NAME}_${SERVER_TYPE}")

    
    api_update_variable "${TYPE}_ENV_VARIABLES"  "$ENV_VARIABLES"
    api_update_variable "${TYPE}_SSH_PRIVATE_KEY" "$SSH_PRIVATE_KEY"
    api_update_variable "${TYPE}_DOMAIN" "$DOMAIN"
    api_update_variable "${TYPE}_DOMAIN_URL" "$PROJECT_URL"
    api_update_variable "${TYPE}_SERVER_PATH" "$SERVER_PATH"
    api_update_variable "${TYPE}_SSH_PORT" "$SSH_PORT"
    api_update_variable "${TYPE}_SSH_USER" "$SSH_USER"
    api_update_webhook
    api_run_pipeline
}

env_generate(){
    APP_KEY="base64:$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32 | base64 )"

    if [[ $SERVER_TYPE == production ]]; then
        APP_DEBUG='false'
    else
        APP_DEBUG='true'
    fi
ENV_VARIABLES=$(echo "
APP_NAME=${PROJECT_NAME}
APP_ENV=${SERVER_TYPE}
APP_KEY=${APP_KEY}
APP_DEBUG=${APP_DEBUG}
APP_URL=http://localhost

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=${NAME_DB}
DB_USERNAME=${USER_DB}
DB_PASSWORD=${PASS_DB}

LOG_CHANNEL=stack

BROADCAST_DRIVER=log
CACHE_DRIVER=file
SESSION_DRIVER=file
SESSION_LIFETIME=120
QUEUE_DRIVER=sync

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_DRIVER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_APP_CLUSTER=mt1

MIX_PUSHER_APP_KEY="\${PUSHER_APP_KEY}"
MIX_PUSHER_APP_CLUSTER="\${PUSHER_APP_CLUSTER}"

BACKEND_URI=back
LOCALES=ua,ru
LOCALE_DEFAULT=ua
" | base64)
}



main(){
get_token
echo "Выберите название проекта: "
PROJECT_NAME=$(select_project)
PROJECT_NAME=${PROJECT_NAME:-valera}
echo
server_quest

check_log
#api_check_project
sure
install_requarements


response_env_var

install_project(){
    
    ssh_create 
    ssh_config "${PROJECT_NAME}_${SERVER_TYPE}" "$DOMAIN" "$SSH_USER" "$SSH_PORT" 
    env_generate
    push_to_git 
}

silent(){
    "$@" >/dev/null 2>&1 &
    spinner
} 

install_project
#silent install_project 

echo -e "


################################################################################
################################################################################
#
# Готово. Хорошего дня!
# 
# Репозитарий проекта $PROJECT_NAME доступен по ссылке
"
green_text " $GIT_LAB_URL/${GITLAB_GROUP}/${PROJECT_NAME}"


echo -e "
################################################################################
#  
#  Название проекта: $PROJECT_NAME
#  
################################################################################
###########################  Настройки $SERVER_TYPE сервера  ############################
#
#  URL проекта: $PROJECT_URL
#  Вид окружения: $SERVER_TYPE
#  Для подключения к $SERVER_TYPE серверу: ssh ${PROJECT_NAME}_${SERVER_TYPE}
#  
#  IP адрес или домен сервера: $SSH_SERVER
#  SSH порт: $SSH_PORT
#  SSH пользователь: $SSH_USER
#  SSH пароль: $SSH_PASSWORD
#  
#  Путь к каталогу проекта на сервере: $SERVER_PATH
#  
#  ssh -i "$HOME/.ssh/$PROJECT_NAME" -p "${SSH_PORT:-22}" "${SSH_USER}"@"${SSH_SERVER}"
#  
#  Имя базы данных: ${NAME_DB}
#  Пользователь БД: ${USER_DB}
#  Пароль БД: ${PASS_DB}
#  
" \
    | tee "${PROJECT_NAME}_${SERVER_TYPE}".log

}

main

