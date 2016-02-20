put testcases/assert-exitcode.test.sh <<EOF
tests:eval exit 88
tests:assert-exitcode 88
EOF

ensure tests.sh -d testcases -A

assert-stdout '1 tests (1 assertions) done successfully!'
