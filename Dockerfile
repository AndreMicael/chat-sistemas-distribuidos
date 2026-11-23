# Imagem oficial, com versões explícitas de Elixir e da família Erlang/OTP.
FROM elixir:1.20.5-otp-27-slim

ENV MIX_ENV=prod
WORKDIR /app

# A imagem slim não mantém o pacote de certificados após sua própria montagem.
# Mix precisa dessas autoridades certificadoras para baixar Hex/Rebar via HTTPS.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only prod --check-locked && mix deps.compile

COPY lib ./lib
COPY priv ./priv
COPY test ./test
COPY .formatter.exs ./
RUN mix compile --warnings-as-errors

EXPOSE 4000
CMD ["mix", "phx.server"]
