#!/bin/bash
set -e -o pipefail

PREFIX=${PREFIX:-"{{"}
SUFFIX=${SUFFIX:-"}}"}
STRIP=${STRIP:-"false"}

function print_usage(){
    echo -e "USAGE:\n1) ${0##*/} <template-path> <parameters-path>\n2) cat <template-path> | ${0##*/} <parameters-path>"
}

case $# in
    1)
      contents="$(</dev/stdin)"
      parameters="$(<$1)"
      ;;
    2)
      contents="$(<$1)"
      parameters="$(<$2)"
      ;;
    *)
      print_usage
      fatal "Inavlid number of arguments." 1
      ;;      
esac

function trim_string() {
    local str="$*"
    # remove leading whitespace characters
    str="${str#"${str%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    str="${str%"${str##*[![:space:]]}"}"
    # remove leading double quotes
    str="${str%\"}"
    # remove trailing double quotes
    str="${str#\"}"
    # remove leading quotes
    str="${str%\'}"
    # remove trailing quotes
    str="${str#\'}"
    printf '%s' "$str"
}

pattern=
while IFS='\n' read key_value; do  
  ### skip empty lines
  [ -z "$key_value" ] && continue

  ### skip lines starting with # or // used for comments
  [[ "$key_value" == \#* ]] || [[ "$key_value" == \/\/* ]] && continue
  key="$(trim_string ${key_value%=*})"
  value="$(eval echo ${key_value#*=})"
  value="$(trim_string ${value})"

  ### remove PREFIX and SUFFIX from param, and get value of the resulted param name as an environment variable 
  # value="$(eval echo \$${param:${#PREFIX}:${#param}-${#PREFIX}-${#SUFFIX}})"
  if [[ (-n "$value") || (-z "$value" && $STRIP == "true" )]]; then
    pattern="$pattern -e 's|${PREFIX}${key}${SUFFIX}|${value}|g' "
  fi
done <<< "$parameters"
eval sed "$pattern" <<< "$contents"
