# Stage 1: Build the Go binary
FROM docker.io/library/golang:1.24-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum files
COPY go.mod ./
# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the binary for a Linux environment
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/main .

# Stage 2: Create the final, minimal image
FROM docker.io/library/alpine:latest

# Install timezone data
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/main .

# Set timezone
ENV TZ=Asia/Seoul


# Expose the port the app runs on
EXPOSE 8080

# Command to run the executable
CMD ["/app/main"]
