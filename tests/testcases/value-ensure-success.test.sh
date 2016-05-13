put testcases/ensure-success.test.sh <<EOF
tests:value problem exit 3
EOF

not ensure tests.sh -d testcases -A
