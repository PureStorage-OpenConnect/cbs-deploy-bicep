#!/bin/bash

CLI_VERSION='0.1'


# terminal colors
NO_FORMAT="\033[0m"
C_ORANGERED1="\033[38;5;202m"
C_GREY100="\033[48;5;231m"
C_GREY85="\033[48;5;253m"
C_BLUE3="\033[38;5;19m"


escape_quotes(){
    echo $@ | sed s/'"'/'\\"'/g
}


curlwithcode() {
    code=0
    # Run curl in a separate command, capturing output of -w "%{http_code}" into statuscode
    # and sending the content to a file with -o >(cat >/tmp/curl_body)
    statuscode=$(curl -w "%{http_code}" \
        -o >(cat >/tmp/curl_body) \
        "$@"
    ) || code="$?"

    body="$(cat /tmp/curl_body)"
    echo "{\"statusCode\": $statuscode,"
    echo "\"exitCode\": $code,"
    echo "\"body\": \"$(escape_quotes $body)\"}"
}

echoerr() { printf "\033[0;31m%s\n\033[0m" "$*" >&2; }
echosuccess() { printf "\033[0;32m%s\n\033[0m" "$*" >&2; }


trap 'echo "";echo "";echoerr "Deployment failed!"; echo ""' ERR 
