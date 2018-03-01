@ECHO OFF

docker run -i --tty --rm -v "%CD%:/project" -v "C:\Source\dev-tools:/tools" ruby:2.1 bash
