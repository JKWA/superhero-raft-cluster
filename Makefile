setup:
	@echo "Running mix deps.get in dispatch"
	mix deps.get
	@echo "Cleaning old builds in dispatch"
	mix clean
	@echo "Compiling new build in dispatch"
	mix compile
