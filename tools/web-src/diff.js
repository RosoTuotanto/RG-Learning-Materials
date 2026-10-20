// Diff page behaviour: view toggle, saved view choice, and gap expansion.
(() => {
    const STORAGE_KEY = "rg-diff-view";
    const DEFAULT_VIEW = "unified";
    const VIEWS = ["unified", "split"];

    const toggle = document.querySelector(".diff-toggle");
    const viewButtons = toggle ? toggle.querySelectorAll("button[data-view]") : [];
    const parsedSources = new WeakMap();

    // Chromium throws from the localStorage getter itself when storage is blocked.
    const withStorage = (action, fallback) => {
        try {
            return action(window.localStorage);
        } catch (error) {
            // Without storage only the remembered view is lost; the page works on the fallback.
            return fallback;
        }
    };

    const readView = () => {
        const stored = withStorage((storage) => storage.getItem(STORAGE_KEY), null);
        return VIEWS.includes(stored) ? stored : DEFAULT_VIEW;
    };

    const saveView = (view) => withStorage((storage) => storage.setItem(STORAGE_KEY, view), null);

    const applyView = (view) => {
        document.querySelectorAll(".diff-files[data-view]").forEach((files) => {
            files.dataset.view = view;
        });

        viewButtons.forEach((button) => {
            button.setAttribute("aria-pressed", button.dataset.view === view ? "true" : "false");
        });
    };

    if (toggle) {
        toggle.hidden = false;
        applyView(readView());

        viewButtons.forEach((button) => {
            button.addEventListener("click", () => {
                applyView(button.dataset.view);
                saveView(button.dataset.view);
            });
        });
    }

    const sourceLines = (file) => {
        if (!parsedSources.has(file)) {
            parsedSources.set(file, JSON.parse(file.querySelector("script.diff-source").textContent));
        }

        return parsedSources.get(file);
    };

    const createCell = (className) => {
        const cell = document.createElement("td");
        cell.className = className;
        return cell;
    };

    const numberCell = (line) => {
        const cell = createCell("diff-num");
        cell.dataset.line = String(line);
        return cell;
    };

    const codeCell = (text) => {
        const cell = createCell("diff-code");
        cell.textContent = text;
        return cell;
    };

    const contextRow = (isSplit, oldLine, newLine, text) => {
        const row = document.createElement("tr");
        row.className = "diff-ctx";

        if (isSplit) {
            row.append(
                numberCell(oldLine), createCell("diff-sign"), codeCell(text),
                numberCell(newLine), createCell("diff-sign"), codeCell(text)
            );
        } else {
            row.append(numberCell(oldLine), numberCell(newLine), createCell("diff-sign"), codeCell(text));
        }

        return row;
    };

    const expandGap = (button) => {
        const clickedRow = button.closest("tr.diff-gap");
        const file = button.closest(".diff-file");
        const oldStart = Number(clickedRow.dataset.oldStart);
        const newStart = Number(clickedRow.dataset.newStart);
        const count = Number(clickedRow.dataset.count);
        const lines = sourceLines(file).slice(newStart - 1, newStart - 1 + count);
        const selector = `tr.diff-gap[data-gap="${CSS.escape(clickedRow.dataset.gap)}"]`;
        let focusTarget;

        file.querySelectorAll(selector).forEach((gapRow) => {
            const isSplit = gapRow.closest("table").classList.contains("diff-split");
            const rows = lines.map((text, index) => contextRow(isSplit, oldStart + index, newStart + index, text));

            if (gapRow === clickedRow) {
                focusTarget = rows[0].querySelector(".diff-code");
            }

            gapRow.replaceWith(...rows);
        });

        // The button is gone, so keep focus at the same spot in the reading order.
        focusTarget.tabIndex = -1;
        focusTarget.focus({ preventScroll: true });
    };

    document.addEventListener("click", (event) => {
        const button = event.target.closest("button.diff-expand");

        if (button) {
            expandGap(button);
        }
    });
})();
