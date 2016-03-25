put testcases/strings-equals.test.sh <<EOF
tests:import-namespace t:

t:assert-equals "1" "1"
t:not t:assert-equals "1" "2"
EOF

ensure tests.sh -d testcases -vA

assert-stdout "importing namespace 'tests:' into 't:'"
assert-stdout "1 tests (2 assertions) done successfully!"
