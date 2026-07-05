# quadrants-dox

A Quadrants fork of [Dox](https://github.com/HaxeFoundation/dox) (the Haxe documentation generator) that:

- builds and runs on **HashLink** (`hl run.hl`), and
- folds the Markdown documentation under `docs/source/` into the generated Haxe API site (landing page, guide pages, unified navigation).

It is the documentation engine used by the [`quadrants-hl`](https://github.com/yolkarian/quadrants-hl) repository to produce a single website containing both the Haxe API reference and the end-user guides, deployed to GitHub Pages.

![image](resources/screenshot.png)

## Installation

This fork drops lix in favour of plain haxelib dependencies. Install the pinned git dependencies and the markdown library with haxelib:

```sh
haxelib git hxtemplo https://github.com/Simn/hxtemplo 4b9ec0c07e9ec619c7c414c3a72af4be63d820cc
haxelib git hxparse   https://github.com/Simn/hxparse 876070ec62a4869de60081f87763e23457a3bda8
haxelib git hxargs    https://github.com/Simn/hxargs  1d8ec84f641833edd6f0cb2e4290b7524fd27219
haxelib install markdown
```

Then register this fork:

```sh
haxelib dev quadrants-dox /path/to/quadrants-dox
# or from a release:
haxelib git quadrants-dox https://github.com/yolkarian/quadrants-dox.git
```

## Build

quadrants-dox is built with the system Haxe toolchain (Haxe 4.3.6 + HashLink). There are two build targets:

```sh
# HashLink (canonical): produces run.hl, run with `hl run.hl`
haxe runHL.hxml

# Neko (fallback, also what `haxelib run` invokes): produces run.n
haxe run.hxml
```

`runBase.hxml` holds the shared compiler flags (`-lib hxtemplo -lib hxparse -lib hxargs -lib markdown -cp src -main dox.Dox`).

## Usage

Generate Haxe XML for the project you want to document, then run quadrants-dox:

```sh
haxe -xml docs/doc.xml -D doc-gen [LIBS] <CLASSPATH> <TARGET> <PACKAGE_NAME>
hl run.hl -i docs -o pages --title "My API" --toplevel-package mypkg
```

To fold in Markdown guides, pass `--guides <dir>` (added by this fork; see `hl run.hl --help`).

## Local development

```sh
haxe runHL.hxml            # build run.hl
hl run.hl -i test/bin/xml -o bin/pages --include dox
```

## Upstream

This fork tracks upstream Dox via the `upstream` remote. The original Dox README and wiki apply for general usage and custom theme creation.