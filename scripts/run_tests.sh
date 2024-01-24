#!/usr/bin/env bash

EXIT_CODE=0
for sut in $(find . -iregex ".*\(test_.*\).lua"); do
    sut_dir=$(dirname ${sut}) 
    sut_file=$(basename ${sut})
    echo "Running tests in ${sut_dir}"
    echo "${sut}" 
    cd ${sut_dir}
    LUA_PATH="${sut_dir}/?.lua;;" lua ${sut_file}
    cd ..
    if [ $? -ne 0 ]; then
        EXIT_CODE=1
    fi
done

exit $EXIT_CODE
