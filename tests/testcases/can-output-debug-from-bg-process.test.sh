put testcases/output-debug-from-bg.test.sh <<EOF
tests:run-background id -- tests:pipe 'tests:debug "hello"'

tests:assert-success false
EOF

not ensure tests.sh -d testcases -Avvvvv

assert-stderr-re '^.*#.*\(bg debug\).*\[BG\].*pid:\<\d+\>.*#\w+: hello'
