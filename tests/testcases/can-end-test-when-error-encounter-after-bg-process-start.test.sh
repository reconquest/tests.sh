put testcases/error.test.sh <<EOF
tests:run-background id "watch -n1 : >/dev/null 2>&1"

some_func() {
    blah?
}

tests:value xxx some_func
EOF

tests:runtime tests.sh -d testcases -Avvvvv

assert-stderr-re 'blah.*command not found'
