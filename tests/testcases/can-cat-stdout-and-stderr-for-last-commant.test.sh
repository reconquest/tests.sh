put testcases/stdout.test.sh <<EOF
tests:ensure echo 123

tests:assert-no-diff stdout <<< "\$(tests:get-stdout)"
EOF

put testcases/stderr.test.sh <<EOF
tests:ensure echo 123 '>&2'

tests:assert-no-diff stderr <<< "\$(tests:get-stderr)"
EOF

ensure tests.sh -d testcases -Avvvvv

assert-stdout "2 tests (4 assertions) done successfully!"
