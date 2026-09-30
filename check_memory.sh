#!/bin/bash

PID=$(pgrep daw)

cat /proc/$PID/status | grep -iE 'VmRSS|RssAnon|RssFile|RssShmem|VmSize'