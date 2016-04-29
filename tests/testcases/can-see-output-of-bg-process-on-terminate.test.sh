put testcases/output-debug-from-bg.test.sh <<EOF
file=\$(tests:get-tmp-dir)/done

tests:eval touch \$file

run-bg() {
    tests:run-background id -- "
        tests:pipe echo \"pre sleep\"
        tests:eval touch \$file
        while sleep 10; do :; done
    "
}

tests:wait-file-changes \$file 0.01 10 run-bg
EOF

tests:runtime tests.sh -d testcases -Avvvvv

assert-stderr '(bg stdout) pre sleep'
assert-stderr '(stdout) pre sleep'

tests:runtime tests.sh -d testcases -Avvvv

not assert-stderr '(bg stdout) pre sleep'
assert-stderr '(stdout) pre sleep'
