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

Хотите отредактировать .env файл в проекте $PROJECT_NAME на git.artjoker.ua? 
	"
        echo "
Продолжить? [y/N]"
        echo -n ' ▶▶▶ '
	read -er response

	case "$response" in
	    [yY][eE][sS]|[yY]) 
	        echo "Начат процесс открытия файла .env"
	        ;;
	    *)
	        exit 0
	        ;;
	esac
 }
$NAM
result(){
    green_text "
################################################################################
################################################################################

Обновлен проект ${PROJECT_NAME} 
в переменную ${TYPE}_ENV_VARIABLES внесенно:
        " 
    cat .env
}

main(){
    install_requarements
    get_token
    sure
    PROJECT_NAME=$(select_project)
    server_quest
    api_get_env_variable
    edit_env_variable
    result
    rm .env
    exit
}

main

