FROM drecom/ubuntu-ruby:2.5.0
# Based on Ubuntu 16.04

RUN apt-get update \
    && apt-get install wget apt-transport-https -y \
    && wget -q https://packages.microsoft.com/config/ubuntu/16.04/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y powershell \
    && apt-get install -y powershell

CMD [ "irb" ]
