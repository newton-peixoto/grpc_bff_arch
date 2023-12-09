FROM golang:1.21-alpine

WORKDIR /app

COPY grpc_client grpc_client
COPY proto_schemas proto_schemas

RUN cd grpc_client && go mod download

RUN cd grpc_client && go build -o application

EXPOSE 8080

CMD ["/app/grpc_client/application"]