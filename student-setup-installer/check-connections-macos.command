#!/bin/bash
printf 'Yomitan API (127.0.0.1:19633): '
if nc -z 127.0.0.1 19633 2>/dev/null; then echo OK; else echo OFFLINE; fi
printf 'AnkiConnect (127.0.0.1:8765): '
if nc -z 127.0.0.1 8765 2>/dev/null; then echo OK; else echo OFFLINE; fi
read -r -p 'Press Return to close.'
