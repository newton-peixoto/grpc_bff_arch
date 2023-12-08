generate-elixir-proto: 
	protoc --elixir_out=plugins=grpc:./grpc_server/lib ./proto_schemas/*.proto