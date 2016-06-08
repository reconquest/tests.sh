put testcases/can-assert-stdout-is-empty.test.sh <<EOF
tests:eval echo -n
tests:assert-stdout ""
tests:assert-stdout-empty
tests:assert-empty stdout
EOF

put testcases/can-assert-stderr-is-empty.test.sh <<EOF
tests:eval echo -n
tests:assert-stderr ""
tests:assert-stderr-empty
tests:assert-empty stderr
EOF

ensure tests.sh -d testcases -A

assert-stdout '2 tests (6 assertions) done successfully!'
