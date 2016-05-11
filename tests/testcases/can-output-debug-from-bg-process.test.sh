put testcases/output-debug-from-bg.test.sh <<EOF
file=\$(tests:get-tmp-dir)/done

tests:eval touch \$file

run-bg() {
    tests:run-background id tests:pipe 'tests:debug "hello" && touch \$file'
}

tests:wait-file-changes \$file 0.01 10 run-bg
EOF

not runtime tests.sh -d testcases -Avvvvv

assert-stderr-re '^.*\[BG\].*\<\d+\>.*# hello'
