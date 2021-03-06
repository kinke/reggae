module tests.ut.default_options;

import unit_threaded;


void testDefaultCCompiler() {
    import reggae;
    Options defaultOptions;
    defaultOptions.cCompiler = "weirdcc";
    enum target = objectFile(SourceFile("foo.c"), Flags("-g -O0"), IncludePaths(["includey", "headers"]));
    mixin build!(target);
    auto build = buildFunc();

    auto args = ["progname", "-b", "ninja", "/path/to/proj"]; //fake main function args
    auto options = getOptions(defaultOptions, args);
    build.targets[0].shellCommand(options).
        shouldEqual("weirdcc -g -O0 -I/path/to/proj/includey -I/path/to/proj/headers -MMD -MT foo.o -MF foo.o.dep -o foo.o -c /path/to/proj/foo.c");
}


void testOldNinja() {
    import reggae;
    Options defaultOptions;
    defaultOptions.oldNinja = true;
    auto args = ["progname", "-b", "ninja", "/path/to/proj"]; //fake main function args
    auto options = getOptions(defaultOptions, args);
}
