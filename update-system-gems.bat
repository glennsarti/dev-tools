@ECHO OFF

ECHO Updating system gems (via HTTP)
gem sources -r https://rubygems.org/
gem sources -a http://rubygems.org/
gem update --system
gem sources -r http://rubygems.org/
gem sources -a https://rubygems.org/
