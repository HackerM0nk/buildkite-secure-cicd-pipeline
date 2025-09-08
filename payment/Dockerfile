# syntax=docker/dockerfile:1.6
ARG GO_VERSION=1.22
ARG ALPINE_VERSION=3.19

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS builder
WORKDIR /src
RUN apk add --no-cache git ca-certificates && update-ca-certificates
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG TARGETOS TARGETARCH
ENV CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH
RUN go build -trimpath -ldflags="-s -w" -o /out/app ./cmd

FROM gcr.io/distroless/static:nonroot
WORKDIR /app
COPY --from=builder /out/app /app/app
EXPOSE 8081
USER 65532:65532
ENTRYPOINT ["/app/app"]
