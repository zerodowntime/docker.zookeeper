#!/bin/bash
REPLY=$(echo ruok | nc localhost 2181)

if [ "$REPLY" == "imok" ]; then
    exit 0
else
    exit 1
fi
