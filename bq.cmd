@ECHO OFF

ECHO Keeping existing bundle...

del Gemfile.lock
bundle install --path .bundle\windows --without system_tests %*