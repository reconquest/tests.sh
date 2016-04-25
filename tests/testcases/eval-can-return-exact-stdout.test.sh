put testcases/return-stdout.test.sh <<EOF
lines=\$(tests:pipe echo meep | wc -l)
tests:assert-equals \$lines 1
EOF


ensure tests.sh -d testcases -A

assert-stdout '1 tests (1 assertions) done successfully!'
