// Route tests with a FAKE Postgres pool injected via setPool() — so CI needs no
// database. We assert the HTTP contract (status codes + shapes), not real SQL.
const request = require("supertest");
const app = require("../src/app");
const { setPool } = require("../src/db");

// Minimal stub: each test sets `query` to whatever it needs.
const fakePool = { query: jest.fn() };
setPool(fakePool);

beforeEach(() => {
  fakePool.query.mockReset();
});

describe("GET /api/healthz", () => {
  it("returns ok when the DB responds", async () => {
    fakePool.query.mockResolvedValueOnce({ rows: [{ "?column?": 1 }] });
    const res = await request(app).get("/api/healthz");
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: "ok", db: "up" });
  });

  it("returns 503 when the DB is unreachable", async () => {
    fakePool.query.mockRejectedValueOnce(new Error("connection refused"));
    const res = await request(app).get("/api/healthz");
    expect(res.status).toBe(503);
    expect(res.body.db).toBe("down");
  });
});

describe("GET /api/items", () => {
  it("returns the rows from the pool", async () => {
    const rows = [{ id: 2, name: "buy milk", created_at: "2026-01-01T00:00:00Z" }];
    fakePool.query.mockResolvedValueOnce({ rows });
    const res = await request(app).get("/api/items");
    expect(res.status).toBe(200);
    expect(res.body).toEqual(rows);
  });
});

describe("POST /api/items", () => {
  it("rejects a missing name with 400", async () => {
    const res = await request(app).post("/api/items").send({});
    expect(res.status).toBe(400);
    expect(fakePool.query).not.toHaveBeenCalled();
  });

  it("inserts and returns the new item with 201", async () => {
    const created = { id: 3, name: "walk dog", created_at: "2026-01-02T00:00:00Z" };
    fakePool.query.mockResolvedValueOnce({ rows: [created] });
    const res = await request(app).post("/api/items").send({ name: "walk dog" });
    expect(res.status).toBe(201);
    expect(res.body).toEqual(created);
    expect(fakePool.query).toHaveBeenCalledWith(expect.stringContaining("INSERT"), [
      "walk dog",
    ]);
  });
});
