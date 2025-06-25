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
		Addr:     "redis:6379",       // Redis service from docker-compose
		Password: "",               // No password set
		DB:       0,                // Default DB
	})
}

func saveUser(user User) error {
	userJSON, err := json.Marshal(user)
	if err != nil {
		return err
	}

	if err := rdb.Set(ctx, "user:"+user.ID, userJSON, 0).Err(); err != nil {
		log.Printf("Failed to save user to Redis: %v", err)
		return err
	}
	return nil
}

func findUserByID(id string) (*User, error) {
	userJSON, err := rdb.Get(ctx, "user:"+id).Result()
	if err != nil {
		return nil, err
	}

	var user User
	if err := json.Unmarshal([]byte(userJSON), &user); err != nil {
		return nil, err
	}
	return &user, nil
}

func getAllUsers() ([]User, error) {
	keys, err := rdb.Keys(ctx, "user:*").Result()
	if err != nil {
		return nil, err
	}

	var users []User
	for _, key := range keys {
		userJSON, err := rdb.Get(ctx, key).Result()
		if err != nil {
			log.Printf("Failed to get user for key %s: %v", key, err)
			continue
		}

		var user User
		if err := json.Unmarshal([]byte(userJSON), &user); err != nil {
			log.Printf("Failed to unmarshal user for key %s: %v", key, err)
			continue
		}
		users = append(users, user)
	}
	return users, nil
}
