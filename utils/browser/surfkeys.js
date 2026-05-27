api.iunmap("<Ctrl-Alt-i>");
api.iunmap("<Ctrl-i>");
api.iunmap("<Ctrl-'>");
api.iunmap("<Ctrl-e>");
api.iunmap("<Ctrl-a>");
api.iunmap("<Ctrl-u>");
api.iunmap("<Alt-b>");
api.iunmap("<Alt-f>");
api.iunmap("<Alt-w>");
api.iunmap("<Alt-d>");

api.map("s", "f");
api.map("S", "C");
api.map("<Ctrl+C>", "yy");
api.map("<Ctrl+p>", "<Alt-i>");
api.unmapAllExcept(["<Ctrl+p>", "<Ctrl+C>", "<Esc>",
  "h", "j", "k", "l", "G", "c", "g", "i", "s", "S", "<<", ">>"]);

// --- github style theme, ignore ---
const hintsCss =
  "font-size: 8pt; font-family: JetBrains Mono NL, Cascadia Code, SauceCodePro Nerd Font, Consolas, Menlo, monospace; border: 0px; color: #0366d6; background: initial; background-color: #ffffff";
api.Hints.style(hintsCss);
api.Hints.style(hintsCss, "text");
settings.theme = `
.sk_theme {
  font-family: JetBrains Mono NL, Cascadia Code, SauceCodePro Nerd Font, Consolas, Menlo, monospace;
  font-size: 8pt;
  background: #ffffff;
  color: #24292f;
}
.sk_theme tbody {
  color: #ffffff;
}
.sk_theme input {
  color: #24292f;
}
.sk_theme .url {
  color: #24292f;
}
.sk_theme .annotation {
  color: #24292f;
}
.sk_theme .omnibar_highlight {
  color: #24292f;
}
.sk_theme #sk_omnibarSearchResult ul li:nth-child(odd) {
  background: #ffffff;
}
.sk_theme #sk_omnibarSearchResult ul li.focused {
  background: #0598bc;
}
#sk_status,
#sk_find {
  font-size: 10pt;
}
`;
