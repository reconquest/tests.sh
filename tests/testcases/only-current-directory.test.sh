put testcases/foo.test.sh <<EOF
tests:assert-equals "foo" "foo"
EOF

put testcases/barr.test.sh <<EOF
tests:assert-equals "barr" "barr"
EOF

tests:make-tmp-dir testcases/sub
put testcases/sub/dom.test.sh <<EOF
tests:assert-equals "dom" "sub"
EOF

ensure tests.sh -d testcases -A

assert-stdout '2 tests (2 assertions) done successfully!'
