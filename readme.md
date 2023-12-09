## Informações iniciais

Neste texto, abordaremos o `gRPC` e como integrá-lo em uma arquitetura que utiliza `BFFs (Backend For Frontend)`. A compreensão será mais proveitosa se o leitor acompanhar o repositório no `Github` para explorar as pastas do projeto.

## O que é um _BFF_?

`Backend For Frontend (BFF)` refere-se a uma camada responsável por intermediar as requisições entre o cliente e o servidor, agregando informações de diferentes serviços, tratando os dados e permitindo atender necessidades específicas de cada cliente.

## _gRPC_

O `gRPC` é um `framework` desenvolvido pela `Google` para facilitar comunicações entre serviços, utilizando um protocolo de contrato bem definido, `Protocol Buffers` (`protobuf`).

## Definição de contrato

A primeira etapa para começarmos a utilizar `gRPC` é instalar o protoc na máquina e definir nosso serviço. Nosso serviço é definido da seguinte forma:

```protobuf
syntax = "proto3";

package grpc_example;

option go_package = "../proto_schemas";

service User {
  rpc Create (CreateRequest) returns (UserReply) {}
  rpc Get (GetRequest) returns (UserReply) {}
}

message UserReply {
  int32 id = 1;
  string email = 2;
  string name = 3;
}

message CreateRequest {
  string email = 1;
  string name = 2;
}

message GetRequest {
  int32 id = 1;
}
```

Onde:

* `User` é nosso serviço composto por duas funções: `Create` e `Get`
* `UserReply` é nosso contrato de resposta, o que nosso serviço retorna após executar a função
* `CreateRequest` e `GetRequest` são os payloads esperados em cada função

Com o contrato definido, executamos os comandos:

* make generate-elixir-proto
* make generate-go-proto
  
Esses comandos criarão as estruturas de cada linguagem. Cada linguagem necessitará de seus respectivos plugins para o protoc criar os arquivos. Os _plugins_ podem ser encontrados em [Protobuf.dev.](https://protobuf.dev/reference/)

## Criando o servidor _gRPC_
Com o contrato criado e os módulos e estruturas gerados, podemos desenvolver nossa aplicação. A pasta `grpc_server` contém nosso código `Elixir` com um servidor `gRPC` implementado. Começamos importando os módulos gerados na etapa anterior, como pode ser visto no arquivo `grpc_server/mix.exs`. Após isso, desenvolvemos nosso endpoint.

```elixir
defmodule App.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Logger.Server
  run App.GrpcServer
end
```
Neste código, especificamos que nosso handler será o módulo customizado `App.GrpcServer`.

```elixir
defmodule App.GrpcServer do
  alias Repository.UserRepository
  require Logger
  use GRPC.Server, service: GrpcExample.User.Service

  def create(request, _stream) do
    Logger.info("Received create request")
    new_user =
      UserRepository.save(%{
        name: request.name,
        email: request.email,
      })

    GrpcExample.UserReply.new(new_user)
  end

  def get(request, _stream) do
    user = UserRepository.get(request.id)
    Logger.info("Received get request")
    if user == nil do
      raise GRPC.RPCError, status: :not_found
    else
      GrpcExample.UserReply.new(user)
    end
  end
end

```
Esse módulo implementa as duas funções especificadas em nosso contrato e retorna os tipos definidos. Com isso, podemos executar nosso endpoint na porta 9000 e teremos uma aplicação pronta para receber requisições `gRPC`.

```elixir
defmodule App.Application do
  @moduledoc false
alias Repository.UserRepository

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      UserRepository,
      {GRPC.Server.Supervisor, {App.Endpoint, 9000}}
    ]

    opts = [strategy: :one_for_one, name: App.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

```

## Criando _BFF_ em _Go_ para consumir servidor _gRPC_
Com nosso servidor `gRPC` em `Elixir` disponível, criaremos uma _API Rest_ que será utilizada pelo nosso `frontend` para consumir informações do serviço que busca e cria usuários.

```go
package main

import (
	"log"
	"net/http"
	"strconv"

	"example.com/grpc_example/proto_schemas"
	"github.com/gin-gonic/gin"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

var (
	addr            = "server:9000"
	grpc_connection *grpc.ClientConn
)

func main() {
	conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}

	grpc_connection = conn
	defer conn.Close()

	r := gin.Default()
	r.GET("/users/:id", get_user)
	r.POST("/users/", insert_user)
	r.Run()
}

func get_user(c *gin.Context) {
	user_client := proto_schemas.NewUserClient(grpc_connection)

	id, err := strconv.Atoi(c.Param("id"))

	if err != nil {
		c.Status(http.StatusUnprocessableEntity)
		return
	}

	r, err := user_client.Get(c.Request.Context(), &proto_schemas.GetRequest{
		Id: int32(id),
	})

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"id":    r.Id,
		"name":  r.Name,
		"email": r.Email,
	})
}

type user_insert_request struct {
	Name  string
	Email string
}

func insert_user(c *gin.Context) {
	user_client := proto_schemas.NewUserClient(grpc_connection)

	var request *user_insert_request
	if err := c.ShouldBindJSON(&request); err != nil {
		c.Status(http.StatusUnprocessableEntity)
		return
	}

	r, err := user_client.Create(c.Request.Context(), &proto_schemas.CreateRequest{
		Email: request.Email,
		Name:  request.Name,
	})

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":    r.Id,
		"name":  r.Name,
		"email": r.Email,
	})
}

```

Nossa função main é responsável por criar a conexão com o servidor `gRPC` e disponibilizar um servidor `web` com duas rotas. Essas rotas executarão funções específicas, validarão o payload de entrada, enviarão a requisição via `gRPC` para o serviço em `Elixir`, verificarão se houve algum erro nesse processo e retornarão o `JSON` esperado de saída.

## _gRPC_ vs _Rest_
O `gRPC` é a melhor alternativa para comunicações entre serviços? Bem, em minha opinião, é uma excelente alternativa para comunicações entre serviços que não dependem de entrada do cliente, uma vez que o suporte para navegadores ainda é limitado. Por outro lado, em uma companhia com diversos serviços que trocam informações constantemente, o `gRPC` pode ser uma excelente alternativa para diminuir o tráfego de dados pela rede devido ao uso dos protobufs no lugar de `JSON` e/ou `XML`, que exigem maior esforço para deserializar. Além disso, oferece maior agilidade para o desenvolvimento entre as equipes, já que a geração de código ocorre de forma ágil com o auxílio do `protoc`. No entanto, a escolha entre tecnologias depende de fatores como familiaridade da equipe e disponibilidade para migração.

## Executando o projeto
Após clonar o projeto em sua máquina, utilize o comando:

* make docker-up
  
Assim, poderá realizar requisições como as abaixo:

Criação de usuário:
```
curl --location 'localhost:8080/users' \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "teste",
    "email" : "teste@teste.com"
}'
```
Busca de usuário por ID:
```
curl --location --request GET 'localhost:8080/users/1' \
--header 'Content-Type: application/json
```