# Dockerfile for building Microverse in Linux CI environments
# Note: This creates a Linux binary, not a macOS app

FROM swift:5.9

WORKDIR /app

# Copy source code
COPY Package.swift ./
COPY Sources ./Sources
COPY Tests ./Tests

# Build the project
RUN swift build -c release

# Run tests
RUN swift test

# The binary will be at .build/release/Microverse
CMD ["swift", "run"]