put testcases/foo.test.sh <<EOF
tests:assert-equals "foo" "foo"
EOF

put testcases/barr.test.sh <<EOF
tests:assert-equals "barr" "barr"
EOF

tests:make-tmp-dir testcases/sub

put testcases/sub/sub.test.sh <<EOF
tests:assert-equals "sub" "sub"
EOF

tests:make-tmp-dir testcases/dom

put testcases/dom/dom.test.sh <<EOF
tests:assert-equals "dom" "dom"
EOF

ensure tests.sh -d testcases -A -s

assert-stdout '4 tests (4 assertions) done successfully!'
