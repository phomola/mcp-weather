package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/fealsamh/go-utils/mcp"
)

type (
	period struct {
		Number          int       `json:"number"`
		Name            string    `json:"name"`
		Start           time.Time `json:"startTime"`
		End             time.Time `json:"endTime"`
		Temperature     float32   `json:"temperature"`
		TemperatureUnit string    `json:"temperatureUnit"`
		Detailed        string    `json:"detailedForecast"`
	}

	weatherRequest struct {
		Latitude  float64 `json:"latitude"`
		Longitude float64 `json:"longitude"`
	}

	weatherResponse struct {
		City    string   `json:"city"`
		State   string   `json:"state"`
		Periods []period `json:"periods"`
	}

	toolInput struct {
		Latitude  float64 `json:"latitude" jsonschema:"the latitude of the location"`
		Longitude float64 `json:"longitude" jsonschema:"the longitude of the location"`
	}

	toolOutput struct {
		Periods []modelPeriod `json:"periods" jsonschema:"forecast periods"`
		Error   string        `json:"error" jsonschema:"an error occurred while getting the forecast"`
	}

	modelPeriod struct {
		Name     string `json:"name" jsonschema:"the name of the period"`
		Forecast string `json:"forecast" jsonschema:"the forecast for the period"`
	}
)

func getForecast(ctx context.Context, input *toolInput) (*toolOutput, error) {
	in := weatherRequest{Latitude: input.Latitude, Longitude: input.Longitude}
	b, err := json.Marshal(&in)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://arax.ee/weather/forecast", bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	var cl http.Client
	resp, err := cl.Do(req)
	if err != nil {
		return nil, err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode == http.StatusNotFound {
		return &toolOutput{Error: "The location couldn't be found. The tool only provides data for the US."}, nil
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %s", resp.Status)
	}
	var out weatherResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	periods := make([]modelPeriod, 0, 5)
	for i, p := range out.Periods {
		if i == 5 {
			break
		}
		periods = append(periods, modelPeriod{p.Name, p.Detailed})
	}
	return &toolOutput{Periods: periods}, nil
}

func main() {
	server := mcp.NewServer("weather", "v1.0.0")
	mcp.AddTool(server, "weatherForecasts", "Provides weather forecasts for the US.", getForecast)
	if err := server.Run(context.Background()); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
