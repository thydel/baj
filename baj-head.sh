baj-head-alias () {
    : ${2:?}
    local -n a=BASH_ALIASES;
    if [[ ! -v a[$1] || -v a[$1] && ${a[$1]} == $2:$1 ]];
    then alias $1="$2:${1}$3";
    else echo warning $(alias $1) not redefined as $2:$1 >&2;
    fi
}

declare -f baj-head-alias
