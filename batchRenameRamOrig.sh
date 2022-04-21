#!/bin/bash

for fl in *ram_orig; do
    mv "$fl" "${fl%_orig}"
    echo "${fl%_orig}"
done
