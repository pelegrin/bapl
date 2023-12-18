#!/usr/bin/env bash

EXIT_CODE=0
for sut in $(find . -iregex ".*\(test_.*\).lua"); do
    echo "Running tests in ${sut}" 
    sut_dir=$(dirname ${sut}) 
    sut_file=$(basename ${sut})
    sut_index=$(echo $sut_file | grep -o "[0-9]\+")
    LUA_PATH="${sut_dir}/?.lua;;" lua ${sut}
    if [ $? -ne 0 ]; then
        EXIT_CODE=1
    fi
done

exit $EXIT_CODE
