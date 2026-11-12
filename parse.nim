import strutils
import std/parseopt
import sha


proc seqToString(str: seq[byte]): string =
  result = newStringOfCap(len(str))
  for ch in str:
    if ch != ord('\n'):
        add(result, chr(ch))

  return result

proc numToByteSeq(num: int): seq[byte] =
  var res: seq[byte]

  for char in intToStr(num):
    res.add(cast[byte](ord(char)))

  return res

type
  nodeType = enum
    dictNodeType,
    stringNodeType,
    integerNodeType,
    listNodeType,

type
  Node = ref object of RootObj
    node_type: nodeType
    child: seq[Node]
    byteVals: seq[byte]
    depth: int
method makeIndent(self: Node, add: int=0) {.base.}  =
    for i in 0..self.depth-1+add:
        stdout.write "   "

type
  byteCursor = ref object
    cur_idx: int
    raw_bytes: seq[byte]
method empty(self: byteCursor): bool {.base.} = 
    return self.cur_idx >= self.raw_bytes.len
method current(self: byteCursor): byte {.base.} = 
    if self.empty():
        return ord('e')
    return self.raw_bytes[self.cur_idx]
method currentToInt(self: byteCursor): int {.base.} = 
    return int(self.current())
method advance(self: byteCursor) {.base.} = 
    self.cur_idx += 1
method moveTo(self: byteCursor, val: int) {.base.} = 
    self.cur_idx = val
method pointingAtNumber(self: byteCursor): bool {.base.} = 
    return self.currentToInt() >= 48 and self.currentToInt() <= 58
method pointingAtDictIdentifier(self: byteCursor): bool {.base.} = 
    return self.current() == ord('d')
method pointingAtListIdentifier(self: byteCursor): bool {.base.} = 
    return self.current() == ord('l')
method pointingAtNumberIdentifier(self: byteCursor): bool {.base.} = 
    return self.current() == ord('i')
method pointingAtColon(self: byteCursor): bool {.base.} = 
    return self.current() == ord(':')
method pointingAtIterableEnd(self: byteCursor): bool {.base.} = 
    return self.current() == ord('e')
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

# this method should move cursor by one to omit 'jumping'
method readStringSlice(self: byteCursor): seq[byte] {.base.} = 
    # it must start from a number!
    # the number is parsed and only then the actual string is read

    var length: int = self.readLength()
    var strBegin: int = self.cur_idx
    var strEnd: int = strBegin+length-1
    
    # set the cursor to be after the string red
    self.moveTo(strEnd + 1)

    return self.raw_bytes[strBegin..strEnd]

method readDigit(self: byteCursor): seq[byte] {.base.} = 
    # it must start from a number!
    # the number is parsed and returned, cursor is set after the end
    var digit: seq[byte]

    while not self.pointingAtIterableEnd():
        digit.add(self.current())
        self.advance()

    # move end
    self.advance()

    return digit


proc parseTree(c: byteCursor, depth: int = 0): Node=

    # trying to read dict
    if c.pointingAtDictIdentifier():
        var rootNode = Node(node_type: nodeType.dictNodeType, depth: depth)

        c.advance()

        while not c.pointingAtIterableEnd:
            var keyNode = Node(node_type: nodeType.stringNodeType, byteVals: c.readStringSlice(), depth:depth+1)
            keyNode.child.add(parseTree(c, depth+1))
            rootNode.child.add(keyNode)

        c.advance()

        return rootNode

    # trying to read number
    elif c.pointingAtNumberIdentifier():
        c.advance()
        return Node(node_type: nodeType.integerNodeType, byteVals: c.readDigit(), depth:depth)

    # trying to read string
    elif c.pointingAtNumber():
        return Node(node_type: nodeType.stringNodeType, byteVals: c.readStringSlice(), depth: depth)

    elif c.pointingAtListIdentifier():
        var rootNode = Node(node_type: nodeType.listNodeType, depth: depth)

        c.advance()

        while not c.pointingAtIterableEnd:
            var elementNode: Node = parseTree(c, depth+1)
            rootNode.child.add(elementNode)

        c.advance()

        return rootNode

    else:
        raise newException(IOError, "IO failed")

proc printNodeBinaryDump(node: Node, res: ptr seq[byte]) =
    if node.node_type == nodeType.dictNodeType:
        res[].add(ord('d'))
        for child in node.child:
            printNodeBinaryDump(child, res)
        res[].add(ord('e'))
    elif node.node_type == nodeType.listNodeType:
        res[].add(ord('l'))
        for child in node.child:
            printNodeBinaryDump(child, res)
        res[].add(ord('e'))
    elif node.node_type == nodeType.stringNodeType:
        res[].add(numToByteSeq(node.byteVals.len))
        res[].add(ord(':'))
        res[].add(node.byteVals)
        for child in node.child:
            printNodeBinaryDump(child, res)
    else:
        res[].add(ord('i'))
        res[].add(node.byteVals)
        res[].add(ord('e'))
        for child in node.child:
            printNodeBinaryDump(child, res)

proc printNodeForHumans(node: Node) = 
    if node.node_type == nodeType.dictNodeType:
        stdout.write 'd'
        for child in node.child:
            printNodeForHumans(child)
        stdout.write 'e'
    elif node.node_type == nodeType.listNodeType:
        stdout.write 'l'
        for child in node.child:
            printNodeForHumans(child)
        stdout.write 'e'
    elif node.node_type == nodeType.stringNodeType:
        for b in numToByteSeq(node.byteVals.len):
            stdout.write chr(b)
        stdout.write ':'
        for b in node.byteVals:
            stdout.write chr(b)
        for child in node.child:
            printNodeForHumans(child)
    else:
        stdout.write 'i'
        for b in node.byteVals:
            stdout.write chr(b)
        stdout.write 'e'
        for child in node.child:
            printNodeForHumans(child)


proc printNodeTreeForHumans(node: Node)=

    if node.node_type == nodeType.dictNodeType:
        stdout.write "\n"
        node.makeIndent()
        stdout.write "{"

        for child in node.child:
            if child.node_type == nodeType.stringNodeType or child.node_type == nodeType.stringNodeType:
                stdout.write "\n"
            child.makeIndent()
            printNodeTreeForHumans(child)

        stdout.write "\n"
        node.makeIndent()
        stdout.write "}"

    elif node.node_type == nodeType.listNodeType:
        stdout.write "\n"
        node.makeIndent()
        stdout.write "["

        for child in node.child:
            if child.node_type == nodeType.stringNodeType or child.node_type == nodeType.stringNodeType:
                stdout.write "\n"
            child.makeIndent()
            printNodeTreeForHumans(child)

        stdout.write "\n"
        node.makeIndent()
        stdout.write "]"

    else:
        stdout.write seqToString(node.byteVals)

        for child in node.child:
            stdout.write ": "
            printNodeTreeForHumans(child)

proc findInfoNode(tree: Node): Node =
    if seqToString(tree.byte_vals) == "info":
        assert tree.child.len == 1 
        return tree.child[0]

    for child in tree.child:
        let n: Node = findInfoNode(child)
        if n != nil:
            return n

    return nil

# TODO: this to sume utils (?)
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

proc getBinaryDump(tree: Node): seq[byte] =
    var res: seq[byte]
    printNodeBinaryDump(tree, res.addr)

    return res

proc createNodeTreeFromTorrentFile() =
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
    var infoNode: Node = findInfoNode(tree)
    # printNodeTreeForHumans(infoNode)
    var res: seq[byte] = getBinaryDump(infoNode)

    var sha: string = sha.generateSHA1Hash(res)
    echo sha

createNodeTreeFromTorrentFile()
