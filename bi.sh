#!/bin/bash

rm -rf .bundle/bash
rm .bundle/config
rm Gemfile.lock

if [ -z $1 ]; then
  bundle install --path .bundle/bash --with system_tests "$@"
else
  bundle install --path .bundle/bash "$@"
fi
