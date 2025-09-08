# Build arguments
ARG TAG=latest
ARG GOARCH=amd64

# Build stage
FROM --platform=linux/${GOARCH} golang:1.19-alpine AS builder
RUN apk add --no-cache git
WORKDIR /usr/src/app

# Download dependencies first (better layer caching)
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${GOARCH} \
    go build -ldflags='-w -s' -o order ./cmd/main.go

# Final stage
FROM --platform=linux/${GOARCH} golang:1.19-alpine
WORKDIR /app

# Install necessary tools for testing
RUN apk add --no-cache ca-certificates git

# Copy only the binary and necessary files
COPY --from=builder /usr/src/app/order /app/

# For testing
COPY --from=builder /usr/src/app/go.mod /app/
COPY --from=builder /usr/src/app/go.sum /app/
COPY --from=builder /usr/src/app/internal /app/internal

# Default command
CMD ["/app/order"]