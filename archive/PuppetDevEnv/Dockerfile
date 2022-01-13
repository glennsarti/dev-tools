FROM microsoft/windowsservercore

MAINTAINER glennsarti

LABEL Description="Puppet Dev Environment" Version="1.0.0"

#ENTRYPOINT ["powershell.exe","C:/neo4j/docker-entrypoint.ps1"]
#CMD ["neo4j"]

COPY tools C:/tools

RUN powershell C:/tools/docker_file-build.ps1
