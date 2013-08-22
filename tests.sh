#!/bin/bash

# Public API Functions {{{

# Function tests_tmpdir returns temporary directory for current test session.
# Echo:
#   Path to temp dir, e.g, /tmp/tests.XXXX
tests_tmpdir() {
    echo "$TEST_ID"
}

# Function tests_assert_equals checks, that first string arg is equals
# to second.
# Args:
#   $1: expected string
#   $2: actual value
# Return:
#   1: if strings is not equals
#   0: otherwise
tests_assert_equals() {
    local expected="$1"
    local actual="$2"

    if [ "$expected" != "$actual" ]; then
        touch "$TEST_ID/_failed"
        tests_debug "expectation failed: two strings not equals"
        tests_debug ">>> $expected$"
        tests_debug "<<< $actual$"
        return 1
    fi

    TEST_ASSERTS=$(($TEST_ASSERTS+1))
}

# Function tests_assert_stdout evaluates given command and compare it's stdout
# to given string.
# Args:
#   $1: expected stdout
#   ${@}: command to evaluate
tests_assert_stdout() {
    local expected="$1"
    shift

    tests_assert_stdout_re "$(tests_quote_re "$expected")" "${@}"
}

# Function tests_assert_re evaluates command and checks that it's output
# (stdout or stderr) matches regexp.
# Args:
#   $1: stdout|stderr
#   $2: regexp
#   ${@}: command to evaluate
tests_assert_re() {
    local target="$1"
    local regexp="$2"
    shift 2

    local stdout=`mktemp --tmpdir=$TEST_ID stdout.XXXX`
    local stderr=`mktemp --tmpdir=$TEST_ID stderr.XXXX`

    tests_debug "? ${@}"
    tests_eval "${@}" > $stdout 2> $stderr

    if [ "$target" = "stdout" ]; then
        target=$stdout
    else
        target=$stderr
    fi

    grep -qP "$regexp" $target
    local result=$?
    if [ $result -gt 0 ]; then
        touch "$TEST_ID/_failed"
        tests_debug "expectation failed: regexp does not match"
        tests_debug ">>> $regexp$"
        tests_debug "<<< $actual$"
    fi

    if [ $result -gt 0 -o $TEST_VERBOSE -ge 5 ]; then
        tests_debug "command stdout:"
        tests_indent < $stdout
        tests_debug "command stderr:"
        tests_indent < $stderr
    fi

    TEST_ASSERTS=$(($TEST_ASSERTS+1))
}

# Function tests_assert_stdout_re evaluates given command and checks, that
# it's stdout matches given regexp.
# Args:
#   $1: regexp
#   ${@}: command to evaluate
tests_assert_stdout_re() {
    tests_assert_re stdout "${@}"
}

# Function tests_assert_stderr_re do the same, as tests_assert_stdout_re, but
# stderr used instead of stdout.
# Args:
#   $1: regexp
#   ${@}: command to evaluate
tests_assert_stderr_re() {
    tests_assert_re stderr "${@}"
}

# Function tests_assert_success evaluates command and checks that it's exit
# code is zero.
# Args:
#   ${@}: command to evaluate
tests_assert_success() {
    tests_assert_exitcode 0 "${@}"
}

# Function tests_assert_exitcode evaluates command and chacks it's exit code to
# specified value.
# Args:
#   $1: expected exit code
#   ${@}: command to evaluate
tests_assert_exitcode() {
    local code=$1
    shift

    local stdout=`mktemp --tmpdir=$TEST_ID stdout.XXXX`
    local stderr=`mktemp --tmpdir=$TEST_ID stderr.XXXX`

    tests_debug "? $(tests_quote_cmd "${@}")"
    tests_eval "${@}" > $stdout 2> $stderr

    local result=$?
    if [ $result -ne $code ]; then
        touch "$TEST_ID/_failed"
        tests_debug "expectation failed: command <${@}> has exit status = $result"
        tests_debug "expected exit code is $code"
    fi

    if [ $result -ne $code -o $TEST_VERBOSE -ge 5 ]; then
        tests_debug "command stdout:"
        tests_indent < $stdout
        tests_debug "command stderr:"
        tests_indent < $stderr
    fi

    TEST_ASSERTS=$(($TEST_ASSERTS+1))
}

# Function tests_cd change current dir to specified and log this action.
# Args:
#   $1: directory to go to
tests_cd() {
    tests_debug "cd $1"
    cd $1
}

# Function tests_describe evaluates given command and show it's output,
# used for debug purposes.
# Args:
#   ${@}: command to evaluate
tests_describe() {
    tests_debug "this test decription:"

    tests_eval "${@}" | tests_indent
}

# Function tests_debug echoes specified string as debug info.
# Args:
#   ${@}: string to echo
tests_debug() {
    if [ $TEST_VERBOSE -lt 1 ]; then
        return
    fi

    if [ "$TEST_ID" ]; then
        echo "# $TEST_ID: ${@}"
    else
        echo "### ${@}"
    fi >&2
}
# }}}

# Internal Code {{{
tests_do() {
    tests_debug "$ ${@}"

    {
        if [ $TEST_VERBOSE -lt 2 ]; then
            tests_eval "${@}" > /dev/null 2>/dev/null
        fi

        if [ $TEST_VERBOSE -lt 3 ]; then
            tests_eval "${@}" > /dev/null
        fi

        if [ $TEST_VERBOSE -ge 4 ]; then
            tests_eval "${@}"
        fi
    } 2>&1 | tests_indent
}

tests_eval() {
    local cmd=()
    for i in "${@}"; do
        case $i in
            '`'*)  cmd+=($i) ;;
            *'`')  cmd+=($i) ;;
            *'>'*) cmd+=($i) ;;
            *'<'*) cmd+=($i) ;;
            *'&')  cmd+=($i) ;;
            '|')   cmd+=($i) ;;
            *)     cmd+=(\"$i\")
        esac
    done

    eval "${cmd[@]}"
}

tests_indent() {
    sed -r -e 's/^/    /' -e '1i\ ' -e '$a\ '
}

tests_quote_re() {
    sed -r 's/[.*+[()?]|]/\\\0/' < "$1"
}

tests_quote_cmd() {
    local cmd=()
    for i in "${@}"; do
        grep -q "[' \"\$]" <<< "$i"
        if [ $? -eq 0 ]; then
            cmd+=($(sed -r -e "s/['\"\$]/\\&/" -e "s/.*/'&'/" <<< "$i"))
        else
            cmd+=($i)
        fi
    done

    echo "${cmd[@]}"
}

tests_run_all() {
    local verbose=$TEST_VERBOSE
    TEST_VERBOSE=4

    echo running test suite at: $(cd "`dirname $0`"; pwd)
    echo
    echo -ne '  '

    local success=0
    local total_assertions_cnt=0
    for file in *.test.sh; do
        if [ $verbose -eq 0 ]; then
            local stdout="`mktemp -t stdout.XXXX`"
            TEST_ASSERTS=0
            local pwd="$(pwd)"
            tests_run_one "$file" > $stdout 2>&1
            local result=$?
            cd "$pwd"
            if [ $result -eq 0 ]; then
                echo -n .
                success=$((success+1))
                rm -f $stdout
            else
                echo -n F
                echo
                echo
                cat $stdout
                rm -f $stdout
                echo "$file" > .last-testcase
                return
            fi
        else
            tests_run_one "$file"
        fi
        total_assertions_cnt=$(($total_assertions_cnt+$TEST_ASSERTS))
    done

    echo
    echo
    echo ---
    echo "$success tests ($total_assertions_cnt assertions) done successfully!"
}

tests_run_one() {
    local file="$1"

    tests_debug "TESTCASE $(readlink -f $file)"

    tests_init
    source "$file"
    tests_cleanup

    if [ $? -gt 0 ]; then
        tests_debug "TEST FAILED $(readlink -f $file)"
        return 1
    else
        tests_debug "TEST PASSED"
        return 0
    fi
}

tests_get_last() {
    cat .last-testcase
}

tests_verbose() {
    export TEST_VERBOSE=$1
}

tests_init() {
    export TEST_ID="$(mktemp -t -d tests.XXXX)"
    tests_debug "new test session"
}

tests_cleanup() {
    tests_debug "$TEST_ID" "cleanup test session"

    test ! -e "$TEST_ID/_failed"
    local success=$?

    rm -rf "$TEST_ID"

    return $success
}

TEST_ID=""
TEST_VERBOSE=0
TEST_ASSERTS=0

if [ "$1" == "all" ]; then
    tests_run_all
fi

if [ "$1" == "one" ]; then
    tests_verbose 5
    if [ -e "$2" ]; then
        tests_run_one "$2"
    else
        if [ "$(tests_get_last)" ]; then
            tests_run_one "$(tests_get_last)"
        else
            echo "no last failed testcase found"
            exit 1
        fi
    fi
fi
# }}}
