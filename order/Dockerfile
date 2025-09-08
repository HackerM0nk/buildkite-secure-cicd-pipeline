# syntax=docker/dockerfile:1.6

ARG GO_VERSION=1.22
ARG ALPINE_VERSION=3.19

# Build stage runs on the build platform; we’ll output for TARGET{OS,ARCH}
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS builder
WORKDIR /src

# Tooling that some modules expect
RUN apk add --no-cache git ca-certificates && update-ca-certificates

# Module setup and caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest
COPY . .

# Build a static binary for the target platform
ARG TARGETOS TARGETARCH
ENV CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH
RUN go build -trimpath -ldflags="-s -w" -o /out/app ./cmd

# Minimal runtime: no shell, no apk, fewer arch pitfalls
FROM gcr.io/distroless/static:nonroot AS runtime
WORKDIR /app
COPY --from=builder /out/app /app/app

# Ports are informative; K8s will map via Service
EXPOSE 8080

USER 65532:65532
ENTRYPOINT ["/app/app"]
