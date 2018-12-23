package src;

typedef HankLine = {
    sourceFile: String;
    lineNumber: Int;
    type: LineType;
}

enum LineType {
    IncludeFile(path: String);
    OutputText(text: String);
    DeclareChoice(text: String, depth: Int);
    DeclareSection(name: String);
    Divert(target: String);
    Gather(depth: Int, restOfLine: LineType);
    HaxeCode(code: String);
    Empty;
}