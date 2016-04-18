put testcases/empty.test.sh <<EOF
EOF

ensure tests.sh -d testcases -A

assert-stdout "running test suite at: $(get-tmp-dir)/testcases"
