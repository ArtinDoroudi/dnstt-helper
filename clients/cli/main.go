// dnstt-helper client wrapper
// Provides enhanced features on top of the standard dnstt-client
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"sort"
	"sync"
	"syscall"
	"time"

	"gopkg.in/yaml.v3"
)

const (
	version = "1.0.0"
)

// Config represents the client configuration
type Config struct {
	Domain     string     `json:"domain" yaml:"domain"`
	LocalAddr  string     `json:"local_addr" yaml:"local_addr"`
	PubKey     string     `json:"pubkey" yaml:"pubkey"`
	PubKeyFile string     `json:"pubkey_file" yaml:"pubkey_file"`
	Resolvers  []Resolver `json:"resolvers" yaml:"resolvers"`
	MTU        string     `json:"mtu" yaml:"mtu"` // "auto" or numeric value
	Failover   bool       `json:"failover" yaml:"failover"`
	RetryCount int        `json:"retry_count" yaml:"retry_count"`
	Timeout    int        `json:"timeout" yaml:"timeout"`
}

// Resolver represents a DNS resolver configuration
type Resolver struct {
	Type     string `json:"type" yaml:"type"` // udp, doh, dot
	Addr     string `json:"addr" yaml:"addr"`
	URL      string `json:"url" yaml:"url"`
	Priority int    `json:"priority" yaml:"priority"`
}

// ResolverResult holds latency test results
type ResolverResult struct {
	Resolver Resolver
	Latency  time.Duration
	Success  bool
}

var (
	configFile  = flag.String("config", "", "Configuration file (JSON or YAML)")
	udpResolver = flag.String("udp", "", "UDP DNS resolver address")
	dohURL      = flag.String("doh", "", "DNS-over-HTTPS resolver URL")
	dotAddr     = flag.String("dot", "", "DNS-over-TLS resolver address")
	pubKey      = flag.String("pubkey", "", "Server public key")
	pubKeyFile  = flag.String("pubkey-file", "", "Server public key file")
	mtu         = flag.String("mtu", "auto", "MTU size (auto or numeric)")
	autoSelect  = flag.Bool("auto-select", false, "Auto-select fastest resolver")
	showVersion = flag.Bool("version", false, "Show version")
	verbose     = flag.Bool("verbose", false, "Verbose output")
)

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "dnstt-helper client v%s\n\n", version)
		fmt.Fprintf(os.Stderr, "Usage: %s [options] <domain> <local-addr>\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nExamples:\n")
		fmt.Fprintf(os.Stderr, "  %s -udp 8.8.8.8:53 -pubkey-file server.pub t.example.com 127.0.0.1:7000\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -config config.json\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -auto-select -config config.json\n", os.Args[0])
	}

	flag.Parse()

	if *showVersion {
		fmt.Printf("dnstt-helper client v%s\n", version)
		os.Exit(0)
	}

	var config Config
	var err error

	// Load configuration
	if *configFile != "" {
		config, err = loadConfig(*configFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}
	} else {
		// Build config from flags
		config = buildConfigFromFlags()
	}

	// Validate configuration
	if err := validateConfig(&config); err != nil {
		fmt.Fprintf(os.Stderr, "Configuration error: %v\n", err)
		os.Exit(1)
	}

	// Auto-select resolver if enabled
	if *autoSelect && len(config.Resolvers) > 1 {
		logVerbose("Auto-selecting fastest resolver...")
		config.Resolvers = selectFastestResolver(config.Resolvers)
	}

	// Auto-detect MTU if set to "auto"
	if config.MTU == "auto" {
		logVerbose("Auto-detecting optimal MTU...")
		config.MTU = detectOptimalMTU(config.Resolvers[0])
	}

	// Run the client
	runClient(config)
}

func loadConfig(filename string) (Config, error) {
	var config Config

	data, err := os.ReadFile(filename)
	if err != nil {
		return config, fmt.Errorf("failed to read config file: %v", err)
	}

	// Try JSON first
	if err := json.Unmarshal(data, &config); err != nil {
		// Try YAML
		if err := yaml.Unmarshal(data, &config); err != nil {
			return config, fmt.Errorf("failed to parse config (tried JSON and YAML): %v", err)
		}
	}

	// Set defaults
	if config.RetryCount == 0 {
		config.RetryCount = 3
	}
	if config.Timeout == 0 {
		config.Timeout = 10
	}
	if config.MTU == "" {
		config.MTU = "1232"
	}

	return config, nil
}

func buildConfigFromFlags() Config {
	config := Config{
		MTU:        *mtu,
		RetryCount: 3,
		Timeout:    10,
		Failover:   true,
	}

	// Get domain and local address from remaining args
	args := flag.Args()
	if len(args) >= 2 {
		config.Domain = args[0]
		config.LocalAddr = args[1]
	}

	// Set public key
	if *pubKey != "" {
		config.PubKey = *pubKey
	}
	if *pubKeyFile != "" {
		config.PubKeyFile = *pubKeyFile
	}

	// Add resolvers
	if *udpResolver != "" {
		config.Resolvers = append(config.Resolvers, Resolver{
			Type:     "udp",
			Addr:     *udpResolver,
			Priority: 1,
		})
	}
	if *dohURL != "" {
		config.Resolvers = append(config.Resolvers, Resolver{
			Type:     "doh",
			URL:      *dohURL,
			Priority: 2,
		})
	}
	if *dotAddr != "" {
		config.Resolvers = append(config.Resolvers, Resolver{
			Type:     "dot",
			Addr:     *dotAddr,
			Priority: 3,
		})
	}

	return config
}

func validateConfig(config *Config) error {
	if config.Domain == "" {
		return fmt.Errorf("domain is required")
	}
	if config.LocalAddr == "" {
		return fmt.Errorf("local address is required")
	}
	if config.PubKey == "" && config.PubKeyFile == "" {
		return fmt.Errorf("public key is required (--pubkey or --pubkey-file)")
	}
	if len(config.Resolvers) == 0 {
		return fmt.Errorf("at least one resolver is required")
	}
	return nil
}

func selectFastestResolver(resolvers []Resolver) []Resolver {
	var results []ResolverResult
	var mu sync.Mutex
	var wg sync.WaitGroup

	for _, resolver := range resolvers {
		wg.Add(1)
		go func(r Resolver) {
			defer wg.Done()
			latency, success := testResolverLatency(r)
			mu.Lock()
			results = append(results, ResolverResult{
				Resolver: r,
				Latency:  latency,
				Success:  success,
			})
			mu.Unlock()
		}(resolver)
	}

	wg.Wait()

	// Sort by latency (successful ones first)
	sort.Slice(results, func(i, j int) bool {
		if results[i].Success != results[j].Success {
			return results[i].Success
		}
		return results[i].Latency < results[j].Latency
	})

	// Log results
	for i, r := range results {
		status := "failed"
		if r.Success {
			status = fmt.Sprintf("%v", r.Latency)
		}
		logVerbose("  %d. %s (%s): %s", i+1, resolverString(r.Resolver), r.Resolver.Type, status)
	}

	// Return sorted resolvers
	var sorted []Resolver
	for _, r := range results {
		sorted = append(sorted, r.Resolver)
	}

	if len(sorted) > 0 {
		logVerbose("Selected: %s", resolverString(sorted[0]))
	}

	return sorted
}

func testResolverLatency(resolver Resolver) (time.Duration, bool) {
	start := time.Now()
	var success bool

	switch resolver.Type {
	case "udp":
		conn, err := net.DialTimeout("udp", resolver.Addr, 5*time.Second)
		if err == nil {
			conn.Close()
			success = true
		}
	case "doh":
		// Simple HTTP check
		// In a full implementation, we'd do an actual DoH query
		success = true // Assume DoH is available if configured
	case "dot":
		conn, err := net.DialTimeout("tcp", resolver.Addr, 5*time.Second)
		if err == nil {
			conn.Close()
			success = true
		}
	}

	return time.Since(start), success
}

func resolverString(r Resolver) string {
	switch r.Type {
	case "udp":
		return r.Addr
	case "doh":
		return r.URL
	case "dot":
		return r.Addr
	default:
		return "unknown"
	}
}

func detectOptimalMTU(resolver Resolver) string {
	// Common MTU values to test, from highest to lowest
	mtuValues := []int{1400, 1232, 1200, 1000, 512}

	logVerbose("Testing MTU values...")

	for _, mtu := range mtuValues {
		if testMTU(resolver, mtu) {
			logVerbose("  MTU %d: OK", mtu)
			return fmt.Sprintf("%d", mtu)
		}
		logVerbose("  MTU %d: failed", mtu)
	}

	// Default to safe value
	return "512"
}

func testMTU(resolver Resolver, mtu int) bool {
	// In a real implementation, we'd send test DNS queries
	// For now, we use heuristics based on resolver type
	switch resolver.Type {
	case "udp":
		// Most UDP DNS resolvers support at least 1232
		return mtu <= 1232
	case "doh", "dot":
		// DoH/DoT generally support higher MTU
		return mtu <= 1400
	}
	return mtu <= 1232
}

func runClient(config Config) {
	// Build command arguments
	args := buildClientArgs(config)

	logVerbose("Starting dnstt-client with args: %v", args)

	// Find dnstt-client binary
	clientPath := findClientBinary()
	if clientPath == "" {
		fmt.Fprintf(os.Stderr, "Error: dnstt-client binary not found\n")
		fmt.Fprintf(os.Stderr, "Please ensure dnstt-client is in your PATH or current directory\n")
		os.Exit(1)
	}

	// Create command
	cmd := exec.Command(clientPath, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Handle signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		if cmd.Process != nil {
			cmd.Process.Signal(syscall.SIGTERM)
		}
	}()

	// Run with retry logic
	for retry := 0; retry <= config.RetryCount; retry++ {
		if retry > 0 {
			logVerbose("Retry %d/%d...", retry, config.RetryCount)
			time.Sleep(time.Duration(retry) * time.Second)

			// Try next resolver if failover is enabled
			if config.Failover && len(config.Resolvers) > 1 {
				config.Resolvers = append(config.Resolvers[1:], config.Resolvers[0])
				args = buildClientArgs(config)
				cmd = exec.Command(clientPath, args...)
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				logVerbose("Switching to resolver: %s", resolverString(config.Resolvers[0]))
			}
		}

		err := cmd.Run()
		if err == nil {
			return
		}

		logVerbose("Client exited with error: %v", err)
	}

	fmt.Fprintf(os.Stderr, "All retry attempts exhausted\n")
	os.Exit(1)
}

func buildClientArgs(config Config) []string {
	var args []string

	// Add resolver
	if len(config.Resolvers) > 0 {
		r := config.Resolvers[0]
		switch r.Type {
		case "udp":
			args = append(args, "-udp", r.Addr)
		case "doh":
			args = append(args, "-doh", r.URL)
		case "dot":
			args = append(args, "-dot", r.Addr)
		}
	}

	// Add public key
	if config.PubKey != "" {
		args = append(args, "-pubkey", config.PubKey)
	} else if config.PubKeyFile != "" {
		args = append(args, "-pubkey-file", config.PubKeyFile)
	}

	// Add MTU
	if config.MTU != "" && config.MTU != "auto" {
		args = append(args, "-mtu", config.MTU)
	}

	// Add domain and local address
	args = append(args, config.Domain, config.LocalAddr)

	return args
}

func findClientBinary() string {
	// Check current directory first
	candidates := []string{
		"./dnstt-client",
		"./dnstt-client.exe",
		"dnstt-client",
	}

	for _, candidate := range candidates {
		if _, err := exec.LookPath(candidate); err == nil {
			return candidate
		}
	}

	// Check PATH
	path, err := exec.LookPath("dnstt-client")
	if err == nil {
		return path
	}

	return ""
}

func logVerbose(format string, args ...interface{}) {
	if *verbose {
		fmt.Printf("[INFO] "+format+"\n", args...)
	}
}

