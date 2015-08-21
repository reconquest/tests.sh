#!/bin/bash


# Current test session
TEST_DIR=""

# Verbosity level
TEST_VERBOSE=0

# Assertions counter
TEST_ASSERTS=0

# Last stdout
TEST_STDOUT=

# Last stderr
TEST_STDERR=

# Current working directory for testcase.
TEST_CASE_DIR=""

# Public API Functions {{{

# Function tests_tmpdir returns temporary directory for current test session.
# Echo:
#   Path to temp dir, e.g, /tmp/tests.XXXX
tests_tmpdir() {
    if [[ "$TEST_DIR" == "" ]]; then
        tests_debug "test session not initialized"
        tests_interrupt
    fi

    echo "$TEST_DIR"
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
        touch "$TEST_DIR/_failed"
        tests_debug "expectation failed: two strings not equals"
        tests_debug ">>> $expected$"
        tests_debug "<<< $actual$"
        tests_interrupt
    fi

    tests_inc_asserts_count
}

# Function tests_assert_stdout compares last evaluated command stdout
# to given string.
# Args:
#   $1: expected stdout
tests_assert_stdout() {
    local expected="$1"
    shift

    tests_assert_stdout_re "$(tests_quote_re "$expected")"
}

# Function tests_re tests that last evaluated command output
# (stdout or stderr) matches regexp.
# Args:
#   $1: stdout|stderr|<filename>
#   $2: regexp
tests_re() {
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
    return $?
}

# Function tests_assert_re checks that last evaluated command output
# (stdout or stderr) matches regexp.
# Args:
#   $1: stdout|stderr|<filename>
#   $2: regexp
tests_assert_re() {
    local target="$1"
    local regexp="$2"
    shift 2

    tests_re "$target" "$regexp"
    local result=$?

    if [ $result -gt 0 ]; then
        touch "$TEST_DIR/_failed"
        tests_debug "expectation failed: regexp does not match"
        tests_debug ">>> ${regexp:-<empty regexp>}"
        tests_debug "<<< ${target}"
        tests_debug "<<< $(cat $file)"
        tests_interrupt
    fi

    tests_inc_asserts_count
}

# Function tests_stdout returns file with stdout of last command.
tests_stdout() {
    echo $TEST_STDOUT
}

# Function tests_stderr returns file with stderr of last command.
tests_stderr() {
    echo $TEST_STDERR
}

# Function tests_diff checks diff of last evaluated command output (stdout or
# stder) or file with given file or content.
# Args:
#   $1: string|file (expected)
#   $2: stdout|stderr|string|file (actual)
tests_diff() {
    local expected_target="$1"
    local actual_target="$2"
    shift 2

    if [ -e "$expected_target" ]; then
        expected_content="$(cat $expected_target)"
    else
        expected_content="$expected_target"
    fi

    if [ -e "$actual_target" ]; then
        actual_content="$(cat $actual_target)"
    elif [ "$actual_target" = "stdout" ]; then
        actual_content="$(cat $TEST_STDOUT)"
    elif [ "$actual_target" = "stderr" ]; then
        actual_content="$(cat $TEST_STDOUT)"
    else
        actual_content="$actual_target"
    fi

    local diff
    diff=$(diff -u <(echo -e "$expected_content") <(echo -e "$actual_content"))

    local result=$?

    if [ $result -ne 0 ]; then
        touch "$TEST_DIR/_failed"
        tests_debug "diff failed: "
        tests_indent <<< "$diff"
        tests_interrupt
    fi

    tests_inc_asserts_count
}

# Function tests_test is the wrapper for 'test' utility, which check exit code
# of 'test' utility after running.
# Args:
#   $@: arguments for 'test' utility
tests_test() {
    local args="$@"

    tests_debug "test $args"
    test "$@"
    local result=$?

    if [ $result -ne 0 ]; then
        touch "$TEST_DIR/_failed"
        tests_debug "test $args: failed"
        tests_interrupt
    fi

    tests_inc_asserts_count
}

tests_put() {
    local file="$1"
    local content="$2"
    tests_debug "writing a file $file with content:"
    tests_debug "$content"
    echo "$content" > "$file"
}

# Function tests_assert_stdout_re checks that stdout of last evaluated command
# matches given regexp.
# Args:
#   $1: regexp
tests_assert_stdout_re() {
    tests_assert_re stdout "$@"
}

# Function tests_assert_stderr_re do the same, as tests_assert_stdout_re, but
# stderr used instead of stdout.
# Args:
#   $1: regexp
tests_assert_stderr_re() {
    tests_assert_re stderr "$@"
}

# Function tests_assert_success checks that last evaluated command exit status
# is zero.
# Args:
#   $@: command to evaluate
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
    if [[ "$result" != "$code" ]]; then
        touch "$TEST_DIR/_failed"
        tests_debug "expectation failed: actual exit status = $result"
        tests_debug "expected exit code is $code"
        tests_interrupt
    fi

    tests_inc_asserts_count
}

# Function tests_describe evaluates given command and show it's output,
# used for debug purposes.
# Args:
#   $@: command to evaluate
tests_describe() {
    tests_debug "this test decription:"

    tests_eval "$@" | tests_indent
}

# Function tests_debug echoes specified string as debug info.
# Args:
#   $@: string to echo
tests_debug() {
    if [ $TEST_VERBOSE -lt 1 ]; then
        return
    fi

    if [ "$TEST_DIR" ]; then
        echo "# $TEST_DIR: $@"
    else
        echo "### $@"
    fi >&2
}

# Function tests_cd changes work directory to specified directory.
# Args:
#   $1: directory
tests_cd() {
    local dir=$1
    tests_debug "\$ cd $1"
    cd $1
}

# Function tests_do evaluates specified string
# Args:
#   $@: string to evaluate
tests_do() {
    tests_debug "$ $@"

    # reset stdout/stderr/exitcode
    >$TEST_STDOUT
    >$TEST_STDERR
    >$TEST_EXITCODE

    (
        if [ $TEST_VERBOSE -lt 2 ]; then
            tests_eval "$@" > $TEST_STDOUT 2> $TEST_STDERR
        fi

        if [ $TEST_VERBOSE -eq 3 ]; then
            tests_eval "$@" \
                2> >(tee $TEST_STDERR) \
                1> >(tee $TEST_STDOUT > /dev/null)
        fi

        if [ $TEST_VERBOSE -gt 3 ]; then
            tests_eval "$@" \
                2> >(tee $TEST_STDERR) \
                1> >(tee $TEST_STDOUT)
        fi

        echo $? > $TEST_EXITCODE
    ) 2>&1 | tests_indent

    return $(cat $TEST_EXITCODE)
}

tests_ensure() {
    tests_do "$@"
    tests_assert_success
}

tests_mkdir() {
    tests_do mkdir -p $TEST_DIR/$1
}

tests_tmp_cd() {
    tests_cd $TEST_DIR/$1
}

# Function tests_background runs any command in background, this is very useful
# if you test some running service.
# Processes which runned by tests_background will be killed on cleanup state,
# and if test failed, stderr and stdout of all background processes will be
# printed.
# Args:
#   $@: string to evaluate
tests_background() {
    local cmd="$@"

    local identifier=$(date +'%s.%N' | md5sum | head -c 6)
    local dir="$TEST_DIR/.bg/$identifier/"


    tests_debug "starting background task #$identifier"
    tests_debug "# '$cmd'"

    mkdir -p "$dir"
    tests_debug "working directory: $dir"

    echo "$identifier" > "$dir/id"
    echo "$cmd" > "$dir/cmd"

    touch "$dir/stdout"
    touch "$dir/stderr"
    touch "$dir/pid"

    eval "( $cmd >$dir/stdout 2>$dir/stderr )" \
        {0..255}\<\&- {0..255}\>\&- \&

    local bg_pid
    bg_pid=$(pgrep -f "$cmd")

    if [ $? -ne 0 ]; then
        tests_debug "background process does not started, interrupting test"
        tests_interrupt
    fi

    echo "$bg_pid" > "$dir/pid"
    tests_debug "background process started, pid = $bg_pid"

    echo "$identifier"
}

# Function tests_background_pid returning pid of last runned background
# process.
tests_background_pid() {
    cat "$TEST_DIR/.bg/$1/pid"
}

# Function tests_background_stdout returning stdout of last runned background
# process.
tests_background_stdout() {
    echo "$TEST_DIR/.bg/$1/stdout"
}

# Function tests_background_stderr returning stdoerr of last runned background
# process.
tests_background_stderr() {
    echo "$TEST_DIR/.bg/$1/stderr"
}

# Function 'tests_stop_background' stops background work.
# Args:
#    $1 - string
tests_stop_background() {
    local id="$1"
    local pid=$(cat $TEST_DIR/.bg/$id/pid)

    kill -9 $pid

    tests_debug "background task #$id stopped"
    rm -rf $TEST_DIR/.bg/$id/
}

tests_wait_file_changes() {
    local function="$1"
    local file="$2"
    local sleep_interval="$3"
    local sleep_max="$4"

    local stat_initial=$(stat $file)
    local sleep_iter=0


    tests_debug "% waiting file changes after executing cmd: $function"
    tests_do $function

    while true; do
        sleep_iter=$(($sleep_iter+1))

        local stat_actual=$(stat $file)
        if [[ "$stat_initial" == "$stat_actual" ]]; then
            if [[ $sleep_iter -ne $sleep_max ]]; then
                tests_do sleep $sleep_interval
                continue
            fi

            return 1
        fi

        return 0
    done
}
# }}}

# Inernal Code {{{
tests_eval() {
    local cmd=()
    for i in "$@"; do
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
    for i in "$@"; do
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
    if ! stat *.test.sh >/dev/null; then
        echo no testcases found.

        exit 1
    fi

    local verbose=$TEST_VERBOSE
    TEST_VERBOSE=4

    echo running test suite at: $(cd "`dirname $0`"; pwd)
    echo
    if [ "$verbose" = "0" ]; then
        echo -ne '  '
    fi

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
                exit $result
            fi
        else
            tests_run_one "$file"
            local result=$?
            if [ $result -ne 0 ]; then
                exit $result
            fi

            success=$((success+1))
        fi
        total_assertions_cnt=$(($total_assertions_cnt+$TEST_ASSERTS))
    done

    tests_rm_last

    echo
    echo
    echo ---
    echo "$success tests ($total_assertions_cnt assertions) done successfully!"
}

tests_run_one() {
    local target="$1"
    local file="$(readlink -f $1)"

    tests_debug "TESTCASE $file"

    tests_init

    touch $TEST_DIR/_asserts
    TEST_CASE_DIR=$(dirname "$file")
    (
        PATH="$TEST_DIR/bin:$PATH"
        cd $TEST_DIR
        source "$file"
    )
    local result=$?

    TEST_ASSERTS=$(cat $TEST_DIR/_asserts)

    if [[ $result -ne 0 && ! -f "$TEST_DIR/_failed" ]]; then
        tests_debug "test exited with non-zero exit code"
        tests_debug "exit code = $result"
        touch "$TEST_DIR/_failed"
    fi

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

tests_rm_last() {
    rm -f .last-testcase
}

tests_verbose() {
    TEST_VERBOSE=$1
}

tests_init() {
    TEST_DIR="$(mktemp -t -d tests.XXXX)"

    mkdir $TEST_DIR/bin

    TEST_STDERR="$TEST_DIR/stderr"
    TEST_STDOUT="$TEST_DIR/stdout"
    TEST_EXITCODE="$TEST_DIR/exitcode"

    tests_debug "new test session"
}

tests_cleanup() {
    tests_debug "$TEST_DIR" "cleanup test session"

    test ! -e "$TEST_DIR/_failed"
    local success=$?

    for bg_dir in $TEST_DIR/.bg/*; do
        if ! test -d $bg_dir; then
            continue
        fi

        local bg_id=$(cat $bg_dir/id)

        if [ $success -ne 0 ]; then
            local bg_cmd=$(cat $bg_dir/cmd)
            local bg_stdout=$(cat $bg_dir/stdout)
            local bg_stderr=$(cat $bg_dir/stderr)


            tests_debug "background task #$bg_id cmd:"
            tests_debug "# $bg_cmd"

            if [[ "$bg_stdout" == "" ]]; then
                tests_debug "background task #$bg_id stdout is empty"
            else
                tests_debug "background task #$bg_id stdout:"
                tests_indent <<< "$bg_stdout"
            fi

            if [[ "$bg_stderr" == "" ]]; then
                tests_debug "background task #$bg_id stderr is empty"
            else
                tests_debug "background task #$bg_id stderr:"
                tests_indent <<< "$bg_stderr"
            fi
        fi

        tests_stop_background $bg_id
    done

    if [ $success -eq 0 ]; then
        rm -rf "$TEST_DIR"
    fi

    return $success
}

tests_interrupt() {
    exit 88
}

tests_copy() {
    tests_debug "cp -r \"$TEST_CASE_DIR/$1\" $TEST_DIR"
    cp -r "$TEST_CASE_DIR/$1" $TEST_DIR
}

tests_inc_asserts_count() {
    local count=$(cat $TEST_DIR/_asserts)
    echo $(($count+1)) > $TEST_DIR/_asserts
}

tests_source() {
    tests_copy "$1"

    local source_name=$(basename $1)
    tests_debug "source $source_name (begin)"
    source "$source_name"
    tests_debug "source $source_name (end)"
}

if [ "$(basename $0)" == "tests.sh" ]; then
    while getopts "hAO:v" arg; do
        case $arg in
            A)
                tests_run_all
                ;;
            O)
                tests_run_one "$OPTARG"
                ;;
            v)
                TEST_VERBOSE=$(($TEST_VERBOSE+1))
                ;;
            *)
                cat <<EOF
tests.sh --- simple test library for testing commands.

tests.sh expected to find files named *.test.sh in current directory, and
they are treated as testcases.

Usage:
    tests.sh -h | ---help
    tests.sh [-v] -A
    tests.sh -O <name>

Options:
    -h | --help  Show this help.
    -A           Run all testcases in current directory.
    -O <name>    Run specified testcase only.
    -v           Verbosity. Flag can be specified several times.
EOF
                ;;
        esac
    done
fi
