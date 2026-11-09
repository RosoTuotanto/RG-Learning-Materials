// Shows the crash panel when the app reports a Lua error (see html5_build_patcher.py).
(() => {
    const frame = document.querySelector(".game-frame");
    const panel = document.querySelector(".crash-panel");
    const errorText = panel.querySelector(".crash-error");
    const reloadButton = panel.querySelector(".crash-reload");

    window.addEventListener("message", (event) => {
        const data = event.data;
        if (event.source !== frame.contentWindow || !data || data.type !== "app-crash" || !panel.hidden) {
            return;
        }

        errorText.textContent = data.message;
        panel.hidden = false;
        reloadButton.focus({ preventScroll: true });
    });

    reloadButton.addEventListener("click", () => {
        panel.hidden = true;
        errorText.textContent = "";
        frame.contentWindow.location.reload();
    });
})();
