package tests;

import utest.Test;
import utest.Assert;

import hank.HankAssert;
using hank.Extensions;
import hank.HInterface;
import hank.StoryTree;
import hank.Parser;

class TestObject {
    public var i: Int;
    public var o: TestObject;
    public function new(i: Int, o: TestObject) {
        this.i = i;
        this.o = o;
    }

}

class HInterfaceTest extends utest.Test {

    var hInterface: HInterface;

    public function setup() {
        var storyTree = StoryNode.FromAST(new Parser().parseFile("examples/subsections/main.hank"));
        var viewCounts = storyTree.createViewCounts();

        viewCounts[storyTree.resolve("start").unwrap()] = 5;
        viewCounts[storyTree.resolve("start").unwrap().resolve("one").unwrap()] = 2;

        hInterface = new HInterface(storyTree, viewCounts);
    }

    function assertExpr(name: String, value: Dynamic) {
        Assert.equals(Std.string(value), hInterface.evaluateExpr(name));
    }

    function testViewCount() {
        assertExpr('start', 5);
        //assertExpr('start.one', 5);
    }

    function testClassInstanceDotAccess() {
        hInterface.addVariable('test1', new TestObject(0, new TestObject(1, new TestObject(2, null))));
        assertExpr('test1.i', 0);
        assertExpr('test1.o.i', 1);
        assertExpr('test1.o.o.i', 2);
    }

    function testAnonymousDotAccess() {
        hInterface.runEmbeddedHaxe('var obj = {x: 5, y: "hey", z: { b: 9}};');
        assertExpr('obj.x', 5);
        assertExpr('obj.y', 'hey');
        assertExpr('obj.z.b', 9);
    }

    public function testVarDeclaration() {
        hInterface.runEmbeddedHaxe('var test = "str"');
        assertExpr('test', 'str');
        hInterface.runEmbeddedHaxe('var test2 = 2');
        assertExpr('test2', 2);
    }

    public function testBoolification() {
        hInterface.runEmbeddedHaxe('var test = 7; var test2 = if(test) true else false;');
        assertExpr('test2', true);
    }

    public function testNullErrors() {
       HankAssert.throws(function() {
           hInterface.evaluateExpr('undeclared_variable');
       });
    }

    public function testIfIdiom() {
       HankAssert.equals("", hInterface.evaluateExpr('if (false) "something"'));
    }

}
