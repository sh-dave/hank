package src;

import hscript.Parser;
import hscript.Interp;

typedef HankLine = {
    var sourceFile: String;
    var lineNumber: Int;
    var type: LineType;
}

typedef Choice = {
    var text: String;
    var depth: Int;
    var id: Int;
}

enum LineType {
    IncludeFile(path: String);
    OutputText(text: String);
    // Choices are parsed with a unique ID so they can be followed even if duplicate text is used for multiple choices
    DeclareChoice(choice: Choice);
    DeclareSection(name: String);
    Divert(target: String);
    Gather(depth: Int, restOfLine: LineType);
    HaxeLine(code: String);
    HaxeBlock(lines: Int, code: String);
    BlockComment(lines: Int);
    Empty;
}

@:allow(src.StoryTest)
class Story {
    private var lineCount: Int = 0;
    private var scriptLines: Array<HankLine> = new Array();
    private var currentLine: Int = 0;
    private var directory: String = "";
    private var parser = new Parser();
    private var interp = new Interp();
    // TODO use interp.set(name, value) to share things (i.e. modules) to script scope

    private var choiceDepth = 0;
    private var choicesFullText = new Array<String>();
    private var debugPrints: Bool;
    private var choicesParsed = 0;

    private function debugTrace(v: Dynamic, ?infos: haxe.PosInfos) {
        if (debugPrints) {
            trace(v, infos);
        }
    }

    public function new(debug: Bool = false) {
        debugPrints = debug;
    }

    public function loadScript(storyFile: String) {
        if (storyFile.lastIndexOf("/") != -1) {
            directory = storyFile.substr(0, storyFile.lastIndexOf("/")+1);
        }

        parseScript(storyFile);
    }

    private function parseLine(line: String, rest: Array<String>): LineType {
        var trimmedLine = StringTools.trim(line);

        // Remove line comments from the line
        if (trimmedLine.indexOf("//") != -1) {
            trimmedLine = trimmedLine.substr(0, trimmedLine.indexOf("//"));
        }
        // Remove block comments from the line
        while (Util.containsEnclosure(trimmedLine, "/*", "*/")) {
            trimmedLine = Util.replaceEnclosure(trimmedLine, "", "/*", "*/");
        }

        if (trimmedLine.length > 0) {
            // Parse an INCLUDE statement
            if (StringTools.startsWith(trimmedLine, "INCLUDE")) {
                return IncludeFile(StringTools.trim(trimmedLine.substr(8)));
            }
            // Parse a section declaration
            else if (StringTools.startsWith(trimmedLine, "==")) {
                var sectionName = StringTools.trim(trimmedLine.substr(2));
                // Initialize its view count variable to 0
                interp.variables[sectionName] = 0;
                return DeclareSection(sectionName);
            } else if (StringTools.startsWith(trimmedLine, "->")) {
                return Divert(StringTools.trim(trimmedLine.substr(2)));
            } else if (StringTools.startsWith(trimmedLine, "*") || StringTools.startsWith(trimmedLine, "+")) {
                var depth = 1;
                while (trimmedLine.charAt(depth) == trimmedLine.charAt(depth-1)) {
                    depth += 1;
                }

                var choiceText = StringTools.trim(trimmedLine.substr(depth));
                return DeclareChoice({
                    text: choiceText,
                    depth: depth,
                    id: choicesParsed++
                    });
            } else if (StringTools.startsWith(trimmedLine,"-")) {
                var gatherDepth = 1;
                while (trimmedLine.charAt(gatherDepth) == trimmedLine.charAt(gatherDepth-1)) {
                    gatherDepth += 1;
                }

                // Gathers store the parsed version of the next line.
                return Gather(gatherDepth, parseLine(trimmedLine.substr(gatherDepth), rest));
            } else if (StringTools.startsWith(trimmedLine, "~")) {
                return HaxeLine(StringTools.trim(trimmedLine.substr(1)));
            } else if (StringTools.startsWith(trimmedLine, "```")) {
                var block = "";
                var lines = 2;
                // Loop until the end of the code block, incrementing the line count every time
                while (!StringTools.startsWith(StringTools.trim(rest[0]), "```")) {
                    // debugTrace(rest[0]);
                    block += rest[0] + '\n';
                    rest.remove(rest[0]);
                    lines += 1;
                }

                return HaxeBlock(lines, block);
            }
            else if(StringTools.startsWith(trimmedLine, "/*")) {
                var lines = 2;
                // Loop until the end of the multiline block comment
                while (!StringTools.endsWith(StringTools.trim(rest[0]), "*/")) {
                    rest.remove(rest[0]);
                    lines += 1;
                }

                return BlockComment(lines);
            }
            else {
                return OutputText(trimmedLine);
            }
        } else {
            return Empty;
        }
    }

    private function parseScript(file: String) {
        var unparsedLines = sys.io.File.getContent(file).split('\n');
        lineCount += unparsedLines.length;
        var parsedLines = new Array<HankLine>() 
 ;

        // Pre-Parse every line in the given file
        var idx = 0;
        while (idx < unparsedLines.length) { 
 
            var parsedLine = {
                sourceFile: file,
                lineNumber: idx+1,
                type: LineType.Empty
            };
            var unparsedLine = unparsedLines[idx];
            parsedLine.type = parseLine(unparsedLine, unparsedLines.slice(idx+1));
            parsedLines.push(parsedLine);

            // Normal lines are parsed alone, but Haxe blocks are parsed as a group, so
            // the index needs to update accordingly 
            switch (parsedLine.type) {
                case HaxeBlock(lines, _):
                    for (i in 0...lines-1) {
                        parsedLines.push({
                            sourceFile: "",
                            lineNumber: 0,
                            type: LineType.Empty
                        });
                    }
                    idx += lines;
                case BlockComment(lines):
                    for (i in 0...lines-1) {
                        parsedLines.push({
                            sourceFile: "",
                            lineNumber: 0,
                            type: LineType.Empty
                        });
                    }
                    idx += lines;
                default:
                    idx += 1;
            }
        }

        // Add these lines at the front of the execution queue to allow INCLUDEd scripts to run immediately
        idx = parsedLines.length - 1;
        while (idx >= 0) {
            if (parsedLines[idx].type != Empty) {
                scriptLines.insert(currentLine, parsedLines[idx]);
            }
            idx -= 1;
        }
    }

    public function nextFrame(): StoryFrame {
        return if (currentLine >= scriptLines.length) {
            Finished;
        } else {
            processNextLine();
        }
    }

    // TODO this doesn't allow for multiple declaration and other edge cases that must exist
    private function processHaxeBlock(lines: String) {
        for (line in lines.split('\n')) {
            // In order to preserve the values of variables declared in embedded Haxe,
            // we need to predeclare them all as globals in this Story's interpreter.
            var trimmed = StringTools.ltrim(line);
            if (trimmed.length > 0) {
                if (StringTools.startsWith(trimmed, "var")) {
                    var varName = trimmed.split(" ")[1];
                    interp.variables[varName] = null;
                    trimmed = trimmed.substr(4); // Strip out the `var ` prefix before executing so the global value doesn't get overshadowed by a new declaration
                }
                var program = parser.parseString(trimmed);
                interp.execute(program);
            }
        }
    }

    private function gotoLine(line: Int) {
        if (line > 0 && line <= scriptLines.length) {
            currentLine = line;
        } else {
            throw "Tried to go to out of range line";
        }

        if (line == scriptLines.length) {
            // Reached the end of the script
            finished = true;
        }
    }

    private function stepLine() {
        if (!finished) {
            // debugTrace('Stepping to line ${Std.string(scriptLines[currentLine+1])}');
            gotoLine(currentLine+1);
        } else {
            throw "Tried to step past the end of a script";
        }
    }

    private function processNextLine(): StoryFrame {
        var scriptLine = scriptLines[currentLine];
        var frame = processLine(scriptLine);

        switch (frame) {
            case Error(message):
                // TODO output this to a log file
                trace('Error at line ${scriptLine.lineNumber} in ${scriptLine.sourceFile}: ${message}');
                return Finished;
            default:
                return frame;
        }
    }

    private var finished: Bool = false;

    private function processLine (line: HankLine): StoryFrame {
        // debugTrace('Processing ${Std.string(line)}');

        var file = line.sourceFile;
        var type = line.type;
        switch (type) {
            case OutputText(text):
                stepLine();
                return HasText(fillHExpressions(text));
            case IncludeFile(path):
                stepLine();
                loadScript(directory + path);
                return processNextLine();
            case Divert(target):
                return gotoSection(target);
            // When a section is declared, skip to the end of its file
            case DeclareSection(_):
                var nextLineFile = "";
                do {
                    stepLine();
                    nextLineFile = scriptLines[currentLine].sourceFile;
                    // debugTrace(nextLineFile);
                } while (nextLineFile == file);
                // debugTrace('${file} != ${nextLineFile}');
                return processNextLine();
            case HaxeLine(code):
                processHaxeBlock(code);
                stepLine();
                return processNextLine();
            case DeclareChoice(choice):
                if (choice.depth > choiceDepth) {
                    choiceDepth = choice.depth;
                }
                return HasChoices([for (choice in collectChoicesToDisplay()) choice.text]);
            // TODO remove the default case after everything is implemented
            default:
                stepLine();
                return processNextLine();
        }
    }

    /**
    Parse haxe expressions in the text
    **/
    function fillHExpressions(text: String) {
        while (Util.containsEnclosure(text, "{", "}")) {
            var expression = Util.findEnclosure(text,"{","}");
            // debugTrace(expression);
            var parsed = parser.parseString(expression);
            text = Util.replaceEnclosure(text, Std.string(interp.expr(parsed)), "{", "}");
        }
        return text;
    }

    /**
    Make a choice for the player.
    @param index A valid index of the choice list returned by nextFrame()
    @return the choice output.
    **/
    public function choose(index: Int): String {
        // TODO remove * choices from scriptLines
        return "";
        /*
        if (choicesFullText.length == 0) {
            trace("Error! Trying to choose when no choices are available!");
        }
        debugTrace('At the start: ${choicesFullText.toString()}');
        var choiceDisplayText = choicesFullText[index];
        debugTrace('Choosing: ${choiceDisplayText}');
        choiceDisplayText = StringTools.ltrim(StringTools.ltrim(choiceDisplayText).substr(choiceDepth));

        // Remove initial condition 
        if (Util.startsWithEnclosure(choiceDisplayText, "{","}")) {
            choiceDisplayText = StringTools.ltrim(Util.replaceEnclosure(choiceDisplayText, "", "{", "}"));
        }
        // remove the contents of the brackets,
        if (Util.containsEnclosure(choiceDisplayText, "[", "]")) {
            choiceDisplayText = Util.replaceEnclosure(choiceDisplayText, "", "[", "]");
        }
        // interpolate expressions in, etc.
        choiceDisplayText = fillHExpressions(choiceDisplayText);

        // set the current line to the line following this choice. Set the current depth to that depth 
        var nextLine = findNextLineAfterChoice(index);
        currentLine = nextLine;
        choiceDepth = depthOf(choicesFullText[index]);

        // When a * choice is chosen, remove its line from scriptLines so it doesn't appear again
        // Update the current index to reflect the removed line
        if (StringTools.startsWith(StringTools.ltrim(choicesFullText[index]), "*")) {
            // debugTrace('Length: ${scriptLines.length}');
            // debugTrace('indexOf: ${scriptLines.indexOf(choicesFullText[index])}');
            scriptLines.remove(choicesFullText[index]);
            // debugTrace('Length: ${scriptLines.length}');
            if (currentLine > index) currentLine -= 1;
        }

        // Stop storing the full text of these choices so we don't accidentally trigger them later.
        choicesFullText = new Array<String>();
        debugTrace('After clearing: ${choicesFullText.toString()}');

        return choiceDisplayText;
        */
    }

//    function skipToGather() {
//        debugTrace('depth: ${choiceDepth}');
//        var gatherOfThisDepth = StringTools.lpad("", "-", choiceDepth);
//        var l = currentLine+1;
//        var foundIt = false;
//        debugTrace(l);
//        debugTrace(scriptLines[l]);
//        while (l < scriptLines.length && scriptLines[l] != "EOF") {
//            var trimmed = StringTools.ltrim(scriptLines[l]);
//            if (trimmed.length == 0) { 
//                l += 1;
//                continue;
//            }
//            if (StringTools.startsWith(StringTools.ltrim(scriptLines[l]), "==")) {
//                break;
//            }
//            if (StringTools.startsWith(trimmed, gatherOfThisDepth)) {
//                // -> diverts can trip false gather positives
//                var possibleGather = trimmed.substr(0, gatherOfThisDepth.length + 1);
//                if (StringTools.endsWith(possibleGather, ">")) {
//                    l += 1;
//                    continue;
//                }
//                foundIt = true;
//                break;
//            }
//            l += 1;
//        }
//        if (foundIt) {
//            currentLine = l;
//            return processNextLine();
//        } else {
//            return Empty;
//        }
//
//    }
//
//    function findNextLineAfterChoice(choice: Int): Int {
//        // The next line is the first line after the choice with no depth (meaning it's plaintext -- unless a different same-depth choice comes first) or a gather of proper depth
//        var gatherOfThisDepth = StringTools.lpad("", "-", choiceDepth);
//        var choiceLine = scriptLines.indexOf(choicesFullText[choice]);
//        // debugTrace('Choice line: ${choiceLine}');
//        var l = choiceLine+1;
//
//        var metNextInSet = false;
//        var foundIt = false;
//        while (l < scriptLines.length && scriptLines[l] != "EOF") {
//            var trimmed = StringTools.ltrim(scriptLines[l]);
//            if (trimmed.length == 0) { 
//                l += 1;
//                continue;
//            }
//            if (StringTools.startsWith(StringTools.ltrim(scriptLines[l]), "==")) {
//                break;
//            }
//            if (!metNextInSet && StringTools.startsWith(trimmed, "->")) {
//                foundIt = true;
//                break;
//            }
//            if (StringTools.startsWith(trimmed, gatherOfThisDepth)) {
//                // -> diverts can trip false gather positives
//                var possibleGather = trimmed.substr(0, gatherOfThisDepth.length + 1);
//                if (StringTools.endsWith(possibleGather, ">")) {
//                    l += 1;
//                    continue;
//                }
//                foundIt = true;
//                break;
//            }
//            else if (!metNextInSet && depthOf(trimmed) == 0) {
//                foundIt = true;
//                break;
//            }
//            else if (!metNextInSet && depthOf(trimmed) == choiceDepth+1) {
//                foundIt = true;
//                break;
//            } else if (depthOf(trimmed) == choiceDepth) {
//                debugTrace('${trimmed} is next in set');
//                metNextInSet = true;
//                l += 1;
//                continue;
//            }
//
//        }
//        if (!foundIt) {
//            debugTrace("no next line found!");
//            return -1; // Need to throw up an empty frame
//        } else {
//            debugTrace('Next line is: ${scriptLines[l]}');
//            return l;
//        }
//    }
//
    /**
    Handle choice declarations starting at the current script line
    **/
    function collectRawChoices(): Array<Choice> {
        var choices = new Array();
        // Scan for more choices in this set until hitting a new section declaration, a gather of the right depth, or the end of this file
        var file = scriptLines[currentLine].sourceFile;
        var nextLineFile = file;
        var l = currentLine;
        while (scriptLines[l].sourceFile == file) { // check for EOF

            var type = scriptLines[currentLine].type;
            switch (type) {
                // Collect choices of the current depth
                case DeclareChoice(choice):
                    choices.push(choice);
                // Stop searching when we hit a gather of the current depth
                case Gather(choiceDepth,_):
                    break;
                default:
            }

            nextLineFile = scriptLines[l++].sourceFile;
            // debugTrace(nextLineFile);
        }

        return choices;
    }

    private function checkChoiceCondition(choice: Choice): Bool {
        return if (Util.startsWithEnclosure(choice.text, "{", "}")) {
            var conditionExpression = Util.findEnclosure(choice.text, "{", "}");
            var parsed = parser.parseString(conditionExpression);
            var conditionValue = interp.expr(parsed);
            conditionValue;
        } else true;
    }

    private function choiceToDisplay(choice: Choice, chosen: Bool): Choice {
        if (Util.startsWithEnclosure(choice.text, "{", "}")) {
            choice.text = StringTools.trim(Util.replaceEnclosure(choice.text, "", "{", "}"));
        }
        // If it's been chosen, drop the bracket contents and keep what's next
        if (chosen) {
            choice.text = Util.replaceEnclosure(choice.text, "", "[", "]");
        } else {
            choice.text = choice.text.substr(0, choice.text.indexOf('[')) + Util.findEnclosure(choice.text, "[", "]");
        }

        choice.text = fillHExpressions(choice.text);
        return choice;
    }

    private function collectChoicesToDisplay(): Array<Choice> {
        var choices = new Array();
        for (choice in collectRawChoices()) {
            // check the choice's condition flag. Skip choices whose flag is not truthy.
            if (checkChoiceCondition(choice)) {
                // fill the choice's h expressions after removing the flag expression
                choices.push(choiceToDisplay(choice, false));
            }
        }
        return choices;
    }

    public function gotoSection(section: String): StoryFrame {
        // this should clear the current choice depth
        choiceDepth = 1;
        // Update this section's view count
        if (!interp.variables.exists(section)) {
            throw 'Tried to divert to undeclared section ${section}.';
        }
        interp.variables[section] += 1;
        for (line in 0...scriptLines.length) {
            if (scriptLines[line].type.equals(DeclareSection(section))) {
                gotoLine(line);
            }
        }
        // Step past the section declaration to the first line of the section
        stepLine();
        return processNextLine();
    }
}
