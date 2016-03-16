put testcases/assert-files-are-same-except-empty.test.sh <<EOF
tests:put multiline-file-a <<EOF2
1
2
EOF2

tests:put multiline-file-b <<EOF2
1

2
EOF2

tests:assert-no-diff-blank multiline-file-a multiline-file-b
EOF

ensure tests.sh -d testcases -A

assert-stdout "1 tests (1 assertions) done successfully!"
