package dox;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

using StringTools;

/**
	Walks `Config.guidesPath` and collects every `*.md` file as a `Guide`.

	The collection mirrors the source directory layout: a file at
	`<guides>/user_guide/hashlink.md` becomes a `Guide` with
	`relPath = "user_guide/hashlink"`, intended to be rendered at
	`<site>/user_guide/hashlink.html`. A file at `<guides>/index.md` becomes
	the landing `Guide` with `relPath = "index"`.

	Guides are returned in a stable order: the landing first, then the rest
	sorted alphabetically by relative path.
**/
class GuideCollector {
	final config:Config;

	public function new(config:Config) {
		this.config = config;
	}

	public function collect():Array<Guide> {
		var out:Array<Guide> = [];
		if (config.guidesPath == null || !FileSystem.exists(config.guidesPath)) {
			return out;
		}
		walk(config.guidesPath, "", out);
		out.sort((a, b) -> a.isLanding ? -1 : b.isLanding ? 1 : comparePath(a.relPath, b.relPath));
		return out;
	}

	function walk(dir:String, relDir:String, out:Array<Guide>):Void {
		var entries = FileSystem.readDirectory(dir);
		entries.sort(Reflect.compare);
		for (name in entries) {
			var full = Path.join([dir, name]);
			if (FileSystem.isDirectory(full)) {
				walk(full, relDir == "" ? name : '$relDir/$name', out);
				continue;
			}
			if (!name.endsWith(".md")) {
				continue;
			}
			var base = name.substr(0, name.length - 3);
			var relPath = relDir == "" ? base : '$relDir/$base';
			var text = File.getContent(full);
			var title = extractTitle(text, base);
			out.push(new Guide(relPath, full, title, depthOf(relPath)));
		}
	}

	static function depthOf(relPath:String):Int {
		var parts = relPath.split("/");
		parts.pop();
		return parts.length;
	}

	static function extractTitle(markdown:String, fallback:String):String {
		for (line in markdown.split("\n")) {
			var trimmed = line.trim();
			if (trimmed.startsWith("# ")) {
				return trimmed.substr(2).trim();
			}
		}
		return prettify(fallback);
	}

	static function prettify(name:String):String {
		return name.replace("_", " ").replace("-", " ");
	}

	static function comparePath(a:String, b:String):Int {
		var pa = a.split("/");
		var pb = b.split("/");
		var n = pa.length < pb.length ? pa.length : pb.length;
		for (i in 0...n) {
			var c = Reflect.compare(pa[i].toLowerCase(), pb[i].toLowerCase());
			if (c != 0) {
				return c;
			}
		}
		return pa.length - pb.length;
	}
}