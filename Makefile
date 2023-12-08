generate-elixir-proto: 
	protoc --elixir_out=plugins=grpc:./grpc_server/lib --elixir_opt=package_prefix=app ./proto_schemas/*.proto