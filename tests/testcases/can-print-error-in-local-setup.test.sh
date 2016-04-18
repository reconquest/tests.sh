put testcases/print-error-in-local-setup.test.sh <<EOF
tests:eval echo meep
EOF

put testcases/local.setup.sh <<EOF
WTF
EOF

not ensure tests.sh -vvd testcases -A -s testcases/local.setup.sh

assert-stdout '{ERROR} in ./local.setup.sh'
assert-stdout 'WTF: command not found'
