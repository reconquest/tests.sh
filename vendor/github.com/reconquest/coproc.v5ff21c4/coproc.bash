# @description Schedules specified job to execution.
#
# **NOTE**: job will not execute until stdout and stderr output descriptors
# will be opened for reading.
#
# @example
#   coproc:run echo_proc echo 1
#   coproc:get-stdout-only "$echo_proc"  # will output 1
#
# @example
#   coproc:run echo_proc echo 2
#   coproc:get-stdout-fd stdout
#   cat <&$stdout
#
# @arg $1 var Variable name to store new coprocess ID.
# @arg $@ any Command to start as a coprocess.
coproc:run() {
    local _id_var=$1
    shift

    self=$(_coproc_create_channels)

    builtin eval $_id_var=\$self

    _coproc_job "$self" "${@}"
}

# @description Gets top-level PID of specified running coprocess.
#
# @arg $1 id Coprocesss ID.
# @arg $2 var Variable name to store PID.
coproc:get-pid() {
    local self=$1
    local _pid_var=$2

    local _pid=$(cat $self/pid)

    eval $_pid_var=\$_pid
}

# @description Waits specified coprocess to finish.
#
# **NOTE**: that function will implicitly drop all output and unblock job.
#
# @arg $1 id Coprocesss ID.
coproc:wait() {
    local self=$1
    local stdout
    local stderr


    exec {stdout}<>$self/stdout.pipe
    exec {stderr}<>$self/stderr.pipe

    if [ -e "$self/done" ]; then
        cat "$self/done" >$self/exit-code
        rm "$self/done"
    fi

    exec {stdout}<&-
    exec {stderr}<&-
}

# @description Gets stdout FD linked to stdout of running coprocess.
#
# @arg $1 id Coprocess ID.
# @arg $2 var Variable name to store FD.
coproc:get-stdout-fd() {
    _coproc_duplicate_pipe_to_fd "<$1/stdout.pipe" "$2"
}

# @description Gets stderr FD linked to stderr of running coprocess.
#
# @arg $1 id Coprocess ID.
# @arg $2 var Variable name to store FD.
coproc:get-stderr-fd() {
    _coproc_duplicate_pipe_to_fd "<$1/stderr.pipe" "$2"
}

coproc:get-stdin-fd() {
    _coproc_duplicate_pipe_to_fd ">$1/stdin.pipe" "$2"
}

# @description Gets only stdout of corresponding coprocess. Standard error
# stream will be silently dropped.
#
# @arg $1 id Coprocess ID.
# @stdout Standard output stream of coprocess.
coproc:get-stdout-only() {
    local self=$1

    local stdout
    local stderr

    coproc:get-stdout-fd "$self" stdout
    coproc:get-stderr-fd "$self" stderr

    cat <&$stdout

    coproc:close-fd stderr
    coproc:close-fd stdout
}

# @description Gets only stderr of corresponding coprocess. Standard output
# stream will be silently dropped.
#
# @arg $1 id Coprocess ID.
# @stderr Standard errput stream of coprocess.
coproc:get-stderr-only() {
    local self=$1

    local stdout
    local stderr

    coproc:get-stdout-fd "$self" stdout
    coproc:get-stderr-fd "$self" stderr

    cat <&$stderr

    coproc:close-fd stderr
    coproc:close-fd stdout
}

_coproc_send_stdin() {
    local self=$1

    local stdin

    exec {stdin}>$self/stdin.pipe

    if [ -s /dev/stdin ]; then
        cat >&$stdin
    else
        cat /dev/null >&$stdin
    fi

    exec {stdin}<&-
}

#coproc:close-stdin() {

#}

# @description Closes specified FD, previously opened by
# `coproc:get-stdout-fd()` or `coproc:get-stderr-fd()` functions.
#
# Descriptor must be closed to prevent leaking.
#
# @arg $1 fd FD to close.
coproc:close-fd() {
    eval "exec {$1}<&-"
}

# @description Stops specified coprocess with SIGTERM. If coprocess is still
# alive after 0.1 second, kill it with SIGKILL. If coprocess requires root
# privileges, kill it with sudo.
#
# @arg $1 id Coprocess ID.
coproc:stop() {
    local self=$1

    local main_pid

    coproc:wait "$self" &
    local wait_pid=$!

    while [ "${main_pid:-}" = "" ]; do
        main_pid=$(cat $self/pid)
    done

    local killed
    while [ ! "${killed:-}" ]; do
        if [ ! -e "$self/done" ]; then
            killed="yes"
        fi

        local pids=$(_coproc_get_job_child_pids "$main_pid")
        local children=($pids)

        if [ "${#children[@]}" = "0" ]; then
            continue
        fi

        _coproc_kill_children "kill" "${children[@]}"
    done

    _coproc_kill_watchdog "$wait_pid" &
    wait $wait_pid
}

# @description Returns error code which will be returned by `coproc:wait()` if
# specified coprocess is killed or errored.
#
# @noargs
# @stdout Kill error code.
coproc:get-killed-code() {
    printf "128"
}

_coproc_job() {
    local self="$1"

    _coproc_eval "${@}" \
        <$self/stdin.pipe \
        >$self/stdout.pipe \
        2>$self/stderr.pipe &

    printf "$!" >$self/pid

    _coproc_send_stdin "$self"
}

_coproc_eval() {
    local self=$1
    shift

    trap "coproc:get-killed-code >$self/done" ERR

    local exit_code

    if builtin eval "${@}"; then
        exit_code=0
    else
        exit_code=$?
    fi

    exec 1<&-
    exec 2<&-

    printf "$exit_code" >$self/done
}

_coproc_kill_children() {
    local kill_command=$1
    shift

    local children=(${@})
    local kill_output

    if kill_output="$(command $kill_command "${children[@]}" 2>&1)"; then
        if grep -qF "not permitted" <<< "$kill_output"; then
            _coproc_kill_children "sudo kill" "${children[@]}"
        else
            _coproc_kill_watchdog "${children[@]}" &

            wait $!
        fi
    fi
}

_coproc_kill_watchdog() {
    local kill_command=$1
    shift

    local children=${@}

    sleep 0.1
    command $kill_command -9 "${children[@]}" &>/dev/null || true
}

_coproc_get_job_child_pids() {
    local main_pid=$1

    pstree -lp "$main_pid" \
        | grep -oP '\(\d+\)' \
        | grep -oP '\d+' \
        | tail -n+2
}

_coproc_duplicate_pipe_to_fd() {
    local pipe=$1
    local _fd_var=$2

    builtin eval "exec {$_fd_var}$pipe"
}

_coproc_create_channels() {
    local self=$(mktemp -d -t coproc.XXXXXXXX)

    mkfifo "$self/stdin.pipe"
    mkfifo "$self/stdout.pipe"
    mkfifo "$self/stderr.pipe"
    mkfifo "$self/done"

    printf "%s" $self
}

_coproc_remove_channels() {
    local self=$1

    coproc:wait "$self"

    rm -rf "$self"
}
