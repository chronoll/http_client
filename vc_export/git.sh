#!/bin/bash

for num in $(seq 1 20); do
    git add "all-${num}"
    git commit -m "Add all-${num}"
    git push origin HEAD
    sleep 1
done
