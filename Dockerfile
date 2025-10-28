# -------------------------------------------------
# Stage 1: Build Go binary
# -------------------------------------------------
FROM golang:1.22 AS builder

# Create working directory inside container
WORKDIR /app

# Copy go.mod and go.sum first (better caching)
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source code
COPY . .

# Build Go binary (static build, no OS dependencies)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o event-collector main.go


# -------------------------------------------------
# Stage 2: Final small runtime image
# -------------------------------------------------
FROM alpine:3.19

WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/event-collector .

# Set environment variables (default values)
ENV APP_PORT=8080
ENV S3_BUCKET=""
ENV DEBUG_BUCKET=""

# Expose port for ECS / ALB
EXPOSE 8080

# Run the application
ENTRYPOINT ["./event-collector"]
