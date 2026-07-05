package dox;

/**
	A single Markdown guide page discovered under `Config.guidesPath`.
**/
class Guide {
	/**
		Site-root relative output path without extension, e.g.
		`index` for the landing source or `user_guide/hashlink` for a guide.
	**/
	public var relPath:String;

	/**
		Absolute path to the source `.md` file.
	**/
	public var sourcePath:String;

	/**
		Display title: the first `# ` heading in the file, or a prettified
		file name fallback.
	**/
	public var title:String;

	/**
		Directory depth of `relPath` below the site root. `index` -> 0,
		`user_guide/foo` -> 1, `a/b/c` -> 3.
	**/
	public var depth:Int;

	public function new(relPath:String, sourcePath:String, title:String, depth:Int) {
		this.relPath = relPath;
		this.sourcePath = sourcePath;
		this.title = title;
		this.depth = depth;
	}

	public var isLanding(get, never):Bool;

	function get_isLanding():Bool {
		return relPath == "index";
	}
}