# Stage 1: Build stage using official Go image
FROM golang:1.22-alpine AS builder

# Set working directory inside the container
WORKDIR /usr/src/app/

# Use Go build cache for dependencies to speed up builds
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    mkdir -p /root/.cache/go-build

# Copy dependency files first (to leverage caching)
COPY go.mod go.sum ./

# Download Go module dependencies
RUN go mod download

# Copy the rest of the source code into the container
COPY . .

# Build the Go binary named 'product-catalog'
RUN go build -o product-catalog .

####################################

# Stage 2: Release stage using minimal Alpine image
FROM alpine AS release

# Set working directory inside the container
WORKDIR /usr/src/app/

# Copy static product files into the container
COPY ./products/ ./products/

# Copy the compiled Go binary from the builder stage
COPY --from=builder /usr/src/app/product-catalog/ ./

# Set environment variable for the service port
ENV PRODUCT_CATALOG_PORT=8088

# Define the entrypoint to run the binary
ENTRYPOINT [ "./product-catalog" ]
