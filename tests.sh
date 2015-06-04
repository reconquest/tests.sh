#!/bin/bash


# Current test session
TEST_ID=""

# Verbosity level
TEST_VERBOSE=0

# Assertations counter
TEST_ASSERTS=0

# Last stdout
TEST_STDOUT=

# Last stderr
TEST_STDERR=

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

# Function tests_assert_stdout compare last evaluated command stdout
# to given string.
# Args:
#   $1: expected stdout
tests_assert_stdout() {
    local expected="$1"
    shift

    tests_assert_stdout_re "$(tests_quote_re "$expected")"
}

# Function tests_assert_re evaluates command and checks that it's output
# (stdout or stderr) matches regexp.
# Args:
#   $1: stdout|stderr|file
#   $2: regexp
tests_assert_re() {
    local target="$1"
    local regexp="$2"
    shift 2

    if [ -f $target ]; then
        file=$target
    elif [ "$target" = "stdout" ]; then
        file=$TEST_STDOUT
    else
        file=$TEST_STDERR
    fi

    grep -qP "$regexp" $file
    local result=$?

    if [ $result -gt 0 ]; then
        touch "$TEST_ID/_failed"
        tests_debug "expectation failed: regexp does not match"
        tests_debug ">>> ${regexp:-<empty regexp>}"
        tests_debug "<<< ${target}"
    fi

    if [ $result -gt 0 -o $TEST_VERBOSE -ge 5 ]; then
        tests_debug "command stdout:"
        tests_indent < "$TEST_STDOUT"
        tests_debug "command stderr:"
        tests_indent < "$TEST_STDERR"
    fi

    TEST_ASSERTS=$(($TEST_ASSERTS+1))
}

# Function tests_assert_stdout_re checks that stdout of last evaluated command
# matches given regexp.
# Args:
#   $1: regexp
tests_assert_stdout_re() {
    tests_assert_re stdout "${@}"
}

# Function tests_assert_stderr_re do the same, as tests_assert_stdout_re, but
# stderr used instead of stdout.
# Args:
#   $1: regexp
tests_assert_stderr_re() {
    tests_assert_re stderr "${@}"
}

# Function tests_assert_success checks that last evaluated command exit status
# is zero.
# Args:
#   ${@}: command to evaluate
tests_assert_success() {
    tests_assert_exitcode 0
}

# Function tests_assert_exitcode chacks exit code of last evaluated command to
# specified value.
# Args:
#   $1: expected exit code
tests_assert_exitcode() {
    local code=$1
    shift

    local result=$(cat $TEST_EXITCODE)
    if [ $result -ne $code ]; then
        touch "$TEST_ID/_failed"
        tests_debug "expectation failed: actual exit status = $result"
        tests_debug "expected exit code is $code"
    fi

    if [ $result -ne $code -o $TEST_VERBOSE -ge 5 ]; then
        tests_debug "command stdout:"
        tests_indent < $TEST_STDOUT
        tests_debug "command stderr:"
        tests_indent < $TEST_STDERR
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

# Function tests_do evaluates specified string
# Args:
#   ${@}: string to evaluate
tests_do() {
    tests_debug "$ ${@}"

    echo >$TEST_STDOUT
    echo >$TEST_STDERR
    echo >$TEST_EXITCODE

    {
        if [ $TEST_VERBOSE -lt 2 ]; then
            tests_eval "${@}" > $TEST_STDOUT 2> $TEST_STDERR
        fi

        if [ $TEST_VERBOSE -lt 3 ]; then
            tests_eval "${@}" > /dev/null
            tests_eval "${@}" \
                2> >(tee $TEST_STDERR 1>&2) \
                1> >(tee $TEST_STDOUT > /dev/null)
        fi

        if [ $TEST_VERBOSE -ge 4 ]; then
            tests_eval "${@}" \
                2> >(tee $TEST_STDERR 1>&2) \
                1> >(tee $TEST_STDOUT)
        fi

        echo $? > $TEST_EXITCODE
    } 2>&1 | tests_indent
}

# }}}

# Internal Code {{{
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
                tests_set_last "$file"
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

tests_set_last() {
    local testcase=$1
    echo "$testcase" > .last-testcase
}

tests_verbose() {
    TEST_VERBOSE=$1
}

tests_init() {
    TEST_ID="$(mktemp -t -d tests.XXXX)"

    TEST_STDERR="$TEST_ID/stderr"
    TEST_STDOUT="$TEST_ID/stdout"
    TEST_EXITCODE="$TEST_ID/exitcode"

    tests_debug "new test session"
}

tests_cleanup() {
    tests_debug "$TEST_ID" "cleanup test session"

    test ! -e "$TEST_ID/_failed"
    local success=$?

    rm -rf "$TEST_ID"

    return $success
}
