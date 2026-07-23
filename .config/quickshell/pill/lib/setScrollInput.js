function escapeRe(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function getTouchpadField(text, name) {
    var blockRe = /input\s+type:touchpad\s*\{([^}]*)\}/i;
    var m = blockRe.exec(text);
    if (!m) return "";
    var re = new RegExp("\\b" + escapeRe(name) + "\\s+(\\S+)");
    var vm = re.exec(m[1]);
    return vm ? vm[1] : "";
}

function setTouchpadField(text, name, value) {
    var blockRe = /(input\s+type:touchpad\s*\{)([^}]*)(\})/i;
    var m = blockRe.exec(text);
    if (!m) return { text: text, ok: false };
    var before = m[1], block = m[2], after = m[3];
    var re = new RegExp("(\\s*)" + escapeRe(name) + "\\s+\\S+");
    if (re.test(block)) {
        block = block.replace(re, "$1" + name + " " + value);
    } else {
        block = block.replace(/(\r?\n?)$/, "\n       " + name + " " + value + "$1");
    }
    return { text: before + block + after, ok: true };
}

function getOutputScale(text, name) {
    var re = new RegExp("output\\s+" + escapeRe(name) + "\\s+.*?\\bscale\\s+([\\d.]+)");
    var m = re.exec(text);
    return m ? parseFloat(m[1]) : 0;
}

function setOutputScale(text, name, scale) {
    var re = new RegExp("(output\\s+" + escapeRe(name) + "\\s+.*?)\\bscale\\s+[\\d.]+");
    if (re.test(text))
        return { text: text.replace(re, "$1scale " + scale), ok: true };
    return { text: text + ("\noutput " + name + " scale " + scale), ok: true };
}

function getOutputAdaptiveSync(text, name) {
    var re = new RegExp("output\\s+" + escapeRe(name) + "\\s+.*?\\badaptive_sync\\s+(on|off)");
    var m = re.exec(text);
    return m ? m[1] : "";
}

function setOutputAdaptiveSync(text, name, value) {
    var re = new RegExp("(output\\s+" + escapeRe(name) + "\\s+.*?)\\badaptive_sync\\s+(on|off)");
    if (re.test(text))
        return { text: text.replace(re, "$1adaptive_sync " + value), ok: true };
    return { text: text + ("\noutput " + name + " force adaptive_sync " + value), ok: true };
}

function getCursorTheme(text) {
    var re = /xcursor_theme\s+(\S+)/;
    var m = re.exec(text);
    return m ? m[1] : "";
}

function getCursorSize(text) {
    var re = /xcursor_theme\s+\S+\s+(\d+)/;
    var m = re.exec(text);
    return m ? parseInt(m[1]) : 0;
}

function setCursorLine(text, theme, size) {
    var re = /(xcursor_theme\s+)\S+(\s+\d+)?/;
    if (re.test(text)) {
        return { text: text.replace(re, "$1" + theme + " " + size), ok: true };
    }
    if (text.length > 0 && !text.endsWith("\n")) text += "\n";
    return { text: text + "seat seat0 xcursor_theme " + theme + " " + size + "\n", ok: true };
}
