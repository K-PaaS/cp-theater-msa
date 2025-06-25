package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", bookingsHandler)

	log.Println("Booking Service started on :8083")
	if err := http.ListenAndServe(":8083", nil); err != nil {
		log.Fatalf("Could not start server: %s\n", err)
	}
}
