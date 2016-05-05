put testcases/show-stdin-in-eval.test.sh <<EOF
tests:eval cat -n <<CAT
hello
from
cat
CAT
EOF

ensure tests.sh -vvvv -d testcases -A

sed -nre '/\(stdin\) evaluating command/,+18 { s/(stdout) //; p }' \
    $(tests:get-stderr-file) \
        | put actual.output

put expected.output <<EOF
# (stdin) evaluating command:

    ($) cat -n

    (eval) "cat" "-n"

    (stdin) hello
    (stdin) from
    (stdin) cat

# evaluation stdout:

    (stdout)      1  hello
    (stdout)      2  from
    (stdout)      3  cat

# evaluation stderr:

    <empty>
EOF

assert-no-diff actual.output expected.output "-w"
