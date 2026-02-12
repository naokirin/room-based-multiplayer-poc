# Development image for Docker Compose (mix phx.server on port 4000)
# Use official Elixir image to avoid missing hexpm/elixir tags
FROM elixir:1.15

RUN apt-get update && apt-get install -y build-essential git curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy mix files first for better layer caching
COPY mix.exs mix.lock ./
RUN mix deps.get

# Copy application code
COPY config config
COPY lib lib
COPY priv priv

# Compile (no build in production sense; for dev we compile at runtime if needed)
RUN mix compile

ENV MIX_ENV=dev
ENV PORT=4000

EXPOSE 4000

CMD ["mix", "phx.server"]
