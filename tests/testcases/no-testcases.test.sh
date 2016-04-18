mkdir empty

eval tests.sh -d empty -A

assert-fail
assert-stdout 'no testcases found'
