module tests.it.runtime.dub;


import tests.it.runtime;
import reggae.reggae;
import reggae.path: deabsolutePath;
import std.path: buildPath;


@("noreggaefile.ninja")
@Tags(["dub", "ninja"])
unittest {

    import std.string: join;
    import std.algorithm: filter;

    with(immutable ReggaeSandbox("dub")) {
        shouldNotExist("reggaefile.d");
        writelnUt("\n\nReggae output:\n\n", runReggae("-b", "ninja").lines.join("\n"), "-----\n");
        shouldExist("reggaefile.d");
        auto output = ninja.shouldExecuteOk;
        output.shouldContain("-debug -g");

        shouldSucceed("atest").filter!(a => a != "").should ==
            [
                "Why hello!",
                "I'm immortal!"
            ];

        // there's only one UT in main.d which always fails
        shouldFail("ut");
    }
}

@("noreggaefile.tup")
@Tags(["dub", "tup"])
unittest {
    with(immutable ReggaeSandbox("dub")) {
        runReggae("-b", "tup").
            shouldThrowWithMessage("dub integration not supported with the tup backend");
    }
}


@("prebuild")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox("dub_prebuild")) {
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("ut");
    }
}


@("postbuild")
@Tags(["dub", "ninja", "posix"])
unittest {
    with(immutable ReggaeSandbox("dub_postbuild")) {
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldExist("foo.txt");
        shouldSucceed("postbuild");
    }
}


@("dependencies not on file system already no dub.selections.json")
@Tags(["dub", "ninja"])
unittest {

    import std.file: exists, rmdirRecurse;
    import std.process: environment;
    import std.path: buildPath;

    const cerealedDir = buildPath(environment["HOME"], ".dub/packages/cerealed-0.6.8");
    if(cerealedDir.exists)
        rmdirRecurse(cerealedDir);

    with(immutable ReggaeSandbox()) {
        writeFile("dub.json", `
        {
          "name": "depends_on_cerealed",
          "license": "MIT",
          "targetType": "executable",
          "dependencies": { "cerealed": "==0.6.8" }
        }`);
        writeFile("source/app.d", "void main() {}");

        runReggae("-b", "ninja");
    }
}


@("no main function but with unit tests")
@Tags(["dub", "ninja"])
unittest {
    import std.file: mkdirRecurse;
    import std.path: buildPath;

    with(immutable ReggaeSandbox()) {
        writeFile("dub.json", `
            {
              "name": "depends_on_cerealed",
              "license": "MIT",
              "targetType": "executable",
              "dependencies": { "cerealed": "==0.6.8" }
            }`);

        writeFile("reggaefile.d", q{
            import reggae;
            mixin build!(dubTestTarget!());
        });

        mkdirRecurse(buildPath(testPath, "source"));
        writeFile("source/foo.d", `unittest { assert(false); }`);
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;

        shouldFail("ut");
    }
}


@("reggae/dub build should rebuild if dub.selections.json changes")
@Tags(["dub", "make"])
unittest {

    import std.process: execute;
    import std.path: buildPath;

    with(immutable ReggaeSandbox("dub")) {
        runReggae("-b", "make");
        make(["VERBOSE=1"]).shouldExecuteOk.shouldContain("-debug -g");
        {
            const ret = execute(["touch", buildPath(testPath, "dub.selections.json")]);
            ret.status.shouldEqual(0);
        }
        {
            const ret = execute(["make", "-C", testPath]);
            ret.output.shouldContain("eggae");
        }
    }
}

@("version from main package is used in dependent packages")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            versions "lefoo"
            targetType "executable"
            dependency "bar" path="bar"
        `);
        writeFile("source/app.d", q{
            void main() {
                import bar;
                import std.stdio;
                writeln(lebar);
            }
        });
        writeFile("bar/dub.sdl", `
            name "bar"
        `);
        writeFile("bar/source/bar.d", q{
            module bar;
            version(lefoo)
                int lebar() { return 3; }
            else
                int lebar() { return 42; }
        });
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("foo").shouldEqual(
            [
                "3",
            ]
        );
    }
}


@("sourceLibrary dependency")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            dependency "bar" path="bar"
        `);
        writeFile("source/app.d", q{
            void main() {
                import bar;
                import std.stdio;
                writeln(lebar);
            }
        });
        writeFile("bar/dub.sdl", `
            name "bar"
            targetType "sourceLibrary"
        `);
        writeFile("bar/source/bar.d", q{
            module bar;
            int lebar() { return 3; }
        });
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
    }
}

@("object source files.simple")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            dependency "bar" path="bar"
        `);
        writeFile("source/app.d", q{
            extern(C) int lebaz();
            void main() {
                import bar;
                import std.stdio;
                writeln(lebar);
                writeln(lebaz);
            }
        });
        writeFile("bar/dub.sdl", `
            name "bar"
            sourceFiles "../baz.o"
        `);
        writeFile("bar/source/bar.d", q{
            module bar;
            int lebar() { return 3; }
        });
        writeFile("baz.d", q{
            module baz;
            extern(C) int lebaz() { return 42; }
        });

        ["dmd", "-c", "baz.d"].shouldExecuteOk;
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
    }
}


@("dub objs option path dependency")
@Tags("dub", "ninja", "dubObjsDir")
unittest {

    with(immutable ReggaeSandbox()) {

        writeFile("reggaefile.d", q{
            import reggae;
            mixin build!(dubDefaultTarget!());
        });

        writeFile("dub.sdl",`
            name "foo"
            targetType "executable"
            dependency "bar" path="bar"
        `);

        writeFile("source/app.d", q{
            import bar;
            void main() { add(2, 3); }
        });

        writeFile("bar/dub.sdl", `
            name "bar"
        `);

        writeFile("bar/source/bar.d", q{
            module bar;
            int add(int i, int j) { return i + j; }
        });

        const dubObjsDir = buildPath(testPath, "objsdir");
        const output = runReggae("-b", "ninja", "--dub-objs-dir=" ~ dubObjsDir, "--dub-deps-objs");
        writelnUt(output);
        ninja.shouldExecuteOk;

        import std.path: buildPath;
        shouldExist(buildPath("objsdir",
                              testPath.deabsolutePath,
                              "foo.objs",
                              testPath.deabsolutePath,
                              "bar",
                              "source_bar.o"));
    }
}


@("dub objs option registry dependency")
@Tags("dub", "ninja", "dubObjsDir")
unittest {

    import reggae.path: dubPackagesDir, deabsolutePath;

    with(immutable ReggaeSandbox()) {

        writeFile("reggaefile.d", q{
            import reggae;
            mixin build!(dubDefaultTarget!());
        });

        writeFile("dub.sdl",`
            name "foo"
            targetType "executable"
            dependency "dubnull" version="==0.0.1"
        `);

        writeFile("source/app.d", q{
            import dubnull;
            void main() { dummy(); }
        });

        const dubObjsDir = buildPath(testPath, "objsdir");
        const output = runReggae("-b", "ninja", "--dub-objs-dir=" ~ dubObjsDir, "--dub-deps-objs");
        writelnUt(output);

        ninja.shouldExecuteOk;

        import std.path: buildPath;
        const dubNullDir = buildPath(dubPackagesDir, "dubnull-0.0.1", "dubnull").deabsolutePath;
        shouldExist(buildPath("objsdir",
                              testPath.deabsolutePath,
                              "foo.objs",
                              dubNullDir,
                              "source_dubnull.o"));
    }
}


@("object source files.with dub objs option")
@Tags("dub", "ninja", "dubObjsDir")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            dependency "bar" path="bar"
        `);
        writeFile("source/app.d", q{
            extern(C) int lebaz();
            void main() {
                import bar;
                import std.stdio;
                writeln(lebar);
                writeln(lebaz);
            }
        });
        writeFile("bar/dub.sdl", `
            name "bar"
            sourceFiles "../baz.o"
        `);
        writeFile("bar/source/bar.d", q{
            module bar;
            int lebar() { return 3; }
        });
        writeFile("baz.d", q{
            module baz;
            extern(C) int lebaz() { return 42; }
        });

        ["dmd", "-c", "baz.d"].shouldExecuteOk;

        const output = runReggae("-b", "ninja", "--dub-objs-dir=" ~ testPath);
        writelnUt(output);

        ninja.shouldExecuteOk;
    }
}


@("depends on package with prebuild")
@Tags(["dub", "ninja"])
unittest {

    import std.path;

    with(immutable ReggaeSandbox("dub_depends_on_prebuild")) {

        copyProject("dub_prebuild", buildPath("..", "dub_prebuild"));

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("app");
        shouldExist(inSandboxPath("../dub_prebuild/el_prebuildo.txt"));
    }
}


// See #73 for "posix"
@("staticLibrary.implicit")
@Tags(["dub", "ninja", "posix"])
unittest {

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            targetName "d++"

            configuration "executable" {
            }

            configuration "library" {
                targetType "library"
                targetName "dpp"
                excludedSourceFiles "source/main.d"
            }
        `);

        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      alias lib = dubConfigurationTarget!(Configuration("library"));
                      enum mainObj = objectFile(SourceFile("source/main.d"));
                      alias exe = link!(ExeName("d++"), targetConcat!(lib, mainObj));
                      mixin build!(exe);
                  });

        writeFile("source/main.d", "void main() {}");
        writeFile("source/foo/bar/mod.d", "module foo.bar.mod; int add1(int i, int j) { return i + j + 1; }");

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("d++");
    }
}


@("staticLibrary.explicit")
@Tags(["dub", "ninja"])
unittest {

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            targetName "d++"

            configuration "executable" {
            }

            configuration "library" {
                targetType "staticLibrary"
                targetName "dpp"
                excludedSourceFiles "source/main.d"
            }
        `);

        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      alias lib = dubConfigurationTarget!(Configuration("library"));
                      enum mainObj = objectFile(SourceFile("source/main.d"));
                      alias exe = link!(ExeName("d++"), targetConcat!(lib, mainObj));
                      mixin build!(exe);
                  });

        writeFile("source/main.d", "void main() {}");
        writeFile("source/foo/bar/mod.d", "module foo.bar.mod; int add1(int i, int j) { return i + j + 1; }");

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("d++");
    }
}


@("failing prebuild command")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox("dub_prebuild_oops")) {
        auto thrownInfo = runReggae("-b", "ninja").shouldThrow;
        "Error calling foo bar baz quux:".should.be in thrownInfo.msg;
        "not found".should.be in thrownInfo.msg;
    }
}


@("libs.plain")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            libs "utils"
            lflags "-L$PACKAGE_DIR"

            configuration "executable" {
            }

            configuration "library" {
                targetType "library"
                targetName "dpp"
                excludedSourceFiles "source/main.d"
            }
        `);

        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      alias exe = dubDefaultTarget!(
                      );
                      mixin build!(exe);
                  });

        writeFile("source/main.d",
                  q{
                      extern(C) int twice(int);
                      void main() {
                          assert(twice(2) == 4);
                          assert(twice(3) == 6);
                      }
                  });

        writeFile("utils.c", "int twice(int i) { return i * 2; }");
        shouldExecuteOk(["gcc", "-o", inSandboxPath("utils.o"), "-c", inSandboxPath("utils.c")]);
        shouldExecuteOk(["ar", "rcs", inSandboxPath("libutils.a"), inSandboxPath("utils.o")]);

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("foo");
    }
}


@("libs.posix")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            libs "utils" platform="posix"
            lflags "-L$PACKAGE_DIR"

            configuration "executable" {
            }

            configuration "library" {
                targetType "library"
                targetName "dpp"
                excludedSourceFiles "source/main.d"
            }
        `);

        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      alias exe = dubDefaultTarget!(
                      );
                      mixin build!(exe);
                  });

        writeFile("source/main.d",
                  q{
                      extern(C) int twice(int);
                      void main() {
                          assert(twice(2) == 4);
                          assert(twice(3) == 6);
                      }
                  });

        writeFile("utils.c", "int twice(int i) { return i * 2; }");
        shouldExecuteOk(["gcc", "-o", inSandboxPath("utils.o"), "-c", inSandboxPath("utils.c")]);
        shouldExecuteOk(["ar", "rcs", inSandboxPath("libutils.a"), inSandboxPath("utils.o")]);

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("foo");
    }
}


@("libs.dependency")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            dependency "bar" path="bar"
        `);

        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      mixin build!(dubDefaultTarget!());
                  });

        writeFile("source/main.d",
                  q{
                      import bar;
                      void main() {
                          assert(times4(2) == 8);
                          assert(times4(3) == 12);
                      }
                  });

        writeFile("bar/dub.sdl", `
            name "bar"
            targetType "library"
            lflags "-L$PACKAGE_DIR"
            libs "utils"
        `);

        writeFile("bar/source/bar.d", q{
                module bar;
                extern(C) int twice(int);
                int times4(int i) { return 2 * twice(i); }
            }
        );

        writeFile("bar/utils.c", "int twice(int i) { return i * 2; }");
        shouldExecuteOk(["gcc", "-o", inSandboxPath("bar/utils.o"), "-c", inSandboxPath("bar/utils.c")]);
        shouldExecuteOk(["ar", "rcs", inSandboxPath("bar/libutils.a"), inSandboxPath("bar/utils.o")]);

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("foo");
    }
}


@("dflags.debug")
@Tags("dub", "ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
        `);

        writeFile("source/main.d",
                  q{
                      void main() {
                          debug assert(false);
                      }
                  });

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldFail("foo");
    }
}


@("unittest.dependency")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            dependency "bar" path="bar"
        `);
        writeFile("source/app.d", q{
            void main() {
            }
        });
        writeFile("bar/dub.sdl", `
            name "bar"
        `);
        writeFile("bar/source/bar.d", q{
            module bar;
            unittest {
                assert(1 == 2);
            }
        });
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("ut");
    }
}


@("unittest.self")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
        `);
        writeFile("source/app.d", q{
            void main() {
            }

            unittest { assert(1 == 2); }
        });
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldFail("ut");
    }
}


@("subpackages")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.json", `
            {
                "name": "oops",
                "targetType": "none",
                "subPackages": [
                    {
                        "name": "pkg1",
                        "targetType": "staticLibrary"
                    },
                    {
                        "name": "pkg2",
                        "targetType": "executable",
                        "sourceFiles": ["main.d"],
                        "dependencies": {
                            "oops:pkg1": "*"
                        }
                    }
                ],
                "dependencies": {
                    "oops:pkg1": "*",
                    "oops:pkg2": "*"
                }
            }
        `);
        writeFile("main.d", q{
            void main() {
                import oops;
                import std.stdio;
                writeln(3.twice);
            }
        });
        writeFile("source/oops.d", q{
            module oops;
            int twice(int i) { return i * 2; }
        });

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldFail("ut");
    }
}


@("buildtype.release")
@Tags("dub", "ninja")
unittest {

    import std.string: splitLines;

    with(immutable ReggaeSandbox()) {
        writeFile(
            "dub.sdl",
            [
                `name "foo"`,
                `targetType "executable"`,
            ],
        );
        writeFile(
            "source/app.d",
            [
                q{void main() {}},
            ],
        );

        runReggae("-b", "ninja", "--dub-build-type=release");
        const buildLines = ninja.shouldExecuteOk;
        const firstLine = buildLines[0];
        "-release ".should.be in firstLine;
        "-O ".should.be in firstLine;
        "-inline ".should.be in firstLine;
    }

}
