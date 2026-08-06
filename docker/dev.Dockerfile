FROM elixir:1.19.5-otp-27

# Sistem paketleri
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    postgresql-client \
    nodejs \
    npm \
    inotify-tools \
    && rm -rf /var/lib/apt/lists/*

# Hex + Rebar
RUN mix local.hex --force && mix local.rebar --force

# Phoenix CLI
RUN mix archive.install hex phx_new

WORKDIR /app
CMD ["bash"]
