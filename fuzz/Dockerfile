FROM golang:alpine AS builder

RUN apk update && apk add --no-cache git cmake make g++ build-base gcc wget bash python linux-headers curl

WORKDIR /usercorn
RUN git clone https://github.com/lunixbochs/usercorn.git && \
  ( cd usercorn && \
  make deps && \
  make)
COPY . .
