put testcases/can-access-stdout.test.sh <<EOF
tests:eval echo 1
tests:assert-equals "\$(cat \$(tests:get-stdout-file))" "1"
tests:assert-equals "\$(cat \$(tests:get-stderr-file))" ""
EOF

put testcases/can-access-stderr.test.sh <<EOF
tests:eval echo 1 '>&' 2
tests:assert-equals "\$(cat \$(tests:get-stdout-file))" ""
tests:assert-equals "\$(cat \$(tests:get-stderr-file))" "1"
EOF

ensure tests.sh -d testcases -A

assert-stdout '2 tests (4 assertions) done successfully!'
