put testcases/strings-equals.test.sh <<EOF
assert-equals "1" "1"
EOF

eval tests.sh -d testcases -A

asssert-fail
assert-stdout "assert-equals: command not found"
