#/bin/bash

tar -czvf lazarus-examples.tar.gz examples
tar -czvf lazarus-package.tar.gz -C package .
docker build -t pelegrin/lazarus --no-cache .
