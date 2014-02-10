#!/usr/bin/env bash
echo "starting build and test of WeblogNG Javascript client"
grunt clean default karma:continuous
grunt_exit_status=$?
echo "grunt exit status: ${grunt_exit_status}"
echo "finished build and test of WeblogNG Javascript client"
exit ${grunt_exit_status}
