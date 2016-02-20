put testcases/assert-files-are-same-via-cat.test.sh <<EOF
tests:put multiline-file-a <<EOF2
1
2
3
EOF2

tests:put multiline-file-b <<EOF2
1
3
EOF2

tests:eval cat multiline-file-a
tests:assert-no-diff stdout multiline-file-a
tests:not tests:assert-no-diff stdout multiline-file-b

tests:eval 'cat multiline-file-a >&2'
tests:assert-no-diff stderr multiline-file-a
tests:not tests:assert-no-diff stderr multiline-file-b
EOF

ensure tests.sh -d testcases -A

assert-stdout "1 tests (4 assertions) done successfully!"
