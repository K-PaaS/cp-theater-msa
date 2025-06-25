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

func saveMovie(movie Movie) error {
	movieJSON, err := json.Marshal(movie)
	if err != nil {
		return err
	}

	if err := rdb.Set(ctx, "movie:"+movie.ID, movieJSON, 0).Err(); err != nil {
		log.Printf("Failed to save movie to Redis: %v", err)
		return err
	}
	return nil
}

func findMovieByID(id string) (*Movie, error) {
	movieJSON, err := rdb.Get(ctx, "movie:"+id).Result()
	if err != nil {
		return nil, err
	}

	var movie Movie
	if err := json.Unmarshal([]byte(movieJSON), &movie); err != nil {
		return nil, err
	}
	return &movie, nil
}

func findAllMovies() ([]Movie, error) {
	keys, err := rdb.Keys(ctx, "movie:*").Result()
	if err != nil {
		log.Printf("Failed to get movie keys from Redis: %v", err)
		return nil, err
	}

	if len(keys) == 0 {
		return []Movie{}, nil
	}

	moviesData, err := rdb.MGet(ctx, keys...).Result()
	if err != nil {
		log.Printf("Failed to get movies from Redis: %v", err)
		return nil, err
	}

	movies := make([]Movie, 0, len(moviesData))
	for _, movieJSON := range moviesData {
		if movieJSON == nil {
			continue
		}
		var movie Movie
		if err := json.Unmarshal([]byte(movieJSON.(string)), &movie); err != nil {
			log.Printf("Failed to unmarshal movie data: %v", err)
			continue
		}
		movies = append(movies, movie)
	}

	return movies, nil
}
