@ECHO OFF

SETLOCAL

SET /P OWNER=Enter project owner (default - puppetlabs):
SET /P PROJECT=Enter project name (e.g. puppet):
SET /P BRANCH=Enter branch name (default - master):
SET /P PRNUM=Enter PR number (e.g. 12345):

if [%OWNER%] == [] (
  SET BRANCH=puppetlabs
)
if [%BRANCH%] == [] (
  SET BRANCH=master
)

SET REPO=%cd%\%PROJECT%-pr%PRNUM%

ECHO Cleaning...
RD /S /Q "%REPO%" > NUL

ECHO Cloning..
git clone https://github.com/%OWNER%/%PROJECT%.git "%REPO%"

PUSHD "%REPO%"

ECHO Fetching PR...
git fetch origin refs/pull/%PRNUM%/head:pr_%PRNUM%

ECHO Changing to intended branch...
git checkout %BRANCH%

ECHO Merging PR...
git merge pr_%PRNUM% --no-ff

POPD
