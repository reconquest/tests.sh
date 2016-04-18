put testcases/can-assert-stdout-is-empty.test.sh <<EOF
tests:eval echo -n
tests:assert-stdout ""
EOF

put testcases/can-assert-stderr-is-empty.test.sh <<EOF
tests:eval echo -n
tests:assert-stderr ""
EOF

ensure tests.sh -d testcases -A

assert-stdout '2 tests (2 assertions) done successfully!'
