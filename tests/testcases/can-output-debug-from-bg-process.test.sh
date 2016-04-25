put testcases/output-debug-from-bg.test.sh <<EOF
id=\$(tests:run-background tests:debug "hello")
EOF


ensure tests.sh -d testcases -Avvv

assert-stderr-re '^\s+# /tmp/[^/]+: hello'
