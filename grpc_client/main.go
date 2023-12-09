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
	addr            = "localhost:9000"
	grpc_connection *grpc.ClientConn
)

func main() {
	// Set up a connection to the server.
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

	c.JSON(http.StatusCreated, gin.H{
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
