#!/bin/bash

while inotifywait -q -e modify . ; do
	clear && clear
	luajit parser.lua
done
