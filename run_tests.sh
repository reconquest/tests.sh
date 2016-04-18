#!/bin/bash

bash tests.sh -d tests -s tests/local.setup.sh -d tests/testcases "${@:--A}"
