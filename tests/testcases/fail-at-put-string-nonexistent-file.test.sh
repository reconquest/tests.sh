put testcases/put-contents.test.sh <<EOF
tests:put-string a/b/c/d/blah "hello"
EOF

not ensure tests.sh -vvd testcases -A
