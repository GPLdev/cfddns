#!/usr/bin/env bash

shopt -s nullglob globstar
set -euo pipefail
REALDIR=$(dirname $(realpath "$0"))
ERROR=false

if [ ! $(command -v curl) ]; then
    printf "\n\e[31;1mERROR: * * * please install curl * * *\e[0m\n\n"
    exit 1
fi

if [ ! $(command -v jq) ]; then
    printf "\n\e[31;1mERROR: * * * please install jq * * *\e[0m\n\n"
    exit 1
fi

if [ ! -f "$REALDIR/myipstun" ]; then
    printf "\n\e[31;1mERROR: * * * please install myip * * *\e[0m\n\n"
    exit 1
fi

if [ ! -f "$REALDIR/config.json" ]; then
    printf "\n\e[31;1mERROR: * * * Missing config file * * *\e[0m\n\n"
    exit 1
fi

IPv4='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'
printf "\n\033[0;32m--- %s ---\033[0m\n\n" "$(date)"
printf "\033[0;33m*** trying to get WAN IP with DNS\033[0m \033[0;34m>>>\033[0m\n"
WAN_IP=$(dig @ns1.google.com o-o.myaddr.l.google.com TXT +short | tr -d \" 2>/dev/null); check=$?

if [ "$check" != 0 ] || [[ ! "$WAN_IP" =~ ^$IPv4$ ]]; then
    printf "\033[0;34m>>>\033[0m \033[0;33mtrying to get WAN IP with STUN\033[0m \033[0;34m>>>\033[0m\n"
    WAN_IP=$("$REALDIR/myipstun" 2>/dev/null); check=$?
fi

if [ "$check" != 0 ] || [[ ! "$WAN_IP" =~ ^$IPv4$ ]]; then
    printf "\033[0;34m>>>\033[0m \033[0;33mtrying to get WAN IP with HTTPS\033[0m \033[0;34m>>>\033[0m\n"
    WAN_IP=$(curl -s "https://checkip.amazonaws.com/"); check=$?
fi

if [ "$check" != 0 ] || [[ ! "$WAN_IP" =~ ^$IPv4$ ]]; then
    printf "\033[0;34m>>>\033[0m \033[0;33mtrying to get WAN IP with HTTPS\033[0m \033[0;34m>>>\033[0m\n"
    WAN_IP=$(curl -s "https://1.1.1.1/cdn-cgi/trace" | sed -nr "s/^ip\=(.+)$/\1/p"); check=$?
fi

printf "\033[0;34m>>>\033[0m \033[0;32mWAN IP is %s\033[0m\n\n" "$WAN_IP"
printf "\033[0;33m*** trying to get recorded IP from logs\033[0m \033[0;34m>>>\033[0m\n"
if [ ! -d "$REALDIR/logs" ]; then
    if [ ! ${EUID} -eq 0 ]; then
        printf "\n\e[31;1mERROR: * * * please run as root or sudo  * * *\e[0m\n\n"
        exit 1
    fi
    printf "\033[0;34m>>>\033[0m \033[0;33mlogs directory is not present\033[0m \033[0;34m>>>\033[0m\n\033[0;34m>>>\033[0m \033[0;33mcreate directory\033[0m \033[0;34m>>>\033[0m\n"
    mkdir "$REALDIR/logs"
fi

if [ -f "$REALDIR/logs/MEM_IP" ]; then
    MEM_IP=$(cat "$REALDIR/logs/MEM_IP")
fi

if [ -z "${MEM_IP+x}" ]; then
    printf "\033[0;34m>>>\033[0m \033[0;33mIP log file is not present\033[0m \033[0;34m>>>\033[0m\n\033[0;34m>>>\033[0m \033[0;33mcreate IP log file\033[0m\n\n"
    echo "$WAN_IP" > "$REALDIR/logs/MEM_IP"
else
    printf "\033[0;34m>>>\033[0m \033[0;32mrecorded IP is %s\033[0m\n\n" "$MEM_IP"
fi

if [ -z "${MEM_IP+x}" ] || [ "$MEM_IP" != "$WAN_IP" ]; then
    printf "\033[0;34m* * * WAN IP has been changed and start to update DNS * * * \033[0m\n\n"
    DNSUPDATE=true
else
    DNSUPDATE=false
fi

for UPDATE in $( jq -r '.[] | @base64' "$REALDIR/config.json" ); do
    _read() { echo "${UPDATE}" | base64 --decode | jq -r "${1}"; }
    unset DOMAIN TTL PROXY ZONEID TOKEN DOMAINID VERAUTH DOMAINDATA APIUPDATE NEWDOMAIN
    DOMAIN=$(_read '.domain')
    TTL=$(_read '.ttl')
    PROXY=$(_read '.proxy')
    ZONEID=$(_read '.zoneid')
    TOKEN=$(_read '.token')
    printf "\033[0;33m*** checking domain %s from zone id %s\033[0m \033[0;34m>>>\033[0m\n" "$DOMAIN" "$ZONEID"
    if [ -f "$REALDIR/logs/id_$DOMAIN" ]; then
        DOMAINID=$(cat "$REALDIR/logs/id_$DOMAIN")
        NEWDOMAIN=false
        printf "\033[0;34m>>>\033[0m \033[0;33mdomain already configured\033[0m \033[0;34m>>>\033[0m\n"
    else
        NEWDOMAIN=true
        printf "\033[0;34m>>>\033[0m \033[0;33mnew domain detected on config file\033[0m \033[0;34m>>>\033[0m\n"
        printf "\033[0;34m>>>\033[0m \033[0;33mtesting the validity token for %s\033[0m \033[0;34m>>>\033[0m\n" "$DOMAIN"
        VERAUTH=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
            -H     "Authorization: Bearer $TOKEN" \
            -H     "Content-Type: application/json" | jq -r ".success")
        if [ "$VERAUTH" != true ]; then
            printf "\033[0;34m>>>\033[0m \033[0;31minvalid token provided for %s\033[0m\n\n" "$DOMAIN"
            ERROR=true
            continue
        fi
        printf "\033[0;34m>>>\033[0m \033[0;33mid log file for %s is not present\033[0m \033[0;34m>>>\033[0m\n\033[0;34m>>>\033[0m \033[0;33mtrying to get id with API\033[0m \033[0;34m>>>\033[0m\n" "$DOMAIN"
        DOMAINDATA=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records?type=A&name=$DOMAIN" \
            -H     "Authorization: Bearer $TOKEN" \
            -H     "Content-Type: application/json" | jq -r ".")
        if [ "$DOMAINDATA" != "" ] && [ $(echo "$DOMAINDATA" | jq -r ".success") = true ]; then
            if [ $(echo "$DOMAINDATA" | jq -r ".result_info.count") != 0 ]; then
                DOMAINID=$(echo "$DOMAINDATA" | jq -r ".result[0] .id")
                if [ "$DOMAINID" = "" ]; then
                    printf "\033[0;34m>>>\033[0m \033[0;31minvalid response id for domain %s\033[0m\n\n" "$DOMAIN"
                    ERROR=true
                    continue
                fi
                printf "\033[0;34m>>>\033[0m \033[0;33mcreate id log file\033[0m \033[0;34m>>>\033[0m\n"
                echo "$DOMAINID" > "$REALDIR/logs/id_$DOMAIN"
            else
                printf "\033[0;34m>>>\033[0m \033[0;31munable to locate a DNS record for the domain %s\033[0m\n\n" "$DOMAIN"
                ERROR=true
                continue
            fi
        else
            if [[ $( echo "$DOMAINDATA" | jq -r ".errors" ) != "" ]]; then
                printf "\033[0;34m>>>\033[0m \033[0;31minvalid zone id provided for the domain %s\033[0m\n\n" "$DOMAIN"
            else
                printf "\033[0;34m>>>\033[0m \033[0;31mAPI connection error occurred for %s\033[0m\n\n" "$DOMAIN"
            fi
            ERROR=true
            continue
        fi
    fi
    if [ "$DNSUPDATE" = true ] || [ "$NEWDOMAIN" = true ]; then
        printf "\033[0;34m>>>\033[0m \033[0;33mtrying to call API with record id %s\033[0m \033[0;34m>>>\033[0m\n" "$DOMAINID"
        APIUPDATE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records/$DOMAINID" \
            -H     "Authorization: Bearer $TOKEN" \
            -H     "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$WAN_IP\",\"ttl\":\"$TTL\",\"proxied\":${PROXY}}" | jq -r ".success")
        if [ "$APIUPDATE" == true ]; then
            printf "\033[0;34m>>>\033[0m \033[0;32mdomain %s has been pointed to %s\033[0m\n\n" "$DOMAIN" "$WAN_IP"
        else
            printf "\033[0;34m>>>\033[0m \033[0;31mAPI connection error occurred for %s during record update\033[0m\n\n" "$DOMAIN"
            ERROR=true
        fi
    else
        printf "\033[0;34m>>>\033[0m \033[0;32mno update required\033[0m\n\n"
    fi
done

if [ "$DNSUPDATE" = true ] && [ "$ERROR" = false ]; then
    printf "\033[0;33m*** trying to update new IP on log file\033[0m \033[0;34m>>>\033[0m\n"
    echo "$WAN_IP" > "$REALDIR/logs/MEM_IP"
    printf "\033[0;34m>>>\033[0m \033[0;32mnew IP updated on file\033[0m\n\n"
fi

printf "\n\033[0;32m* * * DNS update execution has been finished * * * \033[0m\n\n"
unset REALDIR IPv4 WAN_IP MEM_IP DOMAIN TTL PROXY ZONEID TOKEN DOMAINID VERAUTH DOMAINDATA APIUPDATE NEWDOMAIN UPDATE ERROR

exit 0
