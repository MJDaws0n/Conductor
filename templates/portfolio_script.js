const tabs = Array.from(document.querySelectorAll("[data-tab]"));
const panels = Array.from(document.querySelectorAll(".panel"));
const jumpButtons = Array.from(document.querySelectorAll("[data-tab-jump], [data-tab-link]"));

function showTab(name) {
  tabs.forEach((tab) => {
    const active = tab.dataset.tab === name;
    tab.classList.toggle("active", active);
    tab.setAttribute("aria-selected", active ? "true" : "false");
  });

  panels.forEach((panel) => {
    const active = panel.id === name;
    panel.hidden = !active;
    requestAnimationFrame(() => panel.classList.toggle("active", active));
  });

  history.replaceState(null, "", `#${name}`);
}

tabs.forEach((tab) => {
  tab.addEventListener("click", () => showTab(tab.dataset.tab));
});

jumpButtons.forEach((button) => {
  button.addEventListener("click", (event) => {
    const target = button.dataset.tabJump || button.dataset.tabLink;
    if (!target) return;
    event.preventDefault();
    showTab(target);
  });
});

const initial = window.location.hash.replace("#", "");
if (initial && panels.some((panel) => panel.id === initial)) {
  showTab(initial);
}
