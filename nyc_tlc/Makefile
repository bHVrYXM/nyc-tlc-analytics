.PHONY: setup data build test dashboard clean

WAREHOUSE_PATH ?= ./data/warehouse.duckdb

# ── Setup ────────────────────────────────────────────────────────────────────
# Install Python deps and dbt packages. Run once after cloning.
setup:
	pip install -r requirements.txt
	dbt deps

# ── Data ─────────────────────────────────────────────────────────────────────
# Download raw TLC parquet files (Jan–Mar 2024 by default).
# Scale up by extending the loop or adding more months.
data:
	mkdir -p data/raw
	@for month in 2024-01 2024-02 2024-03; do \
		curl -C - -o data/raw/yellow_tripdata_$$month.parquet \
			"https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_$$month.parquet"; \
		curl -C - -o data/raw/green_tripdata_$$month.parquet \
			"https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_$$month.parquet"; \
		curl -C - -o data/raw/fhvhv_tripdata_$$month.parquet \
			"https://d37ci6vzurychx.cloudfront.net/trip-data/fhvhv_tripdata_$$month.parquet"; \
	done
	curl -C - -o data/raw/taxi_zone_lookup.csv \
		"https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"

# ── Build ─────────────────────────────────────────────────────────────────────
# Run all dbt models.
build:
	dbt run

# ── Test ──────────────────────────────────────────────────────────────────────
# Run dbt tests against the built models.
test:
	dbt test

# ── Dashboard ─────────────────────────────────────────────────────────────────
# Build the Evidence.dev static site.
dashboard:
	cd dashboard && npm install && npm run build

# ── Clean ─────────────────────────────────────────────────────────────────────
# Remove all generated files. Does NOT delete downloaded raw data.
clean:
	rm -rf target/ dbt_packages/ logs/
	rm -rf dashboard/build/ dashboard/.evidence/
	@echo "Note: data/raw/ preserved. Run 'make clean-data' to remove it too."

clean-data:
	rm -rf data/
