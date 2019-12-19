FROM golang:1.9.7-stretch AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
      && mkdir -p /usr/share/man/man1 \
      && apt-get install -y \
      build-essential bash \
      git cmake wget python \
      locales sudo openssh-client ca-certificates tar gzip parallel \
      net-tools netcat unzip zip bzip2 gnupg curl

# Set timezone to UTC by default
RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Use unicode
RUN locale-gen C.UTF-8 || true
ENV LANG=C.UTF-8

WORKDIR /usercorn
RUN git clone https://github.com/lunixbochs/usercorn.git && \
      ( cd usercorn && \
      make deps && \
      make)
COPY . .

CMD [ "usercorn/usercorn" ]
