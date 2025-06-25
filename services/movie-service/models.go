package main

// Movie represents a movie model
type Movie struct {
	ID       string `json:"id"`
	Title    string `json:"title"`
	Director string `json:"director"`
	Genre    string `json:"genre"`
}
