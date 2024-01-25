FROM alpine:3.19
RUN apk add --no-cache bash tar vim lua5.3 lua-lpeg luarocks lua-unit
RUN ln -s /usr/bin/lua5.3 /usr/bin/lua
COPY lazarus-package.tar.gz /tmp/
COPY lazarus-examples.tar.gz /tmp/
RUN tar -zxvf /tmp/lazarus-package.tar.gz -C /usr/local/bin
RUN tar -zxvf /tmp/lazarus-examples.tar.gz -C /
RUN rm -f /tmp/lazarus-package.tar.gz; rm -f /tmp/lazarus-examples.tar.gz
ENV LUA_PATH="/usr/local/bin/?.lua;;"
WORKDIR /examples
ENTRYPOINT ["lazarus", "-i", "-v"]
