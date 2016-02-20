put testcases/strings-equals.test.sh <<EOF
tests:import-namespace

assert-equals "1" "1"
not assert-equals "1" "2"
EOF

ensure tests.sh -d testcases -A

assert-stdout "1 tests (2 assertions) done successfully!"
