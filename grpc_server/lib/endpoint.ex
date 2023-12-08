defmodule App.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Logger.Server
  run App.GrpcServer
end
