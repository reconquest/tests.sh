put testcases/assert-files-are-same-via-cat.test.sh <<EOF
tests:put multiline-file-a <<EOF2
1
2
3
EOF2

tests:put multiline-file-b <<EOF2
1
3
EOF2

tests:assert-no-diff multiline-file-a multiline-file-b
EOF

not ensure tests.sh -d testcases -A

put expected.diff <<EOF
@@ -1,3 +1,2 @@
 1
-2
 3
EOF

sed -ne '/no diff/,+9 { /@@/,$ { s/(diff) //; p } }' \
        $(tests:get-stderr-file) \
    | tests:remove-colors | put actual.diff

assert-no-diff actual.diff expected.diff "-w"
