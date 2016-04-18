put testcases/put-contents.test.sh <<EOF
tests:put a/b/c/d/blah <<EOF2
1
2
3
EOF2
EOF

not ensure tests.sh -d testcases -A
