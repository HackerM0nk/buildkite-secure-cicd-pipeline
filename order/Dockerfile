# Build stage
FROM golang:1.19 AS builder
WORKDIR /usr/src/app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o order ./cmd/main.go

# Runtime stage with a minimal image including shell
FROM alpine:3.16
WORKDIR /app

# Install bash and other necessary tools
RUN apk add --no-cache bash ca-certificates

# Copy the binary from builder
COPY --from=builder /usr/src/app/order /app/order

# For testing
RUN mkdir -p /app/cmd
COPY --from=builder /usr/src/app/go.mod /app/
COPY --from=builder /usr/src/app/go.sum /app/
COPY --from=builder /usr/src/app/internal /app/internal

# Default command can be overridden in docker-compose
CMD ["/app/order"]