put testcases/arguments.test.sh <<EOF
tests:ensure echo '\$1 x \$2 y \$3'
tests:assert-stdout '\$1 x \$2 y \$3'
EOF

ensure tests.sh -d testcases -A

assert-stdout "1 tests (1 assertions) done successfully!"
