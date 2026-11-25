-- Reference schema; Spring JPA creates and updates these tables in development.
CREATE TABLE IF NOT EXISTS farmers (
  id BIGSERIAL PRIMARY KEY,
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS farms (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  location VARCHAR(255) NOT NULL,
  area DOUBLE PRECISION NOT NULL CHECK (area > 0),
  user_id BIGINT NOT NULL REFERENCES farmers(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS crops (
  id BIGSERIAL PRIMARY KEY,
  farm_id BIGINT NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  crop_type VARCHAR(100) NOT NULL,
  planting_date DATE NOT NULL,
  expected_harvest_date DATE,
  growth_stage VARCHAR(80) NOT NULL,
  status VARCHAR(80) NOT NULL
);
CREATE TABLE IF NOT EXISTS scan_history (
  id BIGSERIAL PRIMARY KEY,
  crop_id BIGINT NOT NULL REFERENCES crops(id) ON DELETE CASCADE,
  image_path TEXT,
  predicted_disease VARCHAR(255) NOT NULL,
  confidence DOUBLE PRECISION NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  scan_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  recommendations TEXT
);
CREATE TABLE IF NOT EXISTS irrigation_logs (
  id BIGSERIAL PRIMARY KEY,
  crop_id BIGINT NOT NULL REFERENCES crops(id) ON DELETE CASCADE,
  water_amount DOUBLE PRECISION NOT NULL CHECK (water_amount >= 0),
  soil_moisture INTEGER NOT NULL CHECK (soil_moisture BETWEEN 0 AND 100),
  irrigation_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  notes TEXT
);
CREATE TABLE IF NOT EXISTS soil_measurements (
  id BIGSERIAL PRIMARY KEY,
  crop_id BIGINT NOT NULL REFERENCES crops(id) ON DELETE CASCADE,
  moisture_percentage INTEGER NOT NULL CHECK (moisture_percentage BETWEEN 0 AND 100),
  temperature DOUBLE PRECISION,
  measurement_date TIMESTAMPTZ NOT NULL DEFAULT now()
);
