setup:
	@echo "Running mix deps.get"
	mix deps.get
	@echo "Cleaning old builds"
	mix clean
	@echo "Compiling new build"
	mix compile

start-cluster:
	@echo "Starting MissionControl cluster in tmux..."
	@tmux new-session -d -s mission_control \
		'PORT=4900 CITY_NAME=Gotham iex --name gotham@127.0.0.1 --cookie secret_superhero_cookie -S mix phx.server'
	@tmux split-window -v -t mission_control:0.0 \
		'PORT=4901 CITY_NAME=Metropolis iex --name metropolis@127.0.0.1 --cookie secret_superhero_cookie -S mix phx.server'
	@tmux split-window -v -t mission_control:0.1 \
		'PORT=4902 CITY_NAME=Capitol iex --name capitol@127.0.0.1 --cookie secret_superhero_cookie -S mix phx.server'
	@tmux select-pane -t mission_control:0.0
	@tmux split-window -h -t mission_control:0.0 \
		'PORT=4903 CITY_NAME=Smallville iex --name smallville@127.0.0.1 --cookie secret_superhero_cookie -S mix phx.server'
	@tmux select-pane -t mission_control:0.2
	@tmux split-window -h -t mission_control:0.2 \
		'PORT=4904 CITY_NAME=Asgard iex --name asgard@127.0.0.1 --cookie secret_superhero_cookie -S mix phx.server'
	@tmux select-layout -t mission_control tiled
	@echo "Cluster started in tmux session 'mission_control'"
	@echo "  Attach with: make view-cluster"
	@echo "  Navigate panes: Ctrl+b then arrow keys"
	@echo "  Stop cluster: make stop-cluster"

view-cluster:
	tmux attach -t mission_control

stop-cluster:
	@echo "Stopping MissionControl cluster..."
	@tmux kill-session -t mission_control 2>/dev/null || echo "Cluster not running"

.PHONY: setup cluster attach stop-cluster
