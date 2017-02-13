# docker build --pull -t sonarqube:6.2 -t sonarqube .
FROM centos:centos7
MAINTAINER John Deng (john.deng@outlook.com)

ENV SONAR_VERSION=6.2 \
    SONAR_USER=sonar \
    LANG=en_US.utf8 \
    JAVA_HOME=/usr/lib/jvm/jre \
    # Database configuration
    # Defaults to using H2
    SONARQUBE_JDBC_USERNAME=sonar \
    SONARQUBE_JDBC_PASSWORD=sonar \
    SONARQUBE_JDBC_URL=

LABEL name="sonarqube" \
      vendor="SonarSource" \
      version="${SONAR_VERSION}" \
      release="1" \
      summary="SonarQube" \
      description="SonarQube" \
      run='docker run -di \
            --name ${NAME} \
            -p 9000:9000 \
            $IMAGE' \
      io.k8s.description="SonarQube" \
      io.k8s.display-name="SonarQube" \
      io.openshift.build.commit.author="John Deng (john.deng@outlook.com)" \
      io.openshift.expose-services="9000:9000" \
      io.openshift.tags="sonarqube,sonar,sonarsource"

COPY help.md /tmp/

RUN yum -y install wget
RUN yum -y install epel-release

RUN yum -y update-minimal --security --sec-severity=Important --sec-severity=Critical --setopt=tsflags=nodocs && \
    yum -y install --setopt=tsflags=nodocs golang-github-cpuguy83-go-md2man java-1.8.0-openjdk unzip && \
    go-md2man -in /tmp/help.md -out /help.1 && yum -y remove golang-github-cpuguy83-go-md2man && \
    yum clean all

ENV APP_ROOT=/opt/${SONAR_USER} \
    USER_UID=10001
ENV SONARQUBE_HOME=${APP_ROOT}/sonarqube
ENV PATH=$PATH:${SONARQUBE_HOME}/bin
RUN mkdir -p ${APP_ROOT} && \
    useradd -l -u ${USER_UID} -r -g 0 -m -s /sbin/nologin \
            -c "${SONAR_USER} application user" ${SONAR_USER}

WORKDIR ${APP_ROOT}
RUN set -x \
    # pub   2048R/D26468DE 2015-05-25
    #       Key fingerprint = F118 2E81 C792 9289 21DB  CAB4 CFCA 4A29 D264 68DE
    # uid                  sonarsource_deployer (Sonarsource Deployer) <infra@sonarsource.com>
    # sub   2048R/06855C1D 2015-05-25
    gpg --gen-key && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys F1182E81C792928921DBCAB4CFCA4A29D26468DE && \
    curl -o sonarqube.zip -SL https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip \
                --retry 9 --retry-max-time 0 -C - && \
    curl -o sonarqube.zip.asc -SL https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip.asc \
                --retry 9 --retry-max-time 0 -C - && \
    gpg --batch --verify sonarqube.zip.asc sonarqube.zip && \
    unzip sonarqube.zip && \
    mv sonarqube-${SONAR_VERSION} sonarqube && \
    rm sonarqube.zip* && \
    rm -rf ${SONARQUBE_HOME}/bin/*  

COPY run.sh ${SONARQUBE_HOME}/bin/
RUN chown -R ${USER_UID}:0 ${APP_ROOT} && \
    chmod -R g+rw ${APP_ROOT} && \
    find ${APP_ROOT} -type d -exec chmod g+x {} + && \
    chmod ug+x ${SONARQUBE_HOME}/bin/run.sh

RUN wget "http://downloads.sonarsource.com/plugins/org/codehaus/sonar-plugins/sonar-scm-git-plugin/1.1/sonar-scm-git-plugin-1.1.jar" \
    && wget "https://github.com/SonarSource/sonar-java/releases/download/3.12-RC2/sonar-java-plugin-3.12-build4634.jar" \
    && wget "https://github.com/SonarSource/sonar-github/releases/download/1.1-M9/sonar-github-plugin-1.1-SNAPSHOT.jar" \
    && wget "https://github.com/SonarSource/sonar-auth-github/releases/download/1.0-RC1/sonar-auth-github-plugin-1.0-SNAPSHOT.jar" \
    && wget "https://github.com/QualInsight/qualinsight-plugins-sonarqube-badges/releases/download/qualinsight-plugins-sonarqube-badges-1.2.1/qualinsight-sonarqube-badges-1.2.1.jar" \
    && mv *.jar ${SONARQUBE_HOME}/extensions/plugins \
    && ls -lah ${SONARQUBE_HOME}/extensions/plugins

USER ${USER_UID}
WORKDIR ${SONARQUBE_HOME}

# Http port
EXPOSE 9000
VOLUME ["${SONARQUBE_HOME}/data", "${SONARQUBE_HOME}/extensions"]
ENTRYPOINT run.sh
