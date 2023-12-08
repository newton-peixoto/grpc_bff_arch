defmodule App.GrpcServer do
  alias Repository.UserRepository
  use GRPC.Server, service: GrpcExample.User.Service

  def create(request, _stream) do
    new_user =
      UserRepository.save(%{
        name: request.name,
        email: request.email,
      })

    GrpcExample.UserReply.new(new_user)
  end

  def get(request, _stream) do
    user = UserRepository.get(request.id)

    if user == nil do
      raise GRPC.RPCError, status: :not_found
    else
      GrpcExample.UserReply.new(user)
    end
  end
end
