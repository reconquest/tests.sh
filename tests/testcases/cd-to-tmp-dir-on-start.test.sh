put testcases/pwd-equals-tmp-dir.test.sh <<EOF
tests:assert-equals $(pwd) $(tests:get-tmp-dir)
EOF

ensure tests.sh -d testcases -A

assert-stdout "1 tests (1 assertions) done successfully!"
