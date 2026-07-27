const request = require("supertest");
const app = require("./app");

test("GET /healthz returns ok", async () => {
  const res = await request(app).get("/healthz");
  expect(res.statusCode).toBe(200);
  expect(res.body.status).toBe("ok");
});
