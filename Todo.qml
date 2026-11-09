pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Your personal to-do list, kept in todo.json (hand-editable, picked up live). Items are
// {id, text, done, created, done_at, repeat, due, last_done}. Limits follow PatchGoblin's Todo
// plugin: 500 items of up to 500 characters.
//
// A recurring item has a `repeat` rule and a `due` date (YYYY-MM-DD). It counts as open from its
// due day on, and ticking it off doesn't finish it: it schedules the next occurrence after today
// (or after its due date, when done early). Rules:
//   {every: "day"} · {every: "weekday"} (Mon–Fri) · {every: "week", days: [0–6, Sunday = 0]}
//   {every: "month", date: 1–31 (short months use their last day)} · {every: "days", n: 1–365}
Singleton {
    id: root

    readonly property int maxItems: 500
    readonly property int maxText: 500
    readonly property var dayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    property var items: []
    property var writes: []             // recent texts we wrote, so the file watcher doesn't reload our own writes
    property string today: ymd(new Date())
    readonly property int openCount: items.filter(i => isOpen(i)).length

    function isOpen(i) { return i.repeat ? i.due <= today : !i.done; }

    // ---- dates (local, as YYYY-MM-DD) --------------------------------------------------
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function ymd(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
    function parseYmd(s) { const p = s.split("-").map(Number); return new Date(p[0], p[1] - 1, p[2]); }
    function addDays(s, n) { const d = parseYmd(s); d.setDate(d.getDate() + n); return ymd(d); }
    function daysBetween(a, b) { return Math.round((parseYmd(b) - parseYmd(a)) / 86400000); }

    // ---- repeat rules ------------------------------------------------------------------
    function cleanRule(r) {
        if (!r || typeof r !== "object") return null;
        const every = r.every;
        if (every === "day" || every === "weekday") return { every: every };
        if (every === "week") {
            const days = (Array.isArray(r.days) ? r.days : []).map(Number).filter(d => d >= 0 && d <= 6);
            const unique = days.filter((d, i) => days.indexOf(d) === i).sort();
            return unique.length ? { every: every, days: unique } : null;
        }
        if (every === "month") {
            const date = Math.round(Number(r.date));
            return date >= 1 && date <= 31 ? { every: every, date: date } : null;
        }
        if (every === "days") {
            const n = Math.round(Number(r.n));
            return n >= 1 && n <= 365 ? { every: every, n: n } : null;
        }
        return null;
    }
    function matches(rule, s) {
        const d = parseYmd(s), dow = d.getDay();
        if (rule.every === "day") return true;
        if (rule.every === "weekday") return dow >= 1 && dow <= 5;
        if (rule.every === "week") return rule.days.indexOf(dow) >= 0;
        if (rule.every === "month") {
            const last = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
            return d.getDate() === Math.min(rule.date, last);
        }
        return false;
    }
    // The first occurrence on or after `s`.
    function firstFrom(rule, s) {
        if (rule.every === "days") return s;
        for (let i = 0; i < 400; i++) {
            const c = addDays(s, i);
            if (matches(rule, c)) return c;
        }
        return s;
    }
    // The occurrence after `s`.
    function nextAfter(rule, s) {
        return rule.every === "days" ? addDays(s, rule.n) : firstFrom(rule, addDays(s, 1));
    }
    function describe(rule) {
        if (!rule) return "";
        if (rule.every === "day") return "Daily";
        if (rule.every === "weekday") return "Weekdays";
        if (rule.every === "week") return rule.days.length === 7 ? "Daily" : "Weekly on " + rule.days.map(d => dayNames[d]).join(", ");
        if (rule.every === "month") {
            const n = rule.date, suffix = n % 10 === 1 && n !== 11 ? "st" : n % 10 === 2 && n !== 12 ? "nd" : n % 10 === 3 && n !== 13 ? "rd" : "th";
            return "Monthly on the " + n + suffix;
        }
        return rule.n === 1 ? "Daily" : "Every " + rule.n + " days";
    }

    // ---- changes -----------------------------------------------------------------------
    function newId() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 8); }
    function cleanText(text) { return String(text || "").replace(/[\r\n]+/g, " ").trim(); }

    // Returns an error message, or "" when the item was added.
    function add(text, rule) {
        text = cleanText(text);
        if (!text) return "Type something to add.";
        if (text.length > maxText) return "A to-do can be at most " + maxText + " characters.";
        if (items.length >= maxItems) return "The list is full (" + maxItems + " items). Clear some done items first.";
        rule = cleanRule(rule);
        save([{ id: newId(), text: text, done: false, created: Date.now() / 1000, done_at: null,
                repeat: rule, due: rule ? firstFrom(rule, today) : null, last_done: null }].concat(items));
        return "";
    }
    function update(id, change) {
        save(items.map(i => i.id === id ? Object.assign({}, i, change) : i));
    }
    // Tick off. For a recurring item, returns the next due date it was moved to.
    function toggle(id) {
        const item = items.find(i => i.id === id);
        if (!item) return "";
        if (item.repeat) {
            const next = nextAfter(item.repeat, item.due > today ? item.due : today);
            update(id, { due: next, last_done: Date.now() / 1000 });
            return next;
        }
        update(id, { done: !item.done, done_at: item.done ? null : Date.now() / 1000 });
        return "";
    }
    function edit(id, text) {
        text = cleanText(text);
        if (!text) return "A to-do can't be empty.";
        if (text.length > maxText) return "A to-do can be at most " + maxText + " characters.";
        update(id, { text: text });
        return "";
    }
    // Set (or with null, clear) an item's repeat rule; it's next due on the first matching day from today.
    function setRepeat(id, rule) {
        rule = cleanRule(rule);
        update(id, rule ? { repeat: rule, due: firstFrom(rule, today), done: false, done_at: null }
                        : { repeat: null, due: null });
    }
    function remove(id) { save(items.filter(i => i.id !== id)); }
    function clearDone() { save(items.filter(i => i.repeat || !i.done)); }
    // Swap with the next visible item in that direction, so reordering a filtered view only
    // moves items among what you can see.
    function move(id, by, visibleIds) {
        const v = visibleIds.indexOf(id), other = visibleIds[v + by];
        if (v < 0 || other === undefined) return;
        const next = items.slice(), a = next.findIndex(i => i.id === id), b = next.findIndex(i => i.id === other);
        [next[a], next[b]] = [next[b], next[a]];
        save(next);
    }

    function clean(raw) {
        if (!Array.isArray(raw)) return [];
        const seen = {};
        return raw.filter(i => i && typeof i.text === "string" && i.text.trim() && typeof i.id === "string" && !seen[i.id] && (seen[i.id] = true))
            .slice(0, maxItems)
            .map(i => {
                const rule = cleanRule(i.repeat);
                const due = rule && typeof i.due === "string" && /^\d{4}-\d\d-\d\d$/.test(i.due) ? i.due : rule ? firstFrom(rule, today) : null;
                return { id: i.id, text: i.text.trim().slice(0, maxText), done: !rule && i.done === true,
                         created: typeof i.created === "number" ? i.created : Date.now() / 1000,
                         done_at: !rule && i.done === true && typeof i.done_at === "number" ? i.done_at : null,
                         repeat: rule, due: due, last_done: typeof i.last_done === "number" ? i.last_done : null };
            });
    }
    function save(next) {
        items = next;
        const text = JSON.stringify({ items: next }, null, 4) + "\n";
        writes = writes.concat([text]).slice(-8);
        file.setText(text);
    }

    // Roll `today` over at midnight, so recurring items come due without a restart.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.today = root.ymd(new Date())
    }

    FileView {
        id: file
        path: Quickshell.shellPath("todo.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            if (root.writes.indexOf(t) >= 0) return;
            try {
                root.items = root.clean(JSON.parse(t).items);
            } catch (e) {
                console.warn("qs-launchpad: todo.json is not valid JSON:", e);
            }
        }
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) root.save([]); }
    }
}
