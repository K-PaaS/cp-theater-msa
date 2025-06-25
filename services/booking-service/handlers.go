package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/google/uuid"
)

func bookingsHandler(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/")
	// Remove "bookings/" prefix if present (from API Gateway routing)
	path = strings.TrimPrefix(path, "bookings/")
	w.Header().Set("Content-Type", "application/json")
	
	// 실제 라우팅 정보를 헤더에 추가
	w.Header().Set("X-Service-Cluster", getClusterName())
	w.Header().Set("X-Pod-Name", os.Getenv("HOSTNAME"))
	w.Header().Set("X-Service-Name", "booking-service")
	
	// Debug logging
	log.Printf("Request: %s %s, processed path: '%s'", r.Method, r.URL.Path, path)

	switch r.Method {
	case http.MethodPost:
		if path == "" {
			createBookingHandler(w, r)
		} else {
			http.Error(w, "Invalid path for POST", http.StatusBadRequest)
		}
	case http.MethodGet:
		if path == "" {
			getAllBookingsHandler(w, r)
		} else if strings.HasPrefix(path, "user/") {
			userID := strings.TrimPrefix(path, "user/")
			if userID != "" {
				getUserBookingsHandler(w, r, userID)
			} else {
				http.Error(w, "Invalid user ID", http.StatusBadRequest)
			}
		} else {
			http.Error(w, "Invalid path for GET", http.StatusBadRequest)
		}
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func createBookingHandler(w http.ResponseWriter, r *http.Request) {
	var booking Booking
	if err := json.NewDecoder(r.Body).Decode(&booking); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	booking.ID = uuid.New().String()

	if err := saveBooking(booking); err != nil {
		http.Error(w, "Failed to save booking", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(booking)
}

func getAllBookingsHandler(w http.ResponseWriter, r *http.Request) {
	bookings, err := findAllBookings()
	if err != nil {
		http.Error(w, "Failed to retrieve bookings", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(bookings)
}

func getUserBookingsHandler(w http.ResponseWriter, r *http.Request, userID string) {
	bookings, err := findUserBookings(userID)
	if err != nil {
		http.Error(w, "Failed to retrieve bookings", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(bookings)
}

// getClusterName은 현재 파드가 실행 중인 클러스터를 판단합니다
func getClusterName() string {
	// 환경변수에서 클러스터명 확인
	if cluster := os.Getenv("CLUSTER_NAME"); cluster != "" {
		return cluster
	}
	
	// 파드명에서 클러스터 정보 추출
	hostname := os.Getenv("HOSTNAME")
	if strings.Contains(hostname, "ctx1") {
		return "ctx1"
	} else if strings.Contains(hostname, "ctx2") {
		return "ctx2"
	}
	
	// 기본값
	return "unknown"
}
