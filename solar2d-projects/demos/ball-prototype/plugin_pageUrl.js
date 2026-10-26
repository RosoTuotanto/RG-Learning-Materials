// Reports the hosting page's URL: the iframe's parent when same-origin, else the referrer, else this document's own.

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
