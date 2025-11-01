# MissionControl Cluster

Welcome to the MissionControl project!

## Prerequisites

- Erlang 28.0.1
- Elixir 1.18.4-otp-28

## Getting Started

### 1. Clone the Repository

Start by cloning the repository to your local machine:

```sh
git clone https://github.com/JKWA/superhero-dynamic-cluster.git
cd superhero-dynamic-cluster
```

### 2. Install Dependencies

```sh
mix deps.get
mix compile
```

Or if you have Make installed:

```sh
make setup
```

## Running the Cluster

You can run the cluster in your terminal or within VS Code.

### Run in Terminal using tmux

**Requires:** [Make](https://sp21.datastructur.es/materials/guides/make-install.html) and [tmux](https://github.com/tmux/tmux/wiki/Installing)

Start all 5 dispatch centers in a single tmux session:

```bash
make start-cluster
```

This starts all nodes in separate tmux panes, visible at once.

**View the cluster:**

```bash
make view-cluster
```

**Navigate between panes:**

- `Ctrl+b` then arrow keys to switch panes
- `Ctrl+b` then `z` to zoom in/out of current pane
- `Ctrl+b` then `d` to detach (leave running in background)

**Force kill a dispatch center:**

Within a pane, press `Ctrl+c` twice to kill the node:

```bash
iex> Ctrl+c Ctrl+c
```

**Stop the entire cluster:**

1. Detach from tmux: `Ctrl+b` then `d`
2. Stop the cluster:

```bash
make stop-cluster
```

### Run in VS Code with Tasks

**Requires:** [Visual Studio Code](https://code.visualstudio.com/download)

1. Open the Command Palette: `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
2. Type "Run Task" and select it
3. Choose "Run MissionControl Cluster"

This starts all 5 nodes in separate VS Code terminal panels. You can toggle between terminals to view each dispatch center and kill/restart individual nodes using VS Code's terminal controls.

## Accessing Dispatch Centers

Once the cluster is running, access any dispatch center in your browser:

- Gotham: [http://localhost:4900](http://localhost:4900)
- Metropolis: [http://localhost:4901](http://localhost:4901)
- Capitol: [http://localhost:4902](http://localhost:4902)
- Smallville: [http://localhost:4903](http://localhost:4903)
- Asgard: [http://localhost:4904](http://localhost:4904)
