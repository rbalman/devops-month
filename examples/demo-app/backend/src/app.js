// The Express app — exported WITHOUT calling listen(), so tests can import it
// and drive it with supertest without opening a real port (server.js does the
// listening). Same split as the Day 1 first-pipeline sample.
const express = require("express");
const { getPool } = require("./db");

const app = express();
app.use(express.json());

// Liveness + DB readiness in one probe. The ALB target group health check and
// `docker compose` both hit this. `SELECT 1` proves the pool can reach Postgres.
app.get("/api/healthz", async (_req, res) => {
  try {
    await getPool().query("SELECT 1");
    res.json({ status: "ok", db: "up" });
  } catch (err) {
    res.status(503).json({ status: "degraded", db: "down", error: err.message });
  }
});

// List items, newest first.
app.get("/api/items", async (_req, res) => {
  try {
    const { rows } = await getPool().query(
      "SELECT id, name, created_at FROM items ORDER BY id DESC"
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Add an item. Body: { "name": "..." }.
app.post("/api/items", async (req, res) => {
  const name = (req.body && req.body.name ? String(req.body.name) : "").trim();
  if (!name) {
    return res.status(400).json({ error: "name is required" });
  }
  try {
    const { rows } = await getPool().query(
      "INSERT INTO items (name) VALUES ($1) RETURNING id, name, created_at",
      [name]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = app;
