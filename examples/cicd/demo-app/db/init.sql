-- Runs once, on first boot of an empty Postgres data directory
-- (mounted at /docker-entrypoint-initdb.d/). Creates the schema the backend
-- expects and seeds a couple of rows so the UI isn't empty on first load.
CREATE TABLE IF NOT EXISTS items (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO items (name) VALUES
    ('Provision the VPC with Terraform'),
    ('Deploy the containers with Ansible');
