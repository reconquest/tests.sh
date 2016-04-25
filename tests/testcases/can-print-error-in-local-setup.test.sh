put testcases/print-error-in-local-setup.test.sh <<EOF
tests:eval echo meep
EOF

put testcases/local.setup.sh <<EOF
WTF
EOF

not ensure tests.sh -vvd testcases -A -s testcases/local.setup.sh

assert-stderr '{ERROR} in ./local.setup.sh'
assert-stderr 'WTF: command not found'
