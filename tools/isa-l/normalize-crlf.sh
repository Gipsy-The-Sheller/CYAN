#!/bin/sh
# Strip CR bytes in place; ISA-L's NASM macros and make targets require LF.
for f in "$@"; do
  tr -d '\r' < "$f" > "$f.lf" && mv "$f.lf" "$f"
done
