#!/bin/bash

${BASH:-bash} -c 'echo bash version: $BASH_VERSION'
${BASH:-bash} tests.sh -d tests -s tests/local.setup.sh -d tests/testcases "${@:--A}"
