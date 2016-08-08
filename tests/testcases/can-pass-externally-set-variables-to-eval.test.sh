put testcases/external-var.test.sh <<EOF
xxx="echo 123"
tests:ensure '\$xxx'

tests:assert-stdout "123"
EOF

put testcases/external-var-with-dollar.test.sh <<EOF
xxx='echo \$blah'
tests:ensure '\$xxx'

tests:assert-stdout '\$blah'
EOF

ensure tests.sh -d testcases -Avvvvv

assert-stdout "2 tests (4 assertions) done successfully!"
