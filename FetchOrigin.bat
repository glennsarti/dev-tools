@ECHO OFF

IF [%1]==[] (
  ECHO FetchOrigin requires a branch name
  EXIT /B 1
)

SETLOCAL

SET BRANCH=%1

CALL git checkout %BRANCH%

CALL git fetch origin %BRANCH% --prune

CALL git pull origin %BRANCH% --ff-only

Exit /B 0
