package src;

class StoryTest extends haxe.unit.TestCase {
    public static function main() {
        var r = new haxe.unit.TestRunner();
        r.add(new StoryTest());
        // add other TestCases here

        // finally, run the tests
        r.run();
    }

//    public function testHelloWorld() {
//        var story: Story = new Story();
//        story.loadScript("examples/hello.hank");
//        assertEquals('HasText(Hello, world!)', Std.string(story.nextFrame()));
//        assertEquals(StoryFrame.Finished, story.nextFrame());
//        assertEquals(StoryFrame.Finished, story.nextFrame());
//    }
//
//    public function testFullSpec1() {
//        var story: Story = new Story();
//        story.loadScript("examples/main.hank");
//        assertEquals("HasText(This is a section of a Hank story. It's pretty much like a Knot in Ink.)", Std.string(story.nextFrame()));
//        assertEquals("HasText(Line breaks define the chunks of this section that will eventually get sent to your game to process.)", Std.string(story.nextFrame()));
//        assertEquals("HasText(Your Hank scripts will contain the static content of your game, but they can also insert dynamic content, even the result of complex haxe expressions!)", Std.string(story.nextFrame()));
//        assertEquals("HasText(You can include choices for the player.)", Std.string(story.nextFrame()));
//
//        assertEquals("HasChoices([Door A,Door B opens but the room on the other side is identical!])", Std.string(story.nextFrame()));
//
//        assertEquals("Door A opens and there's nothing behind it.", story.choose(0));
//
//        assertEquals("HasText(You can include choices for the player.)", Std.string(story.nextFrame()));
//        assertEquals("HasChoices([Door B opens but the room on the other side is identical!,Choices can depend on logical conditions being truthy.])", Std.string(story.nextFrame()));
//
//        assertEquals("Door B opens but the room on the other side is identical!", story.choose(0)); 
//        assertEquals("HasText(You can include choices for the player.)", Std.string(story.nextFrame()));
//        assertEquals("HasChoices([Door B opens but the room on the other side is identical!,Choices can depend on logical conditions being truthy.])", Std.string(story.nextFrame()));
//        assertEquals("Door B opens but the room on the other side is identical!", story.choose(0)); 
//        assertEquals("HasText(You can include choices for the player.)", Std.string(story.nextFrame()));
//        assertEquals("HasChoices([Door B opens but the room on the other side is identical!,Choices can depend on logical conditions being truthy.])", Std.string(story.nextFrame()));
//        assertEquals("Door B opens but the room on the other side is identical!", story.choose(0)); 
//        assertEquals("HasText(You can include choices for the player.)", Std.string(story.nextFrame()));
//        assertEquals("HasChoices([Door B opens but the room on the other side is identical!,Choices can depend on logical conditions being truthy.])", Std.string(story.nextFrame()));
//
//        assertEquals("Choices can depend on logical conditions being truthy.", story.choose(1));
//
//        assertEquals("HasChoices([I don't think I'll use Hank for my games.,Hank sounds awesome, thanks!])", Std.string(story.nextFrame()));
//        assertEquals("I don't think I'll use Hank for my games.", story.choose(0));
//        assertEquals("HasText(Are you sure?)", Std.string(story.nextFrame()));
//        assertEquals("HasChoices([Yes I'm sure.,I've changed my mind.])", Std.string(story.nextFrame()));
//        assertEquals("Yes I'm sure.", story.choose(0));
//        assertEquals("HasText(That's perfectly valid!)", Std.string(story.nextFrame()));
//        assertEquals(StoryFrame.Finished, story.nextFrame());
//    }
//
    public function testParseLine() {
        var story = new Story();
        assertEquals("IncludeFile(extra.hank)", Std.string(story.parseLine("INCLUDE extra.hank", [])));
        assertEquals("IncludeFile(extra.hank)", Std.string(story.parseLine("INCLUDE    extra.hank", [])));


        // TODO test edge cases of all line types (maybe with more separate functions too)
    }

    public function testParseFullSpec() {
        // Parse the main.hank script and test that all lines are correctly parsed
        var story = new Story(true);
        story.loadScript("examples/main.hank");
        assertEquals(27, story.scriptLines.length);

        var lineNumber = 1;
        var idx = 0;
        var file = "examples/main.hank";
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: ${file}, type: IncludeFile(extra.hank)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: Empty}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: Divert(start)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: Empty}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: DeclareSection(start)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: OutputText(This is a section of a Hank story. It\'s pretty much like a Knot in Ink.)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: OutputText(Line breaks define the chunks of this section that will eventually get sent to your game to process!)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: OutputText(Your Hank scripts will contain the static content of your game, but they can also insert {demo_var}, even the result of complex {part1 + " " + part2}!)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: Empty}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: Divert(choice_example)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: Empty}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: DeclareSection(final_choice)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: Empty}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber}, sourceFile: examples/main.hank, type: HaxeBlock(3,var unused_variable="";\n// This is a comment INSIDE a haxe block\n/*The whole block will be parsed and executed at the same time*/\n)}', Std.string(story.scriptLines[idx++]));
        lineNumber += 5;
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: DeclareChoice(I don\'t think I\'ll use Hank for my games.,1,0)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: OutputText(Are you sure?)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: DeclareChoice(Yes I\'m sure.,2,1)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: OutputText(That\'s perfectly valid!)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: DeclareChoice(I\'ve changed my mind.,2,2)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: Divert(final_choice)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: DeclareChoice(Hank sounds awesome, thanks!,1,3)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: Divert(the_end)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: Empty}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: DeclareSection(the_end)}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: Empty}', Std.string(story.scriptLines[idx++]));
        assertEquals('{lineNumber: ${lineNumber++}, sourceFile: examples/main.hank, type: OutputText(That\'s the end of this example!)}', Std.string(story.scriptLines[idx++]));


        // Parse the extra.hank script and also test its parsing
    }
}