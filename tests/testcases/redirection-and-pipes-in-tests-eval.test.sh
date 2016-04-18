put testcases/arguments.test.sh <<EOF
tests:ensure 'echo 1 > file'
tests:assert-stdout ''
tests:assert-stderr ''
tests:match-re 'file' '1'

tests:ensure echo '1 > 2'
tests:assert-stdout '1 > 2'

tests:ensure echo 1 '> 2'
tests:assert-stdout '1 > 2'

tests:ensure echo 1 '>2'
tests:assert-stdout '1 >2'

tests:ensure echo 1 \>2
tests:assert-stdout '1 >2'

tests:ensure echo 1 \>2
tests:assert-stdout '1 >2'
tests:match-re '2' '1'

tests:ensure echo 1 \>\&2
tests:assert-stdout ''
tests:assert-stderr '1'

tests:ensure echo 1 '>&2'
tests:assert-stdout ''
tests:assert-stderr '1'

tests:ensure echo 1 '>&' 2
tests:assert-stdout ''
tests:assert-stderr '1'

tests:ensure echo 1 \>\&varname
tests:assert-stdout '1 >&varname'
tests:assert-stderr ''

tests:ensure echo 1 \>filename
tests:assert-stdout '1 >filename'
tests:assert-stderr ''

tests:ensure echo 1 \> \&2
tests:assert-stdout ''
tests:assert-stderr ''
tests:match-re '&2' '1'

tests:ensure echo 1 \> \&3
tests:assert-stdout ''
tests:assert-stderr ''
tests:match-re '&3' '1'
EOF

ensure tests.sh -d testcases -A

assert-stdout "1 tests (34 assertions) done successfully!"
