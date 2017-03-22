@ECHO OFF

IF [%1]==[] (
  ECHO FetchUpstream requires a branch name
  EXIT /B 1
)

SETLOCAL

SET BRANCH=%1

CALL git checkout %BRANCH%

CALL git fetch upstream --prune

CALL git pull upstream %BRANCH% --ff-only

SET /P DoPush=Push to origin (Y/N)? :

IF [%DoPush%] == [y] ( GOTO DoPush)
IF [%DoPush%] == [Y] ( GOTO DoPush)

Exit /B 0

:DoPush

CALL git push origin %BRANCH%
