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

eval tests.sh -d testcases -A

assert-fail

put expected.diff <<EOF
@@ -1,3 +1,2 @@
 1
-2
 3
EOF

sed -rne '/no diff/,+8 { /@@/,$ p }' $(tests:get-stdout-file) | put actual.diff
assert-no-diff actual.diff expected.diff "-w"
