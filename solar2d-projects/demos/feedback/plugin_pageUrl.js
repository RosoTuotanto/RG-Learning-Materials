// HTML5-only plugin. Reports the URL of the page the demo is running on, so that the
// Lua side can pick a language from it. Nothing else.
//
// Solar2D's HTML5 loader turns require("plugin.pageUrl") into a lookup for this file
// (dots become underscores) and proxies the window object of the same name into Lua.
// The call boundary is JSON over UTF-8, so returning a string is safe.
//
// The demo is meant to be embedded in a lesson page through an iframe, and the page
// that decides the language is the parent, not the iframe. Three sources are tried in
// order of how much they can be trusted:
//
//   1. The parent's own URL, readable only when the embed is same-origin.
//   2. The referrer, which is the parent page's URL for an iframe and survives a
//      cross-origin embed, unless the page sets a referrer policy that strips it.
//   3. This document's own URL, which is what a directly opened build sees.

window.plugin_pageUrl = {
	getPageUrl: function () {
		try {
			if (window.parent && window.parent !== window && window.parent.location.href) {
				return window.parent.location.href;
			}
		} catch (error) {
			// Cross-origin parent. Expected, and the referrer covers it.
		}

		if (window.parent !== window && document.referrer) {
			return document.referrer;
		}

		return window.location.href;
	},
};
