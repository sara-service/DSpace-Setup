FROM ubuntu:18.04
MAINTAINER Stefan Kombrink "stefan.kombrink@uni-ulm.de"

# upgrades
RUN apt-get update && apt-get -y upgrade && apt-get clean && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

# set locale
RUN apt-get update && apt-get -y install locales && locale-gen en_US.UTF-8 de_DE.UTF-8 && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

# set timezone
RUN echo "Europe/Berlin" > /etc/timezone && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install tzdata && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

# postgres
RUN apt-get update && apt-get -y install git locales postgresql postgresql-contrib && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

# JDK
RUN apt-get update && apt-mark hold openjdk-11-jre-headless && \
    apt-get -y install python openjdk-8-jdk maven ant postgresql postgresql-contrib curl wget && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

# DSpace user/group
RUN groupadd dspace && useradd -m -g dspace dspace

# tomcat
RUN wget http://archive.apache.org/dist/tomcat/tomcat-8/v8.5.32/bin/apache-tomcat-8.5.32.tar.gz -O /tmp/tomcat.tgz && \
    mkdir /opt/tomcat && \
    tar xzvf /tmp/tomcat.tgz -C /opt/tomcat --strip-components=1 && \
    chown -R dspace.dspace /opt/tomcat

COPY config/tomcat/tomcat.service /etc/systemd/system/tomcat.service
COPY config/tomcat/server.xml /opt/tomcat/conf/server.xml

