put testcases/output-debug-from-bg.test.sh <<EOF
file=\$(tests:get-tmp-dir)/done

tests:eval touch \$file

run-bg() {
    tests:run-background id eval "
        tests:pipe echo \"pre sleep\"
        tests:eval touch \$file
        watch -n1 : >/dev/null 2>/dev/null
    "
}

tests:wait-file-changes \$file 0.01 10 run-bg
EOF

tests:runtime tests.sh -d testcases -Avvvvv

assert-stderr-re '\(\<\d+\> stdout\) pre sleep'
