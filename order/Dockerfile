# Build stage
FROM golang:1.19-alpine AS builder
RUN apk add --no-cache git
WORKDIR /usr/src/app

# Download dependencies first (better layer caching)
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags='-w -s' -o order ./cmd/main.go

# Final stage
FROM alpine:3.16
WORKDIR /app

# Only install what's necessary
RUN apk add --no-cache ca-certificates

# Copy only the binary and necessary files
COPY --from=builder /usr/src/app/order /app/

# For testing
COPY --from=builder /usr/src/app/go.mod /app/
COPY --from=builder /usr/src/app/go.sum /app/
COPY --from=builder /usr/src/app/internal /app/internal

# Default command
CMD ["/app/order"]