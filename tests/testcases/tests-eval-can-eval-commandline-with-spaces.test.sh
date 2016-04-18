put testcases/arguments-count.test.sh <<EOF
tests:ensure wc -c '<<<' '1  2  3'
tests:assert-stdout 8
EOF

put testcases/command-not-found.test.sh <<EOF
tests:ensure 'echo 1 2 3'
tests:assert-stdout '1 2 3'
EOF

ensure tests.sh -d testcases -A

assert-stdout "2 tests (4 assertions) done successfully!"
