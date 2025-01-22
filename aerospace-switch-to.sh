#!/bin/bash

focused_window=$(aerospace list-windows --focused | tail -n 1 | awk '{print $1}')
found_window=$(aerospace list-windows --all | grep -v $focused_window | grep -E "$1" | tail -n 1 | awk '{print $1}')

aerospace focus --window-id $found_window
