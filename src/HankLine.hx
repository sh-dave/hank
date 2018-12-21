package src;

typedef HankLine = {
    sourceFile: String;
    lineNumber: Int;
    type: LineType;
}

enum LineType {
    IncludeFile(path: String);
    OutputText(text: String);
    // Choices are parsed with a unique ID so they can be followed even if duplicate text is used for multiple choices
    DeclareChoice(text: String, depth: Int, id: Int);
    DeclareSection(name: String);
    Divert(target: String);
    Gather(depth: Int, restOfLine: LineType);
    HaxeLine(code: String);
    HaxeBlock(code: String);
    Empty;
}