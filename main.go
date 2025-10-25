package main

import (
	"bytes"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
)

// ============================
// Struct Definitions
// ============================

// Standardized event structure for all types
type Event struct {
	DeviceID  string `json:"device_id"`
	ErrorType string `json:"error_type"`
	Timestamp string `json:"timestamp"`
	Details   string `json:"details"`
	Severity  string `json:"severity,omitempty"`
}

// XML version of event for parsing
type XMLEvent struct {
	DeviceID  string `xml:"device_id"`
	ErrorType string `xml:"error_type"`
	Timestamp string `xml:"timestamp"`
	Details   string `xml:"details"`
}

// ============================
// Global Variables
// ============================

var (
	s3Client     *s3.S3
	bucketName   string
	debugBucket  string
	appPort      string
)

// ============================
// Initialization
// ============================

func init() {
	// Load environment variables
	bucketName = os.Getenv("S3_BUCKET")
	debugBucket = os.Getenv("DEBUG_BUCKET")
	appPort = os.Getenv("APP_PORT")

	if bucketName == "" {
		log.Fatal("Missing required environment variable: S3_BUCKET")
	}
	if debugBucket == "" {
		debugBucket = bucketName // fallback
	}
	if appPort == "" {
		appPort = "8080"
	}

	// Initialize AWS session (uses ECS task IAM role)
	sess, err := session.NewSession(&aws.Config{})
	if err != nil {
		log.Fatalf("Failed to create AWS session: %v", err)
	}
	s3Client = s3.New(sess)

	log.Printf("✅ Initialized Event Collector — S3: %s | Debug: %s | Port: %s", bucketName, debugBucket, appPort)
}

// ============================
// Helper Functions
// ============================

// detectGFH checks if a log message indicates a GFH error
func detectGFH(raw string) bool {
	rawUpper := strings.ToUpper(raw)
	return strings.Contains(rawUpper, "GFH") ||
		strings.Contains(rawUpper, "HEADER_INVALID") ||
		strings.Contains(rawUpper, "GFH_ERROR")
}

// extractDeviceID tries to extract a device ID from raw messages
func extractDeviceID(raw string) string {
	raw = strings.ToLower(raw)
	for _, key := range []string{"device=", "device_id=", "fw-", "router-", "switch-"} {
		if idx := strings.Index(raw, key); idx != -1 {
			start := idx + len(key)
			for end := start; end < len(raw); end++ {
				if raw[end] == ' ' || raw[end] == ';' || raw[end] == ',' {
					return strings.TrimSpace(raw[start:end])
				}
			}
			return strings.TrimSpace(raw[start:])
		}
	}
	return "unknown-device"
}

// storeEventToS3 uploads event data to main S3 bucket
func storeEventToS3(event Event) {
	now := time.Now().UTC().Format("20060102T150405Z")
	key := fmt.Sprintf("%s_%s.json", event.DeviceID, now)
	eventBytes, _ := json.MarshalIndent(event, "", "  ")

	_, err := s3Client.PutObject(&s3.PutObjectInput{
		Bucket: aws.String(bucketName),
		Key:    aws.String(key),
		Body:   bytes.NewReader(eventBytes),
	})
	if err != nil {
		log.Printf("❌ Failed to store event in %s: %v", bucketName, err)
	} else {
		log.Printf("✅ Stored event from %s (%s) to %s/%s", event.DeviceID, event.ErrorType, bucketName, key)
	}
}

// storeGFHToDebugBucket uploads GFH events to debug bucket
func storeGFHToDebugBucket(event Event) {
	now := time.Now().UTC().Format("20060102T150405Z")
	key := fmt.Sprintf("GFH/%s_%s.json", event.DeviceID, now)
	eventBytes, _ := json.MarshalIndent(event, "", "  ")

	_, err := s3Client.PutObject(&s3.PutObjectInput{
		Bucket: aws.String(debugBucket),
		Key:    aws.String(key),
		Body:   bytes.NewReader(eventBytes),
	})
	if err != nil {
		log.Printf("❌ Failed to store GFH event in debug bucket: %v", err)
	} else {
		log.Printf("🐞 GFH event stored in %s/%s", debugBucket, key)
	}
}

// ============================
// HTTP Handler
// ============================

func collectHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Unable to read body", http.StatusBadRequest)
		return
	}
	raw := string(body)

	// 1️⃣ Try JSON
	var event Event
	if json.Unmarshal(body, &event) == nil && event.DeviceID != "" {
		if strings.ToUpper(event.ErrorType) == "GFH" {
			storeGFHToDebugBucket(event)
			w.Write([]byte(`{"status":"received-gfh-json"}`))
			return
		}
		storeEventToS3(event)
		w.Write([]byte(`{"status":"received-json"}`))
		return
	}

	// 2️⃣ Try XML
	if strings.HasPrefix(strings.TrimSpace(raw), "<") {
		var xevent XMLEvent
		if xml.Unmarshal(body, &xevent) == nil {
			event = Event{
				DeviceID:  xevent.DeviceID,
				ErrorType: xevent.ErrorType,
				Timestamp: xevent.Timestamp,
				Details:   xevent.Details,
			}
			storeEventToS3(event)
			w.Write([]byte(`{"status":"received-xml"}`))
			return
		}
	}

	// 3️⃣ Detect GFH in raw text
	if detectGFH(raw) {
		event = Event{
			DeviceID:  extractDeviceID(raw),
			ErrorType: "GFH",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
			Details:   raw,
		}
		storeGFHToDebugBucket(event)
		w.Write([]byte(`{"status":"received-gfh"}`))
		return
	}

	// 4️⃣ Fallback: plain text
	event = Event{
		DeviceID:  extractDeviceID(raw),
		ErrorType: "RAW",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Details:   raw,
	}
	storeEventToS3(event)
	w.Write([]byte(`{"status":"received-raw"}`))
}

// ============================
// Syslog Listener
// ============================

func startSyslogServer() {
	addr := ":514" // standard syslog UDP port
	conn, err := net.ListenPacket("udp", addr)
	if err != nil {
		log.Fatalf("❌ Failed to start syslog listener: %v", err)
	}
	defer conn.Close()

	log.Printf("📡 Syslog listener running on %s", addr)

	buffer := make([]byte, 2048)
	for {
		n, _, err := conn.ReadFrom(buffer)
		if err != nil {
			log.Printf("Syslog read error: %v", err)
			continue
		}
		message := strings.TrimSpace(string(buffer[:n]))
		go handleSyslogMessage(message)
	}
}

func handleSyslogMessage(msg string) {
	errorType := "SYSLOG"
	if detectGFH(msg) {
		errorType = "GFH"
	}
	event := Event{
		DeviceID:  extractDeviceID(msg),
		ErrorType: errorType,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Details:   msg,
	}
	if errorType == "GFH" {
		storeGFHToDebugBucket(event)
	} else {
		storeEventToS3(event)
	}
}

// ============================
// Main Function
// ============================

func main() {
	http.HandleFunc("/collect", collectHandler)

	go startSyslogServer() // Run UDP syslog listener in background

	log.Printf("🚀 Event Collector started. Listening on port %s ...", appPort)
	if err := http.ListenAndServe(":"+appPort, nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}

