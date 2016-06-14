put testcases/stdout-will-match-and-stderr-will-not-match-pattern.test.sh <<EOF
tests:put bin/my-command <<COMMAND
while true; do
    sleep 1s
    echo OK
done
COMMAND

tests:ensure chmod +x bin/my-command

tests:run-background command_id my-command
stdout=\$(tests:get-background-stdout \$command_id)
stderr=\$(tests:get-background-stderr \$command_id)

tests:wait-file-matches "\$stdout" "OK" 1 2
tests:assert-success

tests:wait-file-not-matches "\$stderr" "Error" 1 2
tests:assert-success
EOF

put testcases/stdout-will-not-match-and-stderr-will-match-pattern.test.sh <<EOF
tests:put bin/my-command <<COMMAND
while true; do
    sleep 1s
    echo KO
    echo Error 1>&2
done
COMMAND

tests:ensure chmod +x bin/my-command

tests:run-background command_id my-command
stdout=\$(tests:get-background-stdout \$command_id)
stderr=\$(tests:get-background-stderr \$command_id)

tests:wait-file-not-matches "\$stdout" "OK" 1 2
tests:assert-success

tests:wait-file-matches "\$stderr" "Error" 1 2
tests:assert-success
EOF

ensure tests.sh -d testcases -A

assert-stdout "2 tests (6 assertions) done successfully!"
