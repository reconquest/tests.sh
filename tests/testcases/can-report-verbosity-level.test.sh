put testcases/report-verbosity-level.test.sh <<EOF
tests:set-verbose 4
tests:get-verbose
EOF


ensure tests.sh -d testcases -vA

assert-stderr '4'
