#!/usr/bin/env bash

EXIT_CODE=0
for sut in $(find . -iregex ".*\.lz"); do
    echo "Running source file: ${sut}"
    sut_dir=$(dirname ${sut})
    if [ $sut_dir == "./examples" ]; then
        continue
    fi
    sut_file=$(basename ${sut})
    LUA_PATH="${sut_dir}/?.lua;;" ${sut_dir}/lazarus ${sut}
    if [ $? -ne 0 ]; then
        EXIT_CODE=1
    fi
done

exit $EXIT_CODE
