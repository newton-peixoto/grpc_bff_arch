defmodule App.GrpcExample.UserReply do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :id, 1, type: :int32
  field :email, 2, type: :string
  field :name, 3, type: :string
end

defmodule App.GrpcExample.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :email, 1, type: :string
  field :name, 2, type: :string
end

defmodule App.GrpcExample.GetRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :id, 1, type: :int32
end

defmodule App.GrpcExample.User.Service do
  @moduledoc false

  use GRPC.Service, name: "grpc_example.User", protoc_gen_elixir_version: "0.12.0"

  rpc :Create, App.GrpcExample.CreateRequest, App.GrpcExample.UserReply

  rpc :Get, App.GrpcExample.GetRequest, App.GrpcExample.UserReply
end

defmodule App.GrpcExample.User.Stub do
  @moduledoc false

  use GRPC.Stub, service: App.GrpcExample.User.Service
end