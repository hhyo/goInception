FROM golang:1.12-alpine as builder

ENV TZ=Asia/Shanghai
ENV LANG="en_US.UTF-8"

RUN apk add --no-cache \
    wget \
    make \
    git \
    gcc \
    musl-dev

RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64 \
 && chmod +x /usr/local/bin/dumb-init


RUN git clone https://github.com/hhyo/goInception.git \
    && cd goInception \
    && rm -f go.sum \
    && make parser \
    && go build -o bin/goInception tidb-server/main.go \
    && cp bin/goInception /goInception \
    && cp dockersrc/pt-online-schema-change /tmp/pt-online-schema-change \
    && cp config/config.toml.default /etc/config.toml \
    && cd ../ && rm -rf goInception

# Executable image
FROM alpine

COPY --from=builder /goInception /goInception
COPY --from=builder /etc/config.toml /etc/config.toml
COPY --from=builder /usr/local/bin/dumb-init /usr/local/bin/dumb-init
COPY --from=builder /tmp/pt-online-schema-change /usr/local/bin/pt-online-schema-change

WORKDIR /

EXPOSE 4000

RUN set -x \
  && apk add --no-cache perl perl-dbi perl-dbd-mysql perl-io-socket-ssl perl-term-readkey tzdata \
  && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
  && chmod +x /usr/local/bin/pt-online-schema-change

ENTRYPOINT ["/usr/local/bin/dumb-init", "/goInception","--config=/etc/config.toml"]
