put testcases/two-assertions.test.sh <<EOF
tests:eval echo on-stdout
tests:assert-stdout on-stdout

tests:eval echo 'on-stderr >&2'
tests:assert-stderr on-stderr
EOF

ensure tests.sh -d testcases -A

assert-stdout '1 tests (2 assertions) done successfully!'
