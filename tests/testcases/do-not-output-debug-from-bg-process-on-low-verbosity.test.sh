put testcases/output-debug-from-bg.test.sh <<EOF
tests:run-background id -- tests:pipe 'tests:debug "hello"'

tests:assert-success true
EOF

not ensure tests.sh -d testcases -Avvv

not assert-stderr-re '^\s*# /tmp/[^/]+:.*\[BG\].*pid:\<\d+\>.*#\w+: hello'
