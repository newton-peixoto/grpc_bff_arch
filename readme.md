# Integrando um BFF Rest com um microsserviço via gRPC

## Informações iniciais
Nesse texto iremos entender um pouco sobre gRPC e como integrar ele em uma arquitetura que utiliza BFFs (Backend For Frontend).
O texto será mais profeitoso se o leitor acompanhar juntamente ao repositório no Github para que possa abrir e entender as pastas do projeto. 

## O que é um BFF?
Backend For Frontend (BFF) refere-se a uma camada responsável por intermediar as requisições entre o cliente e o servidor agragando informações de diferentes serviços, tratando os dados e permitindo que possamos atender necessidades específicas de cada cliente.

## gRPC
Framework desenvolvido pela Google para facilitar comunicações entre serviços utilizando um protocolo de contrato bem defnido, Protocol Buffers (protobuf).

## Definição de contrato

A primeira etapa para começarmos a utilizar gRPC é instalarmos em nossa máquina o protoc e definirmos nosso serviço. Nosso serviço é definido da seguinte forma: 

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
* `User` é noss serviço composto por duas funções Create e Get
* UserReply é nosso contrato de resposta, o que nosso serviço irá retornar após executar a função
* CreateRequest e GetRequest são os payloads que esperamos em cada função


Com contrato definido podemos executar os comandos 

* make generate-elixir-proto 
* make generate-go-proto 

Esses comandos serão responsáveis por criar as estruturas de cada linguagem. Cada linguagem necessitará de seus respectiveis plugins para o protoc ser capaz de criar os arquivos. Os plugins podem ser encontratos em [Protobuf.dev](https://protobuf.dev/reference/).

## Criando o servidor gRPC

Com nosso contrato criado, módulos e estruturas gerados, podemos começar a desenvolver nossa aplicação. Temos a pasta grpc_server que contém nosso código elixir com um servidor grpc implementado. Começamos importando os módulos que geramos na etapa anterior como pode ser visto no arquivo grpc_server/mix.exs após isso desenvolvemos nosso endpoint.

```elixir 
defmodule App.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Logger.Server
  run App.GrpcServer
end
```

e nele dizemos que nosso handler será o módulo customizado App.GrpcServer. 

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

Esse módulo implementa as duas funções especificadas em nosso contrato e retorna os tipos definidos. Com isso em mãos podemos executar nosso endpoint na porta 9000 e teremos uma aplicação pronta para receber requisisões gRPC.

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

## Criando BFF em go para consumir servidor gRPC

Com nosso servidor gRPC em Elixir disponível nos resta agora criarmos uma API Rest que será utilizada pelo nosso frontend e consumirmos as informações do serviço que busca e cria usuários. </br></br>

Para isso, criamos a pasta grpc_client, inicializamos nosso módulo com o comando go mod init, importamos nossa biblioteca com os arquivos gerados pelo protoc que estão na pasta proto_schemas. Podemos ver o import em grpc_client/go.mod. Por fim, criamos nosso arquivo grpc_client/main.go que conterá nosso servidor web dispovível pela biblioteca gin e as conexões com nosso serviço em Elixir.

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

Nossa função é reponsável por criar nossa conexão com o servidor gRPC e disponibilizar nosso servidor web com duas rotas. Essas rotas por sua vez irão executar as funções get_user e insert_user, validar o payload de entrada, enviar a requisição via gRPC para o serviço em Elixir, validar se não houve nenhum erro nesse processo e retornar JSON esperado de saída.  

## gRPC vs Rest

gRPC é a melhor alternativa para comunicações entre serviços? Bem, em minha opinião é uma excelente alternativa para comunicações entre serviços que não dependem de entrada do cliente uma vez que o suporte para navegadores ainda se encontra bem limitado. Por outro lado, imaginando uma companhia com diversos serviços que trocam informações constantemente gRPC pode ser uma excelente alternativa para diminuirmos os dados trafegados pela rede devido ao uso dos protobuf no lugar de JSON e/ou XML que exigem maior trabalho para deserializar e uma maior agilidade para desenvolvimento entre as equipes uma vez que com o auxilio do protoc a geração de código ocorre de forma uma ágil facilitando o desenvolvimento. Claro que no fim das contas a resposta é depende pois fatores como familiaridade do time e disponibilidade para esse tipo de migração são  cruciais em momentos de tomada de decisão entre qual tecnologia escolher. 

## Executando o projeto 

Feito o clone do projeto em sua máquina utilize o comando 

* make docker-up 

e poderá realizar requisições como as abaixo 


Criação de usuário 
```curl 
curl --location 'localhost:8080/users' \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "teste",
    "email" : "teste@teste.com"
}'
```

Busca usuário por ID

```curl 
curl --location --request GET 'localhost:8080/users/1' \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "LEOZIN",
    "email" : "teste@teste.com"
}'
```