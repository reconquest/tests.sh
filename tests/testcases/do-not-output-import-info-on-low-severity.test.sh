put testcases/strings-equals.test.sh <<EOF
tests:import-namespace t:
EOF

ensure tests.sh -d testcases -vvA

not assert-stderr "importing namespace 'tests:' into 't:'"
