put testcases/assert-re-stdout.test.sh <<EOF
tests:eval echo meep

tests:assert-re stdout m..p
tests:not tests:assert-re stdout w..a
EOF

put testcases/assert-re-stderr.test.sh <<EOF
tests:eval echo 'meep >&2'

tests:assert-re stderr m..p
tests:not tests:assert-re stderr w..a
EOF

put testcases/assert-re-file.test.sh <<EOF
tests:put-string test-file meep

tests:assert-re test-file m..p
tests:not tests:assert-re test-file w..a
EOF

ensure tests.sh -d testcases -A

assert-stdout "3 tests (6 assertions) done successfully!"
