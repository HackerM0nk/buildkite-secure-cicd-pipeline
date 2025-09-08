package main

import (
	"github.com/huseyinbabal/microservices/payment/config"
	"github.com/huseyinbabal/microservices/payment/internal/adapters/db"
	"github.com/huseyinbabal/microservices/payment/internal/adapters/grpc"
	"github.com/huseyinbabal/microservices/payment/internal/application/core/api"
	log "github.com/sirupsen/logrus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/jaeger"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	tracesdk "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.10.0"
	"go.opentelemetry.io/otel/trace"
	"os"
)

const (
	service     = "payment"
	environment = "dev"
	id          = 2
)

func tracerProvider(url string) (*tracesdk.TracerProvider, error) {
	if url == "" {
		// If no URL is provided, return a no-op tracer provider
		return tracesdk.NewTracerProvider(
			tracesdk.WithSampler(tracesdk.NeverSample()),
			tracesdk.WithResource(resource.NewWithAttributes(
				semconv.SchemaURL,
				semconv.ServiceNameKey.String(service),
				attribute.String("environment", environment),
				attribute.Int64("ID", id),
			)),
		), nil
	}

	// Create the Jaeger exporter
	exp, err := jaeger.New(jaeger.WithCollectorEndpoint(jaeger.WithEndpoint(url)))
	if err != nil {
		log.Warnf("Failed to create Jaeger exporter: %v. Tracing will be disabled.", err)
		return tracerProvider("") // Fall back to no-op provider
	}

	tp := tracesdk.NewTracerProvider(
		tracesdk.WithBatcher(exp),
		tracesdk.WithResource(resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceNameKey.String(service),
			attribute.String("environment", environment),
			attribute.Int64("ID", id),
		)),
	)
	return tp, nil
}

func init() {
	log.SetFormatter(customLogger{
		formatter: log.JSONFormatter{FieldMap: log.FieldMap{
			"msg": "message",
		}},
	})
	log.SetOutput(os.Stdout)
	log.SetLevel(log.InfoLevel)
}

type customLogger struct {
	formatter log.JSONFormatter
}

func (l customLogger) Format(entry *log.Entry) ([]byte, error) {
	span := trace.SpanFromContext(entry.Context)
	entry.Data["trace_id"] = span.SpanContext().TraceID().String()
	entry.Data["span_id"] = span.SpanContext().SpanID().String()
	//Below injection is Just to understand what Context has
	entry.Data["Context"] = span.SpanContext()
	return l.formatter.Format(entry)
}

func main() {
	// Make Jaeger URL configurable via environment variable, default to empty (disabled)
	jaegerURL := os.Getenv("JAEGER_URL")
	if jaegerURL == "" {
		log.Info("JAEGER_URL not set, tracing is disabled")
	}

	tp, err := tracerProvider(jaegerURL)
	if err != nil {
		log.Warnf("Failed to initialize tracer: %v. Continuing without tracing.", err)
	} else {
		otel.SetTracerProvider(tp)
		otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}))
	}

	dbAdapter, err := db.NewAdapter(config.GetDataSourceURL())
	if err != nil {
		log.Fatalf("Failed to connect to database. Error: %v", err)
	}

	application := api.NewApplication(dbAdapter)
	grpcAdapter := grpc.NewAdapter(application, config.GetApplicationPort())
	grpcAdapter.Run()
}
