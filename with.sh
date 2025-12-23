# Break script without exiting an interactive shell
with:fail () { unset -v fail; : "${fail:?${FUNCNAME[1]} $@}"; }

_saved_aliases_=$(alias -p)

# Default to quine
alias args='local f=${FUNCNAME[0]}; (($#)) || { declare -f $f:fail $f; false; }'
# Args may be aliases
alias arg='f=${BASH_ALIASES[$1]:-$1}'
# Args must be existing func or var
alias check='declare -p $1 &> /dev/null || declare -f $f > /dev/null || with:fail «$1» neither var nor func'
# Declare a name as either var, func or both
alias decl='declare -p $1 &> /dev/null && declare -p $1; declare -f $f && echo export -f $f'
# Args after '--' if any must start with a func
alias run='(($#)) && { arg; declare -f $f || with:fail «$1» not a func; echo export -f $f; shift; echo $f "${@@Q}"; }'
#
# SYNOPSIS with [var|func]... [--] [func] [argument]...
# Output a bash script made from bash objects from current bash context and a func invocation
# "with a b c --" can be used to output declarations without invocation
# "with a b c -- d e 'f g'" will declare func d and preserve 'f g' as second arg
# "with a b c" is sugar for "with a b c -- c" (so, "c" must be a func)
# Any argument that may be a func will be alias expanded
with () { args && until [[ $# == 1 || $1 == -- ]]; do arg; check; decl; shift; done; [[ $1 == -- ]] && shift; run; }
unalias -a; eval "$_saved_aliases_"
export -f with:fail with
