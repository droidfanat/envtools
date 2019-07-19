#!/usr/bin/env bash
# shellcheck disable=SC2120
# shellcheck disable=SC2155
set -x
# shellcheck source=./lib.sh

source lib.sh

GITLAB_GROUP=modx
GIT_LAB_URL='https://git.artjoker.ua'
GIT_LAB_API="${GIT_LAB_URL}/api/v4"

GITLAB_GROUP_ORIGIN=artjoker-modx
GIT_LAB_URL_ORIGIN='https://gitlab.com'
GIT_LAB_API_ORIGIN="${GIT_LAB_URL_ORIGIN}/api/v4"

TOKEN=$(cat .apikey)
TOKEN_ORIGIN=$(cat .apikeyorigine)

# shellcheck disable=SC2120
api_get_group_projects(){
    #GET /groups/:id/projects
    local API_URL=${1:-$GIT_LAB_API}
    local GROUP_NAME=${2:-$GITLAB_GROUP}
    local API_KEY=${3:-$TOKEN}

    GROUP_ID=$(urlencode "$GROUP_NAME")

    curl \
        -s \
        --header "PRIVATE-TOKEN: $API_KEY" \
        -X GET \
        --form "order_by=path" \
        --form "sort=asc" \
        --form "with_shared=false" \
        "$API_URL/groups/$GROUP_ID/projects?per_page=100" 
}


# shellcheck disable=SC2120
api_get_group_projects_name(){
    local API_URL=${1:-$GIT_LAB_API}
    local GROUP_NAME=${2:-$GITLAB_GROUP}
    local API_KEY=${3:-$TOKEN}
    api_get_group_projects "$API_URL" "$GROUP_NAME" "$API_KEY" \
        | jq --raw-output '.[] | .path_with_namespace'
}


api_project_export(){
#POST /projects/:id/export
    local API_URL=${1:-$GIT_LAB_API}
    local PROJECT_PATH=${2:-'artjoker-laravel/test'}
    local API_KEY=${3:-$TOKEN}
    local PROJECT_ID=$(urlencode "$PROJECT_PATH")
    curl \
        -s \
        --header "PRIVATE-TOKEN: $API_KEY" \
        -X POST \
        "$API_URL/projects/$PROJECT_ID/export" 

}

api_project_export_status(){
#GET /projects/:id/export
    local API_URL=${1:-$GIT_LAB_API}
    local PROJECT_PATH=${2:-'artjoker-laravel/test'}
    local API_KEY=${3:-$TOKEN}
    local PROJECT_ID=$(urlencode "$PROJECT_PATH")
    curl \
        -s \
        --header "PRIVATE-TOKEN: $API_KEY" \
        -X GET \
        "$API_URL/projects/$PROJECT_ID/export" 
}
# {
#  "id": 217,
#  "description": "",
#  "name": "test",
#  "name_with_namespace": "artjoker-laravel / test",
#  "path": "test",
#  "path_with_namespace": "artjoker-laravel/test",
#  "created_at": "2018-12-18T15:56:32.122+02:00",
#  "export_status": "finished",
#  "_links": {
#    "api_url": "https://git.artjoker.ua/api/v4/projects/217/export/download",
#    "web_url": "https://git.artjoker.ua/artjoker-laravel/test/download_export"
#  }
#}

api_project_export_status_check(){
    local API_URL=${1:-$GIT_LAB_API}
    local PROJECT_PATH=${2:-'artjoker-laravel/test'}
    local API_KEY=${3:-$TOKEN}
    
    while [[ ! $STATUS == 'finished' ]]; do
        STATUS=$(api_project_export_status "$API_URL" "$PROJECT_PATH" "$API_KEY" \
        | jq --raw-output '.export_status')
        sleep 1
    done
}

#api_project_export_status_check $GIT_LAB_API 'artjoker-laravel/navis' $TOKEN

api_project_export_download(){
#GET /projects/:id/export/download
    local API_URL=${1:-$GIT_LAB_API}
    local PROJECT_PATH=${2:-'artjoker-laravel/test'}
    local API_KEY=${3:-$TOKEN}
    local PROJECT_ID=$(urlencode "$PROJECT_PATH")

    curl \
        -s \
        --header "PRIVATE-TOKEN: $API_KEY" \
        -X GET \
        --remote-header-name \
        "$API_URL/projects/$PROJECT_ID/export/download" \
        > "migration.tar.gz"
}

api_project_import(){
#POST /projects/import
    local API_URL=${1:-$GIT_LAB_API}
    local PROJECT_PATH=${2:-'artjoker-laravel/test'}
    local API_KEY=${3:-$TOKEN}
    local PROJECT_ID=$(urlencode "$PROJECT_PATH")
    local PROJECT_NAMESAPACE=$(dirname "$PROJECT_PATH")
    local PROJECT_NAME=$(basename "$PROJECT_PATH")
    curl \
        -s \
        --header "PRIVATE-TOKEN: $API_KEY" \
        --form "namespace=$PROJECT_NAMESAPACE" \
        --form "path=${PROJECT_NAME}" \
        --form "file=@migration.tar.gz" \
        -X POST \
        "$API_URL/projects/import" 
}


api_get_secret_variable(){
    #GET /projects/:id/variables
    local API_URL=${1:-$GIT_LAB_API}
    local PROJECT_PATH=${2:-'artjoker-laravel/test'}
    local API_KEY=${3:-$TOKEN}
    local PROJECT_ID=$(urlencode "$PROJECT_PATH")
    curl \
        -s \
        --header "PRIVATE-TOKEN: $API_KEY" \
        -X GET \
        "$API_URL/projects/$PROJECT_ID/variables" 
    }

api_add_variable(){
    #POST /projects/:id/variables
    # api ruquest for add project variable
    local API_URL=${1:-$GIT_LAB_API}
    local PROJECT_PATH=${2:-'laravel/test'}
    local API_KEY=${3:-$TOKEN}
    local VAR_CONTENT=$4

#VAR_CONTENT='
#  {
#    "key": "NEW_AWS_ACCESS_KEY_ID",
#    "value": "AKIAI2CPGQDKUAJRPTQA",
#    "protected": false
#  }
#'

    PROJECT_ID=$(urlencode "$PROJECT_PATH")

    curl \
        -s \
        --header "PRIVATE-TOKEN: $API_KEY" \
        --header "Content-Type: application/json" \
        -X POST \
        --data "$VAR_CONTENT" \
        "$API_URL/projects/$PROJECT_ID/variables"
}

api_secret_variable_copy(){
    local API_URL_ORIGIN=${1:-$GIT_LAB_API_ORIGIN}
    local PROJECT_PATH_ORIGIN=${2:-'artjoker-laravel/test'}
    local API_KEY_ORIGIN=${3:-$TOKEN_ORIGIN}
    local API_URL=${4:-$GIT_LAB_API}
    local PROJECT_PATH=${5:-'artjoker-laravel/test'}
    local API_KEY=${6:-$TOKEN}


    ORIGINAL_VAR=$(api_get_secret_variable "$API_URL_ORIGIN" "$PROJECT_PATH_ORIGIN" "$API_KEY_ORIGIN" \
        | jq --raw-output .)

    if [[ $ORIGINAL_VAR == '[]' ]]; then
        echo 'No variables in the project'
        return 0
    fi

    VARIABLES_LIST=$( echo "$ORIGINAL_VAR" | jq --raw-output '.[] | .key' )
    for VAR in $VARIABLES_LIST; do
        local VAR_CONTENT="$(echo "$ORIGINAL_VAR" | jq -r --arg VAR "$VAR" '.[] | select(.key==$VAR)')"
        api_add_variable "$API_URL" "$PROJECT_PATH" "$API_KEY" "$VAR_CONTENT"
    done

}

api_get_project_info(){
#GET /projects/:id
    local API_URL=${1:-$GIT_LAB_API}
    local PROJECT_PATH=${2:-'artjoker-laravel/test'}
    local API_KEY=${3:-$TOKEN}
    local PROJECT_ID=$(urlencode "$PROJECT_PATH")
    curl \
        -s \
        --header "PRIVATE-TOKEN: $API_KEY" \
        -X GET \
        "$API_URL/projects/$PROJECT_ID" 
}

api_project_rename(){
#PUT /projects/:id
# !!! Don't work on gitlab.com
    local API_URL=${1:-$GIT_LAB_API}
    local PROJECT_PATH=${2:-'artjoker-laravel/test'}
    local API_KEY=${3:-$TOKEN}
    local PROJECT_ID=$(urlencode "$PROJECT_PATH")
    local PROJECT_NAMESAPACE=$(dirname "$PROJECT_PATH")
    local PROJECT_NAME=$(basename "$PROJECT_PATH")
    local NEW_PROJECT_NAME=$(echo "${PROJECT_NAME}-deprecated")
    curl \
        -s \
        --header "PRIVATE-TOKEN: $API_KEY" \
        -X PUT \
        --form "name=${NEW_PROJECT_NAME}" \
        --form "path=${NEW_PROJECT_NAME}" \
        "$API_URL/projects/$PROJECT_ID" 
}

migration(){
    api_project_export "$GIT_LAB_API_ORIGIN" "$PROJECT_ORIGIN" "$TOKEN_ORIGIN"
    api_project_export_status_check "$GIT_LAB_API_ORIGIN" "$PROJECT_ORIGIN" "$TOKEN_ORIGIN"
    api_project_export_download "$GIT_LAB_API_ORIGIN" "$PROJECT_ORIGIN" "$TOKEN_ORIGIN"
    api_project_import "$GIT_LAB_API" "$PROJECT_NEW" "$TOKEN"
    api_secret_variable_copy "$GIT_LAB_API_ORIGIN" "$PROJECT_ORIGIN" "$TOKEN_ORIGIN" "$GIT_LAB_API" "$PROJECT_NEW" "$TOKEN"
#    api_project_rename "$GIT_LAB_API_ORIGIN" "$PROJECT_ORIGIN" "$TOKEN_ORIGIN"
}

main(){
# Check you permissions to groups. You must be the Owner or Maintainer
#api_get_group_projects_name "$GIT_LAB_API_ORIGIN" "$GITLAB_GROUP_ORIGIN" "$TOKEN_ORIGIN" > ${GITLAB_GROUP_ORIGIN}-origin.txt

api_get_group_projects_name "$GIT_LAB_API" "$GITLAB_GROUP" > ${GITLAB_GROUP}-new.txt
exit
# echo 'Please check original project list ${GITLAB_GROUP_ORIGIN}-origin.txt'
# echo 'Please check original project list ${GITLAB_GROUP}.txt'

PROJECT_LIST_ORIGINAL=$(cat ${GITLAB_GROUP_ORIGIN}-origin.txt)
for PROJECT_ORIGIN in $PROJECT_LIST_ORIGINAL; do
    local PROJECT_NEW="${GITLAB_GROUP}/$(basename "$PROJECT_ORIGIN")"
    migration
done


if [[ -f migration.tar.gz ]]; then
    rm migration.tar.gz
fi
}

main