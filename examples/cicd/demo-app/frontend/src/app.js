// The whole client. It only ever talks to /api — nginx proxies that to the
// backend, so the browser never needs to know where the backend lives.
const itemsEl = document.getElementById("items");
const statusEl = document.getElementById("status");
const form = document.getElementById("add-form");
const nameInput = document.getElementById("name");

function setStatus(msg, isError) {
  statusEl.textContent = msg || "";
  statusEl.classList.toggle("error", Boolean(isError));
}

function render(items) {
  if (!items.length) {
    itemsEl.innerHTML = '<li class="empty">No items yet — add one.</li>';
    return;
  }
  itemsEl.innerHTML = "";
  for (const item of items) {
    const li = document.createElement("li");
    li.textContent = item.name;
    itemsEl.appendChild(li);
  }
}

async function load() {
  try {
    const res = await fetch("/api/items");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    render(await res.json());
    setStatus("");
  } catch (err) {
    setStatus(`Could not load items: ${err.message}`, true);
  }
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  const name = nameInput.value.trim();
  if (!name) return;
  try {
    const res = await fetch("/api/items", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    nameInput.value = "";
    await load();
  } catch (err) {
    setStatus(`Could not add item: ${err.message}`, true);
  }
});

load();
