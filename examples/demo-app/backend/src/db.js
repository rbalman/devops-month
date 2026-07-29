// A single shared Postgres connection pool, built from the environment.
//
// Two ways to configure it, in priority order:
//   1. DATABASE_URL      — postgres://user:pass@host:5432/db  (used locally + in compose)
//   2. discrete PG* vars — PGHOST/PGUSER/PGPASSWORD/PGDATABASE/PGPORT
//
// On the EC2 app instances these values come from GitHub secrets, rendered into
// the container's environment by Ansible — never hard-coded, never in git.
const { Pool } = require("pg");

function buildPool() {
  if (process.env.DATABASE_URL) {
    return new Pool({ connectionString: process.env.DATABASE_URL });
  }
  return new Pool({
    host: process.env.PGHOST || "db",
    port: Number(process.env.PGPORT) || 5432,
    user: process.env.PGUSER || "appuser",
    password: process.env.PGPASSWORD || "appsecret",
    database: process.env.PGDATABASE || "appdb",
  });
}

// Exported as a getter-backed singleton so tests can inject a fake pool
// (see test/app.test.js) without opening a real connection.
let pool;
function getPool() {
  if (!pool) pool = buildPool();
  return pool;
}
function setPool(p) {
  pool = p;
}

module.exports = { getPool, setPool };
