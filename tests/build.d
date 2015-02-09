module tests.build;

import unit_threaded;
import reggae;


void testMakefileD() {
    const build = Build(Target("leapp",
                               [Target("foo.o", [Target("foo.d")], "dmd -c -offoo.o foo.d"),
                                Target("bar.o", [Target("bar.d")], "dmd -c -ofbar.o bar.d")],
                               "dmd -ofleapp foo.o bar.o"));
    auto backend = new Makefile(build);
    backend.fileName.shouldEqual("Makefile");
    backend.output.shouldEqual(
        "all: leapp\n"
        "foo.o: foo.d\n"
        "\tdmd -c -offoo.o foo.d\n"
        "bar.o: bar.d\n"
        "\tdmd -c -ofbar.o bar.d\n"
        "leapp: foo.o bar.o\n"
        "\tdmd -ofleapp foo.o bar.o\n"
        );
}


void testMakefileC() {
    const build = Build(Target("otherapp",
                               [Target("boo.o", [Target("boo.c")], "gcc -c -o boo.o boo.c"),
                                Target("baz.o", [Target("baz.c")], "gcc -c -o baz.o baz.c")],
                               "gcc -o otherapp boo.o baz.o"));
    auto backend = new Makefile(build);
    backend.fileName.shouldEqual("Makefile");
    backend.output.shouldEqual(
        "all: otherapp\n"
        "boo.o: boo.c\n"
        "\tgcc -c -o boo.o boo.c\n"
        "baz.o: baz.c\n"
        "\tgcc -c -o baz.o baz.c\n"
        "otherapp: boo.o baz.o\n"
        "\tgcc -o otherapp boo.o baz.o\n"
        );
}


void testInOut() {
    //Tests that specifying $in and $out in the command string gets substituted correctly
    {
        const target = Target("foo",
                              [Target("bar.txt"), Target("baz.txt")],
                              "createfoo -o $out $in");
        target.command.shouldEqual("createfoo -o foo bar.txt baz.txt");
    }
    {
        const target = Target("tgt",
                              [
                                  Target("src1.o", [Target("src1.c")], "gcc -c -o $out $in"),
                                  Target("src2.o", [Target("src2.c")], "gcc -c -o $out $in")
                                  ],
                              "gcc -o $out $in");
        target.command.shouldEqual("gcc -o tgt src1.o src2.o");
    }

    {
        const target = Target(["proto.h", "proto.c"],
                              [Target("proto.idl")],
                              "protocompile $out -i $in");
        target.command.shouldEqual("protocompile proto.h proto.c -i proto.idl");
    }

    {
        const target = Target("lib1.a",
                              [Target(["foo1.o", "foo2.o"], [Target("tmp")], "cmd"),
                               Target("bar.o"),
                               Target("baz.o")],
                              "ar -o$out $in");
        target.command.shouldEqual("ar -olib1.a foo1.o foo2.o bar.o baz.o");
    }
}
