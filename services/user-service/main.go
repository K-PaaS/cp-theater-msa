package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", usersHandler)

	log.Println("User Service started on :8081")
	if err := http.ListenAndServe(":8081", nil); err != nil {
		log.Fatalf("Could not start server: %s\n", err)
	}
}
