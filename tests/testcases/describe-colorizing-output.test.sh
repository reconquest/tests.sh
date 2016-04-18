put testcases/check-color-output.test.sh <<EOF
tests:describe "XXX"
EOF

eval tests.sh -vd testcases -A

assert-stdout-re '@@\s+\e\[7;49;34.*XXX'
