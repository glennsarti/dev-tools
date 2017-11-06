#!/bin/bash

rm -rf .bundle/bash
rm .bundle/config
rm Gemfile.lock

bundle install --path .bundle/bash --with system_tests  "$@"
