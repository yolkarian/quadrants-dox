package dox;

import sys.FileSystem;
import sys.io.File;

/**
	Writes generated pages and copies resources into the output directory.

	Upstream Dox supports writing either to a directory or to a `.zip` file;
	the zip path pulls in `haxe.zip`, which on HashLink is backed by the `fmt`
	native extension (fmt.hdll, an image/audio format library with heavy
	native dependencies). quadrants-dox only ever writes to a directory (the
	GitHub Pages site root), so the zip path is dropped here to keep the
	runtime native dependency surface to libhl only.
**/
class Writer {
	var config:Config;

	public function new(config:Config) {
		this.config = config;
		try {
			if (!FileSystem.exists(config.outputPath)) {
				FileSystem.createDirectory(config.outputPath);
			}
		} catch (e:Dynamic) {
			Sys.println('Could not create output directory ${config.outputPath}');
			Sys.println(Std.string(e));
			Sys.exit(1);
		}
	}

	public function saveContent(path:String, content:String) {
		var path = Path.join([config.outputPath, path]);
		var dir = new Path(path).dir;
		if (dir != null && !FileSystem.exists(dir)) {
			FileSystem.createDirectory(dir);
		}
		File.saveContent(path, content);
	}

	public function copyFrom(dir:String) {
		function loop(rel) {
			var dir = Path.join([dir, rel]);
			for (file in FileSystem.readDirectory(dir)) {
				var path = Path.join([dir, file]);
				if (FileSystem.isDirectory(path)) {
					var outDir = Path.join([config.outputPath, rel, file]);
					if (!FileSystem.exists(outDir))
						FileSystem.createDirectory(outDir);
					loop(Path.join([rel, file]));
				} else {
					File.copy(path, Path.join([config.outputPath, rel, file]));
				}
			}
		}
		loop("");
	}

	public function finalize() {}
}