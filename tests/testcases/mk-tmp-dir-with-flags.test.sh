put testcases/mkdir-with-flags.test.sh <<EOF
tests:make-tmp-dir a
tests:make-tmp-dir -p a/b/c

tests:assert-test -d a/b/c
EOF


ensure tests.sh -d testcases -A

assert-stdout '1 tests (1 assertions) done successfully!'
