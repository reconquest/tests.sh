put testcases/output-debug-from-bg.test.sh <<EOF
tests:run-background id -- echo pre sleep \&\& while sleep 1\; do :\; done
EOF

ensure tests.sh -d testcases -Avvvv

not assert-stderr 'pre sleep'
