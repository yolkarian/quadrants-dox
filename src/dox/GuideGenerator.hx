package dox;

import sys.io.File;

using StringTools;

/**
	Generates HTML pages for the Markdown `Guide`s collected from
	`Config.guidesPath` and writes them into the Dox output site.

	Each guide is rendered with the same `MarkdownHandler` Dox uses for
	doc-comments, so type names mentioned in code spans link into the
	generated API pages. The result is wrapped in the `guide.mtt` template
	(which reuses `main.mtt`) so guides share the Dox theme chrome, sidebar
	nav, search, and dark-mode toggle.

	Guide pages are written at `<site>/<relPath>.html`, mirroring the source
	directory layout, and relative `.md` links are rewritten to `.html`.
**/
class GuideGenerator {
	final api:Api;
	final writer:Writer;
	final markdownHandler:MarkdownHandler;
	final tplGuide:templo.Template;
	final tplLanding:templo.Template;

	public function new(api:Api, writer:Writer) {
		this.api = api;
		this.writer = writer;
	this.markdownHandler = new MarkdownHandler(api.config, api.infos);
		this.tplGuide = api.config.loadTemplate("guide.mtt");
		this.tplLanding = api.config.loadTemplate("landing.mtt");
	}

	public function generate(guides:Array<Guide>):Int {
		var n = 0;
		for (guide in guides) {
			if (guide.isLanding) {
				continue; // landing is handled separately
			}
			api.config.rootPath = rootPathFor(guide.depth);
			api.currentPageName = guide.title;
			var body = renderGuideBody(guide);
			var html = tplGuide.execute({api: api, content: body, guide: guide});
			writer.saveContent(guide.relPath + ".html", html);
			n++;
		}
		return n;
	}

	/**
		Renders the landing `Guide` (relPath == "index") to `<site>/index.html`
		and moves Dox's generated toplevel package listing to `api.html` so the
		site root becomes the Markdown landing while the API entry remains one
		hop away. Returns false if no landing guide was collected (in which case
		Dox's index.html is left untouched).
	**/
	public function generateLanding(guides:Array<Guide>):Bool {
		var landing = null;
		for (g in guides) {
			if (g.isLanding) {
				landing = g;
				break;
			}
		}
		if (landing == null) {
			return false;
		}
		var site = api.config.outputPath;
		var doxIndex = haxe.io.Path.join([site, "index.html"]);
		var apiPage = haxe.io.Path.join([site, "api.html"]);
		if (sys.FileSystem.exists(doxIndex)) {
			sys.io.File.copy(doxIndex, apiPage);
		}
		api.config.rootPath = "./";
		api.currentPageName = api.config.pageTitle != null ? api.config.pageTitle : "Quadrants";
		var body = injectApiCta(renderGuideBody(landing));
		var html = tplLanding.execute({api: api, content: body, guide: landing});
		sys.io.File.saveContent(doxIndex, html);
		return true;
	}

	function injectApiCta(html:String):String {
		if (html.toLowerCase().indexOf('href="api.html"') >= 0) {
			return html;
		}
		var cta = '\n<p><a class="api-cta" href="api.html"><i class="fa fa-cube"></i> API reference</a></p>\n';
		var idx = html.indexOf("</h1>");
		if (idx < 0) {
			idx = html.indexOf("</h2>");
		}
		if (idx < 0) {
			return cta + html;
		}
		var end = idx + 5;
		return html.substr(0, end) + cta + html.substr(end);
	}

	/**
		Injects a "Guides" section (and an API reference link) into the
		Dox-generated nav.js so the sidebar lists guide pages alongside API
		types. Guide links use the `::rootPath::` placeholder that Dox's
		index.js resolves per page, so they work from any depth.
	**/
	public function injectNav(guides:Array<Guide>):Void {
		var navPath = haxe.io.Path.join([api.config.outputPath, "nav.js"]);
		if (!sys.FileSystem.exists(navPath)) {
			Sys.println('guides: warning: nav.js not found at $navPath; skipping nav injection');
			return;
		}
		var nav = sys.io.File.getContent(navPath);
		var marker = "var navContent='<ul class=\"nav nav-list\">";
		if (!nav.contains(marker)) {
			Sys.println('guides: warning: could not locate navContent opening <ul>; skipping nav injection');
			return;
		}
		// Insert the API reference link and the Guides expando at the top of the
		// nav, then wrap the original Dox API type tree in a collapsed "API"
		// expando so the sidebar top level reads: API reference, Guides, API
		// (instead of flattening every API package next to the guides).
		var apiOpen = '<li class="expando package-api"><a class="nav-header" href="#" onclick="return toggleCollapsed(this)"><i class="fa fa-cube"></i>API</a><ul class="nav nav-list">';
		var apiClose = '</ul></li>';
		nav = nav.replace(marker, marker + buildApiLink() + buildGuidesSection(guides) + apiOpen);
		var closeMarker = "</ul>';";
		if (!nav.contains(closeMarker)) {
			Sys.println('guides: warning: could not locate navContent closing </ul>; API tree left unwrapped');
		} else {
			var idx = nav.lastIndexOf(closeMarker);
			nav = nav.substr(0, idx) + apiClose + nav.substr(idx);
		}
		sys.io.File.saveContent(navPath, nav);
	}

	function buildApiLink():String {
		return '<li class="api-ref-link"><a class="nav-header treeLink" href="::rootPath::api.html" title="API reference"><i class="fa fa-cube"></i>API reference</a></li>';
	}

	function buildGuidesSection(guides:Array<Guide>):String {
		var topLevel = [];
		var groups = new Map<String, Array<Guide>>();
		for (g in guides) {
			if (g.isLanding) {
				continue;
			}
			var parts = g.relPath.split("/");
			if (parts.length == 1) {
				topLevel.push(g);
			} else {
				var key = parts[0];
				var arr = groups.get(key);
				if (arr == null) {
					arr = [];
					groups.set(key, arr);
				}
				arr.push(g);
			}
		}
		var buf = new StringBuf();
		buf.add('<li class="expando package-guides"><a class="nav-header" href="#" onclick="return toggleCollapsed(this)"><i class="fa fa-book"></i>Guides</a><ul class="nav nav-list">');
		for (g in topLevel) {
			buf.add(guideLeaf(g));
		}
		for (key in keysSorted(groups)) {
			buf.add('<li class="expando package-$key"><a class="nav-header" href="#" onclick="return toggleCollapsed(this)"><i class="fa fa-folder"></i>');
			buf.add(htmlEscape(prettify(key)));
			buf.add('</a><ul class="nav nav-list">');
			for (g in groups.get(key)) {
				buf.add(guideLeaf(g));
			}
			buf.add('</ul></li>');
		}
		buf.add('</ul></li>');
		return buf.toString();
	}

	function guideLeaf(g:Guide):String {
		return '<li data_path="' + g.relPath + '"><a class="treeLink" href="::rootPath::' + g.relPath + '.html" title="' + htmlEscape(g.title) + '">' + htmlEscape(g.title) + '</a></li>';
	}

	function renderGuideBody(guide:Guide):String {
		var markdown = File.getContent(guide.sourcePath);
		var html = markdownHandler.markdownToHtml(guide.relPath, markdown);
		return rewriteMdLinks(html);
	}

	function rewriteMdLinks(html:String):String {
		// Convert relative .md links to .html, preserving anchors and absolute URLs.
		return ~/href="([^"#?]+\.md)([#?][^"]*)?"/g.map(html, function(e) {
			var href = e.matched(1);
			var suffix = e.matched(2);
			if (suffix == null) {
				suffix = "";
			}
			if (href.startsWith("http://") || href.startsWith("https://") || href.startsWith("//")
				|| href.startsWith("mailto:")) {
				return 'href="$href$suffix"';
			}
			if (href.startsWith("docs/source/")) {
				href = href.substr("docs/source/".length);
			}
			return 'href="${href.substr(0, href.length - 3)}.html$suffix"';
		});
	}

	static function rootPathFor(depth:Int):String {
		return depth == 0 ? "./" : [for (_ in 0...depth) "../"].join("");
	}

	static function htmlEscape(s:String):String {
		return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;");
	}

	static function prettify(name:String):String {
		return name.replace("_", " ").replace("-", " ");
	}

	static function keysSorted(m:Map<String, Array<Guide>>):Array<String> {
		var keys = [for (k in m.keys()) k];
		keys.sort((a, b) -> Reflect.compare(a.toLowerCase(), b.toLowerCase()));
		return keys;
	}
}