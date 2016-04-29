put testcases/assert-there-is-diff-in-echo.test.sh <<EOF
tests:eval echo -e '1\n2'

tests:assert-no-diff "$(echo -e '1\n3')" stdout
EOF


not ensure tests.sh -d testcases -A

put expected.diff <<EOF
@@ -1,2 +1,2 @@
 1
-3
+2
EOF

sed -ne '/no diff/,+9 { /@@/,$ { s/(diff) //; p } }' \
    $(tests:get-stderr-file) \
        | put actual.diff

assert-no-diff actual.diff expected.diff "-w"
