const express = require("express");

const app = express();

app.get("/healthz", (req, res) => res.json({ status: "ok" }));
app.get("/", (req, res) => res.send("Hello from the API tier"));

module.exports = app;
