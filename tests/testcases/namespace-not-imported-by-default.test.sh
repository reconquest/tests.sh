put testcases/strings-equals.test.sh <<EOF
assert-equals "1" "1"
EOF

eval tests.sh -d testcases -A

assert-fail
assert-stderr "assert-equals: command not found"
