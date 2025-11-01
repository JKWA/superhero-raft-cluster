import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dispatch, MissionControlWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6M0al7Zgr8/chjnOx/iakFcSK9/5e0qS39pmeHecV8sXOW3qwctTRZqee9sAFZTt",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
