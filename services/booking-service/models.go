package main

// Booking represents a booking model
type Booking struct {
	ID      string   `json:"id"`
	UserID  string   `json:"userId"`
	MovieID string   `json:"movieId"`
	Seats   []string `json:"seats"`
}
