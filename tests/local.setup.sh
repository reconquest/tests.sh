tests:import-namespace

make-tmp-dir vendor/

clone tests.sh bin/
clone -r vendor/ bin/vendor/

make-tmp-dir testcases
