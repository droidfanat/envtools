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

Создать новый проект на git.artjoker.ua? 
	"
        echo "Этот скрипт: 
Делает все необходимое вместо тебя =)

Продолжить? [y/N]"
        echo -n ' ▶▶▶ '
	read -er response

	case "$response" in
	    [yY][eE][sS]|[yY]) 
	        echo "Начат процесс создание проекта"
	        ;;
	    *)
	        exit 0
	        ;;
	esac
 }

############## защита от дурака при повторном сетапе ######

check_log(){
    if [[ -f "./$PROJECT_NAME.log" ]]; then
        red_text "$PROJECT_NAME уже настраивался. Вы уверены что хотите продолжить?
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

    

add_dev_env(){
    SERVER_TYPE=dev
    SUBDOMAIN=$(echo $PROJECT_NAME | tr '[:upper:]' '[:lower:]' | tr '[:punct:]' - )
    source <(ssh -p 2222 root@app.artjoker.ua sudo althron laravel $SUBDOMAIN)
    
    if [[ -z $SSH_USER ]]; then
            red_text "Не удалось создать Dev хостинг!"
            exit 1
    fi

#    SSH_USER=xxx
#    SSH_PASSWORD=ejTZ0duDPWHncTT5
#    PROJECT_URL=http://xxx.app.artjoker.ua
#    DOMAIN="$(echo "$PROJECT_URL" | sed -e 's|^[^/]*//||' -e 's|/.*$||')"
#    SSH_SERVER=xxx.app.artjoker.ua
#    SSH_PORT=2222
#
#    SERVER_PATH='/hosting/www/xxx/public_html'


    echo "Выберите проект для импорта [template-shop]: "
    IMPORT_PROJECT=$(select_project)
    IMPORT_PROJECT=${IMPORT_PROJECT:-template-shop}

    #   create_dev_env(){
    #   
    #   
    #   SSH_USER=newUser
    #   SSH_USER_PASS=newUserPass
    #   DOMAIN=newDomain
    #   USER_HOME=hostingRoot/newUser
    #   WORK_DIR=hostingRoot/newUser/public_html
    #   USER_DB=dbUser
    #   PASS_DB=dbPass
    #   NAME_DB=dbName
    #   SERVER_TYPE=dev
    #   }

}



add_prod(){
    
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

    get_token

    echo "Введите проект для импорта [template-shop]: "
    echo -n ' ▶▶▶ '
    read -er IMPORT_PROJECT
    IMPORT_PROJECT=${IMPORT_PROJECT:-template-shop}

#    echo "Введите URL сервера [https://example.com/]: "
#    echo -n ' ▶▶▶ '
#    read -er PROJECT_URL
#    PROJECT_URL=${PROJECT_URL:-https://example.com/}
#
#    echo "Введите ip адрес или домен сервера [app.artjoker.ua] or [1.2.3.4]: "
#    echo -n ' ▶▶▶ '
#    read -er SSH_SERVER
#    SSH_SERVER=${SSH_SERVER:-app.artjoker.ua}
#
#    echo "Введите SSH порт (можно оставить пустым) [22]: " 
#    echo -n ' ▶▶▶ '
#    read -er SSH_PORT
#
#    ssh_user
#    ssh_pass
#    server_quest
#    if [[ $SERVER_TYPE == dev ]]; then 
#        add_dev_env; 
#    fi
#    echo "Введите путь к каталогу проекта на сервере [/var/www/]: "
#    echo -n ' ▶▶▶ '
#    read -er SERVER_PATH
#    SERVER_PATH=${SERVER_PATH:-~/public_html}

}






push_to_git(){
    GIT_PROJECT_PATH="${GITLAB_GROUP}/${PROJECT_NAME}"
    TYPE=$(echo $SERVER_TYPE | tr '[:lower:]' '[:upper:]')
    DOMAIN=$DOMAIN
    ENV_VARIABLES=$ENV_VARIABLES
    SSH_PRIVATE_KEY=$(cat ~/.ssh/"${PROJECT_NAME}_${SERVER_TYPE}")

    api_add_variable "${TYPE}_ENV_VARIABLES"  "$ENV_VARIABLES"
    api_add_variable "${TYPE}_SSH_PRIVATE_KEY" "$SSH_PRIVATE_KEY"
    api_add_variable "${TYPE}_DOMAIN" "$DOMAIN"
    api_add_variable "${TYPE}_DOMAIN_URL" "$PROJECT_URL"
    api_add_variable "${TYPE}_SERVER_PATH" "$SERVER_PATH"
    api_add_variable "${TYPE}_SSH_PORT" "$SSH_PORT"
    api_add_variable "${TYPE}_SSH_USER" "$SSH_USER"
    api_add_webhook
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
echo "Введите название проекта [project_name-1]: "
echo -n ' ▶▶▶ '
read -er PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-project_name-1}
echo

check_log
sure
install_requarements
get_token
SERVER_TYPE=dev
add_dev_env

install_silent(){
    
    ssh_create 
    ssh_config "${PROJECT_NAME}_${SERVER_TYPE}" "$DOMAIN" "$SSH_USER" "$SSH_PORT" 
    env_generate 
    api_create_project 
    push_to_git 
}

install_silent >/dev/null 2>&1 &
    spinner

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
#  Проект для импорта: $IMPORT_PROJECT
#  
################################################################################
###########################  Настройки DEV сервера  ############################
#
#  URL проекта: $PROJECT_URL
#  Вид окружения: $SERVER_TYPE
#  Для подключения к Dev серверу: ssh ${PROJECT_NAME}_${SERVER_TYPE}
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
    | tee "$PROJECT_NAME".log

}

main

