put testcases/output-debug-from-bg.test.sh <<EOF
file=\$(tests:get-tmp-dir)/done

tests:eval touch \$file

echo_bg_pid() {
    tests:run-background id -- "
        bash -c '
            bash -c \"
                echo before >> /tmp/debug
                echo MYPID:\\\\$\\\\$
                echo after >> /tmp/debug
                touch \$file
                sleep 10
                echo hello there\?
            \"
        '
    "
}

tests:wait-file-changes \$file 0.01 10 echo_bg_pid
EOF

runtime tests.sh -d testcases -Avvvv

assert-success

pid=$({ grep -oP 'MYPID:\d+' | grep -oP '\d+' | head -n1 ; } < $(tests:get-stderr-file))

not ensure pgrep -P $pid
