put testcases/true.test.sh <<EOF
tests:eval true
tests:assert-success
EOF

put testcases/false.test.sh <<EOF
tests:eval false
tests:assert-fail
EOF

put testcases/false-not-success.test.sh <<EOF
tests:eval false
tests:not tests:assert-success
EOF

ensure tests.sh -d testcases -A

assert-stdout '3 tests (3 assertions) done successfully!'
