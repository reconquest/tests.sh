put testcases/output-debug-from-bg.test.sh <<EOF
tests:run-background id tests:pipe 'tests:debug "hello"'

tests:ensure true
EOF

ensure tests.sh -d testcases -Avvv

assert-stderr '# hello'
