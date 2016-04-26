put source.sh <<EOF
true
EOF

put testcases/source.test.sh <<EOF
tests:involve source.sh
EOF

ensure tests.sh -d testcases -vvvA

not assert-stderr "SOURCE"
