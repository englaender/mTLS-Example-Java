# syntax=docker/dockerfile:1
# this file uses the latest release of the version 1 syntax

# a somewhat slim version of the offical openjdk images for java 11 
FROM openjdk:11-jre-slim

WORKDIR /

COPY /target/mtls-server-0.0.1.jar mtls-server-0.0.1.jar
COPY server_keystore.jks ./src/main/resources/server_keystore.jks
COPY ../certificates/build/ca.pem ca.pem

# add ca cert to jvm truststore
RUN keytool -cacerts -importcert -trustcacerts -file ca.pem -alias ca -storepass changeit -noprompt

EXPOSE 8000

# execute jdk using the run wrapper which setsenv variabels from .env
CMD ["java", "-jar", "mtls-server-0.0.1.jar"]
