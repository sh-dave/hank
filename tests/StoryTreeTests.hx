package;

import hank.Parser;
import hank.StoryTree;

using hank.Extensions;
using tink.CoreApi;

@:build(hank.FileLoadingMacro.build(["examples/diverts/"]))
@:asserts
class StoryTreeTests {
    var tree: StoryNode;

    @:before
    public function setupClass() {
        tree = new StoryNode(0);
        var section = new StoryNode(1);
        var subsection = new StoryNode(2);

        var globalVar = new StoryNode(3);
        var sectionVar = new StoryNode(4);
        var subsectionVar = new StoryNode(5);

        tree.addChild("section", section);
        tree.addChild("ambiguous", globalVar);

        section.addChild("ambiguous", sectionVar);
        section.addChild("subsection", subsection);
        subsection.addChild("ambiguous", subsectionVar);

        return Noise;
    }

    public function traverseAll() {
        asserts.assert(tree.traverseAll().length == 6);
        return asserts.done();
    }

    public function resolve() {
        var global = tree.resolve("ambiguous");
        asserts.assert(global.unwrap().astIndex == 3);
        return asserts.done();
    }

    public function parse() {
        var tree = StoryNode.FromAST(new Parser().parseFile("examples/diverts/main.hank", files));

        // HankAssert.isSome(tree.resolve("start"));
        // HankAssert.isSome(tree.resolve("three"));
        // HankAssert.isSome(tree.resolve("other_section"));
        // // Resolving a nonexistent name should throw
        // HankAssert.isNone(tree.resolve("one"));
        // HankAssert.isSome(tree.resolve("start").unwrap().resolve("end"));
        // HankAssert.isNone(tree.resolve("start").unwrap().resolve("three"));
        // HankAssert.isSome(tree.resolve("three").unwrap().resolve("three"));

        return asserts.done();
        // Assert.pass();
    }

    public function new() {
    }
}