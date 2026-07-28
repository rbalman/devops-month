// Entry point: start the HTTP server. Kept separate from app.js so tests import
// the app without binding a port.
const app = require("./app");

const port = Number(process.env.PORT) || 3000;
app.listen(port, () => {
  console.log(`backend listening on :${port}`);
});
