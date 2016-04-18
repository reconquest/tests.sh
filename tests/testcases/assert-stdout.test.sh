put testcases/echo-meep-success.test.sh <<EOF
tests:eval echo meep
tests:assert-stdout meep
EOF

put testcases/echo-meep-fail.test.sh <<EOF
tests:eval echo whoa
tests:not tests:assert-stdout meep
EOF

ensure tests.sh -d testcases -A

assert-stdout '2 tests (2 assertions) done successfully!'
