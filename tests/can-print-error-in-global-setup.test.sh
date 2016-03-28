put testcases/print-error-in-global-setup.test.sh <<EOF
tests:eval echo meep
EOF

put testcases/global.setup.sh <<EOF
WTF
EOF

not ensure tests.sh -vvd testcases -A

assert-stdout '{ERROR} in ./global.setup.sh'
assert-stdout 'WTF: command not found'
