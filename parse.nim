import std/parseopt

type
  nodeType = enum
    dictNodeType,
    stringNodeType,
    integerNodeType,
    listNodeType,
    unknownNodeType,

type
  Node = ref object of RootObj
    node_type: nodeType
    child: seq[Node]
    strValue: string
    intValue: int

type
  lineCursor = ref object
    value: int
    line: string
method empty(self: lineCursor): bool {.base.} = 
    return self.value >= self.line.len
method current(self: lineCursor): char {.base.} = 
    if self.value >= self.line.len:
        return 'e'
    return self.line[self.value]
method currentToInt(self: lineCursor): int {.base.} = 
    return int(self.line[self.value])
method advance(self: lineCursor) {.base.} = 
    self.value += 1
method moveTo(self: lineCursor, val: int) {.base.} = 
    self.value = val
method pointingAtDictIdentifier(self: lineCursor): bool {.base.} = 
    return self.current == 'd'
method pointingAtNumber(self: lineCursor): bool {.base.} = 
    var curInt = self.currentToInt()
    return curInt >= 48 and curInt <= 58
method pointingAtListIdentifier(self: lineCursor): bool {.base.} = 
    return self.current() == 'l'
method pointingAtNumberIdentifier(self: lineCursor): bool {.base.} = 
    return self.current() == 'i'
method pointingAtColon(self: lineCursor): bool {.base.} = 
    return self.current == ':'
method pointingAtIterableEnd(self: lineCursor): bool {.base.} = 
    return self.current == 'e'
method readLength(self: lineCursor): int {.base.}= 
    # it must start from a number!
    # the number is parsed and returned, cursor is set after colon

    var lenRead: int = 0

    while true:
        if self.pointingAtColon() or self.pointingAtIterableEnd():
            break

        lenRead = lenRead * 10 + (self.currentToInt() - 48)
        self.advance()

    # move from colon or end
    self.advance()

    return lenRead

method readStringSlice(self: lineCursor): string {.base.} = 
    # it must start from a number!
    # the number is parsed and only then the actual string is read

    var length: int = self.readLength()
    var strBegin: int = self.value
    var strEnd: int = strBegin+length-1
    
    # set the cursor to be after the string red
    self.moveTo(strEnd + 1)

    return self.line[strBegin..strEnd]


proc parseTree(c: lineCursor): Node=

    # trying to read dict
    if c.pointingAtDictIdentifier():
        var rootNode = Node(node_type: nodeType.dictNodeType)

        c.advance()

        while not c.pointingAtIterableEnd:
            var keyNode = Node(node_type: nodeType.stringNodeType, strValue: c.readStringSlice())
            keyNode.child.add(parseTree(c))
            rootNode.child.add(keyNode)

        c.advance()

        return rootNode

    # trying to read string
    elif c.pointingAtNumberIdentifier():
        c.advance()
        return Node(node_type: nodeType.integerNodeType, intValue: c.readLength())

    # trying to read string
    elif c.pointingAtNumber():
        return Node(node_type: nodeType.stringNodeType, strValue: c.readStringSlice())

    elif c.pointingAtListIdentifier():
        var rootNode = Node(node_type: nodeType.listNodeType)

        c.advance()

        while not c.pointingAtIterableEnd:
            var elementNode: Node = parseTree(c)
            rootNode.child.add(elementNode)

        c.advance()

        return rootNode

    else:
        raise newException(IOError, "IO failed")


proc printTree(node: Node, indent: int)=

    if node.node_type == nodeType.dictNodeType:
        stdout.write "{\n"
        for child in node.child:
            printTree(child, indent+1)
            stdout.write "\n"

        for i in 0..indent-1:
            stdout.write "   "

        stdout.write "}"

    elif node.node_type == nodeType.listNodeType:
        stdout.write "[\n"

        for child in node.child:
            printTree(child, indent+1)
            stdout.write "\n"

        for i in 0..indent-1:
            stdout.write "   "

        stdout.write "]"

    elif node.node_type == nodeType.stringNodeType and node.child.len == 0:
        stdout.write node.strValue
        stdout.write ", "

    elif node.node_type == nodeType.stringNodeType:
        for i in 0..indent-1:
            stdout.write "   "

        stdout.write node.strValue

        for child in node.child:
            stdout.write ": "
            printTree(child, indent)

    elif node.node_type == nodeType.integerNodeType:
        for i in 0..indent-1:
            stdout.write "   "

        stdout.write node.intValue
        stdout.write ", "

proc parseFilename(): string = 

    var filename: string = ""

    for kind, key, val in getopt():
        case kind
        of cmdEnd: break
        of cmdShortOption, cmdLongOption:
            discard
        of cmdArgument:
            filename = key

    return filename

proc run() =
    var content = open(parseFilename())
    defer: content.close()

    # TODO: multiline supprt

    var cursor: lineCursor = lineCursor(line: content.readLine())

    var tree: Node = parseTree(cursor)

    printTree(tree, 0)
    echo ""

run()
