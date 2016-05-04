put testcases/call-debug.test.sh <<EOF
tests:debug hello from inner world
EOF


ensure tests.sh -d testcases -Avvvv
assert-stderr-re '^\s+# hello from inner world'
