#!/bin/bash

# Public API Functions {{{

# @description Make all functions from tests.sh available without 'tests:'
# prefix.
#
# @noargs
tests:import-namespace() {
    builtin eval $(declare -F | grep -F -- '-f tests:' | cut -d: -f2 |
        sed -re's/.*/&() { tests:& "${@}"; };/'
    )
}

# @description Returns temporary directory for current test session.
#
# It can be used as a workspace for the testcase.
#
# @example
#   ls $(tests:get-tmp-dir)
#
# @echo Path to temp dir, e.g, /tmp/tests.XXXX
tests:get-tmp-dir() {
    if [[ "$tests_dir" == "" ]]; then
        tests:debug "test session not initialized"
        tests_interrupt
    fi

    echo "$tests_dir"
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

    if ! tests_make_assertion "$expected" "$actual"; then
        touch "$tests_dir/.failed"
        tests:debug "expectation failed: two strings not equals"
        tests:debug ">>> $expected$"
        tests:debug "<<< $actual$"
        tests_interrupt
    fi

    tests_inc_asserts_count
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

    tests:assert-stdout-re "$(tests_quote_re <<< "$expected")"
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

    tests:assert-stderr-re "$(tests_quote_re <<< "$expected")"
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
#
# @exitcode 1 If comparison failed.
# @exitcode 0 If contents equals.
tests:match-re() {
    local target="$1"
    local regexp="$2"
    shift 2

    if [ -f $target ]; then
        file=$target
    elif [ "$target" = "stdout" ]; then
        file=$tests_stdout
    else
        file=$tests_stderr
    fi

    grep -qP "$regexp" $file
    return $?
}

# @description Same, as 'tests:match-re', but abort testing if comparison failed.
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
    local result=$?

    if ! tests_make_assertion $result 0; then
        touch "$tests_dir/.failed"
        tests:debug "expectation failed: regexp does not match"
        tests:debug "*** match on: ${target}"
        tests:debug ">>> ${regexp:-<empty regexp>}"
        tests:debug "<<<"
        cat $file | tests_indent

        tests_interrupt
    fi

    tests_inc_asserts_count
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
# @arg $1 'stdout'|'stderr'|string|filename Actual value.
# @arg $2 string|filename Expected value.
# @arg $@ any Additional arguments for diff.
tests:assert-no-diff() {
    local actual_target="$1"
    local expected_target="$2"
    shift 2

    local options="-u $@"

    if [ -e "$expected_target" ]; then
        expected_content="$(cat $expected_target)"
    else
        expected_content="$expected_target"
    fi

    if [ -e "$actual_target" ]; then
        actual_content="$(cat $actual_target)"
    elif [ "$actual_target" = "stdout" ]; then
        actual_content="$(cat $tests_stdout)"
    elif [ "$actual_target" = "stderr" ]; then
        actual_content="$(cat $tests_stderr)"
    else
        actual_content="$actual_target"
    fi

    local diff
    diff=$(diff `echo $options` \
        <(echo -e "$expected_content") \
        <(echo -e "$actual_content"))

    local result=$?

    if ! tests_make_assertion $result 0; then
        touch "$tests_dir/.failed"
        tests:debug "diff failed: "
        tests_indent <<< "$diff"
        tests_interrupt
    fi

    tests_inc_asserts_count
}

# @description Returns file containing stdout of last command.
#
# @example
#   tests:eval echo 123
#   cat $(tests:get-stdout) # will echo 123
#
# @echo Filename containing stdout.
tests:get-stdout() {
    echo $tests_stdout
}

# @description Returns file containing stderr of last command.
#
# @example
#   tests:eval echo 123 '1>&2' # note quotes
#   cat $(tests:get-stderr) # will echo 123
#
# @echo Filename containing stderr.
tests:get-stderr() {
    echo $tests_stderr
}

# @description Same as 'tests:assert-diff', but ignore changes whose lines are
# all blank.
#
# @example
#   tests:eval echo -e '1\n2'
#   tests:assert-no-diff stdout "$(echo -e '1\n2')" # note quotes
#   tests:assert-no-diff stdout "$(echo -e '1\n\n2')" # test will pass
#
# @see tests:diff
tests:assert-no-diff-blank() {
    tests:assert-no-diff "$1" "$2" "-B"
}

# @description Same, as shell 'test' function, but asserts, that exit code is
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
    test "$@"
    local result=$?

    if [ $result -ne 0 ]; then
        touch "$tests_dir/.failed"
        tests:debug "test $args: failed"
        tests_interrupt
    fi

    tests_inc_asserts_count
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

    tests:debug "writing a file $file with content:"
    echo "$content" | tests_indent

    echo "$content" > "$file"
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
# @arg $1 filename Filename (non-temporary).
tests:put() {
    local file="$1"

    cat > "$tests_dir/$file"

    tests:debug "wrote a file $file with content:"
    cat $file | tests_indent
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
    local actual=$?
    local expected=$1
    shift

    if ! tests_make_assertion "$expected" "$actual"; then
        touch "$tests_dir/.failed"
        tests:debug "exit code expectation failed"
        tests:debug "actual exit code = $actual"
        tests:debug "expected exit code $tests_last_assert_operation $expected"
        tests_interrupt
    fi

    tests_inc_asserts_count
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
    local old_exitcode=$?

    tests_assert_operation="!="
    tests_last_assert_operation="!="

    # preserving old exit code for possible tests:assert-success call
    ( return $old_exitcode )

    builtin eval "${@}"
    tests_assert_operation="="
}

# @description Evaluates given command and show it's output in the debug, used
# for debug purposes.
#
# @arg $@ any Command to evaluate.
tests:describe() {
    tests:debug "this test decription:"

    tests_eval "$@" | tests_indent
}

# @description Print specified string in the debug log.
#
# @example
#   tests:debug "hello from debug" # will shown only in verbose mode
#
# @arg $@ any String to echo.
tests:debug() {
    if [ $tests_verbose -lt 1 ]; then
        return
    fi

    if [ "$tests_dir" ]; then
        echo "# $tests_dir: $@"
    else
        echo "### $@"
    fi >&2
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
# @example
#   tests:eval echo 123 "# i'm comment"
#   tests:eval echo 123 \# i\'m comment
#   tests:eval echo 567 '1>&2' # redirect to stderr
#   tests:eval echo 567 1>\&2' # same
#
# @arg $@ string String to evaluate.
tests:eval() {
    tests:debug "$ $@"

    (
        case $tests_verbose in
            0|1)
                tests_eval "$@" > $tests_stdout 2> $tests_stderr
                ;;
            2)
                tests_eval "$@" \
                    2> >(tee $tests_stderr) \
                    1> >(tee $tests_stdout > /dev/null)
                ;;
            *)
                tests_eval "$@" \
                    2> >(tee $tests_stderr) \
                    1> >(tee $tests_stdout)
                ;;
        esac
    ) > $tests_out 2>&1

    echo $? > $tests_exitcode

    tests_indent < $tests_out

    return $(cat $tests_exitcode)
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
# @arg $1 string Directory name.
tests:mkdir() {
    # prepend to any non-flag argument $tests_dir prefix
    tests:eval /bin/mkdir \
        $(sed -re "s#(^|\\s)([^-])#\\1$tests_dir/\\2#g" <<< "${@}")
}

# @description Changes working directory to the specified temporary directory,
# previously created by 'tests:mkdir'.
#
# @arg $1 string Directory name.
tests:cd-tmp-dir() {
    tests:cd $tests_dir/$1
}

# @description Runs any command in background, this is very useful if you test
# some running service.
#
# Processes which are ran by 'tests:background' will be killed on cleanup
# state, and if test failed, stderr and stdout of all background processes will
# be printed.
#
# @arg $@ string Command to start.
#
# @echo Unique identifier of running backout process.
tests:run-background() {
    local cmd="$@"

    local identifier=$(date +'%s.%N' | md5sum | head -c 6)
    local dir="$tests_dir/.bg/$identifier/"


    tests:debug "starting background task #$identifier"
    tests:debug "# '$cmd'"

    /bin/mkdir -p "$dir"

    tests:debug "working directory: $dir"

    echo "$identifier" > "$dir/id"
    echo "$cmd" > "$dir/cmd"

    touch "$dir/stdout"
    touch "$dir/stderr"
    touch "$dir/pid"

    builtin eval "( $cmd >$dir/stdout 2>$dir/stderr )" \
        {0..255}\<\&- {0..255}\>\&- \&

    local bg_pid=$(pgrep -f "$cmd")

    if [ $? -ne 0 ]; then
        tests:debug "background process does not started, interrupting test"
        tests_interrupt
    fi

    echo "$bg_pid" > "$dir/pid"
    tests:debug "background process started, pid = $bg_pid"

    echo "$identifier"
}

# @description Returns pid of specified background process.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
#
# @echo Pid of background process.
tests:get-background-pid() {
    cat "$tests_dir/.bg/$1/pid"
}

# @description Returns stdout of specified background process.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
#
# @echo Stdout from background process.
tests:get-background-stdout() {
    echo "$tests_dir/.bg/$1/stdout"
}

# @description Returns stderr of specified background process.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
#
# @echo Stderr from background process.
tests:background-stderr() {
    echo "$tests_dir/.bg/$1/stderr"
}

# @description Stops background process with 'kill -9'.
#
# @arg $1 string Process ID, returned from 'tests:run-background'.
tests:stop-background() {
    local id="$1"
    local pid=$(cat $tests_dir/.bg/$id/pid)

    kill -9 $pid

    tests:debug "background task #$id stopped"
    rm -rf $tests_dir/.bg/$id/
}

# @description Waits, until specified file will be changed or timeout passed
# after executing specified command.
#
# @arg $1 string Command to evaluate.
# @arg $2 filename Filename to wait changes in.
# @arg $3 int Interval of time to check changes after.
# @arg $4 int Timeout in seconds.
tests:wait-file-changes() {
    local function="$1"
    local file="$2"
    local sleep_interval="$3"
    local sleep_max="$(( $4/$sleep_interval ))"

    local stat_initial=$(stat $file)
    local sleep_iter=0


    tests:debug "% waiting file changes after executing cmd: $function"
    tests:eval $function

    while true; do
        sleep_iter=$(($sleep_iter+1))

        local stat_actual=$(stat $file)
        if [[ "$stat_initial" == "$stat_actual" ]]; then
            if [[ $sleep_iter -ne $sleep_max ]]; then
                tests:eval sleep $sleep_interval
                continue
            fi

            return 1
        fi

        return 0
    done
}

# @description Sets verbosity of testcase output.
#
# @arg $1 int Verbosity.
tests:set-verbose() {
    tests_verbose=$1
}

# @description Recursively copy specified file or directory from the testcases
# dir to the temporary test directory.
#
# @arg $1 filename Filename to copy.
tests:cp() {
    local files=($tests_case_dir/$1)
    shift

    while [ $# -gt 1 ]; do
        files=($files $tests_case_dir/$1)

        shift
    done

    tests:debug "cp -r ${files[@]} $tests_dir/$1"
    /bin/cp -r ${files[@]} $tests_dir/$1
}

# @description Copy specified file from testcases to the temporary test
# directory and then source it.
#
# @arg $1 filename Filename to copy and source.
tests:source() {
    tests:cp "$1"

    local source_name=$(basename $1)
    tests:debug "{BEGIN} source $source_name"
    builtin source "$source_name"
    tests:debug "{END} source $source_name"
}
# }}}

# Internal Code {{{

# Internal global state {{{
#
# Do not use this variables directly.

# Current test session.
tests_dir=""

# Verbosity level.
tests_verbose=0

# Assertions counter.
tests_asserts=0

# File with last stdout.
tests_stdout=""

# File with last stderr.
tests_stderr=""

# File with stderr and stout from eval
tests_out=""

# File with last exitcode.
tests_exitcode=""

# Current working directory for testcase.
tests_case_dir=""

# 1 if global setup script evaled.
tests_setup_done=""

# Operation used in assertions (= or !=)
tests_assert_operation="="

# Last used assert operation.
tests_last_assert_operation="="

# }}}

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

    builtin eval "${cmd[@]}"
}

tests_indent() {
    sed -r -e 's/^/    /' -e '1i\ ' -e '$a\ '
}

tests_quote_re() {
    sed -r 's/[.*+[()?]|]/\\\0/g'
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

    local verbose=$tests_verbose
    if [ $verbose -lt 1 ]; then
        tests_verbose=4
    fi

    echo running test suite at: $(pwd)
    echo
    if [ $verbose -eq 0 ]; then
        echo -ne '  '
    fi

    local success=0
    local assertions_count=0
    for file in *.test.sh; do
        if [ $verbose -eq 0 ]; then
            local stdout="`mktemp -t stdout.XXXX`"
            local pwd="$(pwd)"
            tests_asserts=0

            tests_run_one "$file" > $stdout 2>&1
            local result=$?

            builtin cd "$pwd"
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
        assertions_count=$(($assertions_count+$tests_asserts))
    done

    tests_rm_last

    echo
    echo
    echo ---
    echo "$success tests ($assertions_count assertions) done successfully!"
}

tests_run_one() {
    local target="${1:-$(tests_get_last)}"

    local file="$(readlink -f $target)"

    tests:debug "TEST CASE $file"

    tests_init

    if [ ! -s $tests_dir/.asserts ]; then
        echo 0 > $tests_dir/.asserts
    fi

    local run_global_setup=""
    if [ -e global.setup.sh -a ! "$tests_setup_done" ]; then
        run_global_setup=1
        tests_setup_done=1
    fi

    tests_case_dir=$(dirname "$file")

    (
        PATH="$tests_dir/bin:$PATH"

        if [ $run_global_setup ]; then
            tests:debug "{GLOBAL} SETUP: ${@}"
            tests:source global.setup.sh
        fi

        local run_setup=""
        if [ -e local.setup.sh ]; then
            run_setup=1
        fi

        builtin cd $tests_dir

        if [ $run_setup ]; then
            tests:debug "{BEGIN} SETUP"
            tests:source local.setup.sh
            tests:debug "{END} SETUP"
        fi

        builtin source "$file"
    )
    local result=$?

    tests_asserts=$(cat $tests_dir/.asserts)

    if [[ $result -ne 0 && ! -f "$tests_dir/.failed" ]]; then
        tests:debug "test exited with non-zero exit code"
        tests:debug "exit code = $result"
        touch "$tests_dir/.failed"
    fi

    tests_cleanup

    if [ $result -ne 0 ]; then
        tests:debug "TEST FAILED $(readlink -f $file)"
        return 1
    else
        tests:debug "TEST PASSED $(readlink -f $file)"
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

tests_init() {
    tests_dir="$(mktemp -t -d tests.XXXX)"

    /bin/mkdir $tests_dir/bin

    tests_stderr="$tests_dir/.stderr"
    tests_stdout="$tests_dir/.stdout"
    tests_exitcode="$tests_dir/.exitcode"
    tests_out="$tests_dir/.eval"

    tests:debug "{BEGIN} TEST SESSION"
}

tests_cleanup() {
    tests:debug "{END} TEST SESSION"

    test ! -e "$tests_dir/.failed"
    local success=$?

    for bg_dir in $tests_dir/.bg/*; do
        if ! test -d $bg_dir; then
            continue
        fi

        local bg_id=$(cat $bg_dir/id)

        if [ $success -ne 0 ]; then
            local bg_cmd=$(cat $bg_dir/cmd)
            local bg_stdout=$(cat $bg_dir/stdout)
            local bg_stderr=$(cat $bg_dir/stderr)


            tests:debug "background task #$bg_id cmd:"
            tests:debug "# $bg_cmd"

            if [[ "$bg_stdout" == "" ]]; then
                tests:debug "background task #$bg_id stdout is empty"
            else
                tests:debug "background task #$bg_id stdout:"
                tests_indent <<< "$bg_stdout"
            fi

            if [[ "$bg_stderr" == "" ]]; then
                tests:debug "background task #$bg_id stderr is empty"
            else
                tests:debug "background task #$bg_id stderr:"
                tests_indent <<< "$bg_stderr"
            fi
        fi

        tests:stop-background $bg_id
    done

    if [ $success -eq 0 ]; then
        rm -rf "$tests_dir"
    fi

    tests_dir=""

    return $success
}

tests_interrupt() {
    exit 88
}

tests_make_assertion() {
    test "$1" $tests_assert_operation "$2"
    return $?
}

tests_inc_asserts_count() {
    local count=$(cat $tests_dir/.asserts)
    echo $(($count+1)) > $tests_dir/.asserts
}

tests_print_docs() {
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
        has_echo = 0

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

    /^tests:[a-zA-Z0-9_-]+\(\)/ && docblock != "" {
        print render("h1", $1) "\n\n" docblock

        docblock = ""
    }

    # }}} end of awk code'

    awk "$parser" "$(basename $0)"
}

if [ "$(basename $0)" == "tests.sh" ]; then
    while getopts "hid:AOv" arg ${@:--h}; do
        case $arg in
            d)
                builtin cd "$OPTARG"
                ;;
            A)
                tests_run_all
                ;;
            O)
                tests:set-verbose 4
                tests_run_one "${@:$OPTIND:1}"
                ;;
            v)
                tests_verbose=$(($tests_verbose+1))
                ;;
            i)
                tests_print_docs
                ;;
            *)
                cat <<EOF
tests.sh --- simple test library for testing commands.

tests.sh expected to find files named *.test.sh in current directory, and
they are treated as testcases.

Usage:
    tests.sh -h | ---help
    tests.sh [-v] [-d <dir>] -A
    tests.sh [-v] [-d <dir>] -O [<name>]
    tests.sh -i

Options:
    -h | --help  Show this help.
    -A           Run all testcases in current directory.
    -O <name>    Run specified testcase only. If no testcase specified, last failed
                 testcase will be ran.
    -d <dir>     Change directory to specified before running testcases.
    -v           Verbosity. Flag can be specified several times.
    -i           Pretty-prints documentation for public API in markdown format.
EOF

                exit 2
                ;;
        esac
    done
fi
