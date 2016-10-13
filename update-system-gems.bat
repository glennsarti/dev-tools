@ECHO OFF

ECHO Updating system gems (via HTTP)

ECHO Using http for gem sources ...
call gem sources -r https://rubygems.org/
call gem sources -a http://rubygems.org/

ECHO Updating...
call gem update --system

ECHO Restoring gem sources...
call gem sources -r http://rubygems.org/
call gem sources -a https://rubygems.org/
