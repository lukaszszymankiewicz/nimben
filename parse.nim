import sequtils
import std/parseopt

proc seqToString(str: seq[byte]): string =
  result = newStringOfCap(len(str))
  for ch in str:
    add(result, chr(ch))

  return result

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
    strValue: seq[byte]
    intValue: int

type
  byteCursor = ref object
    cur_idx: int
    raw_bytes: seq[byte]
method empty(self: byteCursor): bool {.base.} = 
    return self.cur_idx >= self.raw_bytes.len
method current(self: byteCursor): char {.base.} = 
    if self.empty():
        return 'e'
    return chr(self.raw_bytes[self.cur_idx])
method currentToInt(self: byteCursor): int {.base.} = 
    return int(self.current())
method advance(self: byteCursor) {.base.} = 
    self.cur_idx += 1
method moveTo(self: byteCursor, val: int) {.base.} = 
    self.cur_idx = val
method pointingAtDictIdentifier(self: byteCursor): bool {.base.} = 
    return self.current() == 'd'
method pointingAtNumber(self: byteCursor): bool {.base.} = 
    return self.currentToInt() >= 48 and self.currentToInt() <= 58
method pointingAtListIdentifier(self: byteCursor): bool {.base.} = 
    return self.current() == 'l'
method pointingAtNumberIdentifier(self: byteCursor): bool {.base.} = 
    return self.current() == 'i'
method pointingAtColon(self: byteCursor): bool {.base.} = 
    return self.current() == ':'
method pointingAtIterableEnd(self: byteCursor): bool {.base.} = 
    return self.current() == 'e'
method readLength(self: byteCursor): int {.base.}= 
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

method readStringSlice(self: byteCursor): seq[byte] {.base.} = 
    # it must start from a number!
    # the number is parsed and only then the actual string is read

    var length: int = self.readLength()
    var strBegin: int = self.cur_idx
    var strEnd: int = strBegin+length-1
    
    # set the cursor to be after the string red
    self.moveTo(strEnd + 1)

    return self.raw_bytes[strBegin..strEnd]


proc parseTree(c: byteCursor): Node=

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
        stdout.write seqToString(node.strValue)
        stdout.write ", "

    elif node.node_type == nodeType.stringNodeType:
        for i in 0..indent-1:
            stdout.write "   "

        stdout.write seqToString(node.strValue)

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
    var f: File 
    var raw: seq[byte]

    if open(f, parseFilename(), fmRead):
        defer: f.close()
        raw = newSeq[byte](f.getFileSize())
        discard f.readBytes(raw, 0, raw.len)
    else:
        echo "failed"
        return

    var bc: byteCursor = byteCursor(raw_bytes: raw)
    var tree: Node = parseTree(bc)

    printTree(tree, 0)
    echo ""

run()
