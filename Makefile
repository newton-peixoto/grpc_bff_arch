generate-elixir-proto: 
	protoc --elixir_out=plugins=grpc:./proto_schemas/elixir_grpc_schemas/lib ./proto_schemas/*.proto

generate-go-proto:
	protoc --go_out=./proto_schemas/golang --go_opt=paths=source_relative \
			--go-grpc_out=./proto_schemas/golang --go-grpc_opt=paths=source_relative \
			./proto_schemas/*.proto