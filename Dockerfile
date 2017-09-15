FROM alpine:3.6

MAINTAINER William Tran <chitran.whitecat@gmail.com>

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT=2017-09-14 \
    LANG=en_US.UTF-8 \
    HOME=/opt/app \
    # Set this so that CTRL+G works properly
    TERM=xterm \
    ERLANG_VERSION=19.3.4 \
    VERSION=v6.11.3 \
    NPM_VERSION=3 \
    YARN_VERSION=latest

RUN apk add --no-cache curl make gcc g++ python linux-headers binutils-gold gnupg libstdc++ && \
  gpg --keyserver ha.pool.sks-keyservers.net --recv-keys \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    56730D5401028683275BD23C23EFEFE93C4CFFFE && \
  curl -sSLO https://nodejs.org/dist/${VERSION}/node-${VERSION}.tar.xz && \
  curl -sSL https://nodejs.org/dist/${VERSION}/SHASUMS256.txt.asc | gpg --batch --decrypt | \
    grep " node-${VERSION}.tar.xz\$" | sha256sum -c | grep . && \
  tar -xf node-${VERSION}.tar.xz && \
  cd node-${VERSION} && \
  ./configure --prefix=/usr ${CONFIG_FLAGS} && \
  make -j$(getconf _NPROCESSORS_ONLN) && \
  make install && \
  cd / && \
  if [ -z "$CONFIG_FLAGS" ]; then \
    npm install -g npm@${NPM_VERSION} && \
    find /usr/lib/node_modules/npm -name test -o -name .bin -type d | xargs rm -rf && \
    if [ -n "$YARN_VERSION" ]; then \
      gpg --keyserver ha.pool.sks-keyservers.net --recv-keys \
        6A010C5166006599AA17F08146C2130DFD2497F5 && \
      curl -sSL -O https://yarnpkg.com/${YARN_VERSION}.tar.gz -O https://yarnpkg.com/${YARN_VERSION}.tar.gz.asc && \
      gpg --batch --verify ${YARN_VERSION}.tar.gz.asc ${YARN_VERSION}.tar.gz && \
      mkdir /usr/local/share/yarn && \
      tar -xf ${YARN_VERSION}.tar.gz -C /usr/local/share/yarn --strip 1 && \
      ln -s /usr/local/share/yarn/bin/yarn /usr/local/bin/ && \
      ln -s /usr/local/share/yarn/bin/yarnpkg /usr/local/bin/ && \
      rm ${YARN_VERSION}.tar.gz*; \
    fi; \
  fi && \
  apk del curl make gcc g++ python linux-headers binutils-gold gnupg ${DEL_PKGS} && \
  rm -rf ${RM_DIRS} /node-${VERSION}* /usr/share/man /tmp/* /var/cache/apk/* \
    /root/.npm /root/.node-gyp /root/.gnupg /usr/lib/node_modules/npm/man \
    /usr/lib/node_modules/npm/doc /usr/lib/node_modules/npm/html /usr/lib/node_modules/npm/scripts

    WORKDIR /tmp/erlang-build

    # Install Erlang
    RUN \
        # Create default user and home directory, set owner to default
        mkdir -p ${HOME} && \
        adduser -s /bin/sh -u 1001 -G root -h ${HOME} -S -D default && \
        chown -R 1001:0 ${HOME} && \
        # Add edge repos tagged so that we can selectively install edge packages
        echo "@edge http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
        # Upgrade Alpine and base packages
        apk --no-cache upgrade && \
        # Install Erlang/OTP deps
        apk add --no-cache pcre@edge && \
        apk add --no-cache \
          ca-certificates \
          openssl-dev \
          ncurses-dev \
          unixodbc-dev \
          zlib-dev && \
        # Install Erlang/OTP build deps
        apk add --no-cache --virtual .erlang-build \
          git autoconf build-base perl-dev && \
        # Shallow clone Erlang/OTP
        git clone -b OTP-$ERLANG_VERSION --single-branch --depth 1 https://github.com/erlang/otp.git . && \
        # Erlang/OTP build env
        export ERL_TOP=/tmp/erlang-build && \
        export PATH=$ERL_TOP/bin:$PATH && \
        export CPPFlAGS="-D_BSD_SOURCE $CPPFLAGS" && \
        # Configure
        ./otp_build autoconf && \
        ./configure --prefix=/usr \
          --sysconfdir=/etc \
          --mandir=/usr/share/man \
          --infodir=/usr/share/info \
          --without-javac \
          --without-wx \
          --without-debugger \
          --without-observer \
          --without-jinterface \
          --without-cosEvent\
          --without-cosEventDomain \
          --without-cosFileTransfer \
          --without-cosNotification \
          --without-cosProperty \
          --without-cosTime \
          --without-cosTransactions \
          --without-dialyzer \
          --without-et \
          --without-gs \
          --without-ic \
          --without-megaco \
          --without-orber \
          --without-percept \
          --without-typer \
          --enable-threads \
          --enable-shared-zlib \
          --enable-ssl=dynamic-ssl-lib \
          --enable-hipe && \
        # Build
        make -j4 && make install && \
        # Cleanup
        apk del --force .erlang-build && \
        cd $HOME && \
        rm -rf /tmp/erlang-build && \
        # Update ca certificates
        update-ca-certificates --fresh

WORKDIR ${HOME}

CMD ["/bin/sh"]
