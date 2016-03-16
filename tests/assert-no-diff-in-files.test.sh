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

tests:assert-no-diff multiline-file-a multiline-file-a
tests:not tests:assert-no-diff multiline-file-a multiline-file-b
EOF

ensure tests.sh -d testcases -A

assert-stdout "1 tests (2 assertions) done successfully!"
