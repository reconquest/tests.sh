put testcases/echo-meep-on-stderr-success.test.sh <<EOF
tests:eval echo meep '1>&2'
tests:assert-stderr meep
EOF


ensure tests.sh -d testcases -A

assert-stdout '1 tests (1 assertions) done successfully!'
