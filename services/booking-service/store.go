package main

import (
	"context"
	"encoding/json"
	"log"

	"github.com/go-redis/redis/v8"
)

var (
	rdb *redis.Client
	ctx = context.Background()
)

func init() {
	// Initialize Redis client
	rdb = redis.NewClient(&redis.Options{
		Addr:     "redis:6379", // Redis service from docker-compose
		Password: "",
		DB:       0, // Default DB
	})
}

func saveBooking(booking Booking) error {
	bookingJSON, err := json.Marshal(booking)
	if err != nil {
		return err
	}

	// Store the booking itself
	if err := rdb.Set(ctx, "booking:"+booking.ID, bookingJSON, 0).Err(); err != nil {
		log.Printf("Failed to save booking: %v", err)
		return err
	}

	// Add the booking ID to a list for the user
	if err := rdb.LPush(ctx, "user_bookings:"+booking.UserID, booking.ID).Err(); err != nil {
		log.Printf("Failed to update user's booking list: %v", err)
		// This is not a fatal error for the booking creation itself, but should be logged.
	}
	return nil
}

func findUserBookings(userID string) ([]Booking, error) {
	bookingIDs, err := rdb.LRange(ctx, "user_bookings:"+userID, 0, -1).Result()
	if err != nil {
		log.Printf("Failed to get booking IDs for user %s: %v", userID, err)
		return nil, err
	}

	if len(bookingIDs) == 0 {
		return []Booking{}, nil
	}

	// Prepend "booking:" to each ID for MGet
	keys := make([]string, len(bookingIDs))
	for i, id := range bookingIDs {
		keys[i] = "booking:" + id
	}

	bookingsData, err := rdb.MGet(ctx, keys...).Result()
	if err != nil {
		log.Printf("Failed to get bookings for user %s: %v", userID, err)
		return nil, err
	}

	bookings := make([]Booking, 0, len(bookingsData))
	for _, bookingJSON := range bookingsData {
		if bookingJSON == nil {
			continue
		}
		var booking Booking
		if err := json.Unmarshal([]byte(bookingJSON.(string)), &booking); err != nil {
			log.Printf("Failed to unmarshal booking data: %v", err)
			continue
		}
		bookings = append(bookings, booking)
	}

	return bookings, nil
}

func findAllBookings() ([]Booking, error) {
	keys, err := rdb.Keys(ctx, "booking:*").Result()
	if err != nil {
		return nil, err
	}

	if len(keys) == 0 {
		return []Booking{}, nil
	}

	bookingsData, err := rdb.MGet(ctx, keys...).Result()
	if err != nil {
		log.Printf("Failed to get all bookings: %v", err)
		return nil, err
	}

	bookings := make([]Booking, 0, len(bookingsData))
	for _, bookingJSON := range bookingsData {
		if bookingJSON == nil {
			continue
		}
		var booking Booking
		if err := json.Unmarshal([]byte(bookingJSON.(string)), &booking); err != nil {
			log.Printf("Failed to unmarshal booking data: %v", err)
			continue
		}
		bookings = append(bookings, booking)
	}

	return bookings, nil
}
