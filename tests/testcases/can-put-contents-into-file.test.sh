put testcases/put-contents.test.sh <<EOF
tests:put multiline-file <<EOF2
1
2
3
EOF2

tests:put-string singleline-file "single line"

tests:eval wc -l multiline-file
tests:assert-stdout "3 multiline-file"

tests:eval wc -l singleline-file
tests:assert-stdout "1 singleline-file"
EOF

ensure tests.sh -d testcases -A
