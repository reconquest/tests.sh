put testcases/assert-there-is-diff-in-echo.test.sh <<EOF
tests:eval echo -e '1\n2'

tests:assert-no-diff "$(echo -e '1\n3')" stdout
EOF


eval tests.sh -d testcases -A

assert-fail

put expected.diff <<EOF
@@ -1,2 +1,2 @@
 1
-3
+2
EOF

sed -rne '/no diff/,+8 { /@@/,$ p }' $(tests:get-stdout-file) | put actual.diff

assert-no-diff actual.diff expected.diff "-w"
