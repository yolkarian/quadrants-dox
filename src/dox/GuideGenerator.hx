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

	public function new(api:Api, writer:Writer) {
		this.api = api;
		this.writer = writer;
		this.markdownHandler = new MarkdownHandler(api.config, api.infos);
		this.tplGuide = api.config.loadTemplate("guide.mtt");
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
		var insertion = buildApiLink() + buildGuidesSection(guides);
		var marker = "var navContent='<ul class=\"nav nav-list\">";
		if (!nav.contains(marker)) {
			Sys.println('guides: warning: could not locate navContent opening <ul>; skipping nav injection');
			return;
		}
		nav = nav.replace(marker, marker + insertion);
		sys.io.File.saveContent(navPath, nav);
	}

	function buildApiLink():String {
		return '<li class="api-ref-link"><a class="nav-header treeLink" href="::rootPath::index.html" title="API reference"><i class="fa fa-cube"></i>API reference</a></li>';
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