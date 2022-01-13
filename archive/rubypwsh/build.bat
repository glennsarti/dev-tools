@ECHO OFF

docker rmi glenn-pwshruby:2.5

docker build --tag glenn-pwshruby:2.5 %~dp0
