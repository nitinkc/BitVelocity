# Database initialization script for BitVelocity
# Creates schemas for different domains following the architecture

# eCommerce domain schemas
CREATE SCHEMA IF NOT EXISTS ecommerce;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS product;
CREATE SCHEMA IF NOT EXISTS order_mgmt;

# Chat domain schema  
CREATE SCHEMA IF NOT EXISTS chat;
CREATE SCHEMA IF NOT EXISTS messaging;

# IoT domain schema
CREATE SCHEMA IF NOT EXISTS iot;
CREATE SCHEMA IF NOT EXISTS telemetry;

# Social domain schema
CREATE SCHEMA IF NOT EXISTS social;
CREATE SCHEMA IF NOT EXISTS social_pulse;

# ML/AI domain schema
CREATE SCHEMA IF NOT EXISTS ml;
CREATE SCHEMA IF NOT EXISTS fraud_detection;

# Observability schema
CREATE SCHEMA IF NOT EXISTS observability;
CREATE SCHEMA IF NOT EXISTS metrics;

-- Create a generic user for development
CREATE USER bv_dev WITH PASSWORD 'bv_dev_password';
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE bitvelocity TO bv_dev;