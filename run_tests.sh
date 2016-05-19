#!/bin/bash

./tests.sh -d tests -s tests/setup.sh -d tests/testcases "${@:--A}"
