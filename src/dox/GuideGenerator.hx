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
}