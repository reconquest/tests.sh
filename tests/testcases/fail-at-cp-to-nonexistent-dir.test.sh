put testcases/put-contents.test.sh <<EOF
tests:cp -r . a/b/c/d/blah
EOF

not ensure tests.sh -d testcases -A
assert-stdout 'cp: command not found'
