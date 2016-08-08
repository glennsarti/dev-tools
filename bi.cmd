@ECHO OFF

RD .bundle\windows /s/q
del Gemfile.lock
bundle install --path .bundle\windows --without system_tests %*