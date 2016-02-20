put testcases/echo-meep-on-stderr-success.test.sh <<EOF
tests:eval 'echo meep >&2'
tests:assert-stderr meep
EOF

put testcases/echo-meep-on-stderr-fail.test.sh <<EOF
tests:eval 'echo whoa >&2'
tests:not tests:assert-stderr meep
EOF


ensure tests.sh -d testcases -A

assert-stdout '2 tests (2 assertions) done successfully!'
