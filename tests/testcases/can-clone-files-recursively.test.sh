make-tmp-dir some-dir

put some-dir/ctulhu <<EOF
:3
EOF

put testcases/can-clone-recursively.test.sh <<EOF
tests:clone -r some-dir void

tests:assert-test -e void/ctulhu
EOF

ensure tests.sh -d testcases -A

assert-stdout '1 tests (1 assertions) done successfully!'
