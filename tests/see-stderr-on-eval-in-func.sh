put testcases/mkdir-with-flags.test.sh <<EOF
set -euo pipefail
function _func() {
    tests:eval "bash -c 'echo errrrrrrrrrrrr >&2; exit 1'"
}

_func
tests:assert-success
EOF


not ensure tests.sh -vvvvd testcases -A
