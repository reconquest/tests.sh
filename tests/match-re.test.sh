put testcases/match-re-stdout.test.sh <<EOF
tests:eval echo meep
tests:match-re stdout m..p
tests:assert-success

tests:match-re stdout w..a
tests:assert-fail
EOF

put testcases/match-re-stderr.test.sh <<EOF
tests:eval echo 'meep >&2'
tests:match-re stderr m..p
tests:assert-success

tests:match-re stderr w..a
tests:assert-fail
EOF

put testcases/match-re-file.test.sh <<EOF
tests:put-string test-file meep
tests:match-re test-file m..p
tests:assert-success

tests:match-re stderr w..a
tests:assert-fail
EOF

ensure tests.sh -d testcases -A

assert-stdout "3 tests (6 assertions) done successfully!"
