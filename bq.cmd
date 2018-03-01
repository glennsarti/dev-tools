@ECHO OFF

ECHO Keeping existing bundle...

del Gemfile.lock
if [%1]==[] (
  CALL bundle install --path .bundle\windows --without system_tests %*
) ELSE (
  CALL bundle install --path .bundle\windows %*
)
