module tests.ut.default_rules;


import reggae;
import unit_threaded;
import std.array;


void testNoDefaultRule() {
    Command("doStuff foo=bar").isDefaultCommand.shouldBeFalse;
}

void testGetRuleD() {
    const command = Command(CommandType.compile, assocList([assocEntry("foo", ["bar"])]));
    command.getType.shouldEqual(CommandType.compile);
    command.isDefaultCommand.shouldBeTrue;
}

void testGetRuleCpp() {
    const command = Command(CommandType.compile, assocList([assocEntry("includes", ["src", "other"])]));
    command.getType.shouldEqual(CommandType.compile);
    command.isDefaultCommand.shouldBeTrue;
}


void testValueWhenKeyNotFound() {
    const command = Command(CommandType.compile, assocList([assocEntry("foo", ["bar"])]));
    command.getParams("", "foo", ["hahaha"]).shouldEqual(["bar"]);
    command.getParams("", "includes", ["hahaha"]).shouldEqual(["hahaha"]);
}


void testObjectFile() {
    auto obj = objectFile(SourceFile("path/to/src/foo.c"), Flags("-m64 -fPIC -O3"));
    obj.hasDefaultCommand.shouldBeTrue;

    auto build = Build(objectFile(SourceFile("path/to/src/foo.c"), Flags("-m64 -fPIC -O3")));
    build.targets.array[0].hasDefaultCommand.shouldBeTrue;
}
