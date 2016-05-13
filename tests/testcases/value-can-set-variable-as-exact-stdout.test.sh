put testcases/set-stdout.test.sh <<EOF
_x() {
    echo "y [\$@]"
}
tests:value response _x a b c
tests:assert-equals "\$response" "y [a b c]"
EOF


ensure tests.sh -d testcases -A

assert-stdout '1 tests (1 assertions) done successfully!'
