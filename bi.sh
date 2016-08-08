#!/bin/bash

rm -rf .bundle/bash
rm Gemfile.lock

bundle install --path .bundle/bash