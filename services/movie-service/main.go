package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", moviesHandler)

	log.Println("Movie Service started on :8082")
	if err := http.ListenAndServe(":8082", nil); err != nil {
		log.Fatalf("Could not start server: %s\n", err)
	}
}
