#!/bin/bash


GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'


pass() {
    echo -e "${GREEN}PASS${NC}: $1"
}


fail() {
    echo -e "${RED}FAIL${NC}: $1"
}


assert eq() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    if [ "$expected" == "$actual" ]; then
        pass "$msg"
    else
        fail "$msg (expected: '$expected', actual: '$actual')"
    fi
}