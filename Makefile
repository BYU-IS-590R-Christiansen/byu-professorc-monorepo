.PHONY: start start-dev start-prod stop clean build-frontend build-backend setup-backend migrate aws-deploy aws-status aws-logs aws-cleanup aws-manifests setup_infrastructure

# Start all services
start:
	@echo "Starting BYU 590R Monorepo..."
	@echo "Cleaning up any existing containers..."
	@$(MAKE) stop
	@echo "Checking Laravel backend configuration..."
	@$(MAKE) setup-backend
	@echo "Installing Laravel backend dependencies locally..."
	cd backend && composer install
	@echo "Starting Laravel backend with MySQL..."
	cd backend && docker compose up -d --build
	@echo "Waiting for database to be ready..."
	@cd backend && mysql_ready=0 && for i in $$(seq 1 30); do \
		if docker compose exec -T mysql mysqladmin ping -h localhost --silent 2>/dev/null; then \
			echo "MySQL is ready!"; mysql_ready=1; break; \
		fi; \
		echo "Waiting for MySQL... ($$i/30)"; sleep 2; \
	done && if [ $$mysql_ready -ne 1 ]; then echo "ERROR: MySQL did not become ready in time."; exit 1; fi
	@echo "Ensuring database 'app_db' exists..."
	@cd backend && docker compose exec -T mysql mysql -u root -prootpassword -e "CREATE DATABASE IF NOT EXISTS app_db;" 2>/dev/null || true
	@cd backend && docker compose exec -T mysql mysql -u root -prootpassword -e "CREATE USER IF NOT EXISTS 'app_user'@'%' IDENTIFIED BY 'app_password';" 2>/dev/null || true
	@cd backend && docker compose exec -T mysql mysql -u root -prootpassword -e "GRANT ALL PRIVILEGES ON app_db.* TO 'app_user'@'%'; FLUSH PRIVILEGES;" 2>/dev/null || true
	@echo "Using Laravel backend dependencies from local install (backend/vendor)..."
	@echo "Clearing Laravel caches and regenerating autoloader..."
	cd backend && docker compose exec -T app composer dump-autoload -o || true
	cd backend && docker compose exec -T app php artisan config:clear || true
	cd backend && docker compose exec -T app php artisan route:clear || true
	cd backend && docker compose exec -T app php artisan view:clear || true
	cd backend && docker compose exec -T app php artisan package:discover || true
	@echo "Running database migrations and seeding..."
	@$(MAKE) migrate
	@echo "Setting up demo book images for local storage..."
	cd backend && docker compose exec -T app php artisan app:setup-demo-images
	@echo "Clearing all caches after migrations..."
	cd backend && docker compose exec -T app php artisan optimize:clear || true
	@echo "Detecting environment..."
	@if [ -n "$$DEVELOPMENT_MODE" ] && [ "$$DEVELOPMENT_MODE" = "true" ]; then \
		echo "Development mode explicitly enabled - starting with hot reloading..."; \
		$(MAKE) start-dev; \
	elif [ -n "$$PRODUCTION_MODE" ] && [ "$$PRODUCTION_MODE" = "true" ]; then \
		echo "Production mode explicitly enabled - building static frontend..."; \
		$(MAKE) start-prod; \
	elif [ "$$(hostname)" = "localhost" ] || [ "$$(hostname)" = "$$(hostname -s)" ] || [ -z "$$HOSTNAME" ] || [ "$$HOSTNAME" = "localhost" ] || [ "$$(uname -s)" = "Darwin" ] || [ "$$(uname -s)" = "Linux" ]; then \
		echo "Localhost/development environment detected - starting with hot reloading..."; \
		$(MAKE) start-dev; \
	else \
		echo "Production environment detected - building static frontend..."; \
		$(MAKE) start-prod; \
	fi
	@echo "Finalizing Laravel setup..."
	@echo "Generating application key to ensure encryption is properly configured..."
	cd backend && docker compose exec -T app php artisan key:generate || true
	@echo "Clearing caches one final time..."
	cd backend && docker compose exec -T app php artisan optimize:clear || true
	@echo "All processes completed successfully!"

# Start with hot reloading (development mode)
start-dev:
	@echo "Starting Angular development server with hot reloading..."
	@echo "Installing Angular dependencies..."
	cd web-app && npm install
	@echo "Frontend will be available at: http://localhost:4200"
	@echo "Backend API: http://localhost:8000"
	@echo "Database: localhost:3307"
	@echo ""
	@echo "Starting Angular dev server in background..."
	cd web-app && npm start &
	@echo "Development environment started with hot reloading!"
	@echo "Press Ctrl+C to stop all services"

# Start with static build (production mode)
start-prod:
	@echo "Building and starting Angular frontend..."
	@echo "Removing any existing frontend image to ensure fresh build..."
		docker rmi byu-590r-frontend || true
	cd web-app && docker build -t byu-590r-frontend . && docker run -d -p 3000:80 --name byu-590r-frontend byu-590r-frontend
	@echo "All services started!"
	@echo "Frontend: http://localhost:3000"
	@echo "Backend API: http://localhost:8000"
	@echo "Database: localhost:3307"

# Run database migrations and seed; used by start
migrate:
	cd backend && docker compose exec -T app php artisan migrate:fresh --force --seed

# Stop all services
stop:
	@echo "Stopping all services..."
	cd backend && docker compose down
	docker stop byu-590r-frontend || true
	docker rm byu-590r-frontend || true
	@echo "Stopping Angular dev server..."
	pkill -f "ng serve" || true
	pkill -f "npm start" || true
	@echo "All services stopped!"

# Clean up everything
clean: stop
	@echo "Cleaning up..."
	cd backend && docker compose down -v
	docker rmi byu-590r-frontend || true
	docker system prune -f
	@echo "Cleanup complete!"


# Help
help:
	@echo "Available commands:"
	@echo "  start        - Start all services (auto-detects environment)"
	@echo "  start-dev    - Start with hot reloading (development mode)"
	@echo "  start-prod   - Start with static build (production mode)"
	@echo "  stop         - Stop all services"
	@echo "  clean        - Stop and clean up everything"
	@echo "  help         - Show this help message"
	@echo ""
