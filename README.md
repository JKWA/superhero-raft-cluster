# MissionControl Cluster

Welcome to the MissionControl MissionControl project! This README will guide you through the setup process and explain how to run various tasks using Visual Studio Code.

## Prerequisites

Before you begin, make sure you have the following software installed on your machine:

- [Visual Studio Code](https://code.visualstudio.com/download)
- [Phoenix Framework](https://hexdocs.pm/phoenix/installation.html)
- [Make](https://sp21.datastructur.es/materials/guides/make-install.html)

## Getting Started

### 1. Clone the Repository

Start by cloning the repository to your local machine:

```sh
git clone https://github.com/JKWA/superhero-dynamic-cluster.git
cd superhero-dynamic-cluster
```

### 2. Install Dependencies

Install dependencies, if you have a Makefile installed, simply run:

```sh
make setup
```

## Tasks Overview

The project includes Visual Studio Code tasks defined in `.vscode/tasks.json`.

### Run the Task

This project includes a `tasks.json` for Visual Studio Code.

1. Open the Command Palette by pressing `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS).
2. Type "Run Task" and select it from the list.
3. Choose "Run MissionControl Cluster"

This task will execute a series of scripts to start the nodes in the cluster, ensuring each component of the system is initiated correctly.

- Gotham runs on [http://localhost:4900](http://localhost:4900)
- Metropolis runs on [http://localhost:4901](http://localhost:4901)
- Capitol runs on [http://localhost:4902](http://localhost:4902)