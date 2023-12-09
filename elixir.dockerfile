# File: docker_phx/Dockerfile
FROM elixir:1.15.7-alpine as build

WORKDIR /app

# install Hex + Rebar
RUN mix do local.hex --force, local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
COPY grpc_server grpc_server
COPY proto_schemas proto_schemas
RUN cd grpc_server && mix deps.get --only $MIX_ENV
RUN cd grpc_server && mix deps.compile

RUN cd grpc_server && mix release

RUN chmod +x /app/grpc_server/_build/prod/rel/grpc_server

CMD ["/app/grpc_server/_build/prod/rel/grpc_server/bin/grpc_server", "start"]