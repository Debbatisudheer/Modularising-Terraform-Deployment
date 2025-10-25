FROM golang:1.21 as builder
WORKDIR /app
COPY . .
RUN go mod init eventcollector && go mod tidy
RUN go build -o event_collector main.go

FROM alpine:latest
RUN apk add --no-cache ca-certificates
WORKDIR /root/
COPY --from=builder /app/event_collector .
EXPOSE 8080 514/udp
CMD ["./event_collector"]
