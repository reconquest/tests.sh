put testcases/show-stdin-in-eval.test.sh <<EOF
tests:eval cat -n <<CAT
hello
from
cat
CAT
EOF

ensure tests.sh -vvvv -d testcases -A

put expected.output <<EOF
# $ (stdin) > cat -n

    (eval) builtin eval "cat" "-n"

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

sed -nre '/cat -n/,+16 { s/(stdout) //; s/# [^:]+:/#/; p }' \
    $(tests:get-stdout-file) \
        | put actual.output

assert-no-diff actual.output expected.output "-w"
