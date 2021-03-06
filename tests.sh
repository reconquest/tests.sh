#!/bin/bash

_base_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source $_base_dir/vendor/github.com/reconquest/coproc.bash/coproc.bash 2>/dev/null \
    || import:use "github.com/reconquest/coproc.bash"

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
# @stdout Path to temp dir, e.g., /tmp/tests.XXXX
tests:get-tmp-dir() {
    if [ -z "$_tests_dir" ]; then
        tests:debug "test session not initialized"
        _tests_interrupt
    fi

    echo "$_tests_dir/root"
}

# @description Suspends testcase execution until file contents matches
# pattern or timeout is reached.
#
# Can be used to check if background-executed command output do not contains
# any error messages.
#
# @example
#   stderr=$(tests:get-background-stderr $command_id)
#   tests:wait-file-not-matches "$stderr" "ERROR" 1 2
#
# @arg $1 string Path to file.
# @arg $2 regexp Regexp, same as in `grep -E`.
# @arg $3 int Interval of time to check changes after.
# @arg $4 int Timeout in seconds.
tests:wait-file-matches() {
    local file="$1"
    local pattern="$2"
    local sleep_interval="$3"
    local sleep_max="$4"

    shift 4

    if [ ! "$_tests_run_exitcode" ]; then
        _tests_prepare_eval_namespace wait-for-matches
    fi

    local sleep_iter=0
    local sleep_iter_max=$(bc <<< "$sleep_max/$sleep_interval")

    tests:debug "! waiting file matches pattern after command:" \
        "pattern '$pattern', file '$file' (${sleep_max}sec max)"

    while true; do
        sleep_iter=$(($sleep_iter+1))

        if grep -qE "$pattern" $file 2>/dev/null; then
            tests:debug "! matches found for pattern '$(\
                echo $pattern)' in file '$file' (after $(\
                bc <<< "$sleep_iter * $sleep_interval" )sec)"

            echo 0 > $_tests_run_exitcode
            break
        fi

        if [[ $sleep_iter -le $sleep_iter_max ]]; then
            sleep $sleep_interval
            continue
        fi

        tests:debug "! no matches found for pattern '$(\
            echo $pattern)' in file '$file' (after $(\
            bc <<< "$sleep_iter * $sleep_interval" )sec)"

        echo 1 > $_tests_run_exitcode
        break
    done
}

tests:wait-file-not-matches() {
    tests:wait-file-matches "${@}"

    if [ $(cat $_tests_run_exitcode) -eq 0 ]; then
        echo 1 > $_tests_run_exitcode
    else
        echo 0 > $_tests_run_exitcode
    fi
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
        "<<< $actual$\n"

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

    if [ ! "$_tests_run_exitcode" ]; then
        _tests_prepare_eval_namespace match
    fi

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

    if [ ! -f "$_tests_run_exitcode" ]; then
        tests:debug "(assert-re) BUG: _tests_run_exitcode is empty"
        _tests_interrupt
    fi

    local result=$(cat $_tests_run_exitcode)

    _tests_make_assertion $result 0 \
        "regexp matches" \
        ">>> ${regexp:-<empty regexp>}" \
        "<<< contents of ${target}:\n\
            $(_tests_pipe _tests_indent "$target" "<empty>" < $file)\n"

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
    local options=(-u $@)

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
    if diff=$(diff ${options[@]} \
            <(echo -e "$expected_content") \
            <(echo -e "$actual_content")); then
        result=0
    else
        result=$?
    fi

    _tests_make_assertion $result 0 \
        "no diff" \
        "\n$(_tests_pipe _tests_indent 'diff' <<< "$diff")\n"

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

# @description Returns contents of the stdout of last command.
#
# @example
#   tests:eval echo 123
#   tests:get-stdout # will echo 123
#
# @stdout Stdout for last command.
tests:get-stdout() {
    cat "$(tests:get-stdout-file)"
}

# @description Returns contents of the stderr of last command.
#
# @example
#   tests:eval echo 123 '>&2'
#   tests:get-stderr # will echo 123
#
# @stdout Stderr for last command.
tests:get-stderr() {
    cat "$(tests:get-stderr-file)"
}

# @description Returns file containing exitcode of last command.
#
# @example
#   tests:eval exit 220
#   cat $(tests:get-exitcode-file) # will echo 220
#
# @stdout Filename containing exitcode.
tests:get-exitcode-file() {
    echo $_tests_run_exitcode
}

# @description Returns exitcode of last command.
#
# @example
#   tests:eval exit 220
#   tests:get-exitcode # will echo 220
#
# @stdout Filename containing exitcode.
tests:get-exitcode() {
    cat $_tests_run_exitcode
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
    tests:assert-no-diff "$@" "-B"
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
    local file="$_tests_dir_root/$1"

    local stderr
    if ! stderr=$(cat 2>&1 > $file); then
        tests:debug "error writing file:"
        _tests_indent 'error' <<< "$stderr"
        _tests_interrupt
    fi

    if [ $_tests_verbose -gt 2 ]; then
        tests:debug "wrote the file $file with content:"
        tests:colorize fg 208 _tests_indent 'file' < $file
    fi

}

# @description Asserts that stdout is empty.
#
# @example
#   tests:eval echo ""
#
#   tests:assert-stdout-empty
#
# @noargs
tests:assert-stdout-empty() {
    tests:assert-empty stdout
}

# @description Asserts that stderr is empty.
#
# @example
#   tests:eval echo "" '1>&2'
#
#   tests:assert-stderr-empty
#
# @noargs
tests:assert-stderr-empty() {
    tests:assert-empty stderr
}

# @description Asserts that target is empty.
#
# @example
#   tests:eval echo ""
#
#   tests:assert-empty stdout
#
# @noargs
tests:assert-empty() {
    tests:assert-re "$1" ""
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
    if [ ! -f "$_tests_run_exitcode" ]; then
        tests:debug "(assert-exitcode) BUG: _tests_run_exitcode is empty"
        _tests_interrupt
    fi

    local actual=$(cat $_tests_run_exitcode)
    local expected=$1
    shift

    _tests_make_assertion "$expected" "$actual" \
        "command exited with code" \
        "actual exit code = $actual" \
        "expected exit code $_tests_last_assert_operation $expected\n"

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
# @arg $@ any Command to evaluate.
tests:not() {
    _tests_assert_operation="!="
    _tests_last_assert_operation="!="

    "${@}"

    _tests_assert_operation="="
}

# @description Prevets eval command to print stdout/stderr.
#
# @example
#   tests:silence tests:eval rm -r blah
#
# @arg $@ any Command to evaluate.
tests:silence() {
    _tests_eval_silence="1"

    "${@}"

    _tests_eval_silence=""
}

# @description Output message and fail current testcase immideately.
#
# @arg $@ any String to output.
tests:fail() {
    tests:describe "$@"
    _tests_interrupt
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

    local prefix=$_tests_debug_prefix
    if [ $_tests_verbose -ge 6 ]; then
        prefix="<$BASHPID> $prefix"
    fi

    if [ "$_tests_dir" ]; then
        echo -e "${prefix}# $@"
    else
        echo -e "### $@"
    fi >&${output}
}

# @description Changes working directory to specified directory.
#
# @arg $1 directory Directory to change to.
tests:cd() {
    local dir=${1:-$(tests:get-tmp-dir)}
    tests:debug "\$ cd $dir"
    if [[ ! -d "$dir" ]]; then
        tests:debug "error changing working directory to $dir:"
        _tests_indent 'error' <<< "$(readlink -fm $dir) not found"
        _tests_interrupt
    else
        builtin cd $dir
    fi
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
    local output

    _tests_prepare_eval_namespace eval

    exec {output}>$_tests_run_output

    _tests_eval_and_output_to_fd ${output} ${output} "${@}"

    exec {output}<&-
}

# @description Same, as `tests:pipe`, but produce unbuffered result.
#
# @example
#   tests:runtime 'echo 1; sleep 10; echo 2'  # see 1 immediately
#
# @arg $@ string String to evaluate.
# @see tests:eval
tests:runtime() {
    local stdout
    local stderr

    _tests_prepare_eval_namespace eval

    exec {stdout}>$_tests_run_output
    exec {stderr}>$_tests_run_output

    # because of pipe, environment variables will not bubble out of
    # _tests_eval_and_output_to_fd call
    _tests_prepare_eval_namespace eval

    { { _tests_eval_and_output_to_fd ${stdout} ${stderr} "${@}" \
        {stdout}>&1 | _tests_indent 'runtime stdout' ; } \
        {stderr}>&1 | _tests_indent 'runtime stderr' ; }

    exec {stdout}<&-
    exec {stderr}<&-
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
    local stdout
    local stderr

    _tests_prepare_eval_namespace eval

    exec {stdout}>&1
    exec {stderr}>&2

    _tests_eval_and_output_to_fd ${stdout} ${stderr} "${@}"

    exec {stdout}<&-
    exec {stderr}<&-
}

# @description Same, as `tests:eval`, but writes stdout into given variable and
# return stderr as expected.
#
# @example
#   _x() {
#       echo "y [$@]"
#   }
#   tests:value response _x a b c
#   tests:assert-equals "$response" "y [a b c]"
#
# @arg $1 string Variable name.
# @arg $@ string String to evaluate.
# @see tests:eval
tests:value() {
    local __variable__="$1"
    local __value__=""
    shift

    tests:ensure "${@}"

    __value__="$(cat "$(tests:get-stdout-file)")"
    eval $__variable__=\"\${__value__}\"

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
        tests:debug "making directories in $_tests_dir_root: mkdir ${@}"
    fi

    local stderr
    if ! stderr=$(
        command mkdir -p \
            $(sed -re "s#(^|\\s)([^-])#\\1$_tests_dir_root/\\2#g" <<< "${@}")); then
        tests:debug "error making directories ${@}:"
        _tests_indent 'error' <<< "$stderr"
        _tests_interrupt
    fi
}

# @description Changes working directory to the specified temporary directory,
# previously created by 'tests:make-tmp-dir'.
#
# @arg $1 string Directory name.
tests:cd-tmp-dir() {
    tests:cd $_tests_dir_root/$1
}

# @description Runs any command in background, this is very useful if you test
# some running service.
#
# Processes which are ran by 'tests:background' will be killed on cleanup
# state, and if test failed, stderr and stdout of all background processes will
# be printed.
#
# @arg $1 variable Name of variable to store BG process ID.
# @arg $@ string Command to start.
tests:run-background() {
    local _run_id_var="$1"
    shift

    local _run_debug_old_prefix=$_tests_debug_prefix
    _tests_debug_prefix="[BG] <$BASHPID>  "

    local _run_coproc=""
    local _run_pid=""

    coproc:run-immediately _run_coproc "${@}"

    _tests_debug_prefix=$_run_debug_old_prefix

    coproc:get-pid "$_run_coproc" _run_pid
    command mkdir $_tests_dir/.bg/$_run_pid
    ln -s "$_run_coproc" $_tests_dir/.bg/$_run_pid/coproc

    builtin eval $_run_id_var=\$_tests_dir/.bg/\$_run_pid

    tests:debug "! running coprocess with pid <$_run_pid>:"
    _tests_indent "coproc" <<< "${@}"

    local _run_stdout=""
    local _run_stderr=""

    coproc:get-stdout-fd "$_run_coproc" _run_stdout
    coproc:get-stderr-fd "$_run_coproc" _run_stderr

    _tests_run_bg_reader \
        $_run_stdout $_tests_dir/.bg/$_run_pid/stdout "<$_run_pid> stdout"
    _tests_run_bg_reader \
        $_run_stderr $_tests_dir/.bg/$_run_pid/stderr "<$_run_pid> stderr"
}

_tests_run_bg_reader() {
    local input_fd=$1
    local output=$2
    local prefix=$3

    ( cat <&$input_fd | tee $output | _tests_indent "$prefix" ) &
}

# @description Returns pid of specified background process.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
#
# @stdout Pid of background process.
tests:get-background-pid() {
    local _pid=""
    coproc:get-pid "$(readlink -f "$1/coproc")" _pid
    echo $_pid
}

# @description Returns stdout of specified background process.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
#
# @stdout Stdout from background process.
tests:get-background-stdout() {
    echo "$1/stdout"
}

# @description Returns stderr of specified background process.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
#
# @stdout Stderr from background process.
tests:get-background-stderr() {
    echo "$1/stderr"
}

# @description Stops background process with 'kill -TERM'.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
tests:stop-background() {
    local bg_proc="$1"

    tests:debug "! terminating coprocess <${bg_proc##*/}>"
    coproc:stop $(readlink -f "$bg_proc/coproc")
    tests:debug "! coprocess <${bg_proc##*/}> has been terminated"
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

    local stat_initial=$(stat $file)
    local sleep_iter=0
    local sleep_iter_max=$(bc <<< "$sleep_max/$sleep_interval")

    tests:debug "! waiting file changes after command:" \
        "file '$file' (${sleep_max}sec max)"


    if [ $# -gt 0 ]; then
        if [ $_tests_verbose -gt 3 ]; then
            _tests_escape_cmd "$@" \
                | _tests_pipe tests:colorize fg 5 _tests_indent 'eval' \
                >&$_tests_debug_fd
        fi

        _tests_pipe "$@"
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

# @description Gets current verbosity level.
#
# @noargs
# @stdout Current verbosity.
tests:get-verbose() {
    printf "%s" $_tests_verbose
}

# @description Copy specified file or directory from the testcases
# dir to the temporary test directory.
#
# @arg $@ any Same args, as for cp commmand.
tests:clone() {
    local args=()
    local last_arg=""

    while [ $# -gt 0 ]; do
        if [ "$last_arg" ]; then
            args+=($_tests_base_dir/$last_arg)
        fi

        last_arg=""

        if grep -q '^-' <<< "$1"; then
            args+=($1)
        else
            last_arg=$1
        fi

        shift
    done

    local dest="$_tests_dir_root/$last_arg"

    if [ $_tests_verbose -gt 2 ]; then
        tests:debug "\$ cp -r ${args[@]} $dest"
    fi

    local stderr
    if ! stderr=$(command cp -r "${args[@]}" "$dest" 2>&1); then
        tests:debug "error copying: cp -r ${args[@]} $dest:"
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

    if ! builtin source "$file"; then
        return 1
    fi

    trap - EXIT

    if [ $_tests_verbose -gt 1 ]; then
        tests:debug "{END} source $file"
    fi
}


tests:colorize() {
    local type=$1  # unused right now
    local color=$2

    shift 2

    local output=$(_tests_get_debug_fd)

    local esc=$(echo -en '\e')

    _tests_pipe "${@}" \
        | sed -u -r -e "s/^/$esc[38;5;"${color}'m/' -e "s/$/$esc[0m/" >&$output
}

tests:remove-colors() {
    local esc=$(echo -en '\e')

    sed -ure "s/$esc\[[^m]+m//g"
}

tests:init() {
    _tests_dir="$(mktemp -t -d tests.XXXX)"

    _tests_dir_root=$_tests_dir/root

    command mkdir -p $_tests_dir_root
    command mkdir -p $_tests_dir_root/bin
    command mkdir -p $_tests_dir/.bg

    tests:debug "{BEGIN} TEST SESSION AT $_tests_dir"
}

tests:progress() {
    cat >/dev/null
}

# }}}

# Internal Code {{{


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

                [[:digit:]]'>&'[[:digit:]]) cmd+=($i) ;;
                [[:digit:]]'<&'[[:digit:]]) cmd+=($i) ;;

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

    builtin eval "$(_tests_escape_cmd "${@}")"
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

    local empty="${2:-}"

    _tests_unbuffer awk \
        -v "prefix=$_tests_debug_prefix    ${prefix:+($prefix) }" \
        -v "empty=$empty" '
        BEGIN {
            if (empty) {
                empty = "    " empty
            }
        }

        {
            if (NR == 1) {
                print ""
            }

            print prefix $0
            empty = ""
        }

        END {
            if (NR == 0 && empty) {
                print "\n" empty "\n"
            }

            if (NR > 0) {
                print ""
            }
        }' >&${output}
}

_tests_quote_re() {
    sed -r 's/[.*+[()?$^]|]/\\\0/g'
}

_tests_quote_cmd() {
    sed -r -e "s/[\`\"]|\\$\{?[0-9#\!?@_\[\]]*\}?/\\\&/g" -e '1s/^/"/' -e '$s/$/"/'
}

_tests_get_testcases() {
    local directory="$1"
    local recursive="$2"

    (
        shopt -s globstar

        builtin cd $directory

        if $recursive; then
            ls -t -- **/*.test.sh
        else
            ls -t -- *.test.sh
        fi
    )
}

# FIXME refactor that shit!
_tests_run_all() {
    local testcases_dir="$1"
    local setup="$2"
    local teardown="$3"
    local recursive="$4"

    local testcases=($(
        _tests_get_testcases "$testcases_dir" "$recursive"
    ))
    if [ "${#testcases[@]}" -eq 0 ]; then
        echo no testcases found.

        exit 1
        return 1
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
            local stdout=$_tests_one_stdout
            local stderr=$_tests_one_stderr
            local pwd="$(pwd)"

            trap "_tests_show_test_output $stdout $stderr $file" EXIT

            _tests_asserts=0

            local result
            if { _tests_run_one "$testcases_dir/$file" "$setup" "$teardown" \
                    > >(tee $stdout >&3) 2> >(tee $stderr >&3); } \
                    3> >(tests:progress)
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
                return $result
            fi
        else
            local result
            if _tests_run_one "$testcases_dir/$file" "$setup" "$teardown"; then
                result=0
            else
                result=$?
            fi
            if [ $result -ne 0 ]; then
                exit $result
                return $result
            fi

            success=$((success+1))
        fi

        assertions_count=$(($assertions_count+$_tests_asserts))
    done

    tests:progress "stop" < /dev/null

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
    local setup="$2"
    local teardown="$3"

    local testcase_file="$_tests_base_dir/$testcase"

    if ! test -e $testcase; then
        echo "testcase '$testcase' not found"
        return 1
    fi

    tests:debug "TESTCASE $testcase"

    tests:init

    tests:print-current-testcase() {
        printf "%s" "$testcase"
    }

    if [ ! -s $_tests_dir/.asserts ]; then
        echo 0 > $_tests_dir/.asserts
    fi

    local result
    if _tests_run_raw "$testcase_file" "$setup" "$teardown"; then
        result=0
    else
        result=$?
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
    local setup="$2"
    local teardown="$3"

    (
        PATH="$_tests_dir_root/bin:$PATH"

        builtin cd $_tests_dir_root

        if [ -n "$setup" ]; then
            if [ $_tests_verbose -gt 2 ]; then
                tests:debug "{BEGIN} SETUP"
            fi

            if ! tests:involve "$setup"; then
                exit 1
                return 1
            fi

            if [ $_tests_verbose -gt 2 ]; then
                tests:debug "{END} SETUP"
            fi
        fi

        local exit_code
        (
            builtin source "$testcase_file"
        )
        exit_code=$?

        _tests_wait_bg_tasks

        builtin cd $_tests_dir_root

        if [ -n "$teardown" ]; then
            if [ $_tests_verbose -gt 2 ]; then
                tests:debug "{BEGIN} TEARDOWN"
            fi

            if ! tests:involve "$teardown"; then
                exit 1
                return 1
            fi

            if [ $_tests_verbose -gt 2 ]; then
                tests:debug "{END} TEARDOWN"
            fi
        fi

        exit $exit_code
    ) 2>&1 | _tests_indent
}

_tests_run_bg_task() {
    local identifier=$1
    local cmd_var=$2

    shift 2

    local to_evaluate=()

    builtin eval to_evaluate=\"\${$cmd_var[@]}\"

    exec {_tests_debug_fd}>$_tests_bg_channels/debug

    tests:debug "{START} [BG] #$identifier: started pid:<$BASHPID>"

    tests:pipe "${cmd[@]}" \
        1>$_tests_bg_channels/stdout \
        2>$_tests_bg_channels/stderr

    touch $_tests_run_donefile
}

_tests_new_id() {
    date +'%s.%N' | md5sum | head -c 6
}

_tests_prepare_eval_namespace() {
    local namespace="$1"

    if [ -e "$_tests_run_clean" ]; then
        if [ "$(cat $_tests_run_clean 2>/dev/null)" = "1" ]; then
            return
        fi
    fi

    local identifier=$(_tests_new_id)
    local dir=$_tests_dir/.ns/$namespace/$identifier

    mkdir -p $dir

    _tests_run_stdout=$dir/stdout
    _tests_run_stderr=$dir/stderr
    _tests_run_exitcode=$dir/exitcode
    _tests_run_pidfile=$dir/pid
    _tests_run_donefile=$dir/done
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

_tests_cleanup() {
    rm -rf "$_tests_dir"

    _tests_dir=""

    tests:debug "{END} TEST SESSION"
}

_tests_wait_bg_tasks() {
    for bg_proc in $_tests_dir/.bg/*; do
        if [ ! -d $bg_proc ]; then
            continue
        fi

        tests:stop-background "$bg_proc"
    done
}

_tests_interrupt() {
    _tests_wait_bg_tasks
    exit 88
}

_tests_make_assertion() {
    local assertion_name=$3

    local assertion_type="$_tests_assert_operation"

    case "$_tests_assert_operation" in
        =)
            assertion_type="positive"
            ;;
        !=)
            assertion_type="negative"
            ;;
    esac

    tests:debug "assertion ($assertion_name): $assertion_type expectation"

    local result
    if test "$1" $_tests_assert_operation "$2"; then
        result=0
    else
        result=$?
    fi

    shift 3

    if [ $result -gt 0 ]; then
        touch "$_tests_dir/.failed"
        tests:colorize fg 1 tests:debug "assertion ($assertion_name): failed"
    fi

    if [ $_tests_verbose -gt 3 -o $result -gt 0 ]; then
        if [ $result -eq 0 ]; then
            tests:colorize fg 2 tests:debug "assertion ($assertion_name): success"
        fi

        while [ $# -gt 0 ]; do
            tests:colorize fg 24 tests:debug "assertion ($assertion_name): $1"

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

_tests_set_options() {
    set -euo pipefail
}

_tests_eval_and_output_to_fd() {
    local stdout=$1
    local stderr=$2

    shift 2

    _tests_prepare_eval_namespace eval

    if [ $_tests_verbose -gt 4 ]; then
        tests:debug "{DEBUG} namespace ID: $_tests_run_id"
    fi

    printf 0 > $_tests_run_clean

    local input=/dev/stdin

    if [ -s "$input" ]; then
        tests:debug "(stdin) evaluating command:"
    else
        input=/dev/null

        tests:debug "evaluating command:"
    fi

    if [ $(_tests_get_debug_fd) -eq 2 ]; then
        exec {_tests_debug_fd}>&2
    fi

    _tests_pipe tests:colorize fg 5 _tests_indent '$' <<< "${@}" \
        | head -n-1 >&$_tests_debug_fd

    if [ $_tests_verbose -gt 3 ]; then
        _tests_escape_cmd "${@}" \
            | _tests_pipe tests:colorize fg 5 _tests_indent 'eval' \
            >&$_tests_debug_fd
    fi

    {
        exec {stdin_debug}>&1

        if _tests_eval_and_capture_output "${@}"; then
            echo 0 > $_tests_run_exitcode
        else
            echo $? > $_tests_run_exitcode
        fi < <(tee >(cat >&${stdin_debug}) < $input) 1>&${stdout} 2>&${stderr}
    } | _tests_pipe _tests_indent 'stdin' \
        | _tests_unbuffer tail -n+2 \
        | _tests_unbuffer head -n-1 \
        >&${_tests_debug_fd}

    printf "\n" >&$_tests_debug_fd

    if [ -z $_tests_eval_silence ]; then
        if [ $_tests_verbose -gt 1 ]; then
            tests:debug "evaluation stdout:"
            tests:colorize fg 107 _tests_indent 'stdout' '<empty>' \
                < $_tests_run_stdout
        fi

        if [ $_tests_verbose -gt 1 ]; then
            tests:debug "evaluation stderr:"
            tests:colorize fg 61 _tests_indent 'stderr' '<empty>'\
                < $_tests_run_stderr
        fi
    fi
}

_tests_eval_and_capture_output() {
    (
        case $_tests_verbose in
            0|1)
                (_tests_set_options; _tests_raw_eval "${@}") \
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
                { (_tests_set_options; _tests_raw_eval "${@}") \
                    | tee $_tests_run_stdout 1>&3; exit ${PIPESTATUS[0]}; } \
                    2> $_tests_run_stderr 3>&1
                ;;
            *)
                # We need to return exitcode of _tests_raw_eval, not tee, so
                # we need to use PIPESTATUS[0] which will be equal to exitcode
                # of _tests_raw_eval.
                #
                # It's required, because -o pipefail is not set here.
                { { (_tests_set_options; _tests_raw_eval "${@}") \
                    | tee $_tests_run_stdout 1>&3; exit ${PIPESTATUS[0]}; } 2>&1 \
                    | tee $_tests_run_stderr 1>&2; exit ${PIPESTATUS[0]}; } 3>&1
                ;;
        esac
    )
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
    -t <path>    Run specified teardown file after running every testcase.
    -d <dir>     Change directory to specified before running testcases.
                 [default: current working directory].
    -v           Verbosity. Flag can be specified several times.
                  -v      Simple debug:
                           - only evaluated commands via tests:eval or
                             tests:pipe will be printed
                  -vv     Output debug:
                           - stdout and stderr of evaluated commands will be
                             printed.
                           - also, sourced files will be printed.
                  -vvv    Extended debug:
                           - notes about namespace and sourced files will be
                             expanded.
                           - file contents put via tests:put will be printed.
                  -vvvv   Extreme debug:
                           - evaluated commands will be printed in form they
                             will be evaluated.
                           - stdin input for tests:eval and tests:put will be
                             printed.
                           - default debug level for \`-O\` mode.
                  -vvvvv  Insane debug:
                           - output of background tasks will be printed in
                             realtime (no proper use without highlighting).
                  -vvvvvv Debug debug (oh, well).
                           - produce messages for debuggin library for itself.
EOF
}


{
    # Internal global state {{{
    _tests_one_stdout=$(mktemp -t stdout.XXXX)

    _tests_one_stderr=$(mktemp -t stderr.XXXX)

    # Current test session.
    _tests_dir=""

    _tests_dir_root=""

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

    # Prevents eval commands to print stdout/stderr.
    _tests_eval_silence=""

    # Last used assert operation.
    _tests_last_assert_operation="="

    _tests_debug_fd="304"

    _tests_bg_channels=""

    _tests_debug_prefix=""

    _tests_base_dir=$(pwd)

    # }}}
}


tests:main() {
    _tests_set_options

    local testcases_dir="."
    local setup=""
    local teardown=""
    local recursive=false

    OPTIND=

    while getopts ":hs:t:d:va" arg "${@}"; do
        case $arg in
            d)
                testcases_dir="$OPTARG"
                ;;
            v)
                _tests_verbose=$(($_tests_verbose+1))
                ;;
            h)
                _tests_show_usage
                exit 1
                return 1
                ;;
            a)
                recursive=true
                ;;
            s)
                setup="$OPTARG"
                ;;
            t)
                teardown="$OPTARG"
                ;;
            ?)
                args+=("$OPTARG")
        esac
    done

    OPTIND=

    while getopts ":hs:t:d:vaAO" arg "${@}"; do
        case $arg in
            A)
                _tests_run_all \
                    "$testcases_dir" "$setup" "$teardown" "$recursive"

                exit $?
                return $?
                ;;
            O)
                if [ $_tests_verbose -eq 0 ]; then
                    tests:set-verbose 4
                fi

                local filemask=${@:$OPTIND:1}
                local files=""
                if [ -z "$filemask" ]; then
                    files=$(_tests_get_last)
                elif files=$(
                    _tests_get_testcases "$testcases_dir" true \
                        | grep -P "$filemask"
                ); then
                    files=($files)
                else
                    echo no testcases found.
                    exit 1
                    return 1
                fi

                for name in "${files[@]}"; do
                    local testcase="$testcases_dir/$name"
                    if ! _tests_run_one "$testcase" "$setup" "$teardown"; then
                        exit 1
                        return 1
                    fi
                done

                exit $?
                return $?
                ;;
            h)
                _tests_show_usage
                exit 1
                return 1
                ;;
        esac
    done

    _tests_show_usage
    exit 1
}


if [ "$(basename $0)" == "tests.sh" ]; then
    tests:main "${@}"
fi
