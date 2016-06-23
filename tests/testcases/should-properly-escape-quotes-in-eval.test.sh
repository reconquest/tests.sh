put testcases/quote.test.sh <<EOF
tests:ensure echo "'1'"
tests:assert-stdout "'1'"

tests:ensure echo '"1"'
tests:assert-stdout '"1"'
EOF

ensure tests.sh -d testcases -vvvA

assert-stdout "1 tests (4 assertions) done successfully!"
