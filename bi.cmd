@ECHO OFF

RD .bundle\windows /s/q
DEL .bundle\config /q /f
del Gemfile.lock

if [%1]==[] (
  CALL bundle install --path .bundle\windows --without system_tests %*
) ELSE (
  CALL bundle install --path .bundle\windows %*
)
