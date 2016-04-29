#!/bin/bash

set -euo pipefail

# Public API Functions {{{

# @description Make all functions from tests.sh available without 'tests:'
# prefix. Prefix can be also user defined, like 't:'.
#
# @arg $1 string Custom prefix for namespace functions.
tests:import-namespace() {
    local prefix="${1:-}"

    if [ $_tests_verbose -gt 2 ]; then
        tests:debug "! importing namespace 'tests:'" \
            $(sed -re"s/.+/ into '&'/" <<< $prefix)
    fi

    builtin eval $(
        declare -F |
        grep -F -- '-f tests:' |
        cut -d: -f2 |
        sed -re's/.*/'$prefix'&() { tests:& "${@}"; };/'
    )
}

# @description Returns temporary directory for current test session.
#
# It can be used as a workspace for the testcase.
#
# @example
#   ls $(tests:get-tmp-dir)
#
# @stdout Path to temp dir, e.g, /tmp/tests.XXXX
tests:get-tmp-dir() {
    if [ -z "$_tests_dir" ]; then
        tests:debug "test session not initialized"
        _tests_interrupt
    fi

    echo "$_tests_dir"
}

# @description Asserts, that first string arg is equals to second.
#
# @example
#   tests:assert-equals 1 2 # fails
#
# @arg $1 string Expected string.
# @arg $2 string Actual value.
tests:assert-equals() {
    local expected="$1"
    local actual="$2"

    _tests_make_assertion "$expected" "$actual" \
        "two strings equals" \
        ">>> $expected$" \
        "<<< $actual$"

    _tests_inc_asserts_count
}

# @description Asserts, that last evaluated command's stdout contains given
# string.
#
# @example
#   tests:eval echo 123
#   tests:assert-stdout 123
#
# @arg $1 string Expected stdout.
tests:assert-stdout() {
    local expected="$1"
    shift

    tests:assert-stdout-re "$(_tests_quote_re <<< "$expected")"
}

# @description Asserts, that last evaluated command's stderr contains given
# string.
#
# @example
#   tests:eval echo 123 '1>&2' # note quoting
#   tests:assert-stderr 123
#
# @arg $1 string Expected stderr.
tests:assert-stderr() {
    local expected="$1"
    shift

    tests:assert-stderr-re "$(_tests_quote_re <<< "$expected")"
}

# @description Compares, that last evaluated command output (stdout, stderr) or
# file contents matches regexp.
#
# @example
#   tests:eval echo aaa
#   tests:match-re stdout a.a
#   echo $? # 0
#   tests:match-re stdout a.b
#   echo $? # 1
#
# @arg $1 'stdout'|'stderr'|filename If 'stdout' or 'stderr' is used, use
# last command's stream as actual value. If filename is specified, then use
# contents of specified filename as actual contents.
#
# @arg $2 regexp Regexp to match, same as in grep.
tests:match-re() {
    local target="$1"
    local regexp="$2"
    shift 2

    if [ -f $target ]; then
        file=$target
    elif [ "$target" = "stdout" ]; then
        file=$_tests_run_stdout
    else
        file=$_tests_run_stderr
    fi

    if [ -z "$regexp" ]; then
        if [ -s $file ]; then
            echo 1
        else
            echo 0
        fi
    elif grep -qP "$regexp" $file; then
        echo 0
    else
        echo $?
    fi > $_tests_run_exitcode
}

# @description Same as 'tests:match-re', but abort testing if comparison
# failed.
#
# @example
#   tests:eval echo aaa
#   tests:assert-re stdout a.a
#   tests:assert-re stdout a.b # test fails there
#
# @see tests:match-re
tests:assert-re() {
    local target="$1"
    local regexp="$2"
    shift 2

    tests:match-re "$target" "$regexp"

    local result=$(cat $_tests_run_exitcode)

    _tests_make_assertion $result 0 \
        "regexp matches" \
        ">>> ${regexp:-<empty regexp>}" \
        "<<< contents of ${target}:\n\
            $(_tests_pipe _tests_indent "$target" < $file \
                | _tests_pipe _tests_check_empty)"

    _tests_inc_asserts_count
}

# @description Asserts, that there are no diff on the last command output
# (stderr or stdout), or on string or on specified file with specified string
# or file.
#
# @example
#   tests:eval echo -e '1\n2'
#   tests:assert-no-diff stdout "$(echo -e '1\n2')" # note quotes
#   tests:assert-no-diff stdout "$(echo -e '1\n3')" # test will fail
#
# @arg $1 string|filename Expected value.
# @arg $2 'stdout'|'stderr'|string|filename Actual value.
# @arg $@ any Additional arguments for diff.
tests:assert-no-diff() {
    if [ -s /dev/stdin ]; then
        local expected_target=/dev/stdin
    else
        local expected_target="$1"
        shift
    fi

    local actual_target="$1"
    shift
    local options="-u $@"

    if [ -e "$expected_target" ]; then
        expected_content="$(cat $expected_target)"
    else
        expected_content="$expected_target"
    fi

    if [ -e "$actual_target" ]; then
        actual_content="$(cat $actual_target)"
    elif [ "$actual_target" = "stdout" ]; then
        actual_content="$(cat $_tests_run_stdout)"
    elif [ "$actual_target" = "stderr" ]; then
        actual_content="$(cat $_tests_run_stderr)"
    else
        actual_content="$actual_target"
    fi

    local diff
    local result=0
    if diff=$(diff `echo $options` \
            <(echo -e "$expected_content") \
            <(echo -e "$actual_content")); then
        result=0
    else
        result=$?
    fi

    _tests_make_assertion $result 0 \
        "no diff" \
        "\n$(_tests_pipe _tests_indent 'diff' <<< "$diff")"

    _tests_inc_asserts_count
}

# @description Returns file containing stdout of last command.
#
# @example
#   tests:eval echo 123
#   cat $(tests:get-stdout-file) # will echo 123
#
# @stdout Filename containing stdout.
tests:get-stdout-file() {
    echo $_tests_run_stdout
}

# @description Returns file containing stderr of last command.
#
# @example
#   tests:eval echo 123 '1>&2' # note quotes
#   cat $(tests:get-stderr) # will echo 123
#
# @stdout Filename containing stderr.
tests:get-stderr-file() {
    echo $_tests_run_stderr
}

# @description Same as 'tests:assert-diff', but ignore changes whose lines are
# all blank.
#
# @example
#   tests:eval echo -e '1\n2'
#   tests:assert-no-diff-blank stdout "$(echo -e '1\n2')" # note quotes
#   tests:assert-no-diff-blank stdout "$(echo -e '1\n\n2')" # test will pass
#
# @see tests:diff
tests:assert-no-diff-blank() {
    tests:assert-no-diff "$1" "$2" "-B"
}

# @description Same as shell 'test' function, but asserts, that exit code is
# zero.
#
# @example
#   tests:assert-test 1 -eq 1
#   tests:assert-test 1 -eq 2 # test will fail
#
# @arg $@ Arguments for 'test' function.
tests:assert-test() {
    local args="$@"

    tests:debug "test $args"
    local result
    if test "$@"; then
        result=0
    else
        result=$?
    fi

    if [ $result -ne 0 ]; then
        touch "$_tests_dir/.failed"
        tests:debug "test $args: failed"
        _tests_interrupt
    fi

    _tests_inc_asserts_count
}

# @description Put specified contents into temporary file with given name.
#
# @example
#   tests:put-string xxx "lala"
#
#   tests:assert-equals xxx "lala" # test will pass
#
# @arg $1 filename Temporary file name.
# @arg $2 string Contents to put.
tests:put-string() {
    local file="$1"
    local content="$2"

    tests:put "$file" <<< "$content"
}

# @description Put stdin into temporary file with given name.
#
# @example
#   tests:put xxx <<EOF
#   1
#   2
#   3
#   EOF
#
#   tests:assert-no-diff xxx "$(echo -e '1\n2\n3')" # test will pass
#
# @arg $1 filename Temporary file name.
tests:put() {
    local file="$_tests_dir/$1"

    local stderr
    if ! stderr=$(cat 2>&1 > $file); then
        tests:debug "error writing file:"
        _tests_indent 'error' <<< "$stderr"
        _tests_interrupt
    fi

    if [ $_tests_verbose -gt 2 ]; then
        tests:debug "wrote the file $file with content:"
        _tests_indent 'file' < $file
    fi

}

# @description Asserts that stdout of last evaluated command matches given
# regexp.
#
# @example
#   tests:eval echo 123
#
#   tests:assert-stdout-re 1.3 # will pass
#
# @arg $1 regexp Regexp, same as in grep.
tests:assert-stdout-re() {
    tests:assert-re stdout "$@"
}

# @description Asserts as 'tests:assert-stdout-re', but stderr used instead
# of stdout.
#
# @example
#   tests:eval echo 123 '1>&2' # note quotes
#
#   tests:assert-stderr-re 1.3 # will pass
#
# @arg $1 regexp Regexp, same as in grep.
tests:assert-stderr-re() {
    tests:assert-re stderr "$@"
}

# @description Asserts that last evaluated command exit status is zero.
#
# @example
#   tests:eval true
#   tests:assert-success
#
# @noargs
tests:assert-success() {
    tests:assert-exitcode 0
}

# @description Asserts that last evaluated command exit status is not zero.
# Basically, alias for `test:not tests:assert-success`.
#
# @example
#   tests:eval false
#   tests:assert-fail
#
# @noargs
tests:assert-fail() {
    tests:not tests:assert-success
}

# @description Asserts that exit code of last evaluated command equals to
# specified value.
#
# @example
#   tests:eval false
#   tests:assert-exitcode 1
#
# @arg $1 int Expected exit code.
tests:assert-exitcode() {
    local actual=$(cat $_tests_run_exitcode)
    local expected=$1
    shift

    _tests_make_assertion "$expected" "$actual" \
        "command exited with code" \
        "actual exit code = $actual" \
        "expected exit code $_tests_last_assert_operation $expected"

    _tests_inc_asserts_count
}

# @description Negates passed assertion.
#
# @example
#   tests:eval false
#   tests:assert-fail
#   tests:not tests:assert-success
#
#   tests:eval true
#   tests:assert-success
#   tests:not tests:assert-fail
#
# @arg $1 int Expected exit code.
tests:not() {
    _tests_assert_operation="!="
    _tests_last_assert_operation="!="

    "${@}"

    _tests_assert_operation="="
}

# @description Same as tests:debug(), but colorize output
# for better vizibility.
#
# @arg $@ any String to output.
tests:describe() {
    tests:debug "@@ \e[7;49;34m" ${@} "\e[0m"
}

# @description Print specified string in the debug log.
#
# @example
#   tests:debug "hello from debug" # will shown only in verbose mode
#
# @arg $@ any String to echo.
tests:debug() {
    local output=$(_tests_get_debug_fd)

    if [ $_tests_verbose -lt 1 ]; then
        return
    fi

    if [ "$_tests_dir" ]; then
        echo -e "${_tests_debug_prefix:-# }$@"
    else
        echo -e "### $@"
    fi >&${output}
}

# @description Changes working directory to specified directory.
#
# @arg $1 directory Directory to change to.
tests:cd() {
    local dir=$1
    tests:debug "\$ cd $1"
    builtin cd $1
}

# @description Evaluates specified string via shell 'eval'.
#
# Redirection syntax differs from what can be found in bash.
#
# Redirection operators will be used as redirection only if they are
# passed as separate argumentm, like this: `tests:eval echo 1 '>' 2`.
#
# List of redirection operators:
# * `>`
# * `<`
# * `>&`
# * `<&`
# * `>&n`, where `n` is a number
# * `<&n`, where `n` is a number
# * `>>`
# * `<<<`
# * `<>`
# * `|`
#
# To redirect output to file use: `> filename` (note space).
#
# Also, if only one argument is passed to `tests:eval`, the it will
# be evaled as is. So, `tests:eval "echo 1 > 2"` will create file `2`,
# but `tests:eval echo "1 > 2"` will only output `1 > 2` to the stdout.
#
# *NOTE*: you will not get any stdout or stderr from evaluated command.
# To obtain stdout or stderr see `tests:pipe`.
#
# *NOTE*: output will be buffered! If you want unbuffered output, use
# `tests:runtime`.
#
# *NOTE*: use of that function will not produce any output to stdout
# nor stderr. If you want to pipe your result to something, use
# `tests:pipe`.
#
# @example
#   tests:eval echo 123 "# i'm comment"
#   tests:eval echo 123 \# i\'m comment
#   tests:eval echo 567 '1>&2' # redirect to stderr
#   tests:eval echo 567 1\>\&2' # same
#
# @arg $@ string String to evaluate.
# @see tests:pipe
# @see tests:runtime
tests:eval() {
    exec {output}>$_tests_run_output

    _tests_eval_and_output_to_fd ${output} ${output} "${@}"
}

# @description Same, as `tests:pipe`, but produce unbuffered result.
#
# @example
#   tests:runtime 'echo 1; sleep 10; echo 2'  # see 1 immediately
#
# @arg $@ string String to evaluate.
# @see tests:eval
tests:runtime() {
    _tests_buffering="stdbuf -e0 -i0 -o0 "

    exec {output}>$_tests_run_output

    { { _tests_eval_and_output_to_fd ${output} ${output} "${@}" \
        {output}>&1 | _tests_indent 'stdout' ; } \
        {output}>&1 | _tests_indent 'stderr' ; }

    _tests_buffering=""
}

# @description Same, as `tests:eval`, but return stdout and stderr
# as expected.
#
# @example
#   lines=$(tests:eval echo 123 | wc -l)  # note not escaped pipe
#   tests:assert-equals $lines 1
#
# @arg $@ string String to evaluate.
# @see tests:eval
tests:pipe() {
    exec {stdout}>&1
    exec {stderr}>&2

    _tests_eval_and_output_to_fd ${stdout} ${stderr} "${@}"
}

# @description Eval specified command and assert, that it has zero exitcode.
#
# @example
#   tests:esnure true # will pass
#   tests:esnure false # will fail
#
# @arg $@ any Command to evaluate.
tests:ensure() {
    tests:eval "$@"
    tests:assert-success
}

# @description Creates temporary directory.
#
# @arg $@ any Same as for mkdir command.
tests:make-tmp-dir() {
    # prepend to any non-flag argument $_tests_dir prefix

    if [ $_tests_verbose -gt 2 ]; then
        tests:debug "making directories in $_tests_dir: mkdir ${@}"
    fi

    local stderr
    if ! stderr=$(
        /bin/mkdir \
            $(sed -re "s#(^|\\s)([^-])#\\1$_tests_dir/\\2#g" <<< "${@}")); then
        tests:debug "error making directories ${@}:"
        _tests_indent 'error' <<< "$stderr"
        _tests_interrupt
    fi
}

# @description Changes working directory to the specified temporary directory,
# previously created by 'tests:mkdir'.
#
# @arg $1 string Directory name.
tests:cd-tmp-dir() {
    tests:cd $_tests_dir/$1
}

# @description Runs any command in background, this is very useful if you test
# some running service.
#
# Processes which are ran by 'tests:background' will be killed on cleanup
# state, and if test failed, stderr and stdout of all background processes will
# be printed.
#
# @arg $1 variable Name of variable to store BG process ID.
# @arg $2 -- -- Delimiter, is REQUIRED.
# @arg $@ string Command to start.
#
# @stdout Unique identifier of running backout process.
tests:run-background() {
    local identifier_var=$1
    shift 2 # for --

    local cmd=("${@}")

    _tests_prepare_eval_namespace bg

    local identifier=$(cat $_tests_run_id)
    local run_mode="&"
    if [ $_tests_verbose -gt 5 ]; then
        tests:debug "{DEBUG} [BG] #$identifier: TASK WILL RUN IN FOREGROUND"
        run_mode=""
    fi


    tests:debug "{START} [BG] #$identifier: ! namespace at '$_tests_run_namespace'"
    tests:debug "{START} [BG] #$identifier: evaluating command:"

    _tests_indent '$' <<< "${cmd[@]}"

    builtin eval "( _tests_run_bg_task $identifier cmd )" $run_mode

    builtin eval $identifier_var=\$identifier
}

# @description Returns pid of specified background process.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
#
# @stdout Pid of background process.
tests:get-background-pid() {
    cat "$_tests_dir/.ns/bg/$1/pid"
}

# @description Returns stdout of specified background process.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
#
# @stdout Stdout from background process.
tests:get-background-stdout() {
    echo "$_tests_dir/.ns/bg/$1/stdout"
}

# @description Returns stderr of specified background process.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
#
# @stdout Stderr from background process.
tests:background-stderr() {
    echo "$_tests_dir/.ns/bg/$1/stderr"
}

# @description Stops background process with 'kill -9'.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
tests:stop-background() {
    local id="$1"
    local pid=$(cat $_tests_dir/.ns/bg/$id/pid)
    if [ -z "$pid" ]; then
        tests:debug "{STOP} [BG] #$id: PID UNAVAILABLE"
        return 1
    fi

    tests:debug "{STOP} [BG] #$id pid:<$pid>: stopping"
    tests:debug "{STOP} [BG] #$id pid:<$pid> tasks:"

    pstree -lp "$pid" | _tests_pipe _tests_indent 'tasks' | _tests_check_empty

    local pids=($(_tests_get_pids_tree $pid))

    _tests_pipe _tests_indent 'pid' <<< "${pids[@]}" | tail -n+2

    if ! _tests_pipe command kill "${pids[@]:-$pid}" \
        | _tests_indent 'kill'
    then
        tests:debug "{STOP} [BG] #$id pid:<$pid>: already stopped"
    else
        local killed
        local done=false

        while ! $done; do
            if ! killed=$(command kill -0 "${pids[@]}" 2>&1 | wc -l); then
                done=true
            fi

            tests:debug "{STOP} [BG] #$id tasks killed $killed/${#pids[@]}"
            sleep 0.5
        done

        if [ "${#killed}" -ne "${#pids[@]}" ]; then
            if command kill -TERM "${pids[@]}" 2>/dev/null; then
                tests:debug "{STOP} [BG] #$id pid:<$pid>: TERMINATED"
            fi
        fi
    fi

    return 0
}

# @description Waits, until specified file will be changed or timeout passed
# after executing specified command.
#
# @arg $1 string Command to evaluate.
# @arg $2 filename Filename to wait changes in.
# @arg $3 int Interval of time to check changes after.
# @arg $4 int Timeout in seconds.
tests:wait-file-changes() {
    local file="$1"
    local sleep_interval="$2"
    local sleep_max="$3"

    shift 3

    local command="${@}"

    local stat_initial=$(stat $file)
    local sleep_iter=0
    local sleep_iter_max=$(bc <<< "$sleep_max/$sleep_interval")

    tests:debug "! waiting file changes after command: file '$file' (${sleep_max}sec max)"

    if [ $# -gt 0 ]; then
        "${command[@]}"
    fi

    while true; do
        sleep_iter=$(($sleep_iter+1))
        local stat_actual=$(stat $file)
        if [[ "$stat_initial" == "$stat_actual" ]]; then
            if [[ $sleep_iter -ne $sleep_iter_max ]]; then
                sleep $sleep_interval
                continue
            fi

            tests:debug "! file left unchanged: file '$file' (after $( \
                bc <<< "$sleep_iter * $sleep_interval" )sec)"

            return 1
        fi

        tests:debug "! file changed: file '$file' (after $( \
            bc <<< "$sleep_iter * $sleep_interval" )sec)"

        return 0
    done
}

# @description Sets verbosity of testcase output.
#
# @arg $1 int Verbosity.
tests:set-verbose() {
    _tests_verbose=$1
}

# @description Copy specified file or directory from the testcases
# dir to the temporary test directory.
#
# @arg $@ any Same args, as for cp commmand.
tests:clone() {
    local args=(dummy)
    local last_arg=""

    while [ $# -gt 0 ]; do
        if [ "$last_arg" ]; then
            args+=($_tests_base_dir/$last_arg)
        fi

        last_arg=""

        if grep -q '^-' <<< "$1"; then
            args=($args $1)
        else
            last_arg=$1
        fi

        shift
    done

    local files="${args[@]:1}"
    local dest="$_tests_dir/$last_arg"

    if [ $_tests_verbose -gt 2 ]; then
        tests:debug "\$ cp $files $dest"
    fi

    local stderr
    if ! stderr=$(/bin/cp "$files" "$dest" 2>&1); then
        tests:debug "error copying: cp $files $dest:"
        _tests_indent 'error' <<< "$stderr"
        _tests_interrupt
    fi

}

# @description Copy specified file from testcases to the temporary test
# directory and then source it.
#
# @arg $1 filename Filename to copy and source.
# @arg $2 filename Destination under test dir (not required).
# $exitcode >0 If source failed
tests:involve() {
    local source="$1"
    local basename="$(basename "$1")"
    local destination="${2:-.}"

    if [ -d $destination ]; then
        destination=$destination/$(basename $source)
    fi

    tests:clone "$source" "$destination"

    tests:require $destination
}

# @description Source file with debug.
#
# @arg $1 filename Filename to source.
# $exitcode >0 If source failed
tests:require() {
    local file="$1"

    if [ $_tests_verbose -gt 1 ]; then
        tests:debug "{BEGIN} source $file"
    fi

    if [ $_tests_verbose -gt 2 ]; then
        tests:debug "\$ source $file"
    fi

    trap "tests:debug '{ERROR} in $file'" EXIT

    builtin source "$file"

    trap - EXIT

    if [ $_tests_verbose -gt 1 ]; then
        tests:debug "{END} source $file"
    fi
}


tests:colorize() {
    local type=$1  # unused right now
    local color=$2

    sed -u -r -e 's/^/\\e[38;5;'${color}'m/' -e 's/$/\\e[0m/'
}
# }}}

# Internal Code {{{

# Internal global state {{{
#
# Do not use this variables directly.

# Current test session.
_tests_dir=""

# Verbosity level.
_tests_verbose=0

# Assertions counter.
_tests_asserts=0

# File with last stdout.
_tests_run_stdout=""

# File with last stderr.
_tests_run_stderr=""

# File with stderr and stout from eval
_tests_run_output=""

_tests_run_id=""

_tests_run_cmd=""

_tests_run_clean=""

# File with last exitcode.
_tests_run_exitcode=""

_tests_run_pidfile=""

_tests_run_namespace=""

# Current working directory for test suite.
_tests_base_dir=""

# Operation used in assertions (= or !=)
_tests_assert_operation="="

# Last used assert operation.
_tests_last_assert_operation="="

_tests_debug_fd="304"

_tests_bg_channels=""

_tests_debug_prefix=""

_tests_buffering=""

# }}}

_tests_escape_cmd() {
    local cmd=()

    if [ $# -gt 1 ]; then
        for i in "$@"; do
            case "$i" in
                '<>')  cmd+=($i) ;;
                '>>')  cmd+=($i) ;;
                '<<<') cmd+=($i) ;;
                '<&')  cmd+=($i) ;;
                '>&')  cmd+=($i) ;;
                '>')   cmd+=($i) ;;
                '<')   cmd+=($i) ;;
                '|')   cmd+=($i) ;;

                '>&'[[:digit:]]) cmd+=($i) ;;
                '<&'[[:digit:]]) cmd+=($i) ;;

                *) cmd+=("$(_tests_quote_cmd <<< "$i")")
            esac
        done
    else
        cmd=("$1")
    fi

    cat <<< "${cmd[@]}"
}

_tests_pipe() {
    {
        builtin eval exec $(_tests_get_debug_fd)\>\&1
        "${@}"
    }
}

_tests_raw_eval() {
    printf $BASHPID > $_tests_run_pidfile

    builtin eval $_tests_buffering "$(_tests_escape_cmd "${@}")"
}

_tests_get_debug_fd() {
    if { >&${_tests_debug_fd}; } 2>/dev/null; then
        echo ${_tests_debug_fd}
    else
        echo 2
    fi
}

_tests_indent() {
    local output=$(_tests_get_debug_fd)

    local prefix="${1:-}"
    if [ $_tests_verbose -lt 4 ]; then
        prefix=""
    fi

    sed -u \
        -e "s/^/    ${prefix:+"($prefix) "}/" \
        -e '1i\ ' \
        -e '$a\ ' | \
            sed -u -e "s/^/$_tests_debug_prefix/" \
        >&${output}
}

_tests_check_empty() {
    local output=$(_tests_get_debug_fd)

    local first_byte
    local empty=false

    if ! first_byte=$(dd bs=1 count=1 2>/dev/null | od -to1 -An); then
        empty=true
    fi

    if [ -z "$first_byte" ]; then
        empty=true
    fi

    if $empty; then
        _tests_pipe _tests_indent <<< "<empty>"
    else
        printf "\\${first_byte# }"
        _tests_unbuffer cat
    fi >&${output}
}

_tests_quote_re() {
    sed -r 's/[.*+[()?$^]|]/\\\0/g'
}

_tests_quote_cmd() {
    sed -r -e "s/['\`\"]|\\$\{?[0-9#\!?@_\[\]]*\}?/\\\&/g" -e '1s/^/"/' -e '$s/$/"/'
}

_tests_get_testcases() {
    local directory="$1"
    local mask="$2"
    (
        shopt -s globstar nullglob
        echo $directory/$mask
    )
}

# FIXME refactor that shit!
_tests_run_all() {
    local testcases_dir="$1"
    local testcase_setup="$2"
    local see_subdirs=$3

    local filemask="*.test.sh"
    if $see_subdirs; then
        filemask="**/*.test.sh"
    fi

    local testcases=($(_tests_get_testcases "$testcases_dir" "$filemask"))
    if [ ! -v testcases ]; then
        echo no testcases found.

        exit 1
    fi


    local verbose=$_tests_verbose
    if [ $verbose -lt 1 ]; then
        _tests_verbose=4
    fi

    local testsuite_dir=$(readlink -f "$_tests_base_dir/$testcases_dir")
    echo running test suite at: $testsuite_dir
    echo
    if [ $verbose -eq 0 ]; then
        echo -ne '  '
    fi

    local success=0
    local assertions_count=0
    for file in "${testcases[@]}"; do
        _tests_set_last "$file"

        if [ $verbose -eq 0 ]; then
            local stdout="`mktemp -t stdout.XXXX`"
            local stderr="`mktemp -t stdout.XXXX`"
            local pwd="$(pwd)"

            trap "_tests_show_test_output $stdout $stderr $file" EXIT

            _tests_asserts=0

            local result
            if _tests_run_one "$file" "$testcase_setup" \
                    >$stdout 2>$stderr;
            then
                result=0
            else
                result=$?
            fi

            builtin cd "$pwd"
            if [ $result -eq 0 ]; then
                echo -n .
                success=$((success+1))
                rm -f $stdout
            else
                echo -n F
                echo
                echo

                exit $result
            fi
        else
            local result
            if _tests_run_one "$file" "$testcase_setup"; then
                result=0
            else
                result=$?
            fi
            if [ $result -ne 0 ]; then
                exit $result
            fi

            success=$((success+1))
        fi

        assertions_count=$(($assertions_count+$_tests_asserts))
    done

    _tests_rm_last

    echo
    echo
    echo ---
    echo "$success tests ($assertions_count assertions) done successfully!"
}

_tests_get_pids_tree() {
    local main_pid=$1

    pstree -lp $main_pid | grep -oP '\(\d+\)' | grep -oP '\d+'
}

_tests_show_test_output() {
    local stdout=$1
    local stderr=$2
    local last=$3

    if [ ! -e $stdout -o ! -e $stderr ]; then
        return
    fi

    cat $stdout
    cat $stderr >&2

    rm -f $stdout
    rm -f $stderr
}

_tests_run_one() {
    local testcase="$1"
    local testcase_setup="$2"

    local testcase_file="$_tests_base_dir/$testcase"

    if ! test -e $testcase; then
        echo "testcase '$testcase' not found"
        return 1
    fi

    tests:debug "TESTCASE $testcase"

    _tests_init

    if [ ! -s $_tests_dir/.asserts ]; then
        echo 0 > $_tests_dir/.asserts
    fi

    local result
    if ! _tests_run_raw "$testcase_file" "$testcase_setup"; then
        result=$?
    else
        result=0
    fi

    _tests_asserts=$(cat $_tests_dir/.asserts)

    if [[ $result -ne 0 && ! -f "$_tests_dir/.failed" ]]; then
        tests:debug "test exited with non-zero exit code"
        tests:debug "exit code = $result"
        touch "$_tests_dir/.failed"
    fi

    _tests_cleanup

    if [ $result -ne 0 ]; then
        tests:debug "TESTCASE FAILED $testcase"
        return 1
    else
        tests:debug "TESTCASE PASSED $testcase"$'\n'
        return 0
    fi
}

_tests_run_raw() {
    local testcase_file="$1"
    local testcase_setup="$2"

    (
        PATH="$_tests_dir/bin:$PATH"

        builtin cd $_tests_dir

        if [ -n "$testcase_setup" ]; then
            if [ $_tests_verbose -gt 2 ]; then
                tests:debug "{BEGIN} SETUP"
            fi

            if ! tests:involve "$testcase_setup"; then
                exit 1
            fi

            if [ $_tests_verbose -gt 2 ]; then
                tests:debug "{END} SETUP"
            fi
        fi

        builtin source "$testcase_file"

        _tests_wait_bg_tasks
    ) 2>&1 | _tests_indent
}

_tests_run_bg_task() {
    local identifier=$1
    local cmd_var=$2

    shift 2

    local to_evaluate=()

    builtin eval to_evaluate=\"\${$cmd_var[@]}\"

    _tests_debug_prefix="[BG] pid:<$BASHPID> #$identifier: "

    exec {_tests_debug_fd}>$_tests_bg_channels/debug

    tests:debug "{START} [BG] #$identifier: started pid:<$BASHPID>"

    printf "%s\0" "${cmd[@]}" > $_tests_run_cmd
    printf "%s" "$BASHPID" > $_tests_run_pidfile

    tests:pipe "${cmd[@]}" \
        1>$_tests_bg_channels/stdout \
        2>$_tests_bg_channels/stderr
}

_tests_new_id() {
    date +'%s.%N' | md5sum | head -c 6
}

_tests_prepare_eval_namespace() {
    if [ $_tests_run_clean ]; then
        if [ "$(cat $_tests_run_clean)" = "1" ]; then
            return
        fi
    fi

    local namespace="$1"

    local identifier=$(_tests_new_id)
    local dir=$_tests_dir/.ns/$namespace/$identifier

    mkdir -p $dir

    _tests_run_stdout=$dir/stdout
    _tests_run_stderr=$dir/stderr
    _tests_run_exitcode=$dir/exitcode
    _tests_run_pidfile=$dir/pid
    _tests_run_output=$dir/output
    _tests_run_cmd=$dir/cmd
    _tests_run_id=$dir/id
    _tests_run_clean=$dir/clean

    _tests_run_namespace=$dir

    touch $_tests_run_stderr
    touch $_tests_run_stdout
    touch $_tests_run_pidfile
    touch $_tests_run_exitcode
    touch $_tests_run_output
    touch $_tests_run_cmd

    printf "%s" $identifier > $_tests_run_id
    printf 1 > $_tests_run_clean

    if [ $_tests_verbose -gt 4 ]; then
        tests:debug "{DEBUG} prepared eval namespace at $dir"
    fi
}

_tests_get_last() {
    cat $_tests_base_dir/.last-testcase
}

_tests_set_last() {
    local testcase=$1
    echo "$testcase" > $_tests_base_dir/.last-testcase
}

_tests_rm_last() {
    rm -f $_tests_base_dir/.last-testcase
}

_tests_run_bg_reader() {
    local prefix=${1:-}
    local pipe=$2

    (
        while [ -e $_tests_bg_channels/.active ]; do
            while read line; do
                if [ $_tests_verbose -gt 4 ]; then
                    _tests_pipe tests:debug "${prefix:+"($prefix) "}$line"
                fi
            done < $pipe
        done | _tests_indent
    ) &
}

_tests_init() {
    _tests_dir="$(mktemp -t -d tests.XXXX)"

    /bin/mkdir $_tests_dir/bin

    _tests_prepare_eval_namespace eval

    _tests_bg_channels="$_tests_dir/.bg-channels/"

    mkdir -p $_tests_bg_channels

    mkfifo $_tests_bg_channels/stdout
    mkfifo $_tests_bg_channels/stderr
    mkfifo $_tests_bg_channels/debug

    touch $_tests_bg_channels/.active

    _tests_run_bg_reader "bg stderr" $_tests_bg_channels/stderr
    _tests_run_bg_reader "bg stdout" $_tests_bg_channels/stdout
    _tests_run_bg_reader "bg debug" $_tests_bg_channels/debug

    tests:debug "{BEGIN} TEST SESSION AT $_tests_dir"
}

_tests_cleanup() {
    local fifo

    rm $_tests_bg_channels/.active

    exec {fifo}>$_tests_bg_channels/stdout
    exec {fifo}<&-

    exec {fifo}>$_tests_bg_channels/stderr
    exec {fifo}<&-

    exec {fifo}>$_tests_bg_channels/debug
    exec {fifo}<&-

    rm -rf "$_tests_dir"

    _tests_dir=""

    tests:debug "{END} TEST SESSION"
}

_tests_wait_bg_tasks() {
    for bg_dir in $_tests_dir/.ns/bg/*; do
        if ! test -d $bg_dir; then
            continue
        fi

        local bg_id=$(cat $bg_dir/id)

        tests:stop-background $bg_id

        if [ -e "$_tests_dir/.failed" -o $_tests_verbose -gt 3 ]; then
            local bg_cmd=$(cat $bg_dir/cmd)
            local bg_stdout=$bg_dir/stdout
            local bg_stderr=$bg_dir/stderr


            tests:debug "{STOP} [BG] #$bg_id: command was:"

            _tests_indent '$' <<< "$bg_cmd"

            tests:debug "{STOP} [BG] #$bg_id stdout:"
            _tests_pipe _tests_indent 'stdout' < "$bg_stdout" \
                | _tests_check_empty

            tests:debug "{STOP} [BG] #$bg_id stderr:"
            _tests_pipe _tests_indent 'stderr' < "$bg_stderr" \
                | _tests_check_empty
        fi
    done

    return 0
}

_tests_interrupt() {
    exit 88
}

_tests_make_assertion() {
    local assertion_name=$3

    tests:debug "assertion ($assertion_name): should be $_tests_assert_operation"

    local result
    if test "$1" $_tests_assert_operation "$2"; then
        result=0
    else
        result=$?
    fi

    shift 3

    if [ $result -gt 0 ]; then
        touch "$_tests_dir/.failed"
        tests:debug "assertion ($assertion_name): failed"
    fi

    if [ $_tests_verbose -gt 3 -o $result -gt 0 ]; then
        if [ $result -eq 0 ]; then
            tests:debug "assertion ($assertion_name): success"
        fi

        while [ $# -gt 0 ]; do
            tests:debug "assertion ($assertion_name): $1"

            shift
        done
    fi


    if [ $result -gt 0 ]; then
        _tests_interrupt
    fi
}

_tests_inc_asserts_count() {
    local count=$(cat $_tests_dir/.asserts)
    echo $(($count+1)) > $_tests_dir/.asserts
}

_tests_unbuffer() {
    stdbuf -o0 -i0 -e0 "${@}"
}

_tests_eval_and_output_to_fd() {
    local stdout=$1
    local stderr=$2

    shift 2

    if [ $_tests_verbose -gt 4 ]; then
        tests:debug "{DEBUG} namespace ID: $_tests_run_id"
    fi

    local input=/dev/stdin

    if [ -s "$input" ]; then
        tests:debug "(stdin) evaluating command:"
    else
        input=/dev/null

        tests:debug "evaluating command:"
    fi

    _tests_pipe _tests_indent '$' <<< "${@}" | head -n-1 >$_tests_debug_fd

    if [ $_tests_verbose -gt 3 ]; then
        _tests_escape_cmd "${@}" | _tests_indent 'eval'
    fi

    if [ $(_tests_get_debug_fd) -eq 2 ]; then
        exec {_tests_debug_fd}>&2
    fi

    _tests_prepare_eval_namespace eval

    printf 0 > $_tests_run_clean

    {
        exec {stdin_debug}>&1

        if _tests_eval_and_capture_output "${@}"; then
            echo 0 > $_tests_run_exitcode
        else
            echo $? > $_tests_run_exitcode
        fi < <(tee >(cat >&${stdin_debug}) < $input) 1>&${stdout} 2>&${stderr}

    } | _tests_pipe _tests_indent 'stdin' \
        | _tests_unbuffer tail -n+2 >&${_tests_debug_fd}

    if [ $_tests_verbose -gt 1 ]; then
        tests:debug "evaluation stdout: $_tests_run_stdout"
        _tests_pipe _tests_indent 'stdout' < $_tests_run_stdout \
            | _tests_check_empty
    fi

    if [ $_tests_verbose -gt 1 ]; then
        tests:debug "evaluation stderr:"
        _tests_pipe _tests_indent 'stderr' < $_tests_run_stderr \
            | _tests_check_empty
    fi
}

_tests_eval_and_capture_output() {
    (
        set +euo pipefail

        case $_tests_verbose in
            0|1)
                _tests_raw_eval "${@}" \
                    > $_tests_run_stdout \
                    2> $_tests_run_stderr
                ;;
            2)
                # Process substitution will not work there, because
                # it will be executed asyncronously.
                #
                # Consider: true > >(sleep 1; echo hello)
                #
                # `true` will exit no matter running sleep, and hello will
                # be shown only after 1 second pass.
                { _tests_raw_eval "${@}" \
                    | tee $_tests_run_stdout 1>&3; exit ${PIPESTATUS[0]}; } \
                    2> $_tests_run_stderr 3>&1
                ;;
            *)
                # We need to return exitcode of _tests_raw_eval, not tee, so
                # we need to use PIPESTATUS[0] which will be equal to exitcode
                # of _tests_raw_eval.
                #
                # It's required, because -o pipefail is not set here.
                { { _tests_raw_eval "${@}" \
                    | tee $_tests_run_stdout 1>&3; exit ${PIPESTATUS[0]}; } 2>&1 \
                    | tee $_tests_run_stderr 1>&2; exit ${PIPESTATUS[0]}; } 3>&1
                ;;
        esac
    )
}

_tests_print_docs() {
    parser='# start of awk code {{{

    BEGIN {
        if (! style) {
            style = "github"
        }

        styles["github", "h1", "from"] = ".*"
        styles["github", "h1", "to"] = "## &"

        styles["github", "h2", "from"] = ".*"
        styles["github", "h2", "to"] = "### &"

        styles["github", "h3", "from"] = ".*"
        styles["github", "h3", "to"] = "#### &"

        styles["github", "code", "from"] = ".*"
        styles["github", "code", "to"] = "```&"

        styles["github", "/code", "to"] = "```"

        styles["github", "argN", "from"] = "^(\\$[0-9]) (\\S+)"
        styles["github", "argN", "to"] = "**\\1** (\\2):"

        styles["github", "arg@", "from"] = "^\\$@ (\\S+)"
        styles["github", "arg@", "to"] = "**...** (\\1):"

        styles["github", "li", "from"] = ".*"
        styles["github", "li", "to"] = "* &"

        styles["github", "i", "from"] = ".*"
        styles["github", "i", "to"] = "_&_"

        styles["github", "anchor", "from"] = ".*"
        styles["github", "anchor", "to"] = "[&](#&)"

        styles["github", "exitcode", "from"] = "([0-9]) (.*)"
        styles["github", "exitcode", "to"] = "**\\1**: \\2"
    }

    function render(type, text) {
        return gensub( \
            styles[style, type, "from"],
            styles[style, type, "to"],
            "g",
            text \
        )
    }

    /^# @description/ {
        in_description = 1
        in_example = 0

        has_example = 0
        has_args = 0
        has_exitcode = 0
        has_stdout = 0

        docblock = ""
    }

    in_description {
        if (/^[^#]|^# @[^d]/) {
            in_description = 0
        } else {
            sub(/^# @description /, "")
            sub(/^# /, "")
            sub(/^#$/, "")

            if ($0) {
                $0 = $0 "\n"
            }

            docblock = docblock $0
        }
    }

    in_example {
        if (! /^#[ ]{3}/) {
            in_example = 0

            docblock = docblock "\n" render("/code") "\n"
        } else {
            sub(/^#[ ]{3}/, "")

            docblock = docblock "\n" $0
        }
    }

    /^# @example/ {
        in_example = 1

        docblock = docblock "\n" render("h3", "Example")
        docblock = docblock "\n\n" render("code", "bash")
    }

    /^# @arg/ {
        if (!has_args) {
            has_args = 1

            docblock = docblock "\n" render("h2", "Arguments") "\n\n"
        }

        sub(/^# @arg /, "")

        $0 = render("argN", $0)
        $0 = render("arg@", $0)

        docblock = docblock render("li", $0) "\n"
    }

    /^# @noargs/ {
        docblock = docblock "\n" render("i", "Function has no arguments.") "\n"
    }

    /^# @exitcode/ {
        if (!has_exitcode) {
            has_exitcode = 1

            docblock = docblock "\n" render("h2", "Exit codes") "\n\n"
        }

        sub(/^# @exitcode /, "")

        $0 = render("exitcode", $0)

        docblock = docblock render("li", $0) "\n"
    }

    /^# @see/ {
        sub(/# @see /, "")

        $0 = render("anchor", $0)
        $0 = render("li", $0)

        docblock = docblock "\n" render("h3", "See also") "\n\n" $0 "\n"
    }

    /^# @stdout/ {
        has_stdout = 1

        sub(/^# @stdout /, "")

        docblock = docblock "\n" render("h2", "Output on stdout")
        docblock = docblock "\n\n" render("li", $0) "\n"
    }

    /^tests:[a-zA-Z0-9_-]+\(\)/ && docblock != "" {
        print render("h1", $1) "\n\n" docblock

        docblock = ""
    }

    # }}} end of awk code'

    awk "$parser" "$(basename $0)"
}


_tests_show_usage() {
    cat <<EOF
tests.sh --- simple test library for testing commands.

tests.sh expected to find files named *.test.sh in current directory, and
they are treated as testcases.

Usage:
    tests.sh -h
    tests.sh [-v] [-d <dir>] [-s <path>] -A [-a]
    tests.sh [-v] [-d <dir>] [-s <path>] -O [<name>]
    tests.sh -i

Options:
    -h | --help  Show this help.
    -A           Run all testcases in current directory.
    -a           Run all testcases in subdirectories of current directory.
    -O <name>    Run specified testcase only. If no testcase specified, last
                 failed testcase will be ran.
    -s <path>    Run specified setup file before running every testcase.
    -d <dir>     Change directory to specified before running testcases.
                 [default: current working directory].
    -v           Verbosity. Flag can be specified several times.
                  -v     Simple debug:
                          - only evaluated commands via tests:eval or
                            tests:pipe will be printed
                  -vv    Output debug:
                          - stdout and stderr of evaluated commands will be
                            printed.
                          - also, sourced files will be printed.
                  -vvv   Extended debug:
                          - notes about namespace and sourced files will be
                            expanded.
                          - file contents put via tests:put will be printed.
                  -vvvv  Extreme debug:
                          - evaluated commands will be printed in form they
                            will be evaluated.
                          - stdin input for tests:eval and tests:put will be
                            printed.
                          - output of background tasks will be printed in
                            realtime.
                          - default debug level for \`-O\` mode.
    -i           Pretty-prints documentation for public API in markdown format.
EOF
}


__main__() {
    _tests_base_dir=$(pwd)

    local testcases_dir="."
    local testcases_setup=""
    local see_subdirs=false

    while getopts ":his:d:va" arg "${@}"; do
        case $arg in
            d)
                testcases_dir="$OPTARG"
                ;;
            v)
                _tests_verbose=$(($_tests_verbose+1))
                ;;
            i)
                _tests_print_docs
                exit $?
                ;;
            h)
                _tests_show_usage
                exit 1
                ;;
            a)
                see_subdirs=true
                ;;
            s)
                testcases_setup="$OPTARG"
                ;;
            ?)
                args+=("$OPTARG")
        esac
    done

    local OPTIND

    while getopts ":his:d:vaAO" arg "${@}"; do
        case $arg in
            A)
                _tests_run_all \
                    "$testcases_dir" "$testcases_setup" $see_subdirs

                exit $?
                ;;
            O)
                if [ $_tests_verbose -eq 0 ]; then
                    tests:set-verbose 4
                fi

                local filemask=${@:$OPTIND:1}
                if [ -z "$filemask" ]; then
                    local files=$(_tests_get_last)
                else
                    local files=(
                        $(eval echo \$testcases_dir/\*$filemask\*.test.sh)
                    )
                fi

                for name in "${files[@]}"; do
                    if ! _tests_run_one "$name" "$testcases_setup"; then
                        exit 1
                    fi
                done

                exit $?
                ;;
            h)
                _tests_show_usage
                exit 1
                ;;
        esac
    done

    _tests_show_usage
    exit 1
}


if [ "$(basename $0)" == "tests.sh" ]; then
    __main__ "${@}"
fi
